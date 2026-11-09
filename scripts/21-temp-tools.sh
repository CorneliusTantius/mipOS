#!/usr/bin/env bash
# Step 21: cross-compile the temporary tools (LFS book, chapter 6), as user lfs.
source "$(dirname "$0")/lib.sh"
need_root
info "Chapter 6: temporary tools"
"$PROJECT_DIR/scripts/as-lfs.sh" lfs/plan/ch6-temp-tools.txt
ok "Temporary tools built. Next: sudo scripts/30-chroot-tools.sh"
