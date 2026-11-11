#!/usr/bin/env bash
# Start a virtual machine (QEMU with UEFI firmware "OVMF") that imitates the
# ThinkPad L14 Gen 5 as far as QEMU can (NVMe disk, Intel Ethernet and sound).
#   scripts/test-vm.sh [path/to/monarch.iso]   start the ISO (default: the one in out/download/)
#   scripts/test-vm.sh --no-iso              start the installed system on the test disk
# The VM always has the test disk out/vm/disk.qcow2 (empty the first time).
# Screen size: VM_RESOLUTION in monarch.conf (default 1920x1080); one-off:
#   VM_RESOLUTION=1280x720 scripts/test-vm.sh
# New test disk: scripts/make-test-disk.sh empty|windows
source "$(dirname "$0")/lib.sh"

iso="${1:-}"
cdrom=()
if [[ ${iso} == --no-iso ]]; then
    iso=""
elif [[ -z "${iso}" ]]; then
    iso="$(find "${OUT_DIR}/download" "${ISO_DIR}" -name '*.iso' -print -quit 2>/dev/null || true)"
fi
if [[ -n ${1:-} && ${1} == --no-iso ]]; then
    :
else
    [[ -f "${iso}" ]] || die "No ISO found. Run scripts/get-iso.sh first, or give the path."
    cdrom=(-drive file="${iso}",media=cdrom,readonly=on)
fi
command -v qemu-system-x86_64 >/dev/null || die "Install QEMU: sudo apt install qemu-system-x86 ovmf"
[[ ${VM_RESOLUTION} =~ ^[0-9]+x[0-9]+$ ]] || die "VM_RESOLUTION must look like 1920x1080 (is: ${VM_RESOLUTION})"

# UEFI firmware files have different names on different distributions.
code=""; vars=""
for pair in "/usr/share/OVMF/OVMF_CODE_4M.fd:/usr/share/OVMF/OVMF_VARS_4M.fd" \
            "/usr/share/edk2/x64/OVMF_CODE.4m.fd:/usr/share/edk2/x64/OVMF_VARS.4m.fd" \
            "/usr/share/OVMF/OVMF_CODE.fd:/usr/share/OVMF/OVMF_VARS.fd" \
            "/usr/share/edk2/ovmf/OVMF_CODE.fd:/usr/share/edk2/ovmf/OVMF_VARS.fd"; do
    if [[ -f "${pair%%:*}" && -f "${pair##*:}" ]]; then code="${pair%%:*}"; vars="${pair##*:}"; break; fi
done
[[ -n "${code}" ]] || die "UEFI firmware (OVMF) not found. Install it: sudo apt install ovmf"

vm="${OUT_DIR}/vm"
mkdir -p "${vm}"
# The VM's own UEFI settings (boot entries) are kept here between runs.
[[ -f "${vm}/OVMF_VARS.fd" ]] || cp "${vars}" "${vm}/OVMF_VARS.fd"
[[ -f "${vm}/disk.qcow2" ]] || qemu-img create -f qcow2 "${vm}/disk.qcow2" "${VM_DISK_GB}G"

accel=(-cpu max)
if [[ -r /dev/kvm && -w /dev/kvm ]]; then
    accel=(-enable-kvm -cpu host)
else
    warn "No access to /dev/kvm: the VM will be very slow. Fix: sudo usermod -aG kvm \$USER, then log out and in."
fi

# Sound from the VM to this computer's speakers if a sound server runs here.
audio=(-audiodev none,id=snd)
command -v pactl >/dev/null && pactl info >/dev/null 2>&1 && audio=(-audiodev pa,id=snd)

say "Starting the VM from $([[ -n ${iso} ]] && basename "${iso}" || echo "the test disk") (close the window to stop it)"
# Devices chosen to look like the ThinkPad L14 Gen 5, so monarch uses the same
# drivers as on the laptop: NVMe disk (nvme), Intel Ethernet (e1000e), Intel HD
# Audio (snd_hda_intel), USB 3 (xhci), and the laptop's name in the firmware
# tables. CPU: this computer's own (-cpu host). Graphics stay virtual (virtio):
# QEMU can't imitate Intel graphics.
exec qemu-system-x86_64 \
    -machine q35 "${accel[@]}" -m "${VM_RAM_MB}" -smp "${VM_CPUS}" \
    -smbios type=1,manufacturer=LENOVO,product=21L2S1LM00,version="ThinkPad L14 Gen 5",family="ThinkPad L14 Gen 5" \
    -drive if=pflash,format=raw,readonly=on,file="${code}" \
    -drive if=pflash,format=raw,file="${vm}/OVMF_VARS.fd" \
    -drive file="${vm}/disk.qcow2",if=none,id=ssd,format=qcow2 \
    -device nvme,serial=MONARCHTEST01,drive=ssd \
    "${cdrom[@]}" \
    -nic user,model=e1000e \
    "${audio[@]}" -device intel-hda -device hda-duplex,audiodev=snd \
    -device qemu-xhci \
    -device virtio-rng-pci \
    -display gtk -device virtio-vga,xres="${VM_RESOLUTION%x*}",yres="${VM_RESOLUTION#*x}"
