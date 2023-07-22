#!/bin/bash

if [ -z "${KERNEL_VERSION}" ]; then
  if grep -q "^ID_LIKE=debian" /etc/os-release; then
    LATEST_LINUX_IMAGE_PACKAGE=$( dpkg -l | grep -oP 'linux-image-\d\S*\b' | sort -r | head -n1 )
    KERNEL_VERSION=${LATEST_LINUX_IMAGE_PACKAGE#linux-image-}
  else
    KERNEL_VERSION=$(uname -r | cut -d '-' -f 1)
  fi
fi

if [ -z "${KERNEL_VERSION}" ]; then
  echo "Determining the kernel version not (yet) supported for your Linux distro. You might want to modify the distro-specific commands. Aborting."
  exit 4
fi

# split kernel version into individual elements
SOURCE_MAJOR_VERSION="${KERNEL_VERSION%%.*}"
SOURCE_MINOR_VERSION="${KERNEL_VERSION#*.}"
SOURCE_MINOR_VERSION="${SOURCE_MINOR_VERSION%%.*}"

if grep -q "^ID_LIKE=debian" /etc/os-release; then
  makefile=/usr/src/linux-headers-${KERNEL_VERSION}/Makefile
  if [ $(wc -l < $makefile) -eq 1 ] && grep -q "^include " $makefile ; then
    makefile=$(tr -s " " < $makefile | cut -d " " -f 2)
  fi

  SOURCE_SUB_VERSION=$(grep "SUBLEVEL =" $makefile | tr -d " " | cut -d "=" -f 2)
elif grep -q "^ID=arch" /etc/os-release; then
  SOURCE_SUB_VERSION=$(uname -r | cut -d '.' -f 3 | cut -d '-' -f 1)
fi

if [ -z $SOURCE_SUB_VERSION ]; then
  echo "Determining the kernel subversion not (yet) supported for your Linux distro. You might want to modify the distro-specific commands. Aborting."
  exit 4
fi
