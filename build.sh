#!/bin/bash
export rawimage=raw.img
export rootmount=root.mount
export bootstrap=root.debootstrap
unset success

#sudo debootstrap stretch root.debootstrap http://ftp.de.debian.org/debian/ 

function setup {
    echo "Setting up $rawimage"
    mkdir -p "$rootmount" || return 2
    sudo -E -u root bash -c "$(declare -f setup_sudo) && setup_sudo"
}

function setup_sudo {

function setup_image {
    if [ ! -f "$rawimage" ]
    then
	echo "Creating partition table in $rawimage"
	truncate -s 2GB "$rawimage"
	parted "$rawimage" <<'EOPARTED'
mklabel msdos
mkpart primary 1M 100%
quit
EOPARTED
    fi

    setup_losetup
}

function rollback_image {
    if [ "x$success" == "xtrue" ]
    then
	echo "Keep image $rawimage"
	return 0
    else
	echo "Remove image $rawimage"
    	return 200
    fi
}

function setup_losetup {
    echo "Creating loopback for $rawimage"
    export loopdev="$(losetup --show -f ""$rawimage"")" 
    [ 0 == $? ] && setup_partitions || rollback_image
}

function rollback_losetup {
    echo "Removing loopback $loopdev"
    losetup -d "$loopdev"
    [ 0 == $? ] && return 201 || return 21    
}

function setup_partitions {
    echo "Registering partitions of $loopdev"
    kpartx -a "$loopdev" 
    [ 0 == $? ] && setup_cryptsetup || rollback_losetup
}

function rollback_kpartx {
    echo "Removing partitions $loopdev"
    kpartx -d "$loopdev"
    [ 0 == $? ] && return 202 || return 22
}

function setup_cryptsetup {
    export partition="/dev/mapper/${loopdev##*/}p1"
    export decrypted="${partition##*/}.decrypted"
    password=initialpassword

    echo "Cryptsetup luksOpen partition $partition"
    echo -n "$password" | cryptsetup luksOpen "$partition" "$decrypted"

    if [ 0 != $? ]
    then
	echo "Cryptsetup luksFormat partition $partition"
	echo -n "$password" | cryptsetup -q luksFormat "$partition" &&
	echo -n "$password" | cryptsetup luksOpen "$partition" "$decrypted"    
    fi

    [ 0 == $? ] && setup_btrfs || rollback_kpartx
}

function rollback_cryptsetup {
    echo "Closing luks $decrypted"
    cryptsetup luksClose "$decrypted"
    [ 0 == $? ] && return 203 || return 23
}

function setup_btrfs {
    btrfs check "/dev/mapper/$decrypted"
    if [ 0 != $? ]
    then
	echo "Creating new btrfs on /dev/mapper/$decrypted"
	mkfs.btrfs "/dev/mapper/$decrypted"
    fi

    [ 0 == $? ] && setup_rootmount || rollback_cryptsetup
}

function setup_rootmount {
    echo "Setting up root in $rootmount"
    mount "/dev/mapper/$decrypted" "$rootmount" || return 25
    if [ ! -d "$rootmount/@root.base" ]
    then
	echo "Creating subvolumes in /dev/mapper/$decrypted on $rootmount"
	btrfs subvolume create "$rootmount/@root.base"
	btrfs subvolume create "$rootmount/@home"
	btrfs subvolume create "$rootmount/@root.snaps"
    else
	echo "Btrfs subvolumes are already set up"
    fi
    
    sleep 3 && umount "$rootmount" || return 27

    echo "Mounting /dev/mapper/$decrypted @root.base on $rootmount" &&
	mount -o subvol=@root.base "/dev/mapper/$decrypted" "$rootmount" || return 26

    if [ ! -d "$rootmount/etc" ]
    then
	echo "Rsync bootstrap from $bootstrap to $rootmount"
	rsync -a "$bootstrap/" "$rootmount" 
    fi

    if [ ! -f "$rootmount/etc/grub.d/00_flashback" ]
    then
	mkdir -p "$rootmount/etc/grub.d" 
	export partuuid=$(blkid $partition | sed -re 's/.*: UUID="([^"]+)".*/\1/')
	export decruuid=$(blkid /dev/mapper/$decrypted | sed -re 's/.*: UUID="([^"]+)".*/\1/')
	echo "Adding flashback with uuid $partuuid"
	echo "system UUID=$partuuid none luks" >> "$rootmount/etc/crypttab"
	echo "UUID=$decruuid / btrfs subvol=@root.curr 0 0" >> "$rootmount/etc/fstab"
	echo "UUID=$decruuid /home btrfs subvol=@home 0 0" >> "$rootmount/etc/fstab"
	chmod a+x "$rootmount/etc/grub.d/00_flashback"
    fi

    setup_chroot 

    sed -ie "s/rootflags=subvol=@root.base/cryptdevice=UUID=$partuuid:system rootflags=subvol=@root.curr/" "$rootmount/boot/grub/grub.cfg" 
    
    rollback_rootmount

    echo "Creating btrfs snapshots in /dev/mapper/$decrypted"
    mount "/dev/mapper/$decrypted" "$rootmount"
    [ ! -d "$rootmount/@root.curr" ] || mv "$rootmount/@root.curr" "$rootmount/@root.snaps/$(date '+%Y-%m-%d-%H-%M-%S')-setup"
    btrfs subvolume snapshot "$rootmount/@root.base" "$rootmount/@root.curr"
    umount "$rootmount"

    return 200
}

function rollback_rootmount {
    echo "Unmounting $rootmount"
    umount "$rootmount/dev/pts"
    umount "$rootmount/dev"
    umount "$rootmount/proc"
    umount "$rootmount/sys"
    umount "$rootmount"
    [ 0 == $? ] && return 204 || return 24
}

function chroot_script {
    echo -n "root:initialpassword" | chpasswd    
    echo "grub-pc grub-pc/install_devices_empty boolean true" | debconf-set-selections 
    echo "grub-pc grub-pc/install_devices_empty seen" | debconf-set-selections 
    echo "grub-pc grub-pc/install_devices string " | debconf-set-selections 
    echo "grub-pc grub-pc/install_devices seen" | debconf-set-selections 
    apt-get update
    apt-get -y install locales kbd less aptitude btrfs-tools cryptsetup grub-pc linux-image-amd64
    sed -i -e "s/# $LANG/$LANG/" /etc/locale.gen
    locale-gen $LANG
    update-locale LANG=$LANG
    echo "GRUB_ENABLE_CRYPTODISK=y" >> "/etc/default/grub"
    echo "CRYPTSETUP=y" >> /usr/share/initramfs-tools/conf-hooks.d/cryptsetup
    echo "export CRYPTSETUP=y" >> /usr/share/initramfs-tools/conf-hooks.d/cryptsetup
    update-initramfs -ut
    echo "Installing grub to $loopdev"
    update-grub
    grub-install $loopdev
    rm "/root/chroot_script"
    echo "DONE with chroot"
}

function initramfs_flashback {

PREREQ="btrfs"

case "${1}" in
	prereqs)
		echo "${PREREQ}"
		exit 0
		;;
esac

if [ -x /bin/btrfs ]
then
    mkdir -p /tmp/system 
    mount /dev/mapper/system /tmp/system
    mv /tmp/system/@root.curr "/tmp/system/@root.snaps/$(date '+%Y-%m-%d-%H-%M-%S')"
    btrfs subvolume snapshot /tmp/system/@root.base /tmp/system/@root.curr
    umount /tmp/system
    rmdir /tmp/system
fi

}

function setup_chroot {
    echo "Running chroot"
    [ 0 == $? ] && mount --bind /proc "$rootmount/proc"
    [ 0 == $? ] && mount --bind /sys "$rootmount/sys"
    [ 0 == $? ] && mount --bind /dev "$rootmount/dev"
    [ 0 == $? ] && mount -t tmpfs tmpfs "$rootmount/dev/pts"
    [ 0 == $? ] && mkdir -p "$rootmount/etc/initramfs-tools/scripts/local-premount/"
    [ 0 == $? ] && declare -f initramfs_flashback | tail -n+3 | head -n-1 > "$rootmount/etc/initramfs-tools/scripts/local-premount/flashback" 
    [ 0 == $? ] && declare -f chroot_script | tail -n+3 | head -n-1 > "$rootmount/root/chroot_script"
    [ 0 == $? ] && chmod a+x "$rootmount/etc/initramfs-tools/scripts/local-premount/flashback"
    [ 0 == $? ] && chmod a+x "$rootmount/root/chroot_script"
    [ 0 == $? ] && chroot "$rootmount/" /root/chroot_script
    [ 0 == $? ] && echo "Build completed" && export success=true
}

setup_image
}

setup

