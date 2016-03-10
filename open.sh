#!/bin/bash
rawimage=raw.img
rootmount=root.mount

echo "Creating mount dir $rootmount"
mkdir -p "$rootmount"

echo "Creating loopback for $rawimage"
export loopdev="$(losetup --show -f ""$rawimage"")" 

echo "Registering partitions of $loopdev"
kpartx -a "$loopdev" 

partition="/dev/mapper/${loopdev##*/}p1"
decrypted="${partition##*/}.decrypted"
echo "Decrypting partition $partition"
echo -n "initialpassword" | cryptsetup luksOpen "$partition" "$decrypted"    

echo "Mounting $decrypted on $rootmount"
mount -o subvol=@root.base "/dev/mapper/$decrypted" "$rootmount"
mount --bind /dev "$rootmount/dev"
mount --bind /proc "$rootmount/proc"
mount --bind /sys "$rootmount/sys"

my_dir="$(dirname "$0")"
cat << EOSTATE > "$my_dir/state.sh"
export loopdev="$loopdev"
export decrypted="$decrypted"
export rootmount="$rootmount"
EOSTATE
