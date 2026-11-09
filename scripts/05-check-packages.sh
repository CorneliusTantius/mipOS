#!/usr/bin/env bash
# Step 05 (optional, no sudo): test the package lists WITHOUT building.
#
# Asks apt to plan the full install from empty, using the same lists,
# pins (blocked packages) and repositories as the real build. Shows:
#   - whether every package can be installed (no conflicts, no missing names)
#   - that no blocked package (snap, telemetry, ...) sneaks in
#   - how big the system will be, and the 20 biggest packages
# Takes about a minute (it downloads Ubuntu's package lists into .cache/).
source "$(dirname "$0")/lib.sh"
export LC_ALL=C   # stable sorting for the size report

SIM="$PROJECT_DIR/.cache/apt-sim"
ROOT="$SIM/root"
CFG="$SIM/config"
rm -rf "$CFG" "$ROOT/etc"
mkdir -p "$ROOT/etc/apt/sources.list.d" "$ROOT/etc/apt/preferences.d" "$ROOT/etc/apt/apt.conf.d" \
         "$ROOT/var/lib/apt/lists/partial" "$ROOT/var/cache/apt/archives/partial" \
         "$ROOT/var/lib/dpkg/info" "$ROOT/var/lib/dpkg/updates" "$CFG"
: > "$ROOT/var/lib/dpkg/status"

info "Generating the same settings files as the real build"
"$PROJECT_DIR/scripts/gen-config.sh" "$CFG" >/dev/null
cp "$CFG"/chroot_apt/*.pref "$ROOT/etc/apt/preferences.d/"

# Repositories: Ubuntu (+ updates + security) and, if used, Mozilla.
KEYRING=/usr/share/keyrings/ubuntu-archive-keyring.gpg
[ -f "$KEYRING" ] || die "Ubuntu's archive key not found ($KEYRING). Install: ubuntu-keyring"
cat > "$ROOT/etc/apt/sources.list.d/ubuntu.sources" <<EOF
Types: deb
URIs: $MIRROR
Suites: $UBUNTU_CODENAME $UBUNTU_CODENAME-updates
Components: $ARCHIVE_AREAS
Signed-By: $KEYRING

Types: deb
URIs: $SECURITY_MIRROR
Suites: $UBUNTU_CODENAME-security
Components: $ARCHIVE_AREAS
Signed-By: $KEYRING
EOF
if [ "$BROWSER" = "firefox-mozilla-apt" ]; then
    cp "$PROJECT_DIR/config/keys/mozilla.asc" "$SIM/mozilla.asc"
    cat > "$ROOT/etc/apt/sources.list.d/mozilla.sources" <<EOF
Types: deb
URIs: https://packages.mozilla.org/apt
Suites: mozilla
Components: main
Signed-By: $SIM/mozilla.asc
EOF
fi

# Point apt at this fake system instead of the real one.
cat > "$SIM/apt.conf" <<EOF
Dir "$ROOT/";
Dir::State::status "$ROOT/var/lib/dpkg/status";
APT::Architecture "$ARCH";
APT::Architectures { "$ARCH"; };
APT::Install-Recommends "false";
APT::Sandbox::User "$(id -un)";
Debug::NoLocking "true";
EOF
export APT_CONFIG="$SIM/apt.conf"

info "Downloading package lists"
apt-get -q update >"$SIM/update.log" 2>&1 || { cat "$SIM/update.log"; die "Could not download package lists."; }

# Everything the real build installs: the "required" base system (what
# debootstrap starts with), casper, and all our package lists.
REQUIRED=$(cat "$ROOT"/var/lib/apt/lists/*_main_binary-${ARCH}_Packages \
    | awk '/^Package:/{p=$2} /^Priority: required/{print p}' | sort -u)
LISTED=$(cat "$PROJECT_DIR"/config/package-lists/*.list.chroot "$CFG"/package-lists/*.list.chroot \
    | sed 's/#.*//' | tr -s ' \t' '\n' | grep -v '^$' | sort -u)

info "Planning the install ($(echo "$LISTED" | wc -l) listed packages)"
if ! apt-get -s install $REQUIRED apt casper $LISTED >"$SIM/plan.txt" 2>&1; then
    cat "$SIM/plan.txt"
    die "apt can't install this package set. See the messages above."
fi
grep '^Inst ' "$SIM/plan.txt" | awk '{print $2}' | sort -u > "$SIM/installed.txt"
ok "All packages can be installed together: $(wc -l < "$SIM/installed.txt") packages in total"

# Blocked packages must not be in the plan.
BAD=""
for p in $BLOCKED_PACKAGES $PLASMA_SKIP; do
    grep -qx "$p" "$SIM/installed.txt" && BAD="$BAD $p"
done
[ -z "$BAD" ] || die "Blocked packages would be installed:$BAD"
ok "No blocked packages (snap, Ubuntu Pro, telemetry, Plasma extras)"

# Size report (installed size, before our doc/man/translation stripping).
cat "$ROOT"/var/lib/apt/lists/*_Packages \
    | awk '/^Package:/{p=$2} /^Installed-Size:/{if(!(p in s)) s[p]=$2} END{for(p in s) print p, s[p]}' \
    | sort > "$SIM/sizes.txt"
join "$SIM/installed.txt" "$SIM/sizes.txt" | sort -k2 -n -r > "$SIM/report.txt"
total=$(awk '{t+=$2} END{printf "%d", t/1024}' "$SIM/report.txt")
ok "Estimated installed size: about ${total} MB (before stripping docs and translations)"
echo
echo "Biggest 20 packages (MB):"
head -20 "$SIM/report.txt" | awk '{printf "  %7.1f  %s\n", $2/1024, $1}'
echo
echo "Full list: $SIM/report.txt"
