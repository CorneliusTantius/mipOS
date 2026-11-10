#!/usr/bin/env bash
# Download the ISO from the newest successful GitHub build into out/download/
# and check that it arrived complete. Needs the GitHub CLI (gh), logged in.
#   scripts/get-iso.sh            newest build of any branch
#   scripts/get-iso.sh <run-id>   a specific build (number from the run's web address)
#
# Faster than "gh run download": the file is fetched in several pieces at
# once (PARTS below), and a build that is already downloaded is not fetched again.
source "$(dirname "$0")/lib.sh"
command -v gh >/dev/null || die "Install the GitHub CLI first: sudo apt install gh"
command -v unzip >/dev/null || die "Install unzip first: sudo apt install unzip"
PARTS=8

run_id="${1:-}"
if [[ -z "${run_id}" ]]; then
    run_id="$(gh run list --workflow build-iso.yml --status success --limit 1 \
              --json databaseId --jq '.[0].databaseId')"
    [[ -n "${run_id}" ]] || die "No successful 'Build ISO' run found yet."
fi

dest="${OUT_DIR}/download"
if [[ -f ${dest}/.run-id && $(<"${dest}/.run-id") == "${run_id}" ]]; then
    say "Build ${run_id} is already downloaded"
else
    repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
    art_id="$(gh api "repos/${repo}/actions/runs/${run_id}/artifacts" \
              --jq '.artifacts[] | select(.name == "mipos-iso" and (.expired | not)) | .id')"
    [[ -n ${art_id} ]] || die "Build ${run_id} has no mipos-iso download (expired after 14 days?)."
    # GitHub answers with a temporary direct link to the file.
    # (Ask with curl, not "gh api": gh would follow the link and download it all.)
    url="$(curl -fsS -o /dev/null -D - -H "Authorization: Bearer $(gh auth token)" \
           "https://api.github.com/repos/${repo}/actions/artifacts/${art_id}/zip" \
           | tr -d '\r' | awk 'tolower($1) == "location:" {print $2; exit}')"
    [[ -n ${url} ]] || die "Couldn't get the download link from GitHub."
    size="$(curl -fsS -r 0-0 -D - -o /dev/null "${url}" | tr -d '\r' \
            | awk -F/ 'tolower($0) ~ /^content-range:/ {print $2}')"

    rm -rf "${dest}"
    mkdir -p "${dest}"
    zip="${dest}/mipos-iso.zip"
    if [[ ${size} =~ ^[0-9]+$ ]] && (( size > 0 )); then
        say "Downloading build ${run_id} ($(( size / 1048576 )) MiB, ${PARTS} pieces at once)"
        chunk=$(( (size + PARTS - 1) / PARTS ))
        pids=()
        for ((i = 0; i < PARTS; i++)); do
            from=$(( i * chunk )); to=$(( from + chunk - 1 )); (( to < size )) || to=$(( size - 1 ))
            curl -fsS --retry 5 -r "${from}-${to}" -o "${zip}.part${i}" "${url}" &
            pids+=($!)
        done
        # Show progress until all pieces are done.
        while sleep 1; do
            got=0
            for f in "${zip}".part*; do [[ -f ${f} ]] && got=$(( got + $(stat -c %s "${f}") )); done
            printf '\r  %3d%%  %d / %d MiB ' $(( got * 100 / size )) $(( got / 1048576 )) $(( size / 1048576 ))
            alive=0
            for p in "${pids[@]}"; do kill -0 "${p}" 2>/dev/null && alive=1; done
            (( alive )) || break
        done
        echo
        for p in "${pids[@]}"; do wait "${p}" || die "A piece of the download failed. Run the script again."; done
        for ((i = 0; i < PARTS; i++)); do cat "${zip}.part${i}"; done >"${zip}"
        rm -f "${zip}".part*
        (( $(stat -c %s "${zip}") == size )) || die "Download is incomplete. Run the script again."
    else
        say "Downloading build ${run_id} (single piece)"
        curl -fL --retry 5 --progress-bar -o "${zip}" "${url}"
    fi
    unzip -q "${zip}" -d "${dest}"
    rm -f "${zip}"
fi

say "Checking the checksum"
# The files may be in a subfolder (e.g. iso/), so look for them.
sum="$(find "${dest}" -name '*.iso.sha256' -print -quit)"
[[ -n "${sum}" ]] || die "No checksum file in the download."
(cd "$(dirname "${sum}")" && sha256sum -c "$(basename "${sum}")")
echo "${run_id}" >"${dest}/.run-id"
find "${dest}" -type f ! -name .run-id -exec ls -lh {} +
