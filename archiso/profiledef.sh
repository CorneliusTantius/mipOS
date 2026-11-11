#!/usr/bin/env bash
# shellcheck disable=SC2034
# archiso profile settings for the monarch live ISO.
# Words between @ signs are filled in from monarch.conf by scripts/10-make-profile.sh.

iso_name="@DISTRO_ID@"
iso_label="MONARCH_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="@DISTRO_NAME@ <@DISTRO_URL@>"
iso_application="@DISTRO_NAME@ live system and installer"
iso_version="@DISTRO_VERSION@-$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="@DISTRO_ID@"
buildmodes=('iso')
bootmodes=('uefi.systemd-boot')          # UEFI only, no old BIOS boot
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=(@SQUASHFS_OPTIONS@)
kernel_params_x86_64="@LIVE_KERNEL_PARAMS@"
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/usr/local/bin/monarch-install"]="0:0:755"
  ["/usr/local/bin/monarch-popup"]="0:0:755"
  ["/usr/local/sbin/monarch-trim-hardware"]="0:0:755"
  ["/usr/local/sbin/monarch-power-source"]="0:0:755"
  ["/usr/local/sbin/monarch-add-desktop"]="0:0:755"
)
