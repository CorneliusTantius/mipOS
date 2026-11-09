#!/usr/bin/env bash
# Writes the files that are generated from mipos.conf into a live-build
# config folder. Used by 10-configure.sh (real build) and
# 05-check-packages.sh (package test). Usage: gen-config.sh <config-dir>
source "$(dirname "$0")/lib.sh"

CFG="${1:?usage: gen-config.sh <config-dir>}"
mkdir -p "$CFG/package-lists" "$CFG/hooks" "$CFG/chroot_apt" \
         "$CFG/includes.chroot/etc/apt/preferences.d" \
         "$CFG/includes.chroot/usr/share/mipos"

# --- Settings copies --------------------------------------------------
# For the hooks during the build (deleted at the end of the build):
cp "$PROJECT_DIR/mipos.conf" "$CFG/includes.chroot/etc/mipos-build.conf"
# For the installer on the live disk (kept as a record on installed systems):
cp "$PROJECT_DIR/mipos.conf" "$CFG/includes.chroot/usr/share/mipos/mipos.conf"

# --- casper.conf: live user and computer name ------------------------
cat > "$CFG/includes.chroot/etc/casper.conf" <<EOF
# Generated from mipos.conf by scripts/gen-config.sh
export USERNAME="$LIVE_USER"
export USERFULLNAME="$DISTRO_NAME live user"
export HOST="$LIVE_HOSTNAME"
export BUILD_SYSTEM="Ubuntu"
export FLAVOUR="$DISTRO_NAME"
EOF

# --- Package lists that depend on settings ----------------------------
{
    echo "# Generated from mipos.conf: kernel, firmware, system services"
    for p in $KERNEL_PACKAGES $FIRMWARE_PACKAGES; do echo "$p"; done
    [ "$POWER_MANAGER" = "tlp" ]  && echo "tlp"
    [ -n "$THERMAL_DAEMON" ]      && echo "$THERMAL_DAEMON"
    [ "$ZRAM" = "yes" ]           && echo "systemd-zram-generator"
    [ "$DBUS_BROKER" = "yes" ]    && echo "dbus-broker"
    true
} > "$CFG/package-lists/05-kernel-firmware.list.chroot"

{
    echo "# Generated from mipos.conf: app format and browser"
    [ "$APP_FORMAT" = "flatpak" ]          && echo "flatpak"
    [ "$BROWSER" = "firefox-mozilla-apt" ] && echo "firefox"
    true
} > "$CFG/package-lists/30-apps.list.chroot"

# --- apt pins ---------------------------------------------------------
# Priority -1 = never install. Used during the build and kept afterwards.
BLOCK="$BLOCKED_PACKAGES $PLASMA_SKIP"
case " $FIRMWARE_PACKAGES " in *" linux-firmware-minimal "*) BLOCK="$BLOCK linux-firmware" ;; esac
{
    echo "# Generated from mipos.conf: packages that must never be installed."
    for p in $BLOCK; do
        printf 'Package: %s\nPin: release a=*\nPin-Priority: -1\n\n' "$p"
    done
} > "$CFG/chroot_apt/mipos-blocked.pref"
cp "$CFG/chroot_apt/mipos-blocked.pref" "$CFG/includes.chroot/etc/apt/preferences.d/"

if [ "$BROWSER" = "firefox-mozilla-apt" ]; then
    # Prefer Mozilla's real Firefox over Ubuntu's snap wrapper package.
    printf 'Package: *\nPin: origin packages.mozilla.org\nPin-Priority: 1000\n' \
        > "$CFG/chroot_apt/mozilla.pref"
    cp "$CFG/chroot_apt/mozilla.pref" "$CFG/includes.chroot/etc/apt/preferences.d/"
fi

# --- Early hooks (run BEFORE the package lists are installed) --------
# 0. The pins again. Ubuntu's live-build moves preferences.d aside while it
#    sets up the package sources, so pins from chroot_apt/ are NOT active
#    during the install. This hook puts them back before any package is chosen.
{
    echo '#!/bin/sh'
    echo '# Generated: activate mipOS apt pins (blocked packages, Mozilla) for the build.'
    echo 'set -e'
    echo 'mkdir -p /etc/apt/preferences.d'
    for f in "$CFG"/chroot_apt/*.pref; do
        echo "cat > /etc/apt/preferences.d/$(basename "$f") <<'EOF'"
        cat "$f"
        echo 'EOF'
    done
} > "$CFG/hooks/0005-mipos-pins.chroot_early"

# 1. dpkg strip rules: skip docs, man pages, translations.
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
} > "$CFG/hooks/0010-mipos-strip.chroot_early"

# 2. Mozilla's apt repository (for Firefox), with its signing key.
if [ "$BROWSER" = "firefox-mozilla-apt" ]; then
    {
        echo '#!/bin/sh'
        echo '# Generated: add Mozilla apt repository (key fingerprint 35BAA0B33E9EB396F59CA838C0BA5CE6DC6315A3).'
        echo 'set -e'
        echo 'apt-get install -y ca-certificates   # needed to download over https'
        echo 'mkdir -p /etc/apt/keyrings'
        echo "cat > /etc/apt/keyrings/packages.mozilla.org.asc <<'KEY'"
        cat "$PROJECT_DIR/config/keys/mozilla.asc"
        echo 'KEY'
        echo "cat > /etc/apt/sources.list.d/mozilla.sources <<'EOF'"
        echo 'Types: deb'
        echo 'URIs: https://packages.mozilla.org/apt'
        echo 'Suites: mozilla'
        echo 'Components: main'
        echo 'Signed-By: /etc/apt/keyrings/packages.mozilla.org.asc'
        echo 'EOF'
        echo 'apt-get update'
    } > "$CFG/hooks/0020-mipos-mozilla.chroot_early"
fi

chmod +x "$CFG"/hooks/*.chroot_early
