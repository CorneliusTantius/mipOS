#!/usr/bin/env bash
# Attach or detach the virtual file systems the chroot needs (LFS book, 7.3).
#   sudo scripts/mounts.sh up      sudo scripts/mounts.sh down
# Safe to run twice: it skips what's already mounted or unmounted.
source "$(dirname "$0")/lib.sh"
need_root

up() {
    mkdir -pv "$LFS"/{dev,proc,sys,run}
    mountpoint -q "$LFS/dev"     || mount -v --bind /dev "$LFS/dev"
    mountpoint -q "$LFS/dev/pts" || mount -vt devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
    mountpoint -q "$LFS/proc"    || mount -vt proc proc "$LFS/proc"
    mountpoint -q "$LFS/sys"     || mount -vt sysfs sysfs "$LFS/sys"
    mountpoint -q "$LFS/run"     || mount -vt tmpfs tmpfs "$LFS/run"
    if [ -h "$LFS/dev/shm" ]; then
        install -v -d -m 1777 "$LFS$(realpath /dev/shm)"
    else
        mountpoint -q "$LFS/dev/shm" || mount -vt tmpfs -o nosuid,nodev tmpfs "$LFS/dev/shm"
    fi
}

down() {
    for m in dev/shm dev/pts sys proc run dev; do
        mountpoint -q "$LFS/$m" && umount -v "$LFS/$m"
    done
    true
}

case "${1:-}" in
    up) up ;;
    down) down ;;
    *) die "usage: mounts.sh up|down" ;;
esac
