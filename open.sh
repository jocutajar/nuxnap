#!/bin/bash

. config.sh

echo "Creating mount dir $rootmount"
mkdir -p "$rootmount"

echo "Creating loopback for $rawimage"
loopdev="$(losetup --show -f ""$rawimage"")" 

echo "Registering partitions of $loopdev"
sudo kpartx -a "$loopdev" 

partition="/dev/mapper/${loopdev##*/}p1"
decrypted="${partition##*/}.decrypted"
echo "Decrypting partition $partition"
echo -n "initialpassword" | sudo cryptsetup luksOpen "$partition" "$decrypted"    

echo "Mounting $decrypted on $rootmount"
sudo mount -o subvol=@root.base "/dev/mapper/$decrypted" "$rootmount"
sudo mount --bind /dev "$rootmount/dev"
sudo mount --bind /proc "$rootmount/proc"
sudo mount --bind /sys "$rootmount/sys"

cat << EOSTATE > "$state"
loopdev="$loopdev"
partition="$partition"
decrypted="$decrypted"
EOSTATE
