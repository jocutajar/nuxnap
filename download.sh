#!/bin/bash

. config.sh

mkdir -p "$bootstrap"

# see https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=737939
# stretch suite may need to be added to /usr/share/cdebootstrap-static/suites :
# Suite: stretch
# Config: generic
# Keyring: debian-archive-keyring.gpg

sudo cdebootstrap-static --flavour=minimal stretch "$bootstrap" http://ftp.de.debian.org/debian/
