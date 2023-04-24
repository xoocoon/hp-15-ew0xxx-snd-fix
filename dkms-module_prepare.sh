#!/bin/sh

# make the script stop on error
set -e

if ! which apt >/dev/null; then
  printf '%s\n\n' 'Warning! This script was created for Debian-based distros. You might want to modify it to suit your Linux distro.'
fi

sudo apt update -y && sudo apt install linux-headers-$(uname -r) 

# see https://askubuntu.com/questions/1348250/skipping-btf-generation-xxx-due-to-unavailability-of-vmlinux-on-ubuntu-21-04
sudo apt install build-essential dkms dwarves
sudo cp /sys/kernel/btf/vmlinux "/usr/lib/modules/$(uname -r)/build/"
