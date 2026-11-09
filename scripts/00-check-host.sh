#!/usr/bin/env bash
# Step 00: check that this computer can build mipOS.
# Changes nothing. Only looks and reports.
source "$(dirname "$0")/lib.sh"

problems=0
fail() { warn "$*"; problems=$((problems + 1)); }

info "Checking the build computer"

# 1. Operating system: must be Ubuntu or Debian.
. /etc/os-release
case "$ID" in
    ubuntu|debian) ok "Operating system: $PRETTY_NAME" ;;
    *) fail "Operating system is $PRETTY_NAME. Ubuntu or Debian is needed." ;;
esac

# 2. Free disk space: a build needs about 20 GB.
free_gb=$(df --output=avail -BG "$PROJECT_DIR" | tail -1 | tr -dc '0-9')
if [ "$free_gb" -ge 20 ]; then ok "Free disk space: ${free_gb} GB"
else fail "Only ${free_gb} GB free. About 20 GB is needed."; fi

# 3. Virtual machine support (KVM).
if [ -e /dev/kvm ]; then
    if [ -r /dev/kvm ] && [ -w /dev/kvm ]; then ok "KVM (fast virtual machines) is usable"
    else fail "KVM exists but you can't use it. Fix: sudo usermod -aG kvm $USER  (then log out and back in)"; fi
else
    fail "KVM not found. Turn on virtualization (VT-x / SVM) in your PC's firmware settings."
fi

# 4. Tools.
for tool in lb debootstrap mksquashfs xorriso grub-mkrescue mformat qemu-system-x86_64 git; do
    if command -v "$tool" >/dev/null 2>&1; then ok "Tool found: $tool"
    else fail "Tool missing: $tool  (run: sudo scripts/01-install-host-tools.sh)"; fi
done

# 5. UEFI firmware for the VM.
for f in "$OVMF_CODE" "$OVMF_VARS"; do
    if [ -f "$f" ]; then ok "UEFI firmware file: $f"
    else fail "UEFI firmware file missing: $f  (package: ovmf)"; fi
done

echo
if [ "$problems" -eq 0 ]; then ok "All checks passed. You're ready to build."
else die "$problems problem(s) found. Fix them and run this check again."; fi
