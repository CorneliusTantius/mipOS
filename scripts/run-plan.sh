#!/bin/bash
# Run every step listed in a plan file, in order, with pkg.sh.
#   run-plan.sh <plan-file>      e.g. lfs/plan/ch5-cross-toolchain.txt
# Plan files list book steps, one per line (# starts a note).
set -euo pipefail
plan=${1:?usage: run-plan.sh <plan-file>}
here=$(cd "$(dirname "$0")" && pwd)
# A line tagged "tests-only" is skipped unless RUN_TESTS=yes (those packages
# only exist to run other packages' test suites).
grep -vE '^[[:space:]]*(#|$)' "$plan" | while read -r step rest; do
    if [[ "$rest" == *tests-only* ]] && [ "${RUN_TESTS:-no}" != yes ]; then
        echo "   skipped (tests only): $(basename "$step" .sh)"; continue
    fi
    "$here/pkg.sh" "$step"
done
