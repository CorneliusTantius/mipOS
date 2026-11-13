# monarch

A small, battery-friendly Linux for Intel laptops, with optional NVIDIA
graphics. It is based on [Arch Linux](https://archlinux.org) and comes as a
**live USB stick (ISO)** with a text installer, `monarch-install`. The ISO is
built on GitHub from the files in this repo.

monarch keeps only the drivers and firmware the supported laptops use, tunes
power use for battery life, and runs as text only or with the MangoWM desktop.

| | |
|---|---|
| **Base** | Arch Linux (official packages, updated with `pacman`), x86_64, UEFI only |
| **Interface** | Text only, or the MangoWM desktop (chosen in the installer or added later) |
| **Tested on** | Lenovo ThinkPad L14 Gen 5 (21L2), Intel Core Ultra 5 135U (Meteor Lake) |
| **Size** | The last ISO was about 690 MB; each build's size report has the current numbers |

## Supported hardware

| Category | Status |
|---|---|
| **Intel laptops, Meteor Lake** (Core Ultra) | Supported. Tested on the ThinkPad L14 Gen 5. |
| **NVIDIA graphics** (optional, proprietary driver) | Asked in the installer when online, or later with `sudo monarch-add-nvidia`. Downloads about 1 GB. Not yet tested on hardware. |
| **Other Intel generations, e.g. MSI Stealth 15M A11UEK (Tiger Lake)** | Not yet. Their graphics, Wi-Fi and sound firmware must first be added to the keep lists. |

On the tested laptop, graphics (including USB-C and Thunderbolt screens), Wi-Fi,
Bluetooth, sound, Ethernet, webcam, touchpad, USB, NVMe disks and Windows (NTFS)
partitions work. Other hardware can be added: see [docs/HARDWARE.md](docs/HARDWARE.md).

## Install

1. **Get the ISO.** Download the newest one from the GitHub build (see
   [Building](#building)), or on Linux run `scripts/get-iso.sh` in this folder.
2. **Write it to a USB stick.** This erases the stick. Find its name with `lsblk`
   (for example `/dev/sdb`), then:
   ```bash
   sudo dd if=out/download/iso/monarch-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
   ```
3. **Turn off Secure Boot** once in the BIOS setup (the key is often F1, F2 or Del).
4. **Boot from the stick** using the boot menu key (often F12). monarch logs in
   as root by itself.
5. **Run `monarch-install`.** It asks a few questions: network, language and
   keyboard, timezone, computer name, your user, disk, encryption, desktop, and
   NVIDIA driver. Nothing changes on the disk until you type `yes` on the summary.
6. Remove the stick, restart, and log in with your user.

monarch copies the live system to the disk, so the install works without
internet. Internet is only used to update the new system and to download the
optional desktop and NVIDIA driver.

**Install options**

- Erase the whole disk, or use free space next to Windows (Windows is kept).
- Optional LUKS2 encryption of the system (the boot partition stays unencrypted).
- Btrfs with subvolumes, and a swap file the size of RAM, so hibernation works.
- GRUB boot menu; with Windows installed, it shows Windows as an entry.
- `monarch-install --dry-run` asks everything and changes nothing.
- `monarch-install --config answers.conf` runs unattended. Start from
  `/usr/share/monarch/answers.example`; it only installs with `CONFIRM=yes`.

**Dual boot with Windows:** in Windows, shrink the Windows partition (leave at
least 13 GB plus your RAM size free) and turn off *Fast Startup*. If the clock is
wrong after switching, run this once in Windows as admin:
`reg add HKLM\System\CurrentControlSet\Control\TimeZoneInformation /v RealTimeIsUniversal /t REG_DWORD /d 1 /f`

## Everyday commands

| Task | Command |
|---|---|
| Wi-Fi | `iwctl`, then `station wlan0 scan`, `station wlan0 get-networks`, `station wlan0 connect "Name"` |
| Bluetooth | `bluetoothctl`, then `scan on`, `pair <address>`, `connect <address>` |
| Update everything | `sudo pacman -Syu` |
| Install a program | `sudo pacman -S <name>` (search: `pacman -Ss <word>`) |
| Volume | `alsamixer` |
| Power mode | `powerprofilesctl`; battery switches to power-saver by itself |
| Hibernate | `systemctl hibernate` |
| Hardware help | `less /usr/share/monarch/HARDWARE.md` |

**Steam and 32-bit games:** the installer turns on the `multilib` repository for
new installs. On an earlier install, turn it on with:

```bash
sudo sed -i '/^#\[multilib\]$/,/^#Include/ s/^#//' /etc/pacman.conf
```

Then run `sudo pacman -Syu steam`.

## Desktop (optional)

Add MangoWM with `sudo monarch-add-desktop`, or pick it in the installer. It
includes a bar (Waybar), a launcher, a terminal (foot), notifications, screenshots,
and PipeWire sound. No browser is included: install one with `pacman -S`.

| Keys | Does |
|---|---|
| **Ctrl+Space** or **Super+Space** | Launcher |
| **Super+Enter** | Terminal |
| **Super+Q** | Close the window |
| **Super+arrows** or **Super+H/J/K/L** | Move focus between windows |
| **Super+Shift+arrows** | Move the window |
| **Alt+Left/Right** | Switch workspace (tag) |
| **Super+N** | Switch layout |
| **Super+R** | Reload settings |
| **Super+M** | Quit the desktop (back to the text shell) |
| **Print** / **Shift+Print** | Screenshot of an area: to the clipboard / to a file |

Settings are in `~/.config/mango`, `waybar`, `fuzzel`, `foot` and `mako`.

## How monarch stays small

- **Only the listed drivers and firmware are kept.** The lists are
  `archiso/airootfs/etc/monarch/keep-modules` and `keep-firmware`. After each
  kernel or firmware update, `monarch-trim-hardware` deletes everything else.
- **No documentation or developer files.** The pacman rules in
  `archiso/airootfs/etc/pacman.d/monarch-noextract.conf` skip docs, man pages,
  C headers and static libraries. Translations are kept, so every language works.
- **Light defaults:** power-profiles-daemon, zram, thermald, plain bash installer.
- Every build checks that the listed drivers and firmware are present and fail if not.

All settings are in [monarch.conf](monarch.conf).

## Building

The GitHub build runs only when you start it:

1. On GitHub, open **Actions** → **Build ISO** → **Run workflow**, and pick `main`.
2. When it finishes, the **Summary** page shows the size report, and the
   **monarch-iso** download has the ISO and its checksum.

From the terminal: `gh workflow run build-iso.yml --ref main`.

On an Arch Linux computer you can also build locally with `sudo scripts/build.sh`.
The build steps are numbered in `scripts/` (00 to 30), and `scripts/build.sh` runs them in order.

## Testing in a virtual machine

The ISO runs in QEMU with UEFI, so you can test the installer without touching a
laptop. `scripts/test-vm.sh` boots it with a test disk. The full checklist is
[TESTING.md](TESTING.md). Laptop-only parts (Wi-Fi, sound, webcam) need a real laptop.

## Project layout

```
monarch.conf              All settings in one file
archiso/                  The ISO profile: packages, boot menu, and files copied into the system
  airootfs/               Files for the system: installer, keep lists, desktop settings
scripts/                  Build steps (numbered), test and helper scripts
docs/HARDWARE.md          Which hardware works, and how to add drivers and firmware
TESTING.md                Test checklist (VM and laptop)
reports/                  Size reports kept for comparison
.github/workflows/        The GitHub build (manual start only)
```

## Status

| Part | Status |
|---|---|
| Live ISO built on GitHub, boots in a VM | Done |
| Install: erase the disk, without encryption | Tested in a VM |
| Install with encryption, next to Windows, hibernation | Not yet tested |
| Battery tuning and size trimming on the laptop | Built; laptop checks open |
| Optional MangoWM desktop and NVIDIA driver | Built; not tested on hardware yet |
