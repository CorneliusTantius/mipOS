#!/bin/sh
# Print a monitor marker if an external display is connected.
# The built-in panel (eDP) is ignored. Prints nothing otherwise.

for c in /sys/class/drm/card*-*; do
    [ -e "$c/status" ] || continue
    name=$(basename "$c")
    name=${name#card*-}
    case $name in
        eDP*) continue ;;
    esac
    if [ "$(cat "$c/status")" = connected ]; then
        echo "□"
        exit 0
    fi
done
