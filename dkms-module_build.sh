#!/bin/sh

# make the script stop on error
set -e

KERNEL_MODULE_NAME="${1}"
DKMS_MODULE_VERSION="${2}"

if [ -z "${KERNEL_VERSION}" ]; then
  LATEST_LINUX_IMAGE_PACKAGE=$( dpkg -l | grep -oP 'linux-image-\d\S*\b' | sort -r | head -n1 )
  KERNEL_VERSION=${LATEST_LINUX_IMAGE_PACKAGE#linux-image-}
fi

echo "Building for kernel version ${KERNEL_VERSION}"

# build and install the DKMS module and update initramfs ------------------------------------------

sudo dkms build -k "${KERNEL_VERSION}" -m "${KERNEL_MODULE_NAME}" -v "${DKMS_MODULE_VERSION}" --force
sudo dkms install -k "${KERNEL_VERSION}" -m "${KERNEL_MODULE_NAME}" -v "${DKMS_MODULE_VERSION}" --force

if sudo dmesg | grep -q 'initramfs'; then
  sudo update-initramfs -u -k "${KERNEL_VERSION}"
fi

printf '\n%s\n    %s\n' "Please reboot your system and check whether ${KERNEL_MODULE_NAME} has been loaded via the command" 'dkms status'
