# mipOS

mipOS is a personal, light, battery-friendly Linux system based on
[Arch Linux](https://archlinux.org). It is text-only (no desktop), uses
systemd, and comes as a **live ISO** with its own small text installer,
`mipos-install`. The ISO is built on GitHub with **archiso**, Arch's official
ISO builder, from the files in this repo, so every rebuild is the same.

Earlier versions (Ubuntu-based, then Linux From Scratch) are in the git
history.

## Words used in this project

| Word | Meaning |
|---|---|
| **distribution (distro)** | A complete Linux system: kernel + programs + settings, ready to install. |
| **Arch Linux** | The distro mipOS is built on. Small, up to date ("rolling": updates arrive continuously). |
| **package** | One program (or part of one) ready to install, e.g. `iwd`. |
| **pacman** | Arch's package manager: installs, updates and removes packages (`pacman -S iwd`). |
| **repo (package repository)** | Arch's servers holding the official packages (`core`, `extra`). |
| **AUR** | Arch User Repository: community build recipes, not official. Only used if approved per package. |
| **kernel** | The core program that talks to the hardware. We use Arch's stock `linux`. |
| **initramfs** | A small start-up system loaded with the kernel; it finds the real system and starts it. |
| **ISO** | A file holding a whole bootable disc image. Put on a USB stick or start it in a VM. |
| **live system** | A system that runs straight from the ISO, in memory, without installing. |
| **archiso / mkarchiso** | Arch's tool that turns a *profile* (a folder of settings) into an ISO. |
| **profile** | The `archiso/` folder: package list, files to add, boot menu. |
| **squashfs** | The compressed file inside the ISO that holds the live system. |
| **UEFI** | The modern firmware that starts a PC (replaces old "BIOS"). mipOS is UEFI-only. |
| **VM (virtual machine)** | A pretend computer inside your computer. We use **QEMU**; **OVMF** is its UEFI firmware; **KVM** makes it fast. |
| **GitHub Actions / workflow** | GitHub's servers running our build when you click "Run workflow". |
| **artifact** | A file a workflow run produces for download (here: the ISO). |
| **TTY** | The plain text screen (no windows, no mouse). |

## Folders

```
mipos.conf             All decisions in one file. The scripts read it.
archiso/               The archiso profile (copied and filled in from mipos.conf)
  profiledef.sh          ISO name, boot method (UEFI), compression
  packages.x86_64        Packages on the live ISO
  pacman.conf            pacman settings used while building
  efiboot/               Boot menu of the ISO (systemd-boot)
  airootfs/              Files copied into the live system (/etc/..., /usr/...)
scripts/               The build steps, numbered, run in order
  00-host-setup.sh       install archiso on the (Arch) build computer
  10-make-profile.sh     copy archiso/ to out/profile, fill in @NAMES@ from mipos.conf
  15-check-packages.sh   check every package exists in Arch's repos
  20-build-iso.sh        build the ISO with mkarchiso, write its checksum
  30-size-report.sh      write out/size-report.txt (what takes the space)
  build.sh               runs 00 -> 30 (what GitHub runs)
  get-iso.sh             download the newest ISO from GitHub and check it
  test-vm.sh             start the ISO in a QEMU/UEFI virtual machine
.github/workflows/     The GitHub build (manual start only)
out/                   Everything the build makes (not stored in git)
```

## Building (on GitHub)

The build runs only when you start it:

1. On GitHub, open **Actions** → **Build ISO** → **Run workflow**.
2. Under **Use workflow from**, pick the branch.
3. Click **Run workflow**. It takes about 10–20 minutes.
4. Open the finished run. Its **Summary** page shows the size report and
   has the download **mipos-iso** (ISO + checksum + size report, kept 14 days).

From the terminal (needs the GitHub CLI `gh`):

```bash
gh workflow run build-iso.yml --ref main
```

GitHub's servers run Ubuntu, so the build runs inside an **Arch Linux
container** (a small Arch system started only for the build). Downloaded
packages are kept in GitHub's cache, so the next build only downloads what
changed.

On an Arch Linux computer you can build locally: `sudo scripts/build.sh`.

## Testing in a virtual machine (on your computer)

One-time setup (Ubuntu):

```bash
sudo apt install qemu-system-x86 ovmf qemu-utils gh
```

```bash
sudo usermod -aG kvm $USER
```

Then log out and back in (so the `kvm` group applies). Then for each build:

```bash
scripts/get-iso.sh
```

```bash
scripts/test-vm.sh
```

`get-iso.sh` downloads the newest ISO into `out/download/` and checks its
checksum. `test-vm.sh` opens a VM window that boots it with UEFI. It also
attaches an empty 20 GB test disk (`out/vm/disk.qcow2`) for the installer.

## Milestones

| | Goal | It works when... |
|---|---|---|
| **A1** | Minimal ISO built on GitHub | The VM boots to `mipos login: root (automatic login)` and a `root@mipos` prompt; the size report is shown. |
| **A2** | Lightweight tuning + size trimming | Wi-Fi and cable work on the live system; size report compared with A1. |
| **A3** | `mipos-install` (erase whole disk, with and without encryption) | The installed system boots and you can log in. |
| **A4** | Dual boot (free space next to Windows) + hibernation | Both tested in a VM. |

## Decisions (details in `mipos.conf`)

- **Base:** Arch Linux, official repos only (AUR only if approved per package), x86_64, UEFI only.
- **Kernel:** Arch's stock `linux`, unused drivers skipped with pacman `NoExtract` (A2).
- **Interface:** text only. **Init:** systemd.
- **Network:** iwd (Wi-Fi) + systemd-networkd + systemd-resolved.
- **Live ISO:** logs in as root automatically on the first screen.
- **Installer:** `mipos-install` (bash + dialog): network, language and keyboard,
  timezone, hostname, user with sudo (root locked), disk (whole disk or free
  space next to Windows), optional encryption, summary with typed
  confirmation. Unattended mode with `--config answers-file`.
- **Disk:** 1 GB EFI partition mounted at `/boot` (holds the kernel, not
  encrypted), Btrfs with subvolumes `@ @home @var_log @var_cache @swap`,
  `noatime,compress=zstd:1`, no snapshots; hibernation swap file (size of RAM).
  Optional LUKS2 encryption (argon2id) of everything except `/boot`.
  Bootloader: GRUB (Secure Boot off).
- **Light:** zram (zstd, 50% of RAM), TLP + thermald, journal max 50 MB,
  short stop timeout, unneeded timers off, kernel options
  `quiet loglevel=3 nowatchdog zswap.enabled=0`.
- **Size:** no docs/man pages/translations, only Intel firmware, unused
  kernel modules left out. No developer tools (gcc, make, python) by default.
