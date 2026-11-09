#!/usr/bin/env bash
# Run a plan file as user lfs, with the clean environment from the book (4.4).
#   sudo scripts/as-lfs.sh lfs/plan/ch5-cross-toolchain.txt
source "$(dirname "$0")/lib.sh"
need_root
plan=${1:?usage: as-lfs.sh <plan-file>}
# Fresh copy of the plans/overrides, in case they changed since step 10.
cp -a "$PROJECT_DIR/lfs" "$PROJECT_DIR/scripts" "$PROJECT_DIR/mipos.conf" "$LFS/mipos/"
chown -R lfs:lfs "$LFS/mipos"

# env -i = start with an empty environment, then load only ~/.bashrc (as the book does).
sudo -u lfs env -i HOME=/home/lfs TERM="${TERM:-dumb}" RUN_TESTS="$RUN_TESTS" \
    MIPOS_DIR="$LFS/mipos" SRC="$LFS/sources" DONE_DIR="$LFS/.mipos-done" LOG_DIR="$LFS/.mipos-logs" \
    bash -c "source ~/.bashrc && $LFS/mipos/scripts/run-plan.sh $LFS/mipos/$plan"
