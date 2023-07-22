#!/bin/sh

# see https://www.collabora.com/news-and-blog/blog/2021/05/05/quick-hack-patching-kernel-module-using-dkms/

# make the script stop on error
set -e

BIN_ABSPATH="$(dirname "$(readlink -f "${0}")")"

KERNEL_MODULE_NAME="${1}"
DKMS_MODULE_VERSION="${2}"

# set up the actual DKMS module -------------------------------------------------------------------

[ ! -e "/usr/src/${KERNEL_MODULE_NAME}-${DKMS_MODULE_VERSION}" ] && mkdir "/usr/src/${KERNEL_MODULE_NAME}-${DKMS_MODULE_VERSION}"

# determine the installed gcc major SOURCE_MAIN_VERSION
GCC_VERSION_DEFAULT=$( gcc --version | perl -ne 'if (m~^gcc\b.+?(1\d)\.\d{,2}\.\d{,2}~) { print $1; }' )
if [ $GCC_VERSION_DEFAULT -lt 12 ]; then
  if ! which gcc-12 >/dev/null; then
    printf '%s %s\n    %s\n' "Your system uses version $GCC_VERSION_DEFAULT of gcc by default, but SOURCE_MAIN_VERSION 12 is required as a minimum." 'You might want to install it with the following command:' 'sudo apt install gcc-12.'
    exit 3
  else
    # explicitly use gcc-12 (if we use a kernel compiled with gcc-12)
    CC_PARAMETER=" CC=$( which gcc-12 )"
  fi
fi

# create the configuration file for the DKMS module
cat << EOF > "/usr/src/${KERNEL_MODULE_NAME}-${DKMS_MODULE_VERSION}/dkms.conf"
PACKAGE_NAME="${KERNEL_MODULE_NAME}"
PACKAGE_VERSION="${DKMS_MODULE_VERSION}"

BUILT_MODULE_NAME[0]="${KERNEL_MODULE_NAME}"
DEST_MODULE_LOCATION[0]="/updates/dkms"

AUTOINSTALL="yes"
MAKE[0]="make${CC_PARAMETER} -C \${kernel_source_dir} M=\${dkms_tree}/\${PACKAGE_NAME}/\${PACKAGE_VERSION}/build"
PRE_BUILD="dkms-patchmodule.sh sound/pci/hda"
EOF

# create the pre-build script within the DKMS module
cat << 'EOF' > "/usr/src/${KERNEL_MODULE_NAME}-${DKMS_MODULE_VERSION}/dkms-patchmodule.sh"
#!/bin/bash

# find out kernel version to use ------------------------------------------------------------------

KERNEL_VERSION=$kernelver
EOF

cat "${BIN_ABSPATH}/include_get-kernel-version.sh" >> "/usr/src/${KERNEL_MODULE_NAME}-${DKMS_MODULE_VERSION}/dkms-patchmodule.sh"

cat << 'EOF' >> "/usr/src/${KERNEL_MODULE_NAME}-${DKMS_MODULE_VERSION}/dkms-patchmodule.sh"
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
EOF

# make the pre-build script executable
chmod u+x "/usr/src/${KERNEL_MODULE_NAME}-${DKMS_MODULE_VERSION}/dkms-patchmodule.sh"
