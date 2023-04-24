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

sudo mkdir /usr/src/snd-hda-codec-realtek-0.1

# create the configuration file for the DKMS module
sudo tee /usr/src/snd-hda-codec-realtek-0.1/dkms.conf <<'EOF'
PACKAGE_NAME="snd-hda-codec-realtek"
PACKAGE_VERSION="0.1"

BUILT_MODULE_NAME[0]="snd-hda-codec-realtek"
DEST_MODULE_LOCATION[0]="/updates/dkms"

AUTOINSTALL="yes"
# explicitly use gcc-12 (if we use a kernel compiled with gcc-12)
# MAKE[0]="make CC=/usr/bin/gcc-12 -C ${kernel_source_dir} M=${dkms_tree}/${PACKAGE_NAME}/${PACKAGE_VERSION}/build"
MAKE[0]="make -C ${kernel_source_dir} M=${dkms_tree}/${PACKAGE_NAME}/${PACKAGE_VERSION}/build"
PRE_BUILD="dkms-patchmodule.sh sound/pci/hda"
EOF

# create the pre-build script within the DKMS module
sudo tee /usr/src/snd-hda-codec-realtek-0.1/dkms-patchmodule.sh <<'EOF'
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
sudo chmod u+x /usr/src/snd-hda-codec-realtek-0.1/dkms-patchmodule.sh

# create the patch file to apply to the source of the snd-hda-codec-realtek kernel module
sudo tee /usr/src/snd-hda-codec-realtek-0.1/patch_realtek.patch <<'EOF'
--- sound/pci/hda/patch_realtek.c.orig
+++ sound/pci/hda/patch_realtek.c
@@ -9452,12 +9452,13 @@
 	SND_PCI_QUIRK(0x103c, 0x89c6, "Zbook Fury 17 G9", ALC245_FIXUP_CS35L41_SPI_2_HP_GPIO_LED),
 	SND_PCI_QUIRK(0x103c, 0x89ca, "HP", ALC236_FIXUP_HP_MUTE_LED_MICMUTE_VREF),
 	SND_PCI_QUIRK(0x103c, 0x89d3, "HP EliteBook 645 G9 (MB 89D2)", ALC236_FIXUP_HP_MUTE_LED_MICMUTE_VREF),
+  SND_PCI_QUIRK(0x103c, 0x8a78, "HP Dev One", ALC285_FIXUP_HP_LIMIT_INT_MIC_BOOST),
 	SND_PCI_QUIRK(0x103c, 0x8a78, "HP Dev One", ALC285_FIXUP_HP_LIMIT_INT_MIC_BOOST),
-	SND_PCI_QUIRK(0x103c, 0x8aa0, "HP ProBook 440 G9 (MB 8A9E)", ALC236_FIXUP_HP_GPIO_LED),
+	SND_PCI_QUIRK(0x103c, 0x8a29, "HP Envy x360 15-ew0xxx", ALC287_FIXUP_CS35L41_I2C_2),
 	SND_PCI_QUIRK(0x103c, 0x8aa3, "HP ProBook 450 G9 (MB 8AA1)", ALC236_FIXUP_HP_GPIO_LED),
 	SND_PCI_QUIRK(0x103c, 0x8aa8, "HP EliteBook 640 G9 (MB 8AA6)", ALC236_FIXUP_HP_GPIO_LED),
 	SND_PCI_QUIRK(0x103c, 0x8aab, "HP EliteBook 650 G9 (MB 8AA9)", ALC236_FIXUP_HP_GPIO_LED),
-	 SND_PCI_QUIRK(0x103c, 0x8abb, "HP ZBook Firefly 14 G9", ALC245_FIXUP_CS35L41_SPI_2_HP_GPIO_LED),
+	SND_PCI_QUIRK(0x103c, 0x8abb, "HP ZBook Firefly 14 G9", ALC245_FIXUP_CS35L41_SPI_2_HP_GPIO_LED),
 	SND_PCI_QUIRK(0x103c, 0x8ad1, "HP EliteBook 840 14 inch G9 Notebook PC", ALC245_FIXUP_CS35L41_SPI_2_HP_GPIO_LED),
 	SND_PCI_QUIRK(0x103c, 0x8ad2, "HP EliteBook 860 16 inch G9 Notebook PC", ALC245_FIXUP_CS35L41_SPI_2_HP_GPIO_LED),
 	SND_PCI_QUIRK(0x103c, 0x8b42, "HP", ALC245_FIXUP_CS35L41_SPI_2_HP_GPIO_LED),
EOF

clear
# build the DKMS module, install it and update the initramfs
sudo dkms build -m snd-hda-codec-realtek -v 0.1 --force
sudo dkms install -m snd-hda-codec-realtek -v 0.1 --force
sudo update-initramfs -u -k $(uname -r)

sudo reboot
