# mipOS

mipOS is a personal desktop Linux distribution built on **Ubuntu 26.04 LTS**.
It starts almost empty (like a fresh Arch install) and adds only what we choose:
KDE Plasma on Wayland, a dark custom theme, and a Btrfs disk with snapshots.

It's a **remix**: we don't compile programs ourselves. We pick ready-made
Ubuntu packages and put them together our own way.

## Words used in this project

| Word | Meaning |
|---|---|
| **live disk / ISO** | A disk image file (`.iso`) you can start a computer from without installing anything. |
| **live-build** | The tool that assembles a Linux system from Ubuntu packages. |
| **chroot** | A folder that holds a complete Linux system while we build it (`build/chroot/`). |
| **package** | One piece of software in Ubuntu's format (`.deb`), installed with `apt`. |
| **hook** | A small script that runs inside the new system during the build, to change settings. |
| **kernel** | The core of the operating system that talks to the hardware. |
| **initrd** | A small starter system that loads first and then finds and starts the real one. |
| **casper** | Ubuntu's program that makes a live disk start (it lives in the initrd). |
| **squashfs** | One compressed file holding the whole system, stored on the live disk. |
| **bootloader** | The program that starts the operating system. We use **GRUB**. |
| **UEFI** | The modern firmware built into PCs that runs the bootloader. |
| **VM** | Virtual machine: a pretend computer running in a window. We use **QEMU/KVM**. |

## Folders

```
mipos.conf          All decisions in one file. Change things here.
config/             Our input for live-build:
  package-lists/      which packages to install (one per line)
  hooks/              scripts that adjust the system during the build
iso/grub.cfg.in     The boot menu of the live disk
scripts/            Numbered build steps (run them in order)
build/              Temporary work area (created by the scripts, not in git)
out/                Finished disk images and logs (not in git)
```

## How to build

Run these from this folder. Steps marked **sudo** need administrator rights.

| Step | Command | What it does |
|---|---|---|
| 01 | `sudo scripts/01-install-host-tools.sh` | Installs the build tools on your computer (once). |
| 00 | `scripts/00-check-host.sh` | Checks your computer is ready. Changes nothing. |
| 10 | `sudo scripts/10-configure.sh` | Prepares `build/` from `mipos.conf` and `config/`. |
| 20 | `sudo scripts/20-build-rootfs.sh` | Builds the system (downloads packages, 10–30 min). |
| 30 | `sudo scripts/30-make-iso.sh` | Packs it into a bootable UEFI disk image in `out/`. |
| 40 | `scripts/40-test-vm.sh` | Starts the image in a VM. **No sudo.** |
| 90 | `sudo scripts/90-clean.sh` | Deletes `build/` so you can build again. |

Shortcut for a full rebuild: `sudo scripts/build-all.sh`, then `scripts/40-test-vm.sh`.

None of these steps touches your real disks. They only write inside this folder.

## Why we pack the ISO ourselves

Ubuntu's version of live-build only builds the system files. It can't make an
image that starts on UEFI PCs (Ubuntu uses other tools for that step).
So `30-make-iso.sh` does it with GRUB's `grub-mkrescue`.

## Milestones

| | Goal | It works when... |
|---|---|---|
| M1 | Bare live disk | The VM starts the image and shows a text login prompt. |
| M2 | KDE Plasma on Wayland | The VM shows the SDDM login screen and the Plasma desktop opens. |
| M3 | Canonical parts removed | Ubuntu Pro prompts and telemetry packages are gone, and the system says "mipOS". |
| M4 | Installer | Calamares installs to a Btrfs disk with subvolumes, and the installed system starts. |
| M5 | Snapshots | snapper can create, list and roll back snapshots. |
| M6 | Look and feel | The dark mipOS theme is applied and survives a rebuild. |

## Decisions

All in `mipos.conf`. Changed from the original plan, by choice:

- **snap is kept** (apps and Firefox via snap). M3 removes only Ubuntu Pro
  prompts and telemetry, and does the rebrand.
- **GRUB is the bootloader** (Limine can't read Btrfs, and GRUB lets you boot
  into snapshots). Limine may be added later as an option.
- **Theme is our own**, built on KDE's Breeze, with Papirus Dark icons, Inter
  font, graphite accent, and no dock.

## Legal

mipOS is not affiliated with Canonical or Ubuntu. Ubuntu's trademark rules ask that
modified versions use their own name and logos, which is why it's called mipOS.
It uses no Apple names, logos or wallpapers.
