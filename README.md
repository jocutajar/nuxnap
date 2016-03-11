# Nuxnap - Encrypted washable system from debootstrap

Steps:
 - install prerequisites: cdebootstrap-static, kpartx, parted, coreutils, cryptsetup, btrfs-tools, util-linux, sudo, rsync, bash
 - open a terminal and find a cozy project folder
 - clone the repo and cd into it
 - optionally create a 'tmp' folder and mount tmpfs over it if you have that much memory to speed things up
 - run `./download.sh` to debootstrap or provide your own bootstrap with recent debian
 - run `./build.sh` to do its magic :boom:WARNING: do not install grub on any device when asked to!
 - run `./runqemu.sh` to run an emulated system from the generated image
 - dd the tmp/raw.img onto a disk or flashdrive and you have a basic encrypted washable system

Notes:
 - the /home is mounted separately so everything user-side is persisted between reboots
 - the system starts afresh every boot from a snapshot of @root.base => @root.curr so anything system-side you wish persisted must be stored in @root.base
 - the system keeps copies of previous states in @root.snaps, these need to be maintained manually
 - if you use the image as it is, you'll eventually run out of space so grow it to your needs
 - to mount the tmp/raw.img @root.base in tmp/root.mount, run `./open.sh`, you can chroot, then umount with `./close.sh`
 - :exclamation:WARNING: Change the default passwords :o) use different passwords for encryption and for root/user login
 - :exclamation:WARNING: If security is your thing, fully randomize the tmp/raw.img before build
 - I take no responsibility for your broken toys, use at your own risk
