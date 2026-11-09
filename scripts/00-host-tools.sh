#!/usr/bin/env bash
# Step 00: install what the build computer needs (LFS book, chapter 2.2).
# Meant for GitHub's Ubuntu build servers.
#
#   sudo scripts/00-host-tools.sh --change-bin-sh
#
# The LFS book needs /bin/sh to be bash. On Ubuntu /bin/sh is dash, so this
# script points /bin/sh to bash. That changes the build computer, which is why
# it only happens when you pass --change-bin-sh.
source "$(dirname "$0")/lib.sh"
need_root

[ "${1:-}" = "--change-bin-sh" ] || die "This changes /bin/sh on this computer. Run with --change-bin-sh to confirm."

export DEBIAN_FRONTEND=noninteractive
info "Installing build tools"
apt-get update -q
apt-get install -y -q build-essential bison gawk texinfo m4 patch python3 \
    wget curl xz-utils zstd bzip2 gzip tar coreutils diffutils findutils grep sed

info "Pointing /bin/sh to bash"
ln -sf bash /bin/sh
ok "Build computer ready. Next: scripts/01-host-check.sh"
