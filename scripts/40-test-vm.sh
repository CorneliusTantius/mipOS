#!/usr/bin/env bash
# Step 40: start the disk image in a virtual machine (QEMU/KVM) with UEFI.
# Doesn't touch any real disk. Close the VM window to stop it.
source "$(dirname "$0")/lib.sh"
no_root

[ -f "$ISO_FILE" ] || die "No disk image found. Run first: sudo scripts/30-make-iso.sh"

# The VM keeps its UEFI settings in a small file. We start from a fresh copy each time.
VARS="$OUT_PATH/uefi-vars-live.fd"
cp "$OVMF_VARS" "$VARS"

info "Starting the VM: ${VM_RAM_MB} MB RAM, ${VM_CPUS} CPUs, UEFI"
info "Messages from the 'debug' boot entry also appear in this terminal."
exec qemu-system-x86_64 \
    -enable-kvm -machine q35 -cpu host \
    -m "$VM_RAM_MB" -smp "$VM_CPUS" \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
    -drive if=pflash,format=raw,file="$VARS" \
    -cdrom "$ISO_FILE" -boot d \
    -vga virtio -display gtk \
    -nic user,model=virtio-net-pci \
    -serial stdio
