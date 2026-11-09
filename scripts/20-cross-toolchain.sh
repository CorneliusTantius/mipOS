#!/usr/bin/env bash
# Step 20: build the cross-toolchain (LFS book, chapter 5), as user lfs.
# Takes about 20-30 minutes on GitHub's servers.
source "$(dirname "$0")/lib.sh"
need_root
info "Chapter 5: cross-toolchain"
"$PROJECT_DIR/scripts/as-lfs.sh" lfs/plan/ch5-cross-toolchain.txt
ok "Cross-toolchain built. Next: sudo scripts/21-temp-tools.sh"
