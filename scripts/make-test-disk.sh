#!/usr/bin/env bash
# Make a fresh test disk for the VM (out/vm/disk.qcow2), replacing the old one.
#   scripts/make-test-disk.sh empty     an empty disk (for "Erase the whole disk")
#   scripts/make-test-disk.sh windows   a disk that looks like a Windows PC whose
#                                       Windows partition was shrunk: Windows EFI
#                                       partition with a (fake) Windows boot manager,
#                                       Windows partitions, and free space between
#                                       (for "Use free space" / dual boot, A4)
# The fake Windows can't really start; it's only there so the installer and the
# boot menu (os-prober) see "Windows" and leave it alone.
source "$(dirname "$0")/lib.sh"

kind="${1:-}"
[[ ${kind} == empty || ${kind} == windows ]] || die "Usage: $0 empty|windows"
command -v qemu-img >/dev/null || die "Install QEMU first: sudo apt install qemu-utils"

vm="${OUT_DIR}/vm"
disk="${vm}/disk.qcow2"
mkdir -p "${vm}"
if [[ -f ${disk} ]]; then
    read -r -p "Replace the test disk ${disk}? Everything on it is lost. [y/N] " ok
    [[ ${ok} == [yY] ]] || exit 1
fi
rm -f "${disk}" "${vm}/OVMF_VARS.fd"   # also forget old boot entries

if [[ ${kind} == empty ]]; then
    qemu-img create -f qcow2 "${disk}" "${VM_DISK_GB}G"
    echo "Empty ${VM_DISK_GB} GB test disk ready."
    exit 0
fi

command -v sgdisk >/dev/null || die "Install gdisk: sudo apt install gdisk"
command -v mkfs.fat >/dev/null || die "Install dosfstools: sudo apt install dosfstools"
command -v mcopy >/dev/null || die "Install mtools: sudo apt install mtools"

size_gb=48
raw="${vm}/disk.raw"
rm -f "${raw}"
truncate -s "${size_gb}G" "${raw}"
# Typical Windows 11 layout (sizes in MiB). Free space is left between
# "Windows" and "Recovery", like after shrinking C: in Disk Management.
sgdisk -o \
    -n 1:2048:+100M  -t 1:ef00 -c 1:"EFI system partition" \
    -n 2:0:+16M      -t 2:0c01 -c 2:"Microsoft reserved partition" \
    -n 3:0:+16G      -t 3:0700 -c 3:"Basic data partition" \
    -n 4:-700M:0     -t 4:2700 -c 4:"Recovery" \
    "${raw}" >/dev/null
# Windows' EFI partition (FAT32) with a fake Windows boot manager file.
start="$(sgdisk -i 1 "${raw}" | awk '/First sector/ {print $3}')"
mkfs.fat -F 32 -n SYSTEM --offset "${start}" "${raw}" $((100 * 1024)) >/dev/null
img="${raw}@@$((start * 512))"
mmd -i "${img}" ::/EFI ::/EFI/Microsoft ::/EFI/Microsoft/Boot ::/EFI/Boot
printf 'fake Windows boot manager for testing\n' >"${vm}/bootmgfw.efi"
mcopy -i "${img}" "${vm}/bootmgfw.efi" ::/EFI/Microsoft/Boot/bootmgfw.efi
rm -f "${vm}/bootmgfw.efi"
qemu-img convert -f raw -O qcow2 "${raw}" "${disk}"
rm -f "${raw}"
echo "Fake Windows test disk ready (${size_gb} GB):"
echo "  1  100 MB  Windows EFI partition (with a fake Windows boot manager)"
echo "  2   16 MB  Microsoft reserved"
echo "  3   16 GB  Windows (C:)"
echo "     ~31 GB  free space  <- mipOS goes here"
echo "  4  700 MB  Windows recovery"
