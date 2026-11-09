#!/usr/bin/env bash
# Runs a complete build from scratch: clean, configure, build system, make image.
# Usage: sudo scripts/build-all.sh
source "$(dirname "$0")/lib.sh"
need_root

"$PROJECT_DIR/scripts/90-clean.sh"
"$PROJECT_DIR/scripts/10-configure.sh"
"$PROJECT_DIR/scripts/20-build-rootfs.sh"
"$PROJECT_DIR/scripts/30-make-iso.sh"
