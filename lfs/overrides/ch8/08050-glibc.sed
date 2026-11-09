# mipOS edits to 8.5 Glibc (applied with sed to the book's commands):
# - no locales here: 08051-mipos-locales builds only the ones in mipos.conf
#   (the book's list plus "make localedata/install-locales" is 200+ MB)
# - no "tzselect" (asks questions); the timezone is UTC until the installer sets it
/^localedef /d
/^make localedata\/install-locales/d
/^tzselect$/d
s|/usr/share/zoneinfo/<xxx>|/usr/share/zoneinfo/UTC|
