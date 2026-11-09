#!/usr/bin/env bash
# Step 50: make the slim "runtime" system from the full LFS build, and report sizes.
#
# The full build in $LFS keeps everything (compilers, headers, sources) so
# later steps can still compile. The runtime system is a copy WITHOUT:
#   - files from build-only packages (DROP_PACKAGES), except their shared libraries
#   - DROP_PATHS (headers, static libraries, docs, translations...)
#   - the build's own folders (sources, scripts, markers)
# Then it adds only the firmware files our drivers ask for (FIRMWARE_FOR).
# Output: out/mipos-rootfs.squashfs, out/vmlinuz, out/size-report.txt
source "$(dirname "$0")/lib.sh"
need_root
ROOTFS=/mnt/mipos-rootfs
FILES="$LFS/.mipos-files"
mkdir -p "$OUT"
"$PROJECT_DIR/scripts/mounts.sh" down >/dev/null

# --- 1. What to leave out ----------------------------------------------------
excl=$(mktemp)
{
    # Build folders and virtual file systems
    printf '%s\n' /sources /mipos '/.mipos-*' /tools '/tmp/*' '/proc/*' '/sys/*' '/dev/*' '/run/*' \
                  '/usr/lib/modules/*/build' '/usr/lib/modules/*/source'
    # Paths from mipos.conf
    # (set -f: treat the * in these patterns as text, rsync expands them)
    set -f; for p in $DROP_PATHS; do echo "$p"; done; set +f
    # Files installed by build-only packages (from the per-step file lists)
    for pkg in $DROP_PACKAGES; do
        awk -F'\t' -v p="$pkg" 'NR>1 && $5==p {print $4}' "$BOOK/index.tsv" | while read -r step; do
            list="$FILES/$(basename "$step" .sh).list"
            [ -f "$list" ] || continue
            # Never drop configuration (/etc), and keep shared libraries if asked.
            { grep -v '^/etc/' "$list" || true; } | {
                if [ "$KEEP_SHARED_LIBS" = yes ]; then grep -vE '\.so(\.[0-9]+)+$' || true; else cat; fi
            }
        done
    done
} | sort -u > "$excl"
info "Leaving out $(wc -l < "$excl") paths and patterns"

# --- 2. Copy the runtime system ----------------------------------------------
rm -rf "$ROOTFS"; mkdir -p "$ROOTFS"
rsync -aHAX --numeric-ids \
      --include=/usr/share/locale/locale.alias \
      --exclude-from="$excl" "$LFS/" "$ROOTFS/"
mkdir -p "$ROOTFS"/{tmp,proc,sys,dev,run}
chmod 1777 "$ROOTFS/tmp"
rm -f "$excl"

# --- 3. Firmware: only what our drivers request ------------------------------
kver=$(ls "$LFS/usr/lib/modules" | head -1)
fwsrc=$(mktemp -d)
info "Picking firmware for: $FIRMWARE_FOR"
tar -xf "$LFS/sources/$(awk -F'\t' 'NR>1 && $1 ~ /^linux-firmware/ {print $1}' "$PROJECT_DIR/lfs/extra-sources.tsv")" -C "$fwsrc"
fwdir=$(find "$fwsrc" -maxdepth 1 -mindepth 1 -type d | head -1)
mkdir -p "$ROOTFS/usr/lib/firmware"
for drv in $FIRMWARE_FOR; do
    mod=$(find "$LFS/usr/lib/modules/$kver" -name "$drv.ko*" | head -1)
    if [ -n "$mod" ]; then
        names=$(chroot "$LFS" /usr/sbin/modinfo -F firmware "${mod#$LFS}" 2>/dev/null || true)
    else   # built into the kernel: firmware names are in modules.builtin.modinfo
        names=$(tr '\0' '\n' < "$LFS/usr/lib/modules/$kver/modules.builtin.modinfo" | sed -n "s/^$drv\.firmware=//p")
    fi
    for n in $names; do
        # Exact file, or the same name with any version number (e.g. iwlwifi-...-89.ucode -> -86.ucode)
        base=$(echo "$n" | sed -E 's/-[0-9]+\.(ucode|bin)$//')
        ( cd "$fwdir" && ls -d $n "$base"* 2>/dev/null || true ) | sort -u | while read -r f; do
            mkdir -p "$ROOTFS/usr/lib/firmware/$(dirname "$f")"
            cp -L "$fwdir/$f" "$ROOTFS/usr/lib/firmware/$f"
        done
    done
done
# The kernel reads zstd-compressed firmware (CONFIG_FW_LOADER_COMPRESS_ZSTD).
find "$ROOTFS/usr/lib/firmware" -type f ! -name '*.zst' -exec zstd -q -19 --rm {} \;
rm -rf "$fwsrc"

# --- 4. Pack, and report sizes ------------------------------------------------
info "Packing the runtime system (squashfs, $SQUASHFS_COMPRESSION)"
rm -f "$OUT/mipos-rootfs.squashfs"
mksquashfs "$ROOTFS" "$OUT/mipos-rootfs.squashfs" -noappend -comp "$SQUASHFS_COMPRESSION" -quiet
cp "$LFS/boot/vmlinuz-$kver" "$OUT/vmlinuz"
cp "$LFS/boot/config-$kver" "$OUT/kernel-config"

{
    echo "mipOS size report ($(date -u +%Y-%m-%d), LFS $LFS_VERSION, kernel $kver)"
    echo
    printf '%-44s %s\n' "Full LFS build (without sources):" "$(du -sh --exclude=sources "$LFS" | cut -f1)"
    printf '%-44s %s\n' "Runtime system (unpacked):" "$(du -sh "$ROOTFS" | cut -f1)"
    printf '%-44s %s\n' "Runtime system (squashfs, $SQUASHFS_COMPRESSION):" "$(du -h "$OUT/mipos-rootfs.squashfs" | cut -f1)"
    printf '%-44s %s\n' "Kernel file (vmlinuz):" "$(du -h "$OUT/vmlinuz" | cut -f1)"
    printf '%-44s %s\n' "Kernel modules:" "$(du -sh "$ROOTFS/usr/lib/modules" | cut -f1) ($(find "$ROOTFS/usr/lib/modules" -name '*.ko*' | wc -l) files)"
    printf '%-44s %s\n' "Firmware:" "$(du -sh "$ROOTFS/usr/lib/firmware" | cut -f1) ($(find "$ROOTFS/usr/lib/firmware" -type f | wc -l) files)"
    echo
    echo "Biggest folders in the runtime system:"
    du -xh --max-depth=3 "$ROOTFS/usr" 2>/dev/null | sort -rh | head -15 | sed "s|$ROOTFS||"
} | tee "$OUT/size-report.txt"
ok "Runtime system ready: out/mipos-rootfs.squashfs, out/vmlinuz, out/size-report.txt"
