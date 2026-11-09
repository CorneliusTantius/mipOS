# mipOS override of 4.3 "Adding the LFS User": same as the book, but without
# "passwd lfs" and "su - lfs" (those need a person typing). The build scripts
# switch to the lfs user by themselves.
groupadd lfs
useradd -s /bin/bash -g lfs -m -k /dev/null lfs
chown -v lfs $LFS/{usr{,/*},var,etc,tools}
case $(uname -m) in
  x86_64) chown -v lfs $LFS/lib64 ;;
esac
