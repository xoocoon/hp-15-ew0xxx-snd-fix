#!/bin/bash

# make the script stop on error
set -e

BIN_ABSPATH="$(dirname "$(readlink -f "${0}")")"

KERNEL_MODULE_NAME="${1}"
DKMS_MODULE_VERSION="${2}"

. "${BIN_ABSPATH}/kernel-version_get.sh"

echo "Building for kernel version ${KERNEL_VERSION}"

# build and install the DKMS module and update initramfs ------------------------------------------

dkms build -k "${KERNEL_VERSION}" -m "${KERNEL_MODULE_NAME}" -v "${DKMS_MODULE_VERSION}" --force
dkms install -k "${KERNEL_VERSION}" -m "${KERNEL_MODULE_NAME}" -v "${DKMS_MODULE_VERSION}" --force

if dmesg | grep -q 'initramfs'; then
  if grep -q "^ID_LIKE=debian" /etc/os-release; then
    update-initramfs -u -k "${KERNEL_VERSION}"
  elif grep -q "^ID=arch" /etc/os-release; then
    mkinitcpio -P
  else
    echo "Update of initramfs not (yet) supported for your Linux distro. You might want to modify the distro-specific commands."
  fi
fi

printf '\n%s\n    %s\n' "Please reboot your system and check whether ${KERNEL_MODULE_NAME} has been loaded via the command" 'dkms status'
