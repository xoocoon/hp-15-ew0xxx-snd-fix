#!/bin/sh

# make the script stop on error
set -e

sudo apt install build-essential dkms dwarves

if grep -q "^ID=ubuntu" /etc/os-release; then
  # see https://askubuntu.com/questions/1348250/skipping-btf-generation-xxx-due-to-unavailability-of-vmlinux-on-ubuntu-21-04
  sudo cp /sys/kernel/btf/vmlinux "/usr/lib/modules/$(uname -r)/build/"
fi
