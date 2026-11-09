# mipOS override of 4.4 "Setting Up the Environment": the same two files as
# the book, written for user lfs. MAKEFLAGS uses all CPU cores. The book's
# "source ~/.bash_profile" (which starts a new shell) is left out.
cat > ~/.bash_profile << "PROFILE"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
PROFILE

cat > ~/.bashrc << "BASHRC"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
PATH=$LFS/tools/bin:$PATH
CONFIG_SITE=$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
export MAKEFLAGS=-j$(nproc)
BASHRC
