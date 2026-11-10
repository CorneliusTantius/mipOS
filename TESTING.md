# Testing mipOS (A2–A4)

Everything here runs on your computer in a virtual machine (VM), except the
last part (real laptop). Do the parts in order. Write down anything that looks
different from "Expected" and send it, with the full error message.

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
| 2.4b | `powerprofilesctl get`; `journalctl -b -u mipos-power-source` | `balanced` (a VM counts as "on charger"); the log says `mipOS power: on charger` |
| 2.5 | `systemctl --failed` | `0 loaded units listed` (thermald failing in a VM is OK) |
| 2.6 | `poweroff` | VM window closes |

## A3. Install: erase the whole disk

### A3a. Without encryption

| # | Do this | Expected |
|---|---|---|
| 3.1 | `scripts/make-test-disk.sh empty`, then `scripts/test-vm.sh` | Live system starts |
| 3.2 | `mipos-install --dry-run`, answer everything | Summary shown, then "Dry run: stopping here". Nothing changed |
| 3.3 | `mipos-install`. Network: automatic. Language `en_US.UTF-8`, keyboard `us`, any timezone, name `mipos`, user e.g. `test`. Disk `/dev/vda`, **Erase the whole disk**, encryption **No**, type `yes` | Progress messages, a copy progress bar, then "mipOS is installed" with the disk space used. **Note the numbers** |
| 3.4 | Answer **No** to "Restart now?", then `poweroff` | VM closes |
| 3.5 | `scripts/test-vm.sh --no-iso` | GRUB shows briefly, then `mipos login:` |
| 3.6 | Log in as your user | Prompt `[test@mipos ~]$` |
| 3.7 | `sudo whoami` (type your password) | `root` |
| 3.8 | `su -` (press Enter at the password prompt) | `Authentication failure` (root is locked) |
| 3.9 | `lsblk -f` | `vda1` vfat on `/boot`, `vda2` btrfs on `/` and others |
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
| 3.20 | `lsblk -f` | `vda2` is `crypto_LUKS`, with `cryptroot` (btrfs) inside |

## A4. Dual boot and hibernation

### A4a. Next to (fake) Windows

| # | Do this | Expected |
|---|---|---|
| 4.1 | `scripts/make-test-disk.sh windows` | Prints the fake Windows layout with ~31 GB free |
| 4.2 | `scripts/test-vm.sh`, then `sgdisk -p /dev/vda` | Partitions 1–4 (Windows); **write down their Start/End numbers** |
| 4.3 | `mipos-install`, disk `/dev/vda`: the menu offers **Use the 31 GB of free space** | Summary says "Windows found: yes" |
| 4.4 | Finish the install, no restart, then `sgdisk -p /dev/vda` | Partitions 1–4 **exactly as in 4.2**, plus 5 (`mipOS EFI`) and 6 (`mipOS`) |
| 4.5 | `poweroff`, then `scripts/test-vm.sh --no-iso` | GRUB menu waits 5 s and lists **mipOS** and **Windows Boot Manager** |
| 4.6 | Pick mipOS | Boots to `mipos login:` (picking Windows fails: it's fake) |

### A4b. Hibernation (on any installed VM from above; best with encryption)

| # | Do this | Expected |
|---|---|---|
| 4.7 | Log in, type `echo hello from before hibernation` | Text on screen |
| 4.8 | `sudo systemctl hibernate` | Screen goes black, VM window closes (or stays black) |
| 4.9 | Close the window if still open, then `scripts/test-vm.sh --no-iso` (encrypted: type the password) | The screen from 4.7 comes back, still logged in |

## Real laptop (when the VM tests pass)

Write the ISO to a USB stick (all data on the stick is erased; replace
`/dev/sdX` with your stick, check with `lsblk` first):
`sudo dd if=out/download/iso/<name>.iso of=/dev/sdX bs=4M status=progress oflag=sync`.
Start the laptop from the stick (UEFI, Secure Boot off).

| # | Do this | Expected |
|---|---|---|
| L.1 | `iwctl station wlan0 scan`, `iwctl station wlan0 get-networks` | Your network is listed |
| L.2 | `iwctl station wlan0 connect "Name"`, password, then `ping -c 3 archlinux.org` | `3 received` |
| L.3 | `alsamixer` (M = unmute, arrows = volume, Esc), then `speaker-test -c 2 -t wav -l 1` | "Front left, front right" from the speakers |
| L.4 | Unplug the charger, wait 3 s, `powerprofilesctl get` | `power-saver`; plug in again: `balanced` |
| L.5 | `ls /usr/lib/firmware/intel/iwlwifi \| wc -l` and Wi-Fi still works | About 100 files (was ~230) |
