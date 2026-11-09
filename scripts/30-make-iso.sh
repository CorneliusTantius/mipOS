#!/usr/bin/env bash
# Step 30: turn build/chroot/ into a bootable disk image (.iso) for UEFI PCs.
#
# Why our own script: Ubuntu's live-build only builds the system files.
# Its own image step can't make UEFI-bootable disks (Ubuntu itself uses
# separate tools for that). So we pack the image ourselves with GRUB.
#
# Only writes inside build/iso/ and out/.
source "$(dirname "$0")/lib.sh"
need_root

CHROOT="$BUILD_PATH/chroot"
STAGE="$BUILD_PATH/iso"
[ -d "$CHROOT/usr" ] || die "No built system found. Run first: sudo scripts/20-build-rootfs.sh"

info "Preparing the disk image layout in $BUILD_DIR/iso/"
rm -rf "$STAGE"
mkdir -p "$STAGE/casper" "$STAGE/boot/grub" "$STAGE/.disk"

# 1. Kernel and initrd (initrd = small starter system that loads the real one).
KVER=$(ls "$CHROOT"/boot/vmlinuz-* | sed 's|.*/vmlinuz-||' | sort -V | tail -1)
[ -n "$KVER" ] || die "No kernel found in $CHROOT/boot"
cp "$CHROOT/boot/vmlinuz-$KVER"    "$STAGE/casper/vmlinuz"
cp "$CHROOT/boot/initrd.img-$KVER" "$STAGE/casper/initrd"
ok "Kernel $KVER copied"

# 2. A list of installed packages (the installer uses it later).
dpkg-query --admindir="$CHROOT/var/lib/dpkg" -W --showformat='${Package} ${Version}\n' \
    > "$STAGE/casper/filesystem.manifest"
du -sx --block-size=1 "$CHROOT" | cut -f1 > "$STAGE/casper/filesystem.size"

# 3. Pack the whole system into one compressed file (squashfs).
info "Compressing the system (a few minutes)"
mksquashfs "$CHROOT" "$STAGE/casper/filesystem.squashfs" \
    -noappend -comp zstd -Xcompression-level 19 \
    -wildcards -e 'proc/*' 'sys/*' 'dev/*' 'run/*' 'tmp/*'

# 4. Small text file that names the disk.
echo "$DISTRO_NAME $DISTRO_VERSION $ARCH ($(date +%Y-%m-%d))" > "$STAGE/.disk/info"

# 5. Boot menu, filled in with values from mipos.conf.
sed -e "s|@DISTRO_NAME@|$DISTRO_NAME|g" \
    -e "s|@DISTRO_VERSION@|$DISTRO_VERSION|g" \
    "$PROJECT_DIR/iso/grub.cfg.in" > "$STAGE/boot/grub/grub.cfg"

# 6. Build the image. grub-mkrescue adds GRUB and the UEFI boot area.
info "Writing $ISO_FILE"
mkdir -p "$OUT_PATH"
grub-mkrescue -o "$ISO_FILE" "$STAGE" -- -volid "${DISTRO_ID^^}" 2>&1 | grep -v '^xorriso : UPDATE' || true
[ -s "$ISO_FILE" ] || die "The image was not created. See the messages above."

# Give the finished files back to your normal user, so you don't need sudo to use them.
if [ -n "${SUDO_USER:-}" ]; then chown -R "$SUDO_USER:" "$OUT_PATH"; fi

ok "Disk image ready: $ISO_FILE ($(du -h "$ISO_FILE" | cut -f1))"
ok "Next: scripts/40-test-vm.sh   (without sudo)"
