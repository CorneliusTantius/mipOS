#!/usr/bin/env bash
# Step 20: build the ISO with mkarchiso (archiso's builder) and write its checksum.
source "$(dirname "$0")/lib.sh"
need_root
need_arch
[[ -f "${PROFILE_DIR}/profiledef.sh" ]] || die "Run scripts/10-make-profile.sh first."

say "Building the ISO (takes 5-15 minutes)"
rm -rf "${WORK_DIR}" "${ISO_DIR}"
mkarchiso -v -w "${WORK_DIR}" -o "${ISO_DIR}" "${PROFILE_DIR}"

say "Writing the checksum"
cd "${ISO_DIR}"
for iso in *.iso; do
    sha256sum "${iso}" >"${iso}.sha256"
    cat "${iso}.sha256"
done
