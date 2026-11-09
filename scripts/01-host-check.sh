#!/usr/bin/env bash
# Step 01: check the build computer has the right tool versions.
# Runs the book's own version-check.sh (chapter 2.2). Changes nothing.
source "$(dirname "$0")/lib.sh"

tmp=$(mktemp -d)
( cd "$tmp" && bash "$BOOK/ch2/02020-hostreqs.sh" ) | tee "$tmp/result.txt"
if grep -q 'ERROR' "$tmp/result.txt"; then
    die "The build computer is missing something (see ERROR lines above)."
fi
rm -rf "$tmp"
ok "Build computer passes the LFS host check."
