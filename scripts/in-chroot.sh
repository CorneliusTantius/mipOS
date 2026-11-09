#!/usr/bin/env bash
# Run a plan file INSIDE the chroot (LFS book 7.4: "Entering the Chroot Environment").
#   sudo scripts/in-chroot.sh lfs/plan/ch7-chroot-tools.txt
# chroot = run programs with $LFS as their root folder "/", so they only see
# the new system. Same clean environment as the book.
source "$(dirname "$0")/lib.sh"
need_root
plan=${1:?usage: in-chroot.sh <plan-file>}
cp -a "$PROJECT_DIR/lfs" "$PROJECT_DIR/scripts" "$PROJECT_DIR/mipos.conf" "$LFS/mipos/"

"$PROJECT_DIR/scripts/mounts.sh" up >/dev/null
trap '"$PROJECT_DIR/scripts/mounts.sh" down >/dev/null' EXIT

chroot "$LFS" /usr/bin/env -i \
    HOME=/root TERM="${TERM:-dumb}" PATH=/usr/bin:/usr/sbin \
    MAKEFLAGS="-j$(nproc)" TESTSUITEFLAGS="-j$(nproc)" RUN_TESTS="$RUN_TESTS" \
    MIPOS_DIR=/mipos SRC=/sources DONE_DIR=/.mipos-done LOG_DIR=/.mipos-logs \
    TRACK_FILES="${TRACK_FILES:-no}" FILES_DIR=/.mipos-files \
    /bin/bash /mipos/scripts/run-plan.sh "/mipos/$plan"
