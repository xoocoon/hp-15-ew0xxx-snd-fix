#!/bin/sh

# make the script stop on error
set -e

KERNEL_MODULE_NAME="${1}"
DKMS_MODULE_VERSION="${2}"

# build and install the DKMS module and update initramfs ------------------------------------------

sudo dkms build -m "${KERNEL_MODULE_NAME}" -v "${DKMS_MODULE_VERSION}" --force
sudo dkms install -m "${KERNEL_MODULE_NAME}" -v "${DKMS_MODULE_VERSION}" --force

if sudo dmesg | grep -q 'initramfs'; then
  sudo update-initramfs -u -k $(uname -r)
fi

printf '\n%s\n    %s\n' "Please reboot your system and check whether ${KERNEL_MODULE_NAME} has been loaded via the command" 'dkms status'
