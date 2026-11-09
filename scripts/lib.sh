# Shared helpers for the mipOS build scripts.
# Each script starts with:  source "$(dirname "$0")/lib.sh"

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"
# shellcheck source=../mipos.conf
source "$PROJECT_DIR/mipos.conf"

BOOK="$PROJECT_DIR/lfs/book"
OVERRIDES="$PROJECT_DIR/lfs/overrides"
OUT="$PROJECT_DIR/out"
DONE_DIR="$LFS/.mipos-done"     # one marker file per finished step (lets a build resume)

info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m OK\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m !!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mERROR\033[0m %s\n' "$*" >&2; exit 1; }

need_root() { [ "$(id -u)" -eq 0 ] || die "Run with sudo: sudo $0"; }

# Book scripts of one chapter that contain a package (column 5 of index.tsv),
# in book order. Prints: script package version
chapter_packages() {
    awk -F'\t' -v c="$1" 'NR>1 && $1==c && $5!="" {print $4, $5, $6}' "$BOOK/index.tsv"
}
