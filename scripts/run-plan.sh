#!/bin/bash
# Run every step listed in a plan file, in order, with pkg.sh.
#   run-plan.sh <plan-file>      e.g. lfs/plan/ch5-cross-toolchain.txt
# Plan files list book steps, one per line (# starts a note).
set -euo pipefail
plan=${1:?usage: run-plan.sh <plan-file>}
here=$(cd "$(dirname "$0")" && pwd)
grep -vE '^[[:space:]]*(#|$)' "$plan" | awk '{print $1}' | while read -r step; do
    "$here/pkg.sh" "$step"
done
