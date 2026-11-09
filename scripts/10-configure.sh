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

# Copy our own files (package lists, hooks, extra files) on top.
cp -a "$PROJECT_DIR/config/." config/

# ---------------------------------------------------------------------
# Generated files: these come from mipos.conf, so they always match it.
# ---------------------------------------------------------------------
mkdir -p config/includes.chroot/etc/apt/preferences.d config/chroot_apt

# A copy of the settings for the hooks to read during the build (removed at the end).
cp "$PROJECT_DIR/mipos.conf" config/includes.chroot/etc/mipos-build.conf

# 1. casper.conf: name of the live user and computer.
cat > config/includes.chroot/etc/casper.conf <<EOF
# Generated from mipos.conf by scripts/10-configure.sh
export USERNAME="$LIVE_USER"
export USERFULLNAME="$DISTRO_NAME live user"
export HOST="$LIVE_HOSTNAME"
export BUILD_SYSTEM="Ubuntu"
export FLAVOUR="$DISTRO_NAME"
EOF

# 2. Kernel, firmware and lightweight system services.
{
    echo "# Generated from mipos.conf by scripts/10-configure.sh"
    for p in $KERNEL_PACKAGES $FIRMWARE_PACKAGES; do echo "$p"; done
    [ "$POWER_MANAGER" = "tlp" ]   && echo "tlp"
    [ -n "$THERMAL_DAEMON" ]       && echo "$THERMAL_DAEMON"
    [ "$ZRAM" = "yes" ]            && echo "systemd-zram-generator"
    [ "$DBUS_BROKER" = "yes" ]     && echo "dbus-broker"
    true
} > config/package-lists/05-kernel-firmware.list.chroot

# 3. Blocked packages: an apt "pin" with priority -1 means "never install".
#    Used during the build (chroot_apt) and kept in the finished system.
BLOCK="$BLOCKED_PACKAGES"
# With the small firmware set, also block the full firmware bundle, so nothing pulls it back in.
case " $FIRMWARE_PACKAGES " in *" linux-firmware-minimal "*) BLOCK="$BLOCK linux-firmware" ;; esac
{
    echo "# Generated from mipos.conf: packages that must never be installed."
    for p in $BLOCK; do
        printf 'Package: %s\nPin: release a=*\nPin-Priority: -1\n\n' "$p"
    done
} > config/chroot_apt/mipos-blocked.pref
cp config/chroot_apt/mipos-blocked.pref config/includes.chroot/etc/apt/preferences.d/

# 4. Strip rules for dpkg. They must be in place BEFORE packages are installed,
#    so they go into an "early" hook (runs before the package lists).
{
    echo '#!/bin/sh'
    echo '# Generated from mipos.conf: tell dpkg to skip files we never use.'
    echo 'set -e'
    echo 'mkdir -p /etc/dpkg/dpkg.cfg.d'
    echo 'cat > /etc/dpkg/dpkg.cfg.d/01-mipos-strip <<EOF'
    if [ "$STRIP_DOCS" = "yes" ]; then
        echo 'path-exclude=/usr/share/doc/*'
        echo 'path-include=/usr/share/doc/*/copyright'
        echo 'path-exclude=/usr/share/lintian/*'
    fi
    if [ "$STRIP_MAN" = "yes" ]; then
        echo 'path-exclude=/usr/share/man/*'
        echo 'path-exclude=/usr/share/info/*'
    fi
    if [ "$STRIP_LOCALES" = "yes" ]; then
        echo 'path-exclude=/usr/share/locale/*'
        echo 'path-include=/usr/share/locale/locale.alias'
        for l in $KEEP_LOCALES; do echo "path-include=/usr/share/locale/$l/*"; done
    fi
    echo 'EOF'
} > config/hooks/0010-mipos-strip.chroot_early

chmod +x config/hooks/*.chroot config/hooks/*.chroot_early

ok "Settings ready. Next: sudo scripts/20-build-rootfs.sh"
