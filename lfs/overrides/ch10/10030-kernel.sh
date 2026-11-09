# mipOS override of 10.3 "Linux": instead of "make menuconfig" (a menu you
# click through), start from the kernel's default settings and merge in
# lfs/kernel/mipos.config. Then check that every setting we asked for stuck.
make mrproper
make defconfig
scripts/kconfig/merge_config.sh -m .config /mipos/lfs/kernel/mipos.config
make olddefconfig

# Report settings that didn't stick (usually a missing dependency).
grep -E '^(CONFIG_[A-Z0-9_]+=.*|# CONFIG_[A-Z0-9_]+ is not set)$' /mipos/lfs/kernel/mipos.config |
while read -r want; do
    grep -qxF "$want" .config || echo "NOTE: kernel setting not applied: $want"
done

make
make modules_install INSTALL_MOD_STRIP=1

ver=$(make -s kernelrelease)
cp -v arch/x86/boot/bzImage "/boot/vmlinuz-$ver"
cp -v System.map "/boot/System.map-$ver"
cp -v .config "/boot/config-$ver"
# (The book also copies the kernel's Documentation folder: we keep no docs.)
