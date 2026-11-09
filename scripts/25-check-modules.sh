#!/usr/bin/env bash
# Step 25: after trimming, check that the drivers we need are still there and
# can load (every driver they depend on was kept too).
#   scripts/25-check-modules.sh [system-folder]   (default: the built live system)
source "$(dirname "$0")/lib.sh"

root="${1:-${WORK_DIR}/${ARCH}/airootfs}"
kdir="$(find "${root}/usr/lib/modules" -mindepth 1 -maxdepth 1 -type d | head -n1)"
[[ -d "${kdir}/kernel" ]] || die "No kernel modules found under ${root}/usr/lib/modules"
say "Checking kernel modules in ${kdir}"

name_of() { local n="${1##*/}"; n="${n%%.ko*}"; echo "${n//-/_}"; }

declare -A present=() builtin=() file_of=()
while IFS= read -r f; do n="$(name_of "$f")"; present[$n]=1; file_of[$n]="$f"; done \
    < <(find "${kdir}/kernel" -name '*.ko*')
while IFS= read -r f; do builtin[$(name_of "$f")]=1; done < "${kdir}/modules.builtin"
echo "${#present[@]} modules present, ${#builtin[@]} built into the kernel"

# 1. Every must-have module exists (as a file or built in).
failed=0
for m in ${MUST_HAVE_MODULES}; do
    if [[ -z "${present[$m]:-}" && -z "${builtin[$m]:-}" ]]; then
        echo "MISSING: ${m}"; failed=1
    fi
done

# 2. Every present module's dependencies are present too.
declare -A broken=()
for m in "${!present[@]}"; do
    deps="$(modinfo -F depends "${file_of[$m]}" 2>/dev/null || true)"
    for d in ${deps//,/ }; do
        d="${d//-/_}"
        [[ -n "${present[$d]:-}" ]] || broken[$m]="${d}"
    done
done
for m in ${MUST_HAVE_MODULES}; do
    if [[ -n "${broken[$m]:-}" ]]; then echo "CAN'T LOAD: ${m} (needs ${broken[$m]})"; failed=1; fi
done
echo "${#broken[@]} rarely used modules can't load because a module they need was trimmed (expected, harmless)."

# 3. Firmware for Intel graphics, Wi-Fi and sound is there.
for fw in i915 xe intel/iwlwifi intel/sof-ipc4; do
    [[ -d "${root}/usr/lib/firmware/${fw}" ]] || { echo "MISSING firmware: ${fw}"; failed=1; }
done

(( failed == 0 )) || die "Module check failed (see above)."
echo "All must-have modules and firmware are present and can load."
