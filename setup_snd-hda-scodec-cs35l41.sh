#!/bin/sh

# see https://www.collabora.com/news-and-blog/blog/2021/05/05/quick-hack-patching-kernel-module-using-dkms/

if ! which apt >/dev/null; then
  printf '%s\n\n' 'Warning! This script was created for Debian-based distros. You might want to modify it to suit your Linux distro.'
fi

sudo apt update -y && sudo apt install linux-headers-$(uname -r) 

# see https://askubuntu.com/questions/1348250/skipping-btf-generation-xxx-due-to-unavailability-of-vmlinux-on-ubuntu-21-04
sudo apt install build-essential dkms dwarves
sudo cp /sys/kernel/btf/vmlinux "/usr/lib/modules/$(uname -r)/build/"

# to avoid the readelf error when calling the dkms executable:
sudo mv "/usr/src/linux-headers-$(uname -r)/vmlinux" "/usr/src/linux-headers-$(uname -r)-generic/vmlinux.orig"

# set up the actual DKMS module -------------------------------------------------------------------

sudo mkdir /usr/src/snd-hda-scodec-cs35l41-0.1

# create the configuration file for the DKMS module
sudo tee /usr/src/snd-hda-scodec-cs35l41-0.1/dkms.conf <<'EOF'
PACKAGE_NAME="snd-hda-scodec-cs35l41"
PACKAGE_VERSION="0.1"

BUILT_MODULE_NAME[0]="snd-hda-scodec-cs35l41"
DEST_MODULE_LOCATION[0]="/updates/dkms"

AUTOINSTALL="yes"
# explicitly use gcc-12 (if we use a kernel compiled with gcc-12)
# MAKE[0]="make CC=/usr/bin/gcc-12 -C ${kernel_source_dir} M=${dkms_tree}/${PACKAGE_NAME}/${PACKAGE_VERSION}/build"
MAKE[0]="make -C ${kernel_source_dir} M=${dkms_tree}/${PACKAGE_NAME}/${PACKAGE_VERSION}/build"
PRE_BUILD="dkms-patchmodule.sh sound/pci/hda"
EOF

# create the pre-build script within the DKMS module
sudo tee /usr/src/snd-hda-scodec-cs35l41-0.1/dkms-patchmodule.sh <<'EOF'
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
sudo chmod u+x /usr/src/snd-hda-scodec-cs35l41-0.1/dkms-patchmodule.sh

# create the patch file to apply to the source of the snd-hda-scodec-cs35l41 kernel module
sudo tee /usr/src/snd-hda-scodec-cs35l41-0.1/cs35l41_hda.patch <<'EOF'
--- sound/pci/hda/cs35l41_hda.c
+++ sound/pci/hda/cs35l41_hda.c
@@ -1235,6 +1235,10 @@
 		hw_cfg->bst_type = CS35L41_EXT_BOOST;
 		hw_cfg->gpio1.func = CS35l41_VSPK_SWITCH;
 		hw_cfg->gpio1.valid = true;
+  } else if (strncmp(hid, "CSC3551", 7) == 0) {
+     hw_cfg->bst_type = CS35L41_EXT_BOOST;
+     hw_cfg->gpio1.func = CS35l41_VSPK_SWITCH;
+     hw_cfg->gpio1.valid = true;
 	} else {
 		/*
 		 * Note: CLSA010(0/1) are special cases which use a slightly different design.
EOF

clear
# build the DKMS module, install it and update the initramfs
sudo dkms build -m snd-hda-scodec-cs35l41 -v 0.1 --force
sudo dkms install -m snd-hda-scodec-cs35l41 -v 0.1 --force
sudo update-initramfs -u -k $(uname -r)

sudo reboot
