#!/bin/bash

# find out kernel version to use ------------------------------------------------------------------

KERNEL_VERSION=$kernelver

. kernel-version_get.sh

echo "Building for kernel version ${KERNEL_VERSION}"

# install linux-headers package if not present ----------------------------------------------------

if grep -q "^ID_LIKE=debian" /etc/os-release; then
  HEADERS_PACKAGE_NAME="linux-headers-${KERNEL_VERSION}"

  if ! dpkg -l | grep -q $HEADERS_PACKAGE_NAME; then
    apt update -y && apt install $HEADERS_PACKAGE_NAME -y
    dpkg -l | grep -q $HEADERS_PACKAGE_NAME || \
       { echo "Could not install ${HEADERS_PACKAGE_NAME}. Try installing it manually."; exit 3; }
  fi
elif grep -q "^ID=arch" /etc/os-release; then
  pacman -S pahole dkms base-devel linux-headers
else
  echo "Auto-installing kernel headers not (yet) supported for your Linux distro. You might want to modify the distro-specific commands."
fi

# download kernel source and patch it -------------------------------------------------------------

# see https://www.collabora.com/news-and-blog/blog/2021/05/05/quick-hack-patching-kernel-module-using-dkms/

echo "Downloading kernel source ${SOURCE_MAJOR_VERSION}.${SOURCE_MINOR_VERSION}.${SOURCE_SUB_VERSION} for ${KERNEL_VERSION}"
wget "https://mirrors.edge.kernel.org/pub/linux/kernel/v${SOURCE_MAJOR_VERSION}.x/linux-${SOURCE_MAJOR_VERSION}.${SOURCE_MINOR_VERSION}.${SOURCE_SUB_VERSION}.tar.xz"

echo "Extracting original source of the kernel module"
tar -xf linux-$SOURCE_MAJOR_VERSION.$SOURCE_MINOR_VERSION.$SOURCE_SUB_VERSION.tar.* linux-$SOURCE_MAJOR_VERSION.$SOURCE_MINOR_VERSION.$SOURCE_SUB_VERSION/$1 --xform=s,linux-$SOURCE_MAJOR_VERSION.$SOURCE_MINOR_VERSION.$SOURCE_SUB_VERSION/$1,.,

for i in `ls *.patch`
do
  echo "Applying $i"
  patch < $i
done