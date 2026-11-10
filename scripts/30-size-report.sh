#!/usr/bin/env bash
# Step 30: write out/size-report.txt: how big the ISO is and what takes the space.
source "$(dirname "$0")/lib.sh"

root="${WORK_DIR}/${ARCH}/airootfs"         # the live system, unpacked
iso="$(ls "${ISO_DIR}"/*.iso 2>/dev/null | head -n1)" || true
[[ -n "${iso}" && -d "${root}" ]] || die "No ISO/work folder found. Run scripts/20-build-iso.sh first."
sfs="$(find "${WORK_DIR}/iso" -name airootfs.sfs | head -n1)"

mib() { echo $(( ($1 + 1048575) / 1048576 )); }   # bytes -> MiB, rounded up
# Compare with an earlier report (SIZE_BASELINE in mipos.conf), if there is one.
baseline="${REPO_DIR}/${SIZE_BASELINE:-}"
[[ -n "${SIZE_BASELINE:-}" && -f "${baseline}" ]] || baseline=""
row() {   # row "label" value  -> label, value, and the change since the baseline
    local old diff=""
    if [[ -n "${baseline}" ]]; then
        old="$(awk -v l="$1" 'substr($0,1,34)==sprintf("%-34s",l) {split(substr($0,36),a," "); print a[1]; exit}' "${baseline}" | grep -oE '^[0-9]+' || true)"
        [[ -n "${old}" ]] && diff="$(printf '%8s %+8d' "${old}" "$(( $2 - old ))")"
    fi
    printf '%-34s %8s %s\n' "$1" "$2" "${diff}"
}
dir_mib() { if [[ -e "${root}$1" ]]; then mib "$(du -sb "${root}$1" | cut -f1)"; else echo 0; fi; }

{
echo "mipOS size report"
echo "Built:   $(date -u '+%Y-%m-%d %H:%M UTC')"
echo "ISO:     $(basename "${iso}")"
echo "Commit:  ${GITHUB_SHA:-$(git -C "${REPO_DIR}" rev-parse HEAD 2>/dev/null || echo unknown)}"
echo
if [[ -n "${baseline}" ]]; then
    printf -- '--- Totals (MiB) ---%22s %8s %8s\n' now "${SIZE_BASELINE_NAME:-before}" change
else
    echo "--- Totals (MiB) ---"
fi
row "ISO file"                         "$(mib "$(stat -c %s "${iso}")")"
row "Live system, compressed (sfs)"    "$(mib "$(stat -c %s "${sfs}")")"
row "Live system, unpacked"            "$(dir_mib /)"
row "Packages installed"               "$(pacman --root "${root}" -Qq | wc -l)"
echo
echo "--- Big folders inside the live system (MiB) ---"
for d in /usr/lib/modules /usr/lib/firmware /usr/lib/firmware/intel /usr/lib/firmware/i915 /usr/share/perl5 /usr/share/terminfo /usr/share/doc /usr/share/man \
         /usr/share/info /usr/share/locale /usr/share/i18n /usr/include \
         /usr/share/zoneinfo /usr/share/kbd /usr/lib/python3* /boot; do
    for match in ${root}${d}; do
        rel="${match#"${root}"}"
        # Show trimmed-away folders as 0 (but skip patterns that matched nothing)
        [[ -e "${match}" || "${rel}" != *"*"* ]] && row "${rel}" "$(dir_mib "${rel}")"
    done
done
echo
echo "--- 20 biggest packages (installed size, MiB) ---"
pacman --root "${root}" -Qi | awk -F': ' '
    /^Name/           { name=$2 }
    /^Installed Size/ { split($2, a, " "); v=a[1]; u=a[2]
                        if (u=="KiB") v/=1024; else if (u=="GiB") v*=1024; else if (u=="B") v/=1048576
                        printf "%8.1f  %s\n", v, name }' | sort -rn | head -n 20
} | tee "${OUT_DIR}/size-report.txt"
