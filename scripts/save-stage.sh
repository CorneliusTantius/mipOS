#!/usr/bin/env bash
# Save the whole build folder ($LFS) into one file, so a later step (or a later
# GitHub job) can continue from here. This is the book's "backup" in 7.15.
#   sudo scripts/save-stage.sh <name>      -> out/<name>.tar.zst
#   sudo scripts/save-stage.sh --load <file>   restore it into $LFS
source "$(dirname "$0")/lib.sh"
need_root
mkdir -p "$OUT"
"$PROJECT_DIR/scripts/mounts.sh" down >/dev/null

if [ "${1:-}" = "--load" ]; then
    f=${2:?usage: save-stage.sh --load <file>}
    info "Restoring $f into $LFS"
    mkdir -p "$LFS"
    tar --zstd -xpf "$f" -C "$LFS" --numeric-owner
    id lfs >/dev/null 2>&1 || { groupadd lfs; useradd -s /bin/bash -g lfs -m -k /dev/null lfs; }
    ok "Restored."
else
    name=${1:?usage: save-stage.sh <name>}
    info "Saving $LFS to $OUT/$name.tar.zst"
    tar --zstd -cpf "$OUT/$name.tar.zst" -C "$LFS" --numeric-owner .
    ok "Saved $(du -h "$OUT/$name.tar.zst" | cut -f1)"
fi
