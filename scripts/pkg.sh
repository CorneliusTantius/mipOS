#!/bin/bash
# Run ONE step of the LFS book.
#
#   pkg.sh <step-script>          e.g. ch5/05020-binutils-pass1.sh
#
# For a package step: unpack its source tarball, go into the folder, run the
# book's commands, then delete the folder (the book's "general instructions").
# For other steps (creating files, folders): just run the commands.
#
# Uses lfs/overrides/<same path> instead of the book's script if it exists.
# A marker file in $DONE_DIR records finished steps, so a rerun skips them.
# Works on the build computer (chapters 5-6, as user lfs) and inside the
# chroot (chapter 7 onwards); paths come from the environment:
#   MIPOS_DIR  folder with lfs/ and scripts/   SRC  source tarballs
#   DONE_DIR   markers                         LOG_DIR  one log per step
set -uo pipefail

step=${1:?usage: pkg.sh <step-script>}
BOOK="$MIPOS_DIR/lfs/book"
name=$(basename "$step" .sh)
marker="$DONE_DIR/$name"
log="$LOG_DIR/$name.log"
mkdir -p "$DONE_DIR" "$LOG_DIR"

if [ -e "$marker" ]; then echo "   done already: $name"; exit 0; fi

script="$BOOK/$step"
[ -f "$MIPOS_DIR/lfs/overrides/$step" ] && script="$MIPOS_DIR/lfs/overrides/$step"
[ -f "$script" ] || { echo "No such step: $step"; exit 1; }

# Package and version for this step, from the book index.
read -r pkg ver < <(awk -F'\t' -v s="$step" '$4==s {print $5, $6}' "$BOOK/index.tsv")

# The book sometimes starts a new interactive shell ("exec bash --login") or
# says "exit"/"logout": those make sense when typing by hand, not in a script.
cmds=$(mktemp)
grep -vE '^[[:space:]]*(exec .*bash --login|logout|exit)[[:space:]]*$' "$script" > "$cmds"

workdir="$SRC"
srcdir=""
if [ -n "${pkg:-}" ]; then
    tarball=$(cd "$SRC" && ls | grep -iE "^${pkg}-${ver}\.tar\.(xz|gz|bz2|zst)$" | head -1)
    [ -n "$tarball" ] || { echo "Source not found for $pkg-$ver in $SRC"; exit 1; }
    srcdir=$(tar -tf "$SRC/$tarball" | head -1 | cut -d/ -f1)
    rm -rf "${SRC:?}/$srcdir"
    tar -xf "$SRC/$tarball" -C "$SRC"
    workdir="$SRC/$srcdir"
fi

printf '   building %-40s ' "$name"
start=$(date +%s)
( cd "$workdir" && bash -eo pipefail "$cmds" ) > "$log" 2>&1
rc=$?
secs=$(( $(date +%s) - start ))
rm -f "$cmds"

if [ "$rc" -ne 0 ]; then
    echo "FAILED after ${secs}s"
    echo "----- last 60 lines of $log -----"
    tail -n 60 "$log"
    exit "$rc"
fi
[ -n "$srcdir" ] && rm -rf "${SRC:?}/$srcdir"
touch "$marker"
echo "ok (${secs}s)"
