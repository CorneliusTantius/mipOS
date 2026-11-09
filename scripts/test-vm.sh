#!/usr/bin/env bash
# Start a virtual machine (QEMU with UEFI firmware "OVMF") from an ISO.
#   scripts/test-vm.sh [path/to/mipos.iso]   (default: the ISO in out/download/)
# Also attaches a test disk out/vm/disk.qcow2 (created empty the first time).
# Wipe the test disk:  rm out/vm/disk.qcow2
source "$(dirname "$0")/lib.sh"

# Look in out/download/ (from get-iso.sh, any subfolder) and out/iso/ (local build).
iso="${1:-}"
if [[ -z "${iso}" ]]; then
    iso="$(find "${OUT_DIR}/download" "${ISO_DIR}" -name '*.iso' -print -quit 2>/dev/null || true)"
fi
[[ -f "${iso}" ]] || die "No ISO found. Run scripts/get-iso.sh first, or give the path."
command -v qemu-system-x86_64 >/dev/null || die "Install QEMU: sudo apt install qemu-system-x86 ovmf"

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

say "Starting the VM from $(basename "${iso}") (close the window to stop it)"
exec qemu-system-x86_64 \
    -machine q35 "${accel[@]}" -m "${VM_RAM_MB}" -smp "${VM_CPUS}" \
    -drive if=pflash,format=raw,readonly=on,file="${code}" \
    -drive if=pflash,format=raw,file="${vm}/OVMF_VARS.fd" \
    -drive file="${vm}/disk.qcow2",if=virtio,format=qcow2 \
    -drive file="${iso}",media=cdrom,readonly=on \
    -nic user,model=virtio-net-pci \
    -device virtio-rng-pci \
    -display gtk -vga virtio
