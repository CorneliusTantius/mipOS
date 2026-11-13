# Hardware: what monarch supports, and adding more

monarch is built for **one laptop: Lenovo ThinkPad L14 Gen 5 (21L2) with an
Intel Core Ultra 5 135U** (Meteor Lake). To stay small it keeps only the
drivers and firmware this laptop uses. Anything else can be added back with
pacman (needs internet). This page shows how.

Two words first:

| Word | Meaning |
|---|---|
| **driver** (kernel module) | The part of the kernel that runs one kind of device, e.g. `iwlwifi` for the Wi-Fi card. Comes with the `linux` package. |
| **firmware** | A small program the driver loads into the device itself. Comes in `linux-firmware-*` packages (one per brand), `sof-firmware` (sound) and `intel-ucode` (CPU fixes). |

## What works out of the box

| Part | Driver | Firmware |
|---|---|---|
| Graphics (Meteor Lake) | `i915` | `i915/mtl_*` |
| Wi-Fi: Intel AX211 | `iwlwifi`, `iwlmvm` | `iwlwifi-ma-b0-gf-a0-*` |
| Bluetooth: Intel AX211 | `btusb`, `btintel` | `intel/ibt-0180-0041` |
| Sound (speakers, mic, HDMI) | SOF Meteor Lake, Conexant codec | `sof-ipc4/mtl`, `sof-hda-generic` topologies |
| Ethernet: Intel I219-LM | `e1000e` | none |
| Disk: NVMe | built in | none |
| Webcam | `uvcvideo` | none |
| Touchpad, TrackPoint, keyboard, ThinkPad buttons | `i2c_hid_acpi`, `psmouse`, built in, `thinkpad_acpi` | none |
| Thunderbolt 4 / USB-C (incl. external screens) | `thunderbolt`, `ucsi_acpi`, `typec_displayport` | none |
| CPU fixes (microcode) | | `intel-ucode/06-aa-04` |
| Extras | USB sticks, USB headsets (`snd_usb_audio`), phone USB tethering and USB-Ethernet adapters, Windows partitions (NTFS), QEMU virtual machines (virtio) | |
| Bluetooth programs | `bluetoothctl` (pair and connect devices) | |
| Not included | AI chip (NPU, `intel_vpu`), fingerprint and smartcard readers | |

Everything else (other Wi-Fi brands, AMD/NVIDIA graphics, other laptops'
chips...) is removed.

## How the trimming works

Two lists decide what stays:

- `/etc/monarch/keep-modules`: driver names, one per line. Drivers they need
  are kept automatically.
- `/etc/monarch/keep-firmware`: firmware file patterns (inside
  `/usr/lib/firmware`).

After every install or update of the kernel or a firmware package, a pacman
hook runs `/usr/local/sbin/monarch-trim-hardware`, which deletes every driver and
firmware file not on the lists. So **to add something: put it on the list, then
reinstall the package**, and the trimming keeps it from then on. Future updates
keep your change.

## 1. Find out what's missing

| # | Do this | What it tells you |
|---|---|---|
| 1 | `journalctl -k -b \| grep -i firmware` | Lines like `Direct firmware load for rtw89/rtw8852b_fw.bin failed` name a missing firmware file. |
| 2 | `sudo pacman -S pciutils usbutils`, then `lspci -k` and `lsusb` | Lists your devices. In `lspci -k`, `Kernel modules:` names the driver a device needs; no `Kernel driver in use:` line means it's not loaded. |
| 3 | `ip link` | Lists network cards. No `wlan0`/`wlp...` line = no Wi-Fi driver. |

To find a driver's name for a USB device, search the web for its ID from
`lsusb` (e.g. `0bda:8153`) plus "linux driver".

## 2. Add a driver

```bash
sudo nano /etc/monarch/keep-modules
```

Add the driver's name on a new line (e.g. `rtw89_8852be`), save (Ctrl+O,
Enter) and close (Ctrl+X). Then unpack the kernel's drivers again; the
trimming now keeps yours:

```bash
sudo pacman -S linux
```

Then restart: `sudo reboot`.

## 3. Add firmware

If the device's firmware comes from another brand, install that package:

| Your device | Firmware package |
|---|---|
| Realtek Wi-Fi / Bluetooth / Ethernet | `linux-firmware-realtek` |
| Qualcomm Atheros Wi-Fi / Bluetooth | `linux-firmware-atheros` |
| MediaTek / Ralink Wi-Fi / Bluetooth | `linux-firmware-mediatek` |
| Broadcom Wi-Fi | `linux-firmware-broadcom` |
| Marvell Wi-Fi | `linux-firmware-marvell` |
| AMD Radeon graphics | `linux-firmware-amdgpu` (new) or `linux-firmware-radeon` (old) |
| NVIDIA graphics (nouveau) | `linux-firmware-nvidia` |
| Cirrus Logic sound | `linux-firmware-cirrus` |
| Other Intel chips (other laptops, cameras, NPU...) | already installed: `linux-firmware-intel` |
| Anything else | `linux-firmware-other` |

Then put the firmware files on the keep list. The missing-file message from
step 1 shows the name; a pattern with `*` covers a whole folder:

```bash
sudo nano /etc/monarch/keep-firmware
```

For example add `rtw89/*` (all Realtek rtw89 Wi-Fi firmware), save, close, and
install or reinstall the package so the files are unpacked again:

```bash
sudo pacman -S linux-firmware-realtek
```

Then restart: `sudo reboot`.

## NVIDIA graphics (proprietary driver)

Laptops with an NVIDIA chip (for example the MSI Stealth 15M A11UEK, RTX 3060)
can use NVIDIA's own driver. The installer asks about it when there's internet:
answer yes. On an installed system, run (needs internet, about 1 GB of disk):

```bash
sudo monarch-add-nvidia
```

Then restart. The driver isn't on the ISO, so it doesn't make the ISO bigger.

## 4. Turn the trimming off completely

For a laptop that isn't the ThinkPad L14 Gen 5, or while finding out what a
device needs: keep **everything** by putting a line with only `*` in both lists.

```bash
echo '*' | sudo tee -a /etc/monarch/keep-modules /etc/monarch/keep-firmware
```

```bash
sudo pacman -S linux linux-firmware-intel sof-firmware intel-ucode
```

Install other brands' firmware packages (step 3) as needed, then
`sudo reboot`. Undo: delete the `*` lines and run the `pacman -S` command again.

## 5. Other things monarch leaves out

Documentation, man pages, C headers and static libraries (only
needed to compile programs), and most terminal descriptions are left out by the
rules in `/etc/pacman.conf` (block `# monarch size trimming`). To get one back,
put `#` in front of its `NoExtract` line, then reinstall the packages it belongs
to. For example, to compile programs (gcc, make, npm native modules):

```bash
sudo cp /etc/pacman.conf /etc/pacman.conf.backup
```

```bash
sudo sed -i '/^NoExtract = usr\/include\|^NoExtract = usr\/lib\/\*\.a/s/^/#/' /etc/pacman.conf
```

```bash
sudo pacman -S $(pacman -Qq)
```

```bash
sudo pacman -S base-devel
```
