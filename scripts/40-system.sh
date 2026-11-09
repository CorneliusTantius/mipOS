#!/usr/bin/env bash
# Step 40: build the final system (LFS book, chapters 8-10) inside the chroot.
#   8: about 80 packages (the long part)   9: configuration   10: the lean kernel
# Every step records the files it installs (TRACK_FILES), so step 50 can leave
# build-only packages out of the finished system.
source "$(dirname "$0")/lib.sh"
need_root
export TRACK_FILES=yes
for plan in ch8-system ch9-config ch10-kernel; do
    info "Plan: $plan"
    "$PROJECT_DIR/scripts/in-chroot.sh" "lfs/plan/$plan.txt"
done
ok "Final system built (chapters 8-10). Next: sudo scripts/50-runtime-image.sh"
