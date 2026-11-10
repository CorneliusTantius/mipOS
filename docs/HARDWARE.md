# Adding drivers and firmware for other hardware

mipOS is trimmed for **Intel laptops**: to stay small it leaves out drivers and
firmware for most other hardware. Everything left out can be added back with
pacman (needs internet). This page shows how.

Two words first:

| Word | Meaning |
|---|---|
| **driver** (kernel module) | The part of the kernel that runs one kind of device, e.g. `rtw89` for some Realtek Wi-Fi cards. Comes with the `linux` package. |
| **firmware** | A small program the driver loads into the device itself. Comes in `linux-firmware-*` packages (one per brand). |

Most devices need **both**. mipOS leaves out both for non-Intel hardware, in
two different ways:

- **Firmware packages for other brands are simply not installed.**
  `sudo pacman -S linux-firmware-realtek` adds one.
- **Drivers (and a few Intel firmware files) are removed while unpacking**,
  by the size-trimming rules (`NoExtract`) in `/etc/pacman.conf`. Installing
  again does nothing until the rule is switched off. Then reinstall the package
  the files come from.

All commands below are for the **installed** mipOS. On the live USB stick,
changes are lost at restart; there, use a cable or Intel Wi-Fi to install, and
add hardware support afterwards.

## 1. Find out what's missing

| # | Do this | What it tells you |
|---|---|---|
| 1 | `journalctl -k -b \| grep -i firmware` | Lines like `Direct firmware load for rtw89/rtw8852b_fw.bin failed` name the missing firmware file. |
| 2 | `sudo pacman -S pciutils usbutils`, then `lspci -k` and `lsusb` | Lists your devices. In `lspci -k`, a device without a `Kernel driver in use:` line has no driver. |
| 3 | `ip link` | Lists network cards. No `wlan0`/`wlp...` line = no Wi-Fi driver. |

## 2. Which brand needs what

| Your device | Firmware package | Driver rule to switch off (step 3) |
|---|---|---|
| Realtek Wi-Fi or Bluetooth | `linux-firmware-realtek` | Wi-Fi cards |
| Qualcomm Atheros Wi-Fi or Bluetooth | `linux-firmware-atheros` | Wi-Fi cards |
| MediaTek / Ralink Wi-Fi or Bluetooth | `linux-firmware-mediatek` | Wi-Fi cards |
| Broadcom Wi-Fi | `linux-firmware-broadcom` | Wi-Fi cards |
| Marvell Wi-Fi | `linux-firmware-marvell` | Wi-Fi cards |
| Realtek Ethernet (cable) | `linux-firmware-realtek` (driver already included) | none |
| Other Ethernet (Broadcom, Atheros, Aquantia...) | the brand's package, if the driver asks for one | Ethernet cards |
| AMD Radeon graphics (new) | `linux-firmware-amdgpu` | Graphics |
| AMD Radeon graphics (old, before ~2012) | `linux-firmware-radeon` | Graphics |
| NVIDIA graphics (open driver nouveau) | `linux-firmware-nvidia` | Graphics |
| Cirrus Logic sound (some laptops' speakers) | `linux-firmware-cirrus` | none |
| Intel camera (IPU), Intel AI chip (NPU) | none (it's in `linux-firmware-intel`) | Intel firmware extras |
| Webcam (USB), TV tuner, other media devices | none, usually | Media devices |
| Anything else / not sure | `linux-firmware-other` | All drivers |

Several firmware packages at once is fine:
`sudo pacman -S linux-firmware-realtek linux-firmware-mediatek`.

## 3. Switch off a trimming rule

The rules are in `/etc/pacman.conf`, in the block that starts with
`# mipOS size trimming`. Each `NoExtract = ...` line leaves out some files.
Switching a rule off = putting `#` in front of it. The commands below do that
for you (they only touch lines containing the text shown).

**First, always make a backup:**

```bash
sudo cp /etc/pacman.conf /etc/pacman.conf.backup
```

Then pick what you need:

| What | Command (switches the rule off) | Then reinstall |
|---|---|---|
| Wi-Fi cards (all brands) | `sudo sed -i '/^NoExtract = .*net\/wireless/s/^/#/' /etc/pacman.conf` | `sudo pacman -S linux` |
| Ethernet cards (all brands) | `sudo sed -i '/^NoExtract = .*net\/ethernet/s/^/#/' /etc/pacman.conf` | `sudo pacman -S linux` |
| Graphics (AMD, NVIDIA, others) | `sudo sed -i '/^NoExtract = .*gpu\/drm/s/^/#/' /etc/pacman.conf` | `sudo pacman -S linux` |
| Media devices (webcams, TV) | `sudo sed -i '/^NoExtract = .*drivers\/media/s/^/#/' /etc/pacman.conf` | `sudo pacman -S linux` |
| **All drivers** (simplest; about +80 MB) | `sudo sed -i '/^NoExtract = .*usr\/lib\/modules/s/^/#/' /etc/pacman.conf` | `sudo pacman -S linux` |
| Intel firmware extras (camera, NPU, server cards) | `sudo sed -i '/^NoExtract = .*usr\/lib\/firmware/s/^/#/' /etc/pacman.conf` | `sudo pacman -S linux-firmware-intel` |

Then:

1. Install the firmware package from the table in step 2 (if any).
2. Restart: `sudo reboot`.
3. Check again with step 1.

Reinstalling `linux` also rebuilds the start-up system (initramfs) by itself.
Future kernel updates keep your change, because the rule stays switched off.

**Undo** (back to the trimmed setup):

```bash
sudo cp /etc/pacman.conf.backup /etc/pacman.conf
```

```bash
sudo pacman -S linux linux-firmware-intel
```

## 4. Intel Wi-Fi: keeping all firmware versions

Intel Wi-Fi works out of the box. To save space, mipOS keeps only the two
newest firmware versions per Wi-Fi chip that the kernel can load (a pacman hook
runs `/usr/local/sbin/mipos-trim-wifi-firmware` after kernel and firmware
updates). If you ever need all versions (for example while testing an older
kernel):

```bash
sudo mv /etc/pacman.d/hooks/90-mipos-trim-wifi-firmware.hook /root/
```

```bash
sudo pacman -S linux-firmware-intel
```

To trim again: move the file back to `/etc/pacman.d/hooks/` and run
`sudo mipos-trim-wifi-firmware`.

## 5. Other things mipOS leaves out

The same rules also leave out documentation, man pages, translations, C
headers and static libraries (only needed to compile programs), and most
terminal descriptions. To get one back, switch off its line in
`/etc/pacman.conf` the same way, then reinstall the packages it belongs to.
For example, to compile programs (gcc, make, npm native modules):

```bash
sudo sed -i '/^NoExtract = usr\/include\|^NoExtract = usr\/lib\/\*\.a/s/^/#/' /etc/pacman.conf
```

```bash
sudo pacman -S $(pacman -Qq)
```

```bash
sudo pacman -S base-devel
```
