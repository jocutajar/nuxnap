#!/bin/bash

. config.sh

qemu-system-x86_64 \
	-serial stdio \
	-hda "$rawimage"

