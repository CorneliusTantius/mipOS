#!/usr/bin/env bash
# Step 10: prepare the build folder (LFS book, chapters 3 and 4).
#   - create $LFS and download all source files, checking their MD5 sums
#   - create the basic folder layout and the "lfs" build user
#   - copy the book scripts to $LFS/mipos so user lfs and the chroot can use them
# Writes only inside $LFS (and adds the user "lfs").
source "$(dirname "$0")/lib.sh"
need_root
export LFS

info "Creating $LFS"
mkdir -p "$LFS/sources"
chmod -v a+wt "$LFS/sources"

# --- Chapter 3: sources -------------------------------------------------
info "Downloading source files (about 600 MB)"
cd "$LFS/sources"
while read -r url; do
    [ -n "$url" ] || continue
    file=$(basename "$url")
    want=$(awk -v f="$file" '$2==f {print $1}' "$BOOK/md5sums")
    if [ -f "$file" ] && [ "$(md5sum < "$file" | cut -d' ' -f1)" = "$want" ]; then continue; fi
    # LFS mirror first (everything in one place), then the project's own site.
    if ! wget -q --tries=3 --timeout=60 "$LFS_MIRROR/$file" -O "$file"; then
        warn "Not on the mirror, trying $url"
        wget -q --tries=3 --timeout=60 "$url" -O "$file" || die "Could not download $file"
    fi
done < "$BOOK/wget-list"
md5sum -c "$BOOK/md5sums" --quiet || die "A downloaded file is damaged (MD5 sum doesn't match)."
ok "All $(wc -l < "$BOOK/md5sums") source files downloaded and checked"

# Extra files mipOS needs beyond the book (lfs/extra-sources.tsv), checked by SHA-256.
info "Downloading extra source files"
tail -n +2 "$PROJECT_DIR/lfs/extra-sources.tsv" | while IFS=$'\t' read -r file url sha; do
    if [ -f "$file" ] && echo "$sha  $file" | sha256sum -c --quiet - 2>/dev/null; then continue; fi
    wget -q --tries=3 --timeout=60 "$url" -O "$file" || die "Could not download $file"
    echo "$sha  $file" | sha256sum -c --quiet - || die "$file is damaged (SHA-256 doesn't match)."
done
ok "Extra source files downloaded and checked"
cd "$PROJECT_DIR"

# --- Chapter 4: layout, user, environment ------------------------------
if [ ! -e "$LFS/usr/bin" ]; then
    info "Creating the folder layout (4.2)"
    ( cd "$LFS" && bash -e "$BOOK/ch4/04020-creatingminlayout.sh" )
fi
if ! id lfs >/dev/null 2>&1; then
    info "Adding the lfs build user (4.3)"
    bash -e "$OVERRIDES/ch4/04030-addinguser.sh"
fi

# Book scripts and our helpers, where user lfs and the chroot can reach them.
info "Copying build scripts to $LFS/mipos"
rm -rf "$LFS/mipos"
mkdir -p "$LFS/mipos"
cp -a "$PROJECT_DIR/lfs" "$PROJECT_DIR/scripts" "$PROJECT_DIR/mipos.conf" "$LFS/mipos/"
mkdir -p "$LFS/.mipos-done" "$LFS/.mipos-logs"
chown -R lfs:lfs "$LFS/mipos" "$LFS/.mipos-done" "$LFS/.mipos-logs"

info "Setting up user lfs's environment (4.4)"
[ ! -e /etc/bash.bashrc ] || mv -v /etc/bash.bashrc /etc/bash.bashrc.NOUSE
sudo -u lfs -H bash -e "$LFS/mipos/lfs/overrides/ch4/04040-settingenviron.sh"
ok "Prepared. Next: sudo scripts/20-cross-toolchain.sh"
