#!/usr/bin/env bash
# Step 00: install the tools that build the ISO (archiso) on the build computer.
# Runs on Arch Linux only: on GitHub inside an "archlinux" container.
source "$(dirname "$0")/lib.sh"
need_root
need_arch

if [[ ! -d /etc/pacman.d/gnupg ]]; then
    say "Setting up pacman's keyring (checks package signatures)"
    pacman-key --init
    pacman-key --populate archlinux
fi

say "Updating the build computer and installing archiso"
pacman -Syu --noconfirm --needed archiso pacman-contrib
pacman -Q archiso
