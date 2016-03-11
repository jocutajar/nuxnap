#!/bin/bash

. config.sh

. "$state"

echo "Unmounting $rootmount"
sudo umount "$rootmount/dev/pts"
sudo umount "$rootmount/dev"
sudo umount "$rootmount/proc"
sudo umount "$rootmount/sys"
sudo umount "$rootmount"

echo "Closing luks $decrypted"
sudo cryptsetup luksClose "$decrypted"

echo "Removing partitions $loopdev"
sudo kpartx -d "$loopdev"

echo "Removing loop dev $loopdev"
sudo losetup -d "$loopdev"

