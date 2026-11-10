#!/usr/bin/env bash
# Make a fresh test disk for the VM (out/vm/disk.qcow2), replacing the old one.
#   scripts/make-test-disk.sh empty     an empty disk (for "Erase the whole disk")
#   scripts/make-test-disk.sh windows   a disk that looks like a Windows PC whose
#                                       Windows partition was shrunk: Windows EFI
#                                       partition with a (fake) Windows boot manager,
#                                       Windows partitions, and free space between
#                                       (for "Use free space" / dual boot)
#   scripts/make-test-disk.sh ubuntu    a disk that looks like Ubuntu 24.04 installed
#                                       with free space left over: Ubuntu's EFI
#                                       partition (fake shim/GRUB) and an ext4
#                                       partition with a fake Ubuntu system
# The fake systems can't really start; they're only there so the installer and
# the boot menu (os-prober) see "Windows" / "Ubuntu" and leave them alone.
source "$(dirname "$0")/lib.sh"

kind="${1:-}"
[[ ${kind} == empty || ${kind} == windows || ${kind} == ubuntu ]] || die "Usage: $0 empty|windows|ubuntu"
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

if [[ ${kind} == ubuntu ]]; then
    command -v mkfs.ext4 >/dev/null || die "Install e2fsprogs: sudo apt install e2fsprogs"
    # Ubuntu 24.04 layout: 1 GB EFI partition + ext4 system, here only 16 GB
    # so ~31 GB stay free (like an Ubuntu install that left free space).
    sgdisk -o \
        -n 1:2048:+1G  -t 1:ef00 -c 1:"" \
        -n 2:0:+16G    -t 2:8300 -c 2:"" \
        "${raw}" >/dev/null
    # Ubuntu's EFI partition: fake shim and GRUB in EFI/ubuntu.
    start="$(sgdisk -i 1 "${raw}" | awk '/First sector/ {print $3}')"
    mkfs.fat -F 32 --offset "${start}" "${raw}" $((1024 * 1024)) >/dev/null 2>&1
    img="${raw}@@$((start * 512))"
    mmd -i "${img}" ::/EFI ::/EFI/ubuntu ::/EFI/BOOT
    printf 'fake Ubuntu boot file for testing\n' >"${vm}/fake.efi"
    for f in EFI/ubuntu/shimx64.efi EFI/ubuntu/grubx64.efi EFI/ubuntu/mmx64.efi EFI/BOOT/BOOTX64.EFI; do
        mcopy -i "${img}" "${vm}/fake.efi" "::/${f}"
    done
    rm -f "${vm}/fake.efi"
    # Ubuntu's system partition (ext4) with just enough for os-prober to say
    # "Ubuntu": os-release, a loader file, a kernel and GRUB menu in /boot.
    tree="${vm}/ubuntu-tree"
    rm -rf "${tree}"
    mkdir -p "${tree}"/{etc,lib64,boot/grub,home/ubuntu-user}
    cat >"${tree}/etc/os-release" <<'OSR'
PRETTY_NAME="Ubuntu 24.04.1 LTS"
NAME="Ubuntu"
VERSION_ID="24.04"
VERSION="24.04.1 LTS (Noble Numbat)"
ID=ubuntu
ID_LIKE=debian
OSR
    echo "trixie/sid" >"${tree}/etc/debian_version"
    : >"${tree}/lib64/ld-linux-x86-64.so.2"
    echo "fake kernel" >"${tree}/boot/vmlinuz-6.8.0-45-generic"
    echo "fake initrd" >"${tree}/boot/initrd.img-6.8.0-45-generic"
    cat >"${tree}/boot/grub/grub.cfg" <<'GRUB'
menuentry 'Ubuntu' --class ubuntu --class gnu-linux --class os {
	linux	/boot/vmlinuz-6.8.0-45-generic root=/dev/nvme0n1p2 ro quiet splash
	initrd	/boot/initrd.img-6.8.0-45-generic
}
GRUB
    echo "This is the fake Ubuntu user's file. monarch must not change it." >"${tree}/home/ubuntu-user/keep-me.txt"
    start="$(sgdisk -i 2 "${raw}" | awk '/First sector/ {print $3}')"
    mkfs.ext4 -F -q -E offset=$((start * 512)) -d "${tree}" "${raw}" $((16 * 1024 * 1024))k 2>/dev/null
    rm -rf "${tree}"
    qemu-img convert -f raw -O qcow2 "${raw}" "${disk}"
    rm -f "${raw}"
    echo "Fake Ubuntu test disk ready (${size_gb} GB):"
    echo "  1    1 GB  Ubuntu's EFI partition (fake shim + GRUB in EFI/ubuntu)"
    echo "  2   16 GB  Ubuntu 24.04 (ext4, fake system + /home/ubuntu-user/keep-me.txt)"
    echo "     ~31 GB  free space  <- monarch goes here"
    exit 0
fi

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
echo "     ~31 GB  free space  <- monarch goes here"
echo "  4  700 MB  Windows recovery"
