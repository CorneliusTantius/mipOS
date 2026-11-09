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
| M2 | KDE Plasma on Wayland | The VM shows the tuigreet login screen and the Plasma desktop opens. |
| M3 | Canonical parts removed | snap, Ubuntu Pro and telemetry packages are gone, and the system says "mipOS". |
| M4 | Installer | Calamares installs to a Btrfs disk with subvolumes, and the installed system starts. |
| M5 | Snapshots | snapper can create, list and roll back snapshots. |
| M6 | Look and feel | The dark mipOS theme is applied and survives a rebuild. |

## Decisions

All in `mipos.conf`. Changed from the original plan, by choice:

- **No snap.** Apps come from Flatpak/Flathub, Firefox from Mozilla's apt repo.
  snap and the Ubuntu Pro, telemetry and crash-report packages are *blocked*
  (apt will refuse to install them).
- **Login screen: greetd + tuigreet** (a dark text login) instead of SDDM.
- **KDE Plasma, trimmed:** kept for its automatic monitor handling, with file
  indexing (Baloo), mail/calendar services (Akonadi), KDE Connect, Discover and
  blur effects left out.
- **GRUB is the bootloader** (Limine can't read Btrfs, and GRUB lets you boot
  into snapshots). Limine may be added later as an option.
- **Theme is our own**, built on KDE's Breeze, with Papirus Dark icons, Inter
  font, graphite accent, and no dock.

## Lightweight and battery settings

Each one can be switched off in `mipos.conf`.

| Setting | What it does | Why |
|---|---|---|
| Kernel only, no headers | `linux-image-generic` instead of `linux-generic` | Saves ~100 MB. Headers are only for compiling drivers. |
| Small firmware set | Intel, Realtek, MediaTek, Qualcomm Wi-Fi, AMD graphics, Intel audio | ~250 MB instead of ~620 MB. |
| No recommended extras | apt installs only what we list | Stops packages from dragging in optional extras. |
| No docs, man pages, translations | dpkg skips these files | Saves disk space. Copyright files stay (required). |
| No package indexes in the image | `/var/lib/apt/lists` emptied | Smaller image. Run `sudo apt update` before installing anything. |
| zram | Compressed swap in RAM | Low-RAM PCs stay fast; no swap writes to the disk. |
| dbus-broker | Lighter, faster D-Bus | Less CPU for messages between programs. |
| TLP + thermald | CPU, Wi-Fi, USB and sound power saving; Intel heat control | Longer battery life. |
| Small system log | Capped at 50 MB | Fewer disk writes. |
| Masked timers | No twice-a-day update checks, no man-db and disk-check timers, no waiting for network at boot | Fewer wake-ups, faster boot. **Update by hand weekly:** `sudo apt update && sudo apt upgrade` |
| Kernel options | `nowatchdog`, `zswap.enabled=0`, quiet boot | Fewer CPU wake-ups. |
| Btrfs `noatime,compress=zstd:1` (M4) | No write on every file read; light compression | Fewer disk writes, smaller files. |
| Initrd with only needed drivers (M4) | `MODULES=dep` on the installed system | Faster boot. |

## Legal

mipOS is not affiliated with Canonical or Ubuntu. Ubuntu's trademark rules ask that
modified versions use their own name and logos, which is why it's called mipOS.
It uses no Apple names, logos or wallpapers.

## Building on GitHub (GitHub Actions)

GitHub can build the ISO on its own servers
([.github/workflows/build-iso.yml](.github/workflows/build-iso.yml)).
It only runs when you start it:

1. On GitHub, open the **Actions** tab and pick **Build ISO** on the left.
2. Click **Run workflow**.
3. Under **Use workflow from**, choose the branch to build.
4. Optional: tick **Publish a GitHub Release** and fill in a version like `v0.1`.
5. Click the green **Run workflow** button.

When it finishes, open the run and download **mipos-iso** at the bottom (kept
14 days). If it fails, download **build-log** from the same page.

From the terminal instead:
```bash
gh workflow run build-iso.yml --ref main
```
