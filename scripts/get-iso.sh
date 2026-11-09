#!/usr/bin/env bash
# Download the ISO from the newest successful GitHub build into out/download/
# and check that it arrived complete. Needs the GitHub CLI (gh), logged in.
#   scripts/get-iso.sh            newest build of any branch
#   scripts/get-iso.sh <run-id>   a specific build (number from the run's web address)
source "$(dirname "$0")/lib.sh"
command -v gh >/dev/null || die "Install the GitHub CLI first: sudo apt install gh"

run_id="${1:-}"
if [[ -z "${run_id}" ]]; then
    run_id="$(gh run list --workflow build-iso.yml --status success --limit 1 \
              --json databaseId --jq '.[0].databaseId')"
    [[ -n "${run_id}" ]] || die "No successful 'Build ISO' run found yet."
fi

dest="${OUT_DIR}/download"
rm -rf "${dest}"
mkdir -p "${dest}"
say "Downloading build ${run_id} to ${dest}"
gh run download "${run_id}" --name mipos-iso --dir "${dest}"

say "Checking the checksum"
(cd "${dest}" && sha256sum -c ./*.sha256)
ls -lh "${dest}"
