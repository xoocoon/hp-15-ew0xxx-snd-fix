#!/bin/sh

# see https://www.collabora.com/news-and-blog/blog/2021/05/05/quick-hack-patching-kernel-module-using-dkms/

# make the script stop on error
set -e

KERNEL_MODULE_NAME="${1}"
DKMS_MODULE_VERSION="${2}"

# set up the actual DKMS module -------------------------------------------------------------------

[ ! -e "/usr/src/${KERNEL_MODULE_NAME}-${DKMS_MODULE_VERSION}" ] && sudo mkdir "/usr/src/${KERNEL_MODULE_NAME}-${DKMS_MODULE_VERSION}"

# determine the installed gcc major version
GCC_VERSION_DEFAULT=$( gcc --version | perl -ne 'if (m~^gcc\b.+?(1\d)\.\d{,2}\.\d{,2}~) { print $1; }' )
if [ $GCC_VERSION_DEFAULT -lt 12 ]; then
  if ! which gcc-12 >/dev/null; then
    printf '%s %s\n    %s\n' "Your system uses version $GCC_VERSION_DEFAULT of gcc by default, but version 12 is required as a minimum." 'You might want to install it with the following command:' 'sudo apt install gcc-12.'
    exit 3
  else
    # explicitly use gcc-12 (if we use a kernel compiled with gcc-12)
    CC_PARAMETER=" CC=$( which gcc-12 )"
  fi
fi

# create the configuration file for the DKMS module
sudo tee "/usr/src/${KERNEL_MODULE_NAME}-${DKMS_MODULE_VERSION}/dkms.conf" <<EOF
PACKAGE_NAME="${KERNEL_MODULE_NAME}"
PACKAGE_VERSION="${DKMS_MODULE_VERSION}"

BUILT_MODULE_NAME[0]="${KERNEL_MODULE_NAME}"
DEST_MODULE_LOCATION[0]="/updates/dkms"

AUTOINSTALL="yes"
MAKE[0]="make${CC_PARAMETER} -C \${kernel_source_dir} M=\${dkms_tree}/\${PACKAGE_NAME}/\${PACKAGE_VERSION}/build"
PRE_BUILD="dkms-patchmodule.sh sound/pci/hda"
EOF

# create the pre-build script within the DKMS module
sudo tee "/usr/src/${KERNEL_MODULE_NAME}-${DKMS_MODULE_VERSION}/dkms-patchmodule.sh" <<'EOF'
#!/bin/bash

# see https://www.collabora.com/news-and-blog/blog/2021/05/05/quick-hack-patching-kernel-module-using-dkms/

# kernelver is not set on kernel upgrade from apt, but DPKG_MAINTSCRIPT_PACKAGE
# contains the kernel image or header package upgraded

if [ -z "$kernelver" ] ; then
  echo "using DPKG_MAINTSCRIPT_PACKAGE instead of unset kernelver"
  kernelver=$( echo $DPKG_MAINTSCRIPT_PACKAGE | sed -r 's/linux-(headers|image)-//' )
fi

vers=(${kernelver//./ })   # split kernel version into individual elements
major="${vers[0]}"
minor="${vers[1]}"
version="$major.$minor"    # recombine as needed
subver=$(grep "SUBLEVEL =" /usr/src/linux-headers-${kernelver}/Makefile | tr -d " " | cut -d "=" -f 2)

echo "Downloading kernel source $version.$subver for $kernelver"
wget https://mirrors.edge.kernel.org/pub/linux/kernel/v$major.x/linux-$version.$subver.tar.xz

echo "Extracting original source of the kernel module"
tar -xf linux-$version.$subver.tar.* linux-$version.$subver/$1 --xform=s,linux-$version.$subver/$1,.,

for i in `ls *.patch`
do
  echo "Applying $i"
  patch < $i
done
EOF

# make the pre-build script executable
sudo chmod u+x "/usr/src/${KERNEL_MODULE_NAME}-${DKMS_MODULE_VERSION}/dkms-patchmodule.sh"
