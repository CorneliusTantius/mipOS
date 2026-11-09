# Shared helpers for all mipOS build scripts.
# Each script loads this file first with:  source "$(dirname "$0")/lib.sh"

set -euo pipefail   # Stop at the first error instead of carrying on broken

# Find the project folder (one level above scripts/) and work from there.
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# Load the settings.
# shellcheck source=../mipos.conf
source "$PROJECT_DIR/mipos.conf"

BUILD_PATH="$PROJECT_DIR/$BUILD_DIR"
OUT_PATH="$PROJECT_DIR/$OUT_DIR"
ISO_FILE="$OUT_PATH/${DISTRO_ID}-${DISTRO_VERSION}-${ARCH}.iso"

# Coloured messages so it's easy to see what is going on.
info() { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m OK\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m !!\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mERROR\033[0m %s\n' "$*" >&2; exit 1; }

# Some steps need administrator rights (root). Stop early if we don't have them.
need_root() {
    [ "$(id -u)" -eq 0 ] || die "This step needs administrator rights. Run it again with: sudo $0"
}

# Some steps must NOT run as root (for example starting the VM).
no_root() {
    [ "$(id -u)" -ne 0 ] || die "Run this step without sudo: $0"
}
