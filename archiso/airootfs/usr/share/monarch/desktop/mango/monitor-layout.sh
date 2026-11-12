#!/bin/sh
# Choose where the external monitor sits relative to the laptop screen.
#
# Usage:
#   sh monitor-layout.sh            pick top/left/right/bottom from a menu
#   sh monitor-layout.sh right      apply a layout directly
#   add --dry-run to print the result without applying it
#
# Writes ~/.config/mango/monitor.conf (loaded by mango.conf through
# source_optional) and reloads mango.

set -eu

CONF="$HOME/.config/mango/monitor.conf"
choice=""
dry=0
for arg in "$@"; do
    case $arg in
        --dry-run) dry=1 ;;
        *) choice=$arg ;;
    esac
done

# Find the connected external output (anything that is not the built-in eDP panel).
ext=""
for c in /sys/class/drm/card*-*; do
    [ -e "$c/status" ] || continue
    name=$(basename "$c")
    name=${name#card*-}
    case $name in
        eDP*) continue ;;
    esac
    if [ "$(cat "$c/status")" = connected ]; then
        ext=$name
        break
    fi
done
if [ -z "$ext" ]; then
    echo "No external monitor connected." >&2
    exit 1
fi

# Logical size of the laptop panel and the external monitor, from mango.
monitors=$(mmsg get all-monitors | python3 -c '
import json, sys
for m in json.load(sys.stdin)["monitors"]:
    print(m["name"], m["width"], m["height"])
')
sizes=$(printf '%s\n' "$monitors" | awk -v e="$ext" '
    $1 ~ /^eDP/ { main = $1; mw = $2; mh = $3 }
    $1 == e     { ew = $2; eh = $3 }
    END { if (main == "" || ew == "") exit 1; print main, mw, mh, ew, eh }
') || {
    echo "Could not read monitor sizes from mango for $ext." >&2
    exit 1
}
set -- $sizes
main=$1; mw=$2; mh=$3; ew=$4; eh=$5

if [ -z "$choice" ]; then
    choice=$(printf 'top\nleft\nright\nbottom\n' | fuzzel --dmenu --prompt 'external monitor: ' || true)
    [ -n "$choice" ] || exit 0
fi

# Positions must not be negative (XWayland bug), so the layout is built from 0,0.
case $choice in
    top)    main_x=0;  main_y=$eh; ext_x=0;  ext_y=0 ;;
    left)   main_x=$ew; main_y=0;  ext_x=0;  ext_y=0 ;;
    right)  main_x=0;  main_y=0;  ext_x=$mw; ext_y=0 ;;
    bottom) main_x=0;  main_y=0;  ext_x=0;  ext_y=$mh ;;
    *)
        echo "Unknown layout: $choice (use top, left, right or bottom)" >&2
        exit 2
        ;;
esac

content="monitor_rule=name:^${main}\$,x:${main_x},y:${main_y}
monitor_rule=name:^${ext}\$,x:${ext_x},y:${ext_y}"

if [ "$dry" -eq 1 ]; then
    printf '%s\n' "$content"
    exit 0
fi

mkdir -p "$(dirname "$CONF")"
printf '%s\n' "$content" > "$CONF"
mmsg dispatch reload_config >/dev/null
echo "External monitor $ext placed $choice of $main."
