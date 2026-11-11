#!/usr/bin/env bash
# Step 26: check that the offline desktop repository on the ISO is complete:
# installing the desktop on top of the built live system must work using only
# the repository (no missing or mismatching packages).
#   scripts/26-check-repo.sh [system-folder]   (default: the built live system)
source "$(dirname "$0")/lib.sh"

root="${1:-${WORK_DIR}/${ARCH}/airootfs}"
repo="${root}/usr/share/${DISTRO_ID}/repo"
[[ -f "${repo}/${DISTRO_ID}-local.db.tar.zst" ]] || die "No offline repository in ${repo}"
say "Checking that the desktop can be installed from the offline repository"

tmp="$(mktemp -d)"
trap 'rm -rf "${tmp}"' EXIT
mkdir -p "${tmp}/db/sync"
cp -a "${root}/var/lib/pacman/local" "${tmp}/db/local"
cp -L "${repo}/${DISTRO_ID}-local.db.tar.zst" "${tmp}/db/sync/${DISTRO_ID}-local.db"
cat >"${tmp}/pacman.conf" <<EOF
[options]
Architecture = ${ARCH}
SigLevel = Never
[${DISTRO_ID}-local]
Server = file://${repo}
EOF
# shellcheck disable=SC2086   # DESKTOP_PACKAGES is a list of words
if ! out="$(pacman --config "${tmp}/pacman.conf" --dbpath "${tmp}/db" \
        -S --print --needed --noconfirm ${DESKTOP_PACKAGES} 2>&1)"; then
    echo "${out}"
    die "The desktop can't be installed from the offline repository (a package is missing or doesn't match the ISO). Rebuild: Arch probably published an update during the build."
fi
echo "Offline repository complete: $(grep -c . <<<"${out}") packages would be installed."
