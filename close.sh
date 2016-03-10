#!/bin/bash
rawimage=raw.img

my_dir="$(dirname "$0")"
. "$my_dir/state.sh"

echo "Unmounting $rootmount"
umount "$rootmount/dev"
umount "$rootmount/proc"
umount "$rootmount/sys"
umount "$rootmount"

echo "Closing luks $decrypted"
cryptsetup luksClose "$decrypted"

echo "Removing partitions $loopdev"
kpartx -d "$loopdev"

echo "Removing loopback $loopdev"
losetup -d "$loopdev"
