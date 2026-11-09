# mipOS override of 8.84 "Stripping": strip debug data from every program and
# library, like the book, but WITHOUT keeping separate .dbg debug files
# (we never debug on the finished system, and they're big).
# Programs that are running right now (bash, find, strip) and the libraries
# they use are stripped through a copy, as the book does, to avoid
# "text file busy" errors.
online_usrbin="bash find strip"
online_usrlib="ld-linux-x86-64.so.2 libc.so.6 libm.so.6 libz.so.* libzstd.so.* \
               libreadline.so.* libhistory.so.* libncursesw.so.* libbfd-*.so libsframe.so.*"

cd /usr/lib
for LIB in $(ls $online_usrlib 2>/dev/null); do
    [ -L "$LIB" ] && continue
    cp "$LIB" "/tmp/$LIB"
    strip --strip-unneeded "/tmp/$LIB"
    install -m755 "/tmp/$LIB" /usr/lib
    rm "/tmp/$LIB"
done
for BIN in $online_usrbin; do
    cp "/usr/bin/$BIN" "/tmp/$BIN"
    strip --strip-unneeded "/tmp/$BIN"
    install -m755 "/tmp/$BIN" /usr/bin
    rm "/tmp/$BIN"
done

# Everything else, in place. Static libraries only lose debug data.
skip=" $online_usrbin $(cd /usr/lib && ls $online_usrlib 2>/dev/null | tr '\n' ' ') "
find /usr/lib /usr/libexec /usr/bin /usr/sbin -type f \( -name '*.so*' -o -perm -u+x \) ! -name '*.dbg' |
while read -r f; do
    case "$skip" in *" $(basename "$f") "*) continue ;; esac
    strip --strip-unneeded "$f" 2>/dev/null || true
done
find /usr/lib -type f -name '*.a' -exec strip --strip-debug {} + 2>/dev/null || true
