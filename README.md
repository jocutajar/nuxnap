# Nuxnap - Encrypted washable system from debootstrap

Steps:
 - install prerequisites: cdebootstrap-static, kpartx, parted, coreutils, cryptsetup, btrfs-tools, util-linux, sudo, rsync, bash
 - open a terminal and find a cozy project folder
 - clone the repo and cd into it
 - optionally create a 'tmp' folder and mount tmpfs over it if you have that much memory to speed things up
 - run `./download.sh` to debootstrap or provide your own bootstrap with recent debian
 - run `./build.sh` to do its magic
 - run `./runqemu.sh` to run an emulated system from the generated image

Notes:
 - the system starts afresh every boot from a snapshot of @root.base => @root.curr so anything you wish persisted must be stored in @root.base
 - the system keeps copies of previous states in @root.snaps, these need t be maintained manually
 - if you use the image as it is, you'll eventually run out of space so grow it to your needs
 - to mount the @root.base in tmp/root.mount, run `./open.sh`, you can chroot, then umount with `./close.sh`
