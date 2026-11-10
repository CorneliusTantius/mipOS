# mipOS

A small, battery-friendly, text-only Linux for **one laptop: the Lenovo
ThinkPad L14 Gen 5 (21L2) with an Intel Core Ultra 5 135U** (Meteor Lake).

mipOS is based on [Arch Linux](https://archlinux.org). It keeps only the
drivers and firmware this laptop uses, tunes it for battery life, and comes as
a **live USB stick (ISO)** with its own text installer, `mipos-install`. The
ISO is built on GitHub from the files in this repo, so every rebuild is the
same.

| | |
|---|---|
| **Made for** | ThinkPad L14 Gen 5 (21L2), Intel Core Ultra 5 135U. Other hardware can be added: [docs/HARDWARE.md](docs/HARDWARE.md) |
| **Base** | Arch Linux (official packages, updated with `pacman`), x86_64, UEFI only |
| **Interface** | Text only, or with the MangoWM desktop (Waybar bar, Ctrl+Space launcher, foot terminal, black-and-white look): chosen in the installer or added later with `sudo mipos-add-desktop` (needs internet) |
| **Network** | Wi-Fi with `iwctl`, cable automatic, phone USB tethering; Bluetooth with `bluetoothctl` |
| **Install** | Erase the disk, or use free space next to Windows; optional disk encryption; hibernation |
| **Battery** | power-saver on battery, device power saving, zram, thermald |
| **Size** | ISO about 240 MB; installed system about 430 MB plus a swap file the size of RAM (each build's size report shows the exact numbers) |

Earlier versions (Ubuntu-based, then Linux From Scratch) are in the git history.

## What works on the laptop

| Part | Status |
|---|---|
| Graphics (Intel Meteor Lake), incl. external screens over USB-C / Thunderbolt | Works |
| Wi-Fi (Intel AX211) | Works |
| Bluetooth (Intel AX211) | Works (`bluetoothctl` to pair and connect) |
| Sound: speakers, microphone, HDMI, USB headsets | Works (ALSA, `alsamixer`) |
| Ethernet (Intel I219-LM) | Works |
| Webcam | Works (driver loaded) |
| Keyboard, touchpad, TrackPoint, ThinkPad buttons, battery, temperature sensors | Works |
| NVMe disk, USB sticks, Windows (NTFS) partitions | Works |
| Phone USB tethering, USB-to-Ethernet adapters | Works |
| AI chip (NPU), fingerprint/smartcard readers | Not included |

Everything else (other laptops' chips, other Wi-Fi brands, AMD/NVIDIA
graphics...) is left out to save space and can be added back with two list
entries and `pacman`: see [docs/HARDWARE.md](docs/HARDWARE.md).

## Quick start: install on the ThinkPad

1. **Get the ISO.** Either run the build on GitHub (see
   [Building](#building-on-github)) and download it, or on Linux with the
   GitHub CLI, in this repo's folder:
   ```bash
   scripts/get-iso.sh
   ```
2. **Write it to a USB stick** (everything on the stick is erased). Find the
   stick's name with `lsblk` (e.g. `/dev/sdb`), then:
   ```bash
   sudo dd if=out/download/iso/mipos-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
   ```
3. **Switch off Secure Boot** (once): start the laptop, press **F1** for the
   BIOS setup → *Security* → *Secure Boot* → *Off*, save with **F10**.
4. **Start from the stick:** plug it in, start the laptop, press **F12** and
   pick the USB stick. mipOS logs in as root by itself.
5. **Install:** type `mipos-install` and answer the 8 questions (details in
   [Installing](#installing-mipos-install)). Nothing changes on the disk until
   you type `yes` on the summary.
6. Remove the stick, restart, log in with your user.

## Using mipOS

| Task | Command |
|---|---|
| Wi-Fi | `iwctl`, then `station wlan0 scan`, `station wlan0 get-networks`, `station wlan0 connect "Name"`, `exit` |
| Check the internet | `ping -c 3 archlinux.org` |
| Bluetooth | `bluetoothctl`, then `scan on`, `pair <address>`, `connect <address>`, `exit` (keyboards and mice work right away; Bluetooth headphones also need a sound server such as PipeWire, not included yet) |
| Update everything | `sudo pacman -Syu` |
| Install a program | `sudo pacman -S <name>` (search: `pacman -Ss <word>`) |
| Volume / test speakers | `alsamixer` (M = mute, Esc = quit) / `speaker-test -c 2 -t wav -l 1` |
| Power mode | `powerprofilesctl` (see) / `powerprofilesctl set performance` (change); battery switches to power-saver by itself |
| Hibernate | `systemctl hibernate` |
| Hardware help | `less /usr/share/mipos/HARDWARE.md` |
| Power off / restart | `poweroff` / `reboot` |

## Installing: mipos-install

On the live system, type `mipos-install`. Its screens are plain text with
colors: arrow keys and Enter to pick, typing to search the long lists
(language, keyboard, timezone), Esc to quit. It asks, in this order:

1. **Network**: cable connects by itself; otherwise pick a Wi-Fi network, or
   skip. Internet is only used to update the new system at the end.
2. **Language and keyboard** (the keyboard layout applies right away).
3. **Timezone**.
4. **Computer name**.
5. **Your user** (full name, username, password). Your user may use `sudo`;
   the root account is locked.
6. **Disk**: which disk, then **Erase the whole disk** or **Use free space**
   (keeps Windows; only offered when there is enough free space).
7. **Encryption** (yes/no, and its password).
8. **Summary**: nothing is changed until you type `yes`.

It **copies the live system** to the disk (so it works without internet), then
sets it up as an installed system:

| Part | What mipOS does |
|---|---|
| Partitions | Erase mode: 1 GB EFI partition + the rest for mipOS. Free-space mode: the same two partitions inside the largest free area; Windows' partitions and its EFI partition are never changed. |
| Encryption | Optional LUKS2 (argon2id) on the mipOS partition. The EFI partition (kernel, boot menu) stays unencrypted. One password at start. |
| File system | Btrfs, subvolumes `@ @home @var_log @var_cache @swap`, `noatime,compress=zstd:1`. |
| Hibernation | A swap file the size of RAM in `@swap`; `systemctl hibernate` works. |
| Boot menu | GRUB (UEFI). With Windows on the disk, the menu shows for 5 s with a Windows entry. |
| Battery and size | Same as the live system: power rules, zram, thermald, small journal; the hardware and size trimming keep working after updates. |

The log is `/var/log/mipos-install.log` (copied to the new system); the disk
space used is shown at the end and saved in `/var/log/mipos-install-size.txt`.

Options:

- `mipos-install --dry-run`: ask everything and show the summary, change nothing.
- `mipos-install --config answers.conf`: unattended install. Start from
  `/usr/share/mipos/answers.example`; it only installs with `CONFIRM=yes`.

**Dual boot with Windows:** first, in Windows, open *Disk Management*, shrink
the Windows partition (leave at least 13 GB + your RAM size free), and switch
off *Fast Startup* (Control Panel → Power Options). Windows keeps the hardware
clock in local time, Linux in UTC; if the clock is off after switching, run
this once in Windows (admin):
`reg add HKLM\System\CurrentControlSet\Control\TimeZoneInformation /v RealTimeIsUniversal /t REG_DWORD /d 1 /f`.

## How mipOS stays small

1. **Only this laptop's drivers and firmware.** Two lists say what to keep:
   `archiso/airootfs/etc/mipos/keep-modules` (drivers) and `keep-firmware`
   (firmware files). After every kernel or firmware install or update, a
   pacman hook runs `/usr/local/sbin/mipos-trim-hardware`, which deletes
   everything not on the lists (and Intel Wi-Fi firmware versions the kernel
   can't load). Same on the live ISO and the installed system.
2. **No documentation or developer files.** The rules in
   `archiso/airootfs/etc/pacman.d/mipos-noextract.conf` make pacman skip
   documentation, man pages, translations, C headers and static libraries, most
   terminal descriptions and GRUB's old-BIOS parts.
3. **Light packages.** power-profiles-daemon instead of TLP (no perl), plain
   bash for the installer screens, no developer tools.

Every build checks that each driver in `MUST_HAVE_MODULES` and each firmware
file in `MUST_HAVE_FIRMWARE` (mipos.conf) is present and can load, and fails
if not. The size report compares each build with the one named in
`SIZE_BASELINE`; older reports are in `reports/`.

## Building (on GitHub)

The build runs only when you start it:

1. On GitHub, open **Actions** → **Build ISO** → **Run workflow**.
2. Under **Use workflow from**, pick the branch, then **Run workflow**. It
   takes about 15–25 minutes.
3. The finished run's **Summary** page shows the size report and has the
   download **mipos-iso** (ISO + checksum + size report, kept 14 days).

From the terminal (GitHub CLI): `gh workflow run build-iso.yml --ref main`.

GitHub's servers run Ubuntu, so the build runs inside an **Arch Linux
container**. Downloaded packages are cached, so the next build only downloads
what changed. On an Arch Linux computer you can also build locally:
`sudo scripts/build.sh`.

## Testing in a virtual machine

The ISO also runs in QEMU (with UEFI) on any Linux computer, for testing the
installer without touching the laptop. The VM imitates the ThinkPad where QEMU
can: NVMe disk, Intel Ethernet (e1000e), Intel HD Audio, USB 3, the laptop's
name in the firmware tables, and (on the ThinkPad itself) its real CPU; the
screen is 1280×720 (`VM_RESOLUTION` in mipos.conf). One-time setup (Ubuntu):

```bash
sudo apt install qemu-system-x86 qemu-utils ovmf gh gdisk dosfstools mtools
```

Then for each build:

```bash
scripts/get-iso.sh
```

```bash
scripts/test-vm.sh
```

`test-vm.sh` boots the ISO with a 20 GB test disk (`out/vm/disk.qcow2`);
`scripts/test-vm.sh --no-iso` boots the installed system on it.
`scripts/make-test-disk.sh empty` gives a fresh disk; `windows` or `ubuntu`
instead of `empty` gives a disk with a fake Windows or Ubuntu plus free space
(for install-alongside tests). The full checklist is
[TESTING.md](TESTING.md). In the VM, the laptop-only parts (Wi-Fi, sound,
webcam) can't be tested; the checklist has a laptop section for those.

## Folders

```
mipos.conf             All decisions in one file. The scripts read it.
archiso/               The archiso profile (copied and filled in from mipos.conf)
  profiledef.sh          ISO name, boot method (UEFI), compression
  packages.x86_64        Packages on the ISO (and the installed system)
  pacman.conf            pacman settings used while building
  efiboot/               Boot menu of the ISO (systemd-boot)
  airootfs/              Files copied into the system (/etc/..., /usr/...)
    etc/mipos/keep-modules, keep-firmware   this laptop's drivers and firmware
    etc/pacman.d/mipos-noextract.conf       files pacman leaves out
    etc/udev/rules.d/50-mipos-power.rules   battery saving rules
    usr/local/bin/mipos-install             the installer
    usr/local/sbin/mipos-trim-hardware      applies the keep lists
    usr/local/sbin/mipos-power-source       battery / charger power mode
    usr/share/mipos/answers.example         answers file for unattended installs
scripts/               Build steps (numbered, run in order) and helpers
  00-host-setup.sh       install archiso on the (Arch) build computer
  10-make-profile.sh     copy archiso/ to out/profile, fill in values from mipos.conf
  15-check-packages.sh   check every package exists in Arch's repos
  20-build-iso.sh        build the ISO with mkarchiso, write its checksum
  25-check-modules.sh    check the laptop's drivers and firmware survived the trimming
  30-size-report.sh      write out/size-report.txt (what takes the space)
  build.sh               runs 00 -> 30 (what GitHub runs)
  get-iso.sh             download the newest ISO from GitHub and check it
  test-vm.sh             start the ISO (or the installed system) in a VM
  make-test-disk.sh      new VM test disk: "empty", "windows" or "ubuntu"
docs/HARDWARE.md       What hardware works, and adding drivers/firmware for more
TESTING.md             Test checklist (VM and laptop)
reports/               Size reports kept for comparison
.github/workflows/     The GitHub build (manual start only)
out/                   Everything the build makes (not stored in git)
```

## Decisions (details in `mipos.conf`)

- **Hardware:** ThinkPad L14 Gen 5 (21L2), Intel Core Ultra 5 135U only; drivers
  and firmware trimmed to this laptop (+ USB sticks, encryption, VM testing,
  webcam, tethering, USB sound, NTFS).
- **Base:** Arch Linux, official repos only (AUR only if approved per package),
  x86_64, UEFI only (Secure Boot off).
- **Kernel:** Arch's stock `linux`, trimmed by the keep lists.
- **Interface:** text only (tty login, no greeter). Optional MangoWM + Waybar + fuzzel + foot, installed from the official repos on request, never part of the ISO. **Init:** systemd.
- **Network:** iwd (Wi-Fi) + systemd-networkd + systemd-resolved.
- **Live ISO:** logs in as root automatically on the first screen; xz compressed.
- **Installer:** `mipos-install`, plain bash with colored text menus; unattended
  mode with `--config`.
- **Disk:** 1 GB EFI partition at `/boot` (kernel, not encrypted), Btrfs with
  subvolumes `@ @home @var_log @var_cache @swap`, `noatime,compress=zstd:1`, no
  snapshots; swap file the size of RAM for hibernation; optional LUKS2
  (argon2id) for everything except `/boot`. Boot loader: GRUB.
- **Battery:** power-profiles-daemon (power-saver on battery, balanced on the
  charger) + mipOS rules (USB, PCI, SATA, sound power saving, PCIe ASPM),
  thermald, zram (zstd, 50% of RAM), journal max 50 MB, short stop timeout,
  unneeded timers off, kernel options `quiet loglevel=3 nowatchdog zswap.enabled=0`.
- **Size:** no docs, man pages, translations, headers or static libraries; no
  developer tools by default (see [docs/HARDWARE.md](docs/HARDWARE.md) to add them).

## Desktop keys (optional MangoWM desktop)

| Keys | Does |
|---|---|
| **Ctrl+Space** or **Super+Space** | Launcher (type, Enter); the red dot on the bar opens it too |
| **Alt+Enter** | Terminal (foot) |
| **Alt+Q** | Close the window |
| **Alt+arrows** | Move focus between windows (they scroll sideways) |
| **Super+arrows** / **Ctrl+1..9** | Switch tag (workspace); **Alt+1..9** moves the window there |
| **Super+N** | Switch layout (starts as scroller) |
| **Super+R** | Reload the settings |
| **Super+M** | Quit the desktop (back to the text shell) |
| Fn keys | Brightness, volume, mute, microphone mute |
| **Print** / **Shift+Print** | Screenshot of an area: to the clipboard / to `~/screenshot-DATE.png` |

Also installed with the desktop: PipeWire (sound), notifications (mako),
screenshots (grim, slurp, wl-clipboard), brightness keys (brightnessctl) and
udiskie (USB sticks mount by themselves under `/run/media/YOURNAME/`, with a
notification; `udiskie-umount -a` unmounts them before you pull them out).
Closing the lid puts the laptop to sleep (s2idle); `systemctl hibernate` still
hibernates. No browser is included: add one with `pacman -S`.

Settings are in `~/.config/mango`, `waybar`, `fuzzel`, `foot` and `mako` (copies of
`/usr/share/mipos/desktop`). Colors: black, white, grey and red `#d71921`.

## Status

| Part | Status |
|---|---|
| Live ISO built on GitHub, boots in a VM | Done |
| Battery tuning, size trimming, Wi-Fi and cable on the live system | Built; laptop checks open |
| Install: erase the disk without encryption | Tested in the VM |
| Install: with encryption, next to Windows or Ubuntu, hibernation | Open |
| Optional MangoWM desktop | Built; not tested yet |

Test steps for each: [TESTING.md](TESTING.md).

## Words used in this project

| Word | Meaning |
|---|---|
| **distribution (distro)** | A complete Linux system: kernel + programs + settings, ready to install. |
| **Arch Linux** | The distro mipOS is built on. Small and always up to date ("rolling"). |
| **package / pacman** | A program ready to install / Arch's tool that installs, updates and removes packages. |
| **AUR** | Arch User Repository: community build recipes, not official. Only used if approved per package. |
| **kernel** | The core program that talks to the hardware. mipOS uses Arch's `linux`. |
| **driver (kernel module)** | A piece of the kernel for one kind of hardware, loaded only when needed. |
| **firmware** | A small program loaded into a chip (Wi-Fi, graphics, sound) when its driver starts. |
| **initramfs** | A small start-up system loaded with the kernel; it finds the real system and starts it. |
| **ISO / live system** | A file holding a bootable disk image / a system that runs straight from it, in memory, without installing. |
| **archiso** | Arch's tool that turns a *profile* (the `archiso/` folder) into an ISO. |
| **UEFI / Secure Boot** | The firmware that starts a PC (replaces old "BIOS") / a UEFI check that only allows signed boot loaders; mipOS needs it off. |
| **NoExtract** | A pacman setting: matching files are not unpacked when a package is installed. |
| **zram** | Compressed swap space inside RAM. |
| **power-profiles-daemon / thermald** | Power modes (power-saver, balanced, performance) / Intel CPU temperature control. |
| **VM, QEMU, OVMF, KVM** | A pretend computer inside your computer; the program that runs it; its UEFI firmware; what makes it fast. |
| **GitHub Actions / artifact** | GitHub's servers running the build when you start it / a file the build produces (the ISO). |
| **TTY** | The plain text screen (no windows, no mouse). |
