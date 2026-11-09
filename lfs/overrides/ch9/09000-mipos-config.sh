# mipOS step (replaces the fill-in-the-blank parts of LFS chapter 9 and the
# release files of chapter 11.1). Everything comes from mipos.conf.
. /mipos/mipos.conf

# 9.2 Network: systemd-networkd gets an address by DHCP on any cable or Wi-Fi
# connection; systemd-resolved looks up names. (iwd joins Wi-Fi from L3 on.)
mkdir -p /etc/systemd/network
cat > /etc/systemd/network/20-wired.network << "CONF"
[Match]
Type=ether

[Network]
DHCP=yes
CONF
cat > /etc/systemd/network/25-wireless.network << "CONF"
[Match]
Type=wlan

[Network]
DHCP=yes
IgnoreCarrierLoss=3s
CONF
ln -sf ../run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
systemctl enable systemd-networkd systemd-resolved

# 9.2.3 Hostname and hosts
echo "$DISTRO_ID" > /etc/hostname
cat > /etc/hosts << CONF
127.0.0.1  localhost
127.0.1.1  $DISTRO_ID
::1        localhost ip6-localhost ip6-loopback
CONF

# 9.5 Clock: the hardware clock keeps UTC (the systemd default). Nothing to do.
# 9.6 Console: keyboard layout for the text console.
cat > /etc/vconsole.conf << CONF
KEYMAP=us
CONF

# 9.7 Language
echo "LANG=${GLIBC_LOCALES%% *}" > /etc/locale.conf

# 9.9 Login shells
cat > /etc/shells << "CONF"
/bin/sh
/bin/bash
CONF

# 9.10 systemd settings, with the lightweight tuning from mipos.conf
mkdir -p /etc/systemd/journald.conf.d /etc/systemd/system.conf.d
cat > /etc/systemd/journald.conf.d/10-mipos.conf << CONF
[Journal]
SystemMaxUse=$JOURNAL_MAX_SIZE
RuntimeMaxUse=$JOURNAL_MAX_SIZE
CONF
cat > /etc/systemd/system.conf.d/10-mipos.conf << CONF
[Manager]
DefaultTimeoutStopSec=$SERVICE_STOP_TIMEOUT
CONF

# zram: compressed swap in RAM, set up at boot with zramctl (from util-linux).
if [ "$ZRAM" = yes ]; then
    mkdir -p /usr/libexec/mipos
    cat > /usr/libexec/mipos/zram-setup << CONF
#!/bin/sh
# Create a zram swap device of $ZRAM_SIZE_PERCENT% of RAM, compressed with zstd.
kib=\$(awk '/MemTotal/ {print int(\$2 * $ZRAM_SIZE_PERCENT / 100)}' /proc/meminfo)
dev=\$(zramctl --find --algorithm zstd --size "\${kib}KiB") || exit 1
mkswap "\$dev" >/dev/null && swapon --priority 100 "\$dev"
CONF
    chmod 755 /usr/libexec/mipos/zram-setup
    cat > /etc/systemd/system/mipos-zram.service << "CONF"
[Unit]
Description=Compressed swap in RAM (zram)
DefaultDependencies=no
Before=swap.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/libexec/mipos/zram-setup
ExecStop=/bin/sh -c 'swapoff /dev/zram0; zramctl --reset /dev/zram0'

[Install]
WantedBy=swap.target
CONF
    mkdir -p /etc/sysctl.d
    printf 'vm.swappiness = 180\nvm.page-cluster = 0\n' > /etc/sysctl.d/90-mipos-zram.conf
    systemctl enable mipos-zram.service
fi

# 10.2 fstab: the live system mounts nothing extra; the installer writes the real one.
echo "# /etc/fstab: written by mipos-install on installed systems" > /etc/fstab

# 11.1 Release files: mipOS instead of "Linux From Scratch"
echo "$LFS_VERSION" > /etc/lfs-release
cat > /etc/os-release << CONF
NAME="$DISTRO_NAME"
VERSION="$DISTRO_VERSION (LFS $LFS_VERSION)"
ID=$DISTRO_ID
ID_LIKE=lfs
PRETTY_NAME="$DISTRO_NAME $DISTRO_VERSION"
VERSION_ID="$DISTRO_VERSION"
HOME_URL="$DISTRO_URL"
BUG_REPORT_URL="$DISTRO_URL/issues"
CONF
cat > /etc/lsb-release << CONF
DISTRIB_ID="$DISTRO_NAME"
DISTRIB_RELEASE="$DISTRO_VERSION"
DISTRIB_DESCRIPTION="$DISTRO_NAME $DISTRO_VERSION (built from LFS $LFS_VERSION)"
CONF
printf '%s %s \\n \\l\n\n' "$DISTRO_NAME" "$DISTRO_VERSION" > /etc/issue

# Live system for testing: root can log in on the console without a password.
# (mipos-install locks root and creates a real user on installed systems.)
passwd -d root
