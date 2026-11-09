#!/usr/bin/env bash
# Step 15: make sure every package in the list exists in Arch's repos,
# before spending time on a build. Works on Arch (pacman) and on other
# Linux systems (asks archlinux.org instead).
source "$(dirname "$0")/lib.sh"

list="${PROFILE_DIR}/packages.${ARCH}"
[[ -f "${list}" ]] || die "Run scripts/10-make-profile.sh first."
mapfile -t pkgs < <(read_package_list "${list}")
say "Checking ${#pkgs[@]} packages"

missing=()
if command -v pacman >/dev/null; then
    for p in "${pkgs[@]}"; do
        pacman -Si -- "${p}" >/dev/null 2>&1 || pacman -Sg -- "${p}" >/dev/null 2>&1 || missing+=("${p}")
    done
else
    for p in "${pkgs[@]}"; do
        json="$(curl -fsS "https://archlinux.org/packages/search/json/?name=${p}")" || die "Can't reach archlinux.org"
        grep -q '"pkgname"' <<<"${json}" || missing+=("${p}")
    done
fi

if (( ${#missing[@]} )); then
    die "Not found in Arch's repos: ${missing[*]}"
fi
echo "All packages exist."
