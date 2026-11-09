#!/usr/bin/env bash
# Step 10: prepare the live-build work folder (build/) from mipos.conf
# and the files in config/. Only writes inside build/.
source "$(dirname "$0")/lib.sh"
need_root

if [ -d "$BUILD_PATH/chroot" ]; then
    die "An old build is still in $BUILD_DIR/. Run: sudo scripts/90-clean.sh  (then run this step again)"
fi

info "Creating live-build settings in $BUILD_DIR/"
mkdir -p "$BUILD_PATH" "$OUT_PATH"
cd "$BUILD_PATH"

# lb config writes live-build's own settings into build/config/.
# --mode ubuntu        : build from Ubuntu, not Debian
# --bootstrap-flavour minimal : smallest possible starting system
# --apt-recommends false : install only what we list, not "recommended" extras
# --initramfs casper   : casper = Ubuntu's program that boots a live disk
# --initsystem none    : casper already sets up the live session (no live-config)
lb config \
    --mode ubuntu \
    --distribution "$UBUNTU_CODENAME" \
    --architectures "$ARCH" \
    --archive-areas "$ARCHIVE_AREAS" \
    --mirror-bootstrap "$MIRROR" \
    --mirror-chroot "$MIRROR" \
    --mirror-binary "$MIRROR" \
    --mirror-chroot-security "$SECURITY_MIRROR" \
    --mirror-binary-security "$SECURITY_MIRROR" \
    --security true \
    --volatile true \
    --bootstrap debootstrap \
    --bootstrap-flavour minimal \
    --keyring-packages ubuntu-keyring \
    --apt apt \
    --apt-recommends false \
    --apt-source-archives false \
    --initramfs casper \
    --initsystem none \
    --linux-packages linux \
    --linux-flavours "$KERNEL_FLAVOUR" \
    --debian-installer false

# Copy our own files (package lists, hooks, extra files) on top.
cp -a "$PROJECT_DIR/config/." config/
chmod +x config/hooks/*.chroot

# Generated files: these come from mipos.conf, so they always match it.
mkdir -p config/includes.chroot/etc
# A copy of the settings for the hooks to read during the build (removed at the end).
cp "$PROJECT_DIR/mipos.conf" config/includes.chroot/etc/mipos-build.conf

# casper.conf: name of the live user and computer.
cat > config/includes.chroot/etc/casper.conf <<EOF
# Generated from mipos.conf by scripts/10-configure.sh
export USERNAME="$LIVE_USER"
export USERFULLNAME="$DISTRO_NAME live user"
export HOST="$LIVE_HOSTNAME"
export BUILD_SYSTEM="Ubuntu"
export FLAVOUR="$DISTRO_NAME"
EOF

ok "Settings ready. Next: sudo scripts/20-build-rootfs.sh"
