#!/usr/bin/env bash
# Step 20: build the system itself (the "root filesystem" = all the files
# of the operating system) inside build/chroot/.
# Downloads Ubuntu packages. Takes 10 to 30 minutes the first time.
# Only writes inside build/. A full log is saved to out/build-rootfs.log.
source "$(dirname "$0")/lib.sh"
need_root

[ -f "$BUILD_PATH/config/common" ] || die "Settings not found. Run first: sudo scripts/10-configure.sh"

LOG="$OUT_PATH/build-rootfs.log"
cd "$BUILD_PATH"

info "Stage 1 of 2: creating the minimal base system (lb bootstrap)"
lb bootstrap 2>&1 | tee "$LOG"

info "Stage 2 of 2: installing packages and running our hooks (lb chroot)"
lb chroot 2>&1 | tee -a "$LOG"

ok "System built in $BUILD_DIR/chroot/. Next: sudo scripts/30-make-iso.sh"
