#!/bin/bash

# find out kernel version to use ------------------------------------------------------------------

KERNEL_VERSION=$kernelver

. kernel-version_get.sh

if [ -z $SOURCE_SUB_VERSION ]; then
  echo "Determining the kernel subversion not (yet) supported for your Linux distro. You might want to modify the distro-specific commands. Aborting."
  exit 4
fi

echo "Building for kernel version ${KERNEL_VERSION}"

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