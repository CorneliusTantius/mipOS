#!/usr/bin/env bash
# Step 30: enter the chroot and build the last temporary tools (LFS book, chapter 7).
source "$(dirname "$0")/lib.sh"
need_root
export LFS

# 7.2: from now on root owns everything (not the lfs user).
if [ ! -e "$DONE_DIR/07020-changingowner" ]; then
    info "Changing owner to root (7.2)"
    bash -e "$BOOK/ch7/07020-changingowner.sh"
    touch "$DONE_DIR/07020-changingowner"
fi

# 7.3 - 7.15 inside the chroot (in-chroot.sh mounts 7.3's virtual file systems).
info "Chapter 7: inside the chroot"
"$PROJECT_DIR/scripts/in-chroot.sh" lfs/plan/ch7-chroot-tools.txt
ok "Temporary system complete (milestone L1). Next: sudo scripts/save-stage.sh l1-temp-system"
