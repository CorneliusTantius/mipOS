#!/usr/bin/env bash
# Step 90: delete the build work folder so the next build starts fresh.
#   sudo scripts/90-clean.sh        deletes build/ but keeps downloaded packages (faster rebuild)
#   sudo scripts/90-clean.sh --all  also deletes downloaded packages
# Never touches out/ (your finished images) or any disk.
source "$(dirname "$0")/lib.sh"
need_root

[ -d "$BUILD_PATH" ] || { ok "Nothing to clean."; exit 0; }
cd "$BUILD_PATH"

# lb clean safely unmounts anything still attached to build/chroot before deleting it.
if [ "${1:-}" = "--all" ]; then
    info "Deleting the build folder AND the package cache"
    lb clean --purge
    cd "$PROJECT_DIR" && rm -rf "$BUILD_PATH"
else
    info "Deleting the build folder (keeping the package cache)"
    lb clean --chroot --binary --stage
    rm -rf "$BUILD_PATH/iso" "$BUILD_PATH/config" "$BUILD_PATH/auto"
fi
ok "Clean."
