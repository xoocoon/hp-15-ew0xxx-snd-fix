#!/bin/sh

# make the script stop on error
set -e

BIN_ABSPATH="$(dirname "$(readlink -f "${0}")")"

# check Linux distro
if grep -q "^ID_LIKE=debian" /etc/os-release; then
  apt install build-essential dkms dwarves

  if grep -q "^ID=ubuntu" /etc/os-release; then
    # see https://askubuntu.com/questions/1348250/skipping-btf-generation-xxx-due-to-unavailability-of-vmlinux-on-ubuntu-21-04
    cp /sys/kernel/btf/vmlinux "/usr/lib/modules/$(uname -r)/build/"
  fi
else
  echo "Preparation steps not (yet) supported for your Linux distro. You might want to modify the distro-specific commands."
fi
