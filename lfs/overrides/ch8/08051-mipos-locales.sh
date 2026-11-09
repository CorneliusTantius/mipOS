# mipOS step (not in the book): build only the locales listed in mipos.conf.
# C.UTF-8 is always built: systemd and many programs expect it.
. /mipos/mipos.conf
localedef -i C -f UTF-8 C.UTF-8
for l in $GLIBC_LOCALES; do
    localedef -i "${l%%.*}" -f "${l#*.}" "$l"
done
