# mipOS

mipOS is a personal Linux system built **from source** by following
[Linux From Scratch](https://www.linuxfromscratch.org/) (LFS), version
**13.1-systemd**. Every program is compiled from its source code. Each step of
the book is a script in this repo, so a rebuild repeats exactly.

It's a learning project: text-only (no desktop), systemd, a live ISO with a
small text installer. There is no package manager, so updates mean
recompiling (the scripts make that repeatable).

## Words used in this project

| Word | Meaning |
|---|---|
| **LFS** | Linux From Scratch: a book that explains how to build a Linux system from source code, step by step. |
| **source code / tarball** | A program's code, downloaded as a compressed file (`.tar.xz`). |
| **compile** | Turn source code into a program the computer can run. |
| **toolchain** | The compiler (GCC), linker (Binutils) and C library (Glibc): the tools that build everything else. |
| **cross-toolchain** | A toolchain that runs on the build computer but makes programs for the new system (LFS chapter 5). |
| **chroot** | Run programs with a folder (here `/mnt/lfs`) as their root `/`, so they only see the new system. |
| **host** | The computer doing the building (here: GitHub's Ubuntu servers). |
| **init system** | The first program the kernel starts. We use **systemd**. |
| **bootloader** | The program that starts the operating system. We use **GRUB** (UEFI). |
| **stage** | A saved copy of the half-built system, so the next step can continue from it. |

## Folders

```
mipos.conf          All decisions in one file.
lfs/book/           The book's commands, one script per section (generated, don't edit)
  index.tsv           every section, with its package and version
  wget-list, md5sums  the source files and their checksums
  LICENSE             the book's commands are extracted under the MIT License
lfs/overrides/      Our changes to book steps (same file name as in lfs/book/)
lfs/plan/           Which steps run, in which order, per chapter
scripts/            The build steps (numbered) and helpers
tools/extract-book.py  Turns the LFS book (HTML) into lfs/book/
.github/workflows/  The GitHub build
```

## How a step runs

`scripts/pkg.sh ch5/05020-binutils-pass1.sh` does what the book's "general
instructions" say: unpack the package's tarball, go into its folder, run the
book's commands, delete the folder. If `lfs/overrides/` has a file with the
same name, that file is used instead. A marker in `/mnt/lfs/.mipos-done/`
records finished steps, so a rerun continues where it stopped. Each step's
full output goes to `/mnt/lfs/.mipos-logs/<step>.log`.

Test suites (`make check` and similar) only run when `RUN_TESTS=yes`.

## Building (on GitHub)

1. On GitHub, open **Actions** → **Build LFS** → **Run workflow**.
2. Under **Use workflow from**, pick the branch. Leave "Run tests" off.
3. Click **Run workflow**. Milestone L1 takes about 1–2 hours.
4. When it finishes, the run page has **l1-temp-system** (the saved system,
   kept 7 days) and **l1-logs** (one log per package; useful when something fails).

From the terminal: `gh workflow run build-lfs.yml --ref main`

The build steps, in order (the workflow runs them for you):

| Step | Script | LFS chapter |
|---|---|---|
| 00 | `sudo scripts/00-host-tools.sh --change-bin-sh` | 2: build tools; points `/bin/sh` to bash (the book needs it) |
| 01 | `scripts/01-host-check.sh` | 2.2: the book's version check |
| 10 | `sudo scripts/10-prepare.sh` | 3–4: download and check sources, folder layout, `lfs` user |
| 20 | `sudo scripts/20-cross-toolchain.sh` | 5: cross-toolchain (as user `lfs`) |
| 21 | `sudo scripts/21-temp-tools.sh` | 6: temporary tools (as user `lfs`) |
| 30 | `sudo scripts/30-chroot-tools.sh` | 7: enter the chroot, last temporary tools, clean up |
| — | `sudo scripts/save-stage.sh l1-temp-system` | 7.15: save the temporary system |

## Milestones

| | Goal | It works when... |
|---|---|---|
| L1 | Temporary system (chapters 4–7) | The GitHub job finishes and **l1-temp-system** is on the run page. |
| L2 | Base system and lean kernel (chapters 8–10), size reductions | The ISO starts in the VM and shows `mipos login:`; its size is reported. |
| L3 | Live ISO extras: Btrfs, LUKS, GRUB tools, iwd, dialog, TLP, zram | Wi-Fi or cable works on the live system. |
| L4 | `mipos-install` | It installs to a VM disk and the installed system starts. |

## Decisions

All in `mipos.conf`: LFS 13.1-systemd, text only, iwd + systemd-networkd,
installer in bash with `dialog` menus, Btrfs with subvolumes (no snapshots),
optional LUKS2, whole disk or free space next to Windows, hibernation swap
file, GRUB on UEFI, lean kernel for Intel PCs and QEMU, zram, TLP, small logs,
no docs or man pages.

**Secure Boot must be off**: our GRUB and kernel aren't signed by Microsoft.

## Keeping it small

Settings in `mipos.conf`, applied from milestone L2 on. Rough targets: the
finished system about 300–500 MB, the ISO about 150–250 MB (a plain LFS
system after chapter 8 is around 1.5–2.5 GB). Real numbers get measured at L2.

**Kernel** (a distro kernel with modules is 300–400 MB; ours aims for 10–20 MB):

| Setting | What it does |
|---|---|
| No debug info (`DEBUG_INFO`, `DEBUG_INFO_BTF` off) | The biggest saving: modules shrink up to 10× |
| Start from `make defconfig` | Only basic settings, not a distro's "everything" |
| Drivers built in (`KERNEL_BUILTIN`) | Intel graphics and Wi-Fi, NVMe, USB, Btrfs, LUKS, QEMU: few or no module files |
| Unused areas off (`KERNEL_DISABLE`) | AMD/NVIDIA graphics, old filesystems, NFS, staging drivers, 32-bit support… |
| zstd compression, stripped modules | Smaller kernel file, fast to unpack |
| Firmware per driver (`FIRMWARE_FOR`) | Only the files our drivers load, not whole firmware packages |

Trade-off: the kernel only supports the hardware we chose (Intel PCs and QEMU).

**System:**

| Setting | What it does |
|---|---|
| `RUNTIME_ONLY` | Compilers, headers and static libraries stay in the build, not in the ISO. Everything is compiled on GitHub, so the finished system doesn't need them. Runtime libraries like `libstdc++` are kept. |
| `STRIP_BINARIES` | LFS 8.85: remove debug data from every program and library |
| `GLIBC_LOCALES` | One language (`en_US.UTF-8`) instead of hundreds (200+ MB) |
| `STRIP_DOCS` | No docs, man or info pages, no translations |
| Test-only packages | Tcl, Expect, DejaGNU are only for test suites: left out of the ISO |
| zstd compression | ISO image (squashfs) and installed Btrfs |

## Updating to a new LFS book

1. Download the new `LFS-BOOK-<version>-NOCHUNKS.html`, `wget-list` and
   `md5sums` from the LFS site.
2. `python3 tools/extract-book.py LFS-BOOK-<version>-NOCHUNKS.html lfs/book`
3. Copy `wget-list` and `md5sums` into `lfs/book/`, update `LFS_VERSION` and
   `LFS_MIRROR` in `mipos.conf`, and check `lfs/overrides/` still fits.

## Legal

The commands in `lfs/book/` come from the LFS book (© Gerard Beekmans), whose
computer instructions may be extracted under the MIT License (see
`lfs/book/LICENSE`).
