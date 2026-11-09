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
| **firmware** | Small programs loaded into a chip (Wi-Fi, graphics) when its driver starts. |
| **kernel module / driver** | A piece of the kernel for one kind of hardware, loaded only when needed. |
| **NoExtract** | A pacman setting: files that match are not unpacked when a package is installed. We use it to leave out docs, translations and unused drivers. |
| **zram** | Swap space inside RAM, compressed. Lets a small RAM hold more without a slow disk. |
| **TLP / thermald** | Battery saving settings / Intel CPU temperature control. |

## Folders

```
mipos.conf             All decisions in one file. The scripts read it.
archiso/               The archiso profile (copied and filled in from mipos.conf)
  profiledef.sh          ISO name, boot method (UEFI), compression
  packages.x86_64        Packages on the live ISO
  pacman.conf            pacman settings used while building
  efiboot/               Boot menu of the ISO (systemd-boot)
  airootfs/              Files copied into the live system (/etc/..., /usr/...)
    etc/pacman.d/mipos-noextract.conf   the size-trimming rules (NoExtract)
    usr/local/bin/mipos-install         the installer
    usr/share/mipos/answers.example     answers file for unattended installs
scripts/               The build steps, numbered, run in order
  00-host-setup.sh       install archiso on the (Arch) build computer
  10-make-profile.sh     copy archiso/ to out/profile, fill in @NAMES@ from mipos.conf
  15-check-packages.sh   check every package exists in Arch's repos
  20-build-iso.sh        build the ISO with mkarchiso, write its checksum
  25-check-modules.sh    check the needed drivers survived the trimming
  30-size-report.sh      write out/size-report.txt (what takes the space)
  build.sh               runs 00 -> 30 (what GitHub runs)
  get-iso.sh             download the newest ISO from GitHub and check it
  test-vm.sh             start the ISO (or, with --no-iso, the installed system) in a VM
  make-test-disk.sh      new VM test disk: "empty" or "windows" (fake Windows, for dual boot)
reports/               Size reports kept for comparison (size-A1.txt = first build)
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

## Using the live system

- **Cable:** connects by itself.
- **Wi-Fi:** type `iwctl`, then inside it:
  `device list` (your Wi-Fi card, usually `wlan0`),
  `station wlan0 scan`, `station wlan0 get-networks`,
  `station wlan0 connect "Network name"` (asks for the password), `exit`.
  Check with `ping -c 3 archlinux.org`.
- **Sound:** `alsamixer` sets the volume (M = mute on/off, Esc = quit);
  `speaker-test -c 2 -t wav -l 1` says "front left, front right".
- **Power off:** `poweroff`.

## Installing: mipos-install

On the live system, type `mipos-install`. Its screens are plain text with
colors (no extra program needed): arrow keys and Enter to pick, typing to
search the long lists (language, keyboard, timezone), Esc to quit. It asks, in
this order:

1. **Network**: cable connects by itself; otherwise pick a Wi-Fi network, or
   skip. Internet is only used to update the new system at the end.
2. **Language and keyboard** (the keyboard layout applies right away).
3. **Timezone** (region, then city).
4. **Computer name**.
5. **Your user** (full name, username, password). Your user may use `sudo`;
   the root account is locked.
6. **Disk**: which disk, then **Erase the whole disk** or **Use free space**
   (keeps Windows; only offered when there is enough free space).
7. **Encryption** (yes/no, and its password).
8. **Summary**: nothing is changed until you type `yes`.

How it installs: it **copies the live system** to the disk (so it works without
internet), then sets it up as an installed system:

| Part | What mipOS does |
|---|---|
| Partitions | Erase mode: 1 GB EFI partition + the rest for mipOS. Free-space mode: the same two partitions inside the largest free area; Windows' partitions and its EFI partition are never changed. |
| Encryption | Optional LUKS2 (argon2id) on the mipOS partition. The EFI partition (kernel, boot menu) stays unencrypted. One password at start. |
| File system | Btrfs, subvolumes `@ @home @var_log @var_cache @swap`, `noatime,compress=zstd:1`. |
| Hibernation | A swap file the size of RAM in `@swap`; `systemctl hibernate` works. |
| Boot menu | GRUB (UEFI). With Windows on the disk, the menu shows for 5 s with a Windows entry. |
| Tuning | zram, TLP, thermald, small journal, size trimming for future packages. |

Log: `/var/log/mipos-install.log` (copied to the new system). The disk space used
is shown at the end and saved in `/var/log/mipos-install-size.txt`.

Options:

- `mipos-install --dry-run`: ask everything and show the summary, change nothing.
- `mipos-install --config answers.conf`: unattended install. Start from
  `/usr/share/mipos/answers.example`; it only installs with `CONFIRM=yes`.

**Dual boot with Windows:** first, in Windows, open *Disk Management*, shrink
the Windows partition (leave at least 13 GB + your RAM size free), and switch off
*Fast Startup* (Control Panel → Power Options). Windows keeps the hardware clock
in local time, Linux in UTC; if the clock is off after switching, run this once
in Windows (admin): `reg add HKLM\System\CurrentControlSet\Control\TimeZoneInformation /v RealTimeIsUniversal /t REG_DWORD /d 1 /f`.

## Size trimming

`archiso/airootfs/etc/pacman.d/mipos-noextract.conf` lists files pacman
leaves out: documentation, man/info pages, translations, firmware for chips
mipOS doesn't use (cameras, sound DSPs, server network cards) and kernel
drivers for hardware it doesn't support (AMD/NVIDIA graphics, non-Intel
Wi-Fi, most Ethernet cards except Intel and Realtek, webcams, rare file
systems...). After each build, `scripts/25-check-modules.sh` checks that
every driver in `MUST_HAVE_MODULES` (mipos.conf) is there and can load, and
fails the build if not.

To get something back, put `!` in front of its pattern (or delete the line)
and rebuild. On an installed system, reinstall the package afterwards
(`sudo pacman -S <package>`).

The size report compares every build with `reports/size-A1.txt`.

## Milestones

Full test checklist (A2–A4): [TESTING.md](TESTING.md).

| | Goal | It works when... |
|---|---|---|
| **A1** | Minimal ISO built on GitHub | The VM boots to `mipos login: root (automatic login)` and a `root@mipos` prompt; the size report is shown. |
| **A2** | Lightweight tuning + size trimming | Wi-Fi and cable work on the live system; size report compared with A1. |
| **A3** | `mipos-install` (erase whole disk, with and without encryption) | The installed system boots and you can log in. |
| **A4** | Dual boot (free space next to Windows) + hibernation | Both tested in a VM. |

## Decisions (details in `mipos.conf`)

- **Base:** Arch Linux, official repos only (AUR only if approved per package), x86_64, UEFI only.
- **Kernel:** Arch's stock `linux`, unused drivers left out with pacman `NoExtract`.
- **Interface:** text only. **Init:** systemd.
- **Network:** iwd (Wi-Fi) + systemd-networkd + systemd-resolved.
- **Live ISO:** logs in as root automatically on the first screen.
- **Installer:** `mipos-install` (plain bash, colored text menus, type-to-search lists): network, language and keyboard,
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
- **Size:** no docs/man pages/translations, only Intel firmware
  (`linux-firmware-intel`, `sof-firmware` for sound), unused kernel modules
  left out. Sound works through ALSA (`alsamixer` for volume). No developer tools (gcc, make, python) by default.
