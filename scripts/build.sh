#!/usr/bin/env bash
# Runs all build steps in order (what the GitHub workflow does).
# On an Arch Linux computer:  sudo scripts/build.sh
source "$(dirname "$0")/lib.sh"
need_root
need_arch
dir="$(dirname "$0")"
"${dir}/00-host-setup.sh"
"${dir}/10-make-profile.sh"
"${dir}/12-make-repo.sh"
"${dir}/15-check-packages.sh"
"${dir}/20-build-iso.sh"
"${dir}/25-check-modules.sh"
"${dir}/26-check-repo.sh"
"${dir}/30-size-report.sh"
