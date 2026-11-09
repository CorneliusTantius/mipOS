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
# --linux-packages none : we list the kernel ourselves (see below), so it's
#                         installed together with our small firmware set
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
    --linux-packages none \
    --debian-installer false

# Copy our own files (package lists, hooks, extra files) on top,
# then add the files generated from mipos.conf.
cp -a "$PROJECT_DIR/config/." config/
rm -rf config/keys   # only used by gen-config.sh, not a live-build folder
"$PROJECT_DIR/scripts/gen-config.sh" "$BUILD_PATH/config"
chmod +x config/hooks/*.chroot config/includes.chroot/usr/local/sbin/*

ok "Settings ready. Next: sudo scripts/20-build-rootfs.sh"
