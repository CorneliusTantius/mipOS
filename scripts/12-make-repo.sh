#!/usr/bin/env bash
# Step 12: put the desktop's packages on the ISO as a small offline package
# repository (usr/share/monarch/repo), so the installer can add the desktop
# without internet. Only packages the ISO doesn't already have are included.
# The installer does not copy the repository to the installed disk.
source "$(dirname "$0")/lib.sh"
need_root
need_arch
list="${PROFILE_DIR}/packages.${ARCH}"
[[ -f "${list}" ]] || die "Run scripts/10-make-profile.sh first."

repo="${PROFILE_DIR}/airootfs/usr/share/${DISTRO_ID}/repo"
cache=/var/cache/pacman/pkg
tmp="$(mktemp -d)"
chmod 755 "${tmp}"   # pacman downloads as an unprivileged user, which must be able to reach the folder
trap 'rm -rf "${tmp}"' EXIT
db="${tmp}/db"
mkdir -p "${db}/local"

say "Working out which desktop packages the ISO doesn't already have"
pacman --dbpath "${db}" -Sy --noconfirm >/dev/null
mapfile -t iso_pkgs < <(read_package_list "${list}")
# Names of everything pacman would install for a list of packages (with dependencies).
closure() { pacman --dbpath "${db}" -Sp --print-format '%n' --noconfirm "$@" | sort -u; }
# shellcheck disable=SC2086   # DESKTOP_PACKAGES is a list of words
mapfile -t all < <(closure "${iso_pkgs[@]}" ${DESKTOP_PACKAGES})
mapfile -t base < <(closure "${iso_pkgs[@]}")
mapfile -t need < <(comm -13 <(printf '%s\n' "${base[@]}") <(printf '%s\n' "${all[@]}"))
(( ${#need[@]} )) || die "No extra packages found for the desktop (DESKTOP_PACKAGES empty?)"
echo "${#need[@]} packages needed for the desktop on top of the ISO"

say "Downloading them (kept in the package cache between builds)"
pacman --dbpath "${db}" -Sddw --noconfirm --cachedir "${cache}" "${need[@]}"

say "Writing the repository to the ISO"
rm -rf "${repo}"
mkdir -p "${repo}"
while read -r f; do
    cp -- "${cache}/${f}" "${repo}/"
    [[ -f "${cache}/${f}.sig" ]] && cp -- "${cache}/${f}.sig" "${repo}/"
done < <(pacman --dbpath "${db}" -Sddp --print-format '%f' "${need[@]}")
repo-add -q "${repo}/${DISTRO_ID}-local.db.tar.zst" "${repo}"/*.pkg.tar.zst
echo "Offline repository: $(find "${repo}" -name '*.pkg.tar.zst' | wc -l) packages, $(du -sh "${repo}" | cut -f1)"
