#!/usr/bin/env bash
# Shared helpers for the numbered build scripts. Not run on its own.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${REPO_DIR}/out"
PROFILE_DIR="${OUT_DIR}/profile"     # filled-in copy of archiso/
WORK_DIR="${OUT_DIR}/work"           # mkarchiso's scratch folder
ISO_DIR="${OUT_DIR}/iso"             # finished ISO + checksum

# shellcheck source=../monarch.conf
source "${REPO_DIR}/monarch.conf"

say()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARNING: %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }

need_root() { [[ ${EUID} -eq 0 ]] || die "Run this as root (sudo $0)."; }
need_arch() { [[ -f /etc/arch-release ]] || die "This step must run on Arch Linux (the GitHub build uses an Arch container)."; }

# Package names from a package list file: drop notes and empty lines.
read_package_list() { sed -e 's/#.*//' -e 's/[[:space:]]//g' -e '/^$/d' "$1"; }
