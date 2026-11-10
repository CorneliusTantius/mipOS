# Testing mipOS (ThinkPad L14 Gen 5)

mipOS is built for the **Lenovo ThinkPad L14 Gen 5 (21L2), Intel Core Ultra 5
135U**. Most tests run in a virtual machine (VM) on any Linux computer; the last
part runs on the ThinkPad itself, because Wi-Fi, sound, graphics firmware and
the webcam only exist there. Do the parts in order. Write down anything that
looks different from "Expected" and send it, with the full error message.

## 0. Preparation (once)

| # | Do this | Expected |
|---|---|---|
| 0.1 | `sudo apt install qemu-system-x86 qemu-utils ovmf gh gdisk dosfstools mtools` | Installs (or says already installed) |
| 0.2 | In the repo folder: `git pull` | Gets the newest scripts |
| 0.3 | GitHub → **Actions** → **Build ISO** → **Run workflow** → `main` | Run finishes green (about 15–25 min) |
| 0.4 | `scripts/get-iso.sh` | Ends with `...x86_64.iso: OK` |
| 0.5 | Copy the **size report** from the run's Summary page | Has a column comparing with A1 |

## A2. Live system (VM)

| # | Do this | Expected |
|---|---|---|
| 2.1 | `scripts/make-test-disk.sh empty`, then `scripts/test-vm.sh` | VM shows the welcome text and `[root@mipos ~]#` |
| 2.2 | `ping -c 3 archlinux.org` | `3 received` |
| 2.3 | `swapon --show` | A line with `/dev/zram0` |
| 2.4 | `systemctl is-active iwd power-profiles-daemon thermald` | `active` (thermald may be `inactive` in a VM) |
| 2.3b | `lsblk -d`; `ip -br link`; `cat /sys/class/dmi/id/product_version` | Disk `nvme0n1`; a network card `enp...` (Intel e1000e, like the laptop); `ThinkPad L14 Gen 5` |
| 2.3c | `cat /proc/asound/cards` | An `HDA-Intel` sound card (the VM's Intel HD Audio) |
| 2.4a | `systemctl is-active bluetooth` | `inactive` is fine in a VM (no Bluetooth chip); on the laptop: `active` |
| 2.4b | `powerprofilesctl get`; `journalctl -b -u mipos-power-source` | `balanced` (a VM counts as "on charger"); the log says `mipOS power: on charger` |
| 2.5 | `systemctl --failed` | `0 loaded units listed` (thermald failing in a VM is OK) |
| 2.6 | `poweroff` | VM window closes |

## A3. Install: erase the whole disk

### A3a. Without encryption

| # | Do this | Expected |
|---|---|---|
| 3.1 | `scripts/make-test-disk.sh empty`, then `scripts/test-vm.sh` | Live system starts |
| 3.2 | `mipos-install --dry-run`, answer everything | Summary shown, then "Dry run: stopping here". Nothing changed |
| 3.3 | `mipos-install`. Network: automatic. Language `en_US.UTF-8`, keyboard `us`, any timezone, name `mipos`, user e.g. `test`. Disk `/dev/nvme0n1`, **Erase the whole disk**, encryption **No**, type `yes` | Progress messages, a copy progress bar, then "mipOS is installed" with the disk space used. **Note the numbers** |
| 3.4 | Answer **No** to "Restart now?", then `poweroff` | VM closes |
| 3.5 | `scripts/test-vm.sh --no-iso` | GRUB shows briefly, then `mipos login:` |
| 3.6 | Log in as your user | Prompt `[test@mipos ~]$` |
| 3.7 | `sudo whoami` (type your password) | `root` |
| 3.8 | `su -` (press Enter at the password prompt) | `Authentication failure` (root is locked) |
| 3.9 | `lsblk -f` | `nvme0n1p1` vfat on `/boot`, `nvme0n1p2` btrfs on `/` and others |
| 3.10 | `findmnt -t btrfs -o TARGET,OPTIONS` | `/ /home /var/log /var/cache /swap`, each with `compress=zstd:1` and `subvol=/@...` |
| 3.11 | `swapon --show` | `/dev/zram0` and `/swap/swapfile` (size of the VM's RAM, 4G) |
| 3.12 | `ping -c 3 archlinux.org` | `3 received` |
| 3.13 | `systemctl --failed` | `0 loaded units listed` (thermald in a VM is OK) |
| 3.14 | `cat /etc/os-release`, `cat /var/log/mipos-install-size.txt` | `NAME="mipOS"`; the installed size. **Send me this** |
| 3.15 | `sudo pacman -S --noconfirm tree` then `ls /usr/share/man` | Installs; then `No such file or directory` (no man pages: size trimming works for new packages too) |

### A3b. With encryption

| # | Do this | Expected |
|---|---|---|
| 3.16 | Shut down the VM, `scripts/make-test-disk.sh empty`, `scripts/test-vm.sh` | Live system |
| 3.17 | `mipos-install`, same as 3.3 but encryption **Yes** (separate or same password) | "mipOS is installed" |
| 3.18 | No restart, `poweroff`, then `scripts/test-vm.sh --no-iso` | After GRUB: a password prompt (`Please enter passphrase for disk ...`) |
| 3.19 | Type the encryption password | Continues to `mipos login:`; log in works |
| 3.20 | `lsblk -f` | `nvme0n1p2` is `crypto_LUKS`, with `cryptroot` (btrfs) inside |

## A4. Dual boot and hibernation

### A4a. Next to (fake) Windows

| # | Do this | Expected |
|---|---|---|
| 4.1 | `scripts/make-test-disk.sh windows` | Prints the fake Windows layout with ~31 GB free |
| 4.2 | `scripts/test-vm.sh`, then `sgdisk -p /dev/nvme0n1` | Partitions 1–4 (Windows); **write down their Start/End numbers** |
| 4.3 | `mipos-install`, disk `/dev/nvme0n1`: the menu offers **Use the 31 GB of free space** | Summary says "Windows found: yes" |
| 4.4 | Finish the install, no restart, then `sgdisk -p /dev/nvme0n1` | Partitions 1–4 **exactly as in 4.2**, plus 5 (`mipOS EFI`) and 6 (`mipOS`) |
| 4.5 | `poweroff`, then `scripts/test-vm.sh --no-iso` | GRUB menu waits 5 s and lists **mipOS** and **Windows Boot Manager** |
| 4.6 | Pick mipOS | Boots to `mipos login:` (picking Windows fails: it's fake) |

### A4b. Next to (fake) Ubuntu, without encryption

| # | Do this | Expected |
|---|---|---|
| 4.7 | `scripts/make-test-disk.sh ubuntu` | Prints the fake Ubuntu layout with ~31 GB free |
| 4.8 | `scripts/test-vm.sh`, then `sgdisk -p /dev/nvme0n1` | Partitions 1 (EFI) and 2 (Ubuntu); **write down their Start/End numbers** |
| 4.9 | `mipos-install`, disk `/dev/nvme0n1`: the menu offers **Use the 31 GB of free space**; encryption **No** | Summary says "free space ... everything else is kept", "Windows found: no" |
| 4.10 | Finish the install, answer **No** to restart, then `sgdisk -p /dev/nvme0n1` | Partitions 1–2 **exactly as in 4.8**, plus 3 (`mipOS EFI`) and 4 (`mipOS`) |
| 4.11 | `mount /dev/nvme0n1p2 /mnt && cat /mnt/home/ubuntu-user/keep-me.txt && umount /mnt` | "This is the fake Ubuntu user's file..." (Ubuntu's files untouched) |
| 4.12 | `poweroff`, then `scripts/test-vm.sh --no-iso` | GRUB menu waits 5 s and lists **mipOS** and **Ubuntu 24.04.1 LTS** |
| 4.13 | Pick mipOS, log in | Works (picking Ubuntu fails: it's fake) |
| 4.14 | `lsblk -f` | `nvme0n1p3` vfat on `/boot`, `nvme0n1p4` btrfs on `/`; `nvme0n1p1`/`p2` (Ubuntu) not mounted |

### A4c. Hibernation (on any installed VM from above; best with encryption)

| # | Do this | Expected |
|---|---|---|
| 4.15 | Log in, type `echo hello from before hibernation` | Text on screen |
| 4.16 | `sudo systemctl hibernate` | Screen goes black, VM window closes (or stays black) |
| 4.17 | Close the window if still open, then `scripts/test-vm.sh --no-iso` (encrypted: type the password) | The screen from 4.15 comes back, still logged in |

### A5. Desktop choice (MangoWM + Waybar)

Needs internet in the VM. Best on top of A3a (or run step 5.2 on an already installed VM).

| # | Do this | Expected |
|---|---|---|
| 5.1 | Install as in 3.3, but on step 8 "Desktop" pick **With desktop** (on a fresh install; `scripts/make-test-disk.sh empty` first) | Extra step "Installing the desktop" with pacman downloading `mangowm`, `waybar`, `foot`, `ttf-dejavu` and their dependencies; the summary shows `Desktop: MangoWM` |
| 5.2 | On an already installed system instead: `sudo mipos-add-desktop` | Same packages install; "Done." |
| 5.3 | `cat ~/.bash_profile` | Ends with the `# mipOS desktop` block (tty1 only) |
| 5.4 | Log in on tty1 (or type `mango`) | The desktop starts: mouse pointer and a Waybar bar on the screen edge |
| 5.5 | Press **Alt+Enter** | A foot terminal opens: black, white text, JetBrains Mono |
| 5.5a | Press **Ctrl+Space**, type `foot`, Enter (Esc closes it). Repeat with **Super+Space** and by clicking the red dot on the bar | A black launcher with a red `>` prompt opens; Enter starts foot |
| 5.5b | Look at the screen | Black background, thin red border on the focused window, rounded corners, floating Waybar pills (dots for tags, layout, clock, status). Screenshot welcome |
| 5.5c | Open two terminals (Alt+Enter twice), then **Alt+Left/Right** | Windows sit side by side in a strip and scroll when focus moves (scroller layout) |
| 5.5d | In a foot terminal: `wpctl status`, then `notify-send hello` | `wpctl status` lists PipeWire and the sound card; a black notification with a thin outline appears at the top right |
| 5.5e | Press **Print**, drag over an area, then `wl-paste > /tmp/a.png && file /tmp/a.png` | `PNG image data` (the screenshot reached the clipboard) |
| 5.6 | Quit MangoWM (default: **Super+M** (the Windows key); see `~/.config/mango/config.conf`) | Back at the text shell, no error |
| 5.6b | In `~/.config/mango/config.conf` look for `exec_once=waybar` at the end | Present once |
| 5.7 | Switch to tty2 (Ctrl+Alt+F2) and log in | Plain text shell, no desktop |
| 5.8 | `df -h /` before vs after, and `pacman -Qq \| wc -l` | **Send me the disk difference**: it is the real cost of the desktop |

Known: **Alt+Space** (launcher) uses `rofi`, which isn't installed; it does nothing.

## On the ThinkPad L14 Gen 5 (when the VM tests pass)

Write the ISO to a USB stick (everything on the stick is erased; find the
stick's name with `lsblk` first, e.g. `/dev/sdb`):

```bash
sudo dd if=out/download/iso/mipos-*.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

Secure Boot must be off (once: **F1** at start → *Security* → *Secure Boot* →
*Off*, **F10** to save). Then plug in the stick, start the laptop, press **F12**
and pick the USB stick.

| # | Do this | Expected |
|---|---|---|
| L.1 | Watch the start | mipOS starts, screen sharp, `[root@mipos ~]#` |
| L.2 | `journalctl -k -b \| grep -iE 'guc\|huc\|dmc'` | Lines saying the `i915/mtl_...` firmware was loaded (graphics firmware works) |
| L.3 | `journalctl -k -b \| grep -i 'firmware.*failed'` | No output: no firmware file is missing |
| L.4 | `iwctl station wlan0 scan`, then `iwctl station wlan0 get-networks` | Your network is listed |
| L.5 | `iwctl station wlan0 connect "Name"`, password, then `ping -c 3 archlinux.org` | `3 received` |
| L.6 | `bluetoothctl show`, then `bluetoothctl scan on` (wait 10 s, Ctrl+C) | `Powered: yes`; nearby Bluetooth devices are listed |
| L.7 | `alsamixer` (M = unmute, arrows = volume, Esc), then `speaker-test -c 2 -t wav -l 1` | "Front left, front right" from the speakers |
| L.8 | `ls /dev/video*` | `/dev/video0` (and more): the webcam driver is loaded |
| L.9 | Unplug the charger, wait 3 s, `powerprofilesctl get` | `power-saver`; plug in again: `balanced` |
| L.10 | `cat /sys/class/power_supply/BAT0/capacity` | Battery charge in % |
| L.11 | Plug in your phone, turn on USB tethering, `ip link` | A new network card (e.g. `enp...u1`); `ping -c 3 archlinux.org` works |
| L.12 | Touchpad, TrackPoint, Fn keys (volume, brightness) | All react (brightness: screen gets darker/brighter) |
| L.12a | Desktop installed: Fn volume, mute, mic mute and brightness keys; the bar's `VOL` and brightness numbers change | Each key reacts; volume changes sound loudness |
| L.12b | Close the lid for 10 s, open it | The screen is off while closed, comes back instantly, still logged in (`journalctl -b \| grep -i 'suspend\|s2idle'` shows the sleep) |
| L.12c | Plug in a USB stick, `lsblk`, then `udisksctl mount -b /dev/sdb1` (your stick's name) | Mounted under `/run/media/...`; `udisksctl unmount -b /dev/sdb1` when done |
| L.13 | Optional: install on the laptop with `mipos-install` (only if you're ready to erase its disk, or use free space next to Windows) | Installs; after restart everything above still works |
