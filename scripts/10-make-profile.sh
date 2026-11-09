#!/usr/bin/env bash
# Step 10: copy archiso/ to out/profile and fill in the @NAMES@ from mipos.conf.
source "$(dirname "$0")/lib.sh"

case "${SQUASHFS_COMPRESSION}" in
    zstd) SQUASHFS_OPTIONS="'-comp' 'zstd' '-Xcompression-level' '${SQUASHFS_LEVEL}' '-b' '1M'" ;;
    xz)   SQUASHFS_OPTIONS="'-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M'" ;;
    *)    die "SQUASHFS_COMPRESSION must be zstd or xz (is: ${SQUASHFS_COMPRESSION})" ;;
esac

# NoExtract rules (size trimming) go into the build's pacman.conf.
NOEXTRACT="$(grep '^NoExtract' "${REPO_DIR}/archiso/airootfs/etc/pacman.d/mipos-noextract.conf")"
[[ "${STRIP_DOCS}" == "yes" ]] || NOEXTRACT=""

say "Copying archiso/ to ${PROFILE_DIR}"
rm -rf "${PROFILE_DIR}"
mkdir -p "${OUT_DIR}"
cp -a "${REPO_DIR}/archiso" "${PROFILE_DIR}"
find "${PROFILE_DIR}" -name .keep -delete

say "Filling in values from mipos.conf"
names=(DISTRO_NAME DISTRO_ID DISTRO_VERSION DISTRO_URL KERNEL LIVE_HOSTNAME
       LIVE_KERNEL_PARAMS SQUASHFS_OPTIONS NOEXTRACT JOURNAL_MAX_SIZE
       SERVICE_STOP_TIMEOUT ZRAM_SIZE_PERCENT ZRAM_COMPRESSION)
while IFS= read -r -d '' file; do
    text="$(<"${file}")"
    for name in "${names[@]}"; do
        text="${text//@${name}@/${!name}}"
    done
    printf '%s\n' "${text}" >"${file}"
done < <(find "${PROFILE_DIR}" -type f -print0)

# Anything still looking like @NAME@ is a typo or a missing setting.
if leftovers="$(grep -rnoE '@[A-Z][A-Z_]+@' "${PROFILE_DIR}")"; then
    die "Unfilled names in the profile:"$'\n'"${leftovers}"
fi
echo "Profile ready: ${PROFILE_DIR}"
