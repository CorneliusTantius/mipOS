# mipOS override of 7.15 "Cleaning up and Saving the Temporary System".
# Only the part that runs inside the chroot. Leaving the chroot, unmounting
# and saving a backup are done by scripts/30-chroot-tools.sh and
# scripts/save-stage.sh instead.
rm -rf /usr/share/{info,man,doc}/*
find /usr/{lib,libexec} -name \*.la -delete
rm -rf /tools
