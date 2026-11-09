#!/usr/bin/env bash
# Step 01: install the tools needed to build and test mipOS.
# Installs packages on THIS computer only. Doesn't touch any disk.
source "$(dirname "$0")/lib.sh"
need_root

PACKAGES=(
    live-build          # builds the system from Ubuntu packages
    debootstrap         # creates the empty base system live-build starts from
    squashfs-tools      # packs the system into one compressed file
    xorriso             # writes the bootable disk image (.iso)
    grub-efi-amd64-bin  # GRUB files used to make the image boot on UEFI PCs
    grub-common         # contains grub-mkrescue, which assembles the image
    mtools              # lets grub-mkrescue create the small UEFI boot area
    dosfstools          # FAT tools, also for the UEFI boot area
    qemu-system-x86     # the virtual machine program
    qemu-utils          # virtual disk tools (used from M4 on)
    ovmf                # UEFI firmware for the virtual machine
    git                 # keeps the history of this project
)

info "Installing: ${PACKAGES[*]}"
apt-get update
apt-get install -y "${PACKAGES[@]}"
ok "Build tools installed. Next: scripts/00-check-host.sh"
