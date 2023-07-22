#!/bin/bash

# see https://www.collabora.com/news-and-blog/blog/2021/05/05/quick-hack-patching-kernel-module-using-dkms/

# make the script stop on error
set -e

BIN_ABSPATH="$(dirname "$(readlink -f "${0}")")"

KERNEL_MODULE_NAME='snd-hda-codec-realtek'
DKMS_MODULE_VERSION='0.1'

declare -a QUIRKS=( 'ALC245_FIXUP_CS35L41_SPI_2' 'ALC287_FIXUP_CS35L41_I2C_2' )

IS_AUTO_PATCH=false
TARGET_QUIRK=

if [[ ! $EUID = 0 ]]; then
  echo "Only root can perform this setup. Aborting."
  exit 1
fi

# Evaluate cmd line arguments #####################################################################

POSITIONAL_ARGUMENTS=( )
while [[ $# -gt 0 ]] ; do
  argument="$1"
  case $argument in
    -a|--auto)
      IS_AUTO_PATCH=true
      shift
      ;;
    -q|--quirk)
      TARGET_QUIRK=$2
      shift 2
      ;;
    --)
      break
      ;;
    *)
      POSITIONAL_ARGUMENTS+=("$1")
      shift
      ;;
  esac
done
set -- "${POSITIONAL_ARGUMENTS[@]}"

if [ $IS_AUTO_PATCH = true ] && [ -z $TARGET_QUIRK ] || [ ! $TARGET_QUIRK =~ ^$QUIRKS$ ]; then
  printf "%s\n$( for i in $( seq 1 ${#QUIRKS[@]} ); do echo -n '    %s\n'; done )%s\n" 'Please specify one of' ${QUIRKS[*]} "as Realtek quirk to apply to your machine (at your own risk), e.g. -q ${QUIRKS[0]}"
  exit 1
fi

# set up the actual DKMS module -------------------------------------------------------------------

"${BIN_ABSPATH}/dkms-module_create.sh" "${KERNEL_MODULE_NAME}" "${DKMS_MODULE_VERSION}"

if [ $IS_AUTO_PATCH = true ]; then
  # generate the patch based on the system running (added by samliddicott)
  if read PRODUCT < /sys/devices/virtual/dmi/id/product_name &&
      read ID < /sys/class/sound/hwC0D0/subsystem_id &&
      ID1=$(printf "0x%04x" $(( ID >> 16 & 0xffff ))) &&
      ID2=$(printf "0x%04x" $(( ID & 0xffff ))); then
    AUTO_PATCH_LINE="SND_PCI_QUIRK($ID1, $ID2, "'"'"$PRODUCT"'"'", $TARGET_QUIRK),"
  fi
fi

# create the patch file to apply to the source of the snd-hda-codec-realtek kernel module
tee "/usr/src/${KERNEL_MODULE_NAME}-${DKMS_MODULE_VERSION}/patch_realtek.patch" <<EOF
--- sound/pci/hda/patch_realtek.c.orig
+++ sound/pci/hda/patch_realtek.c
@@ -9452,6 +9452,10 @@
 	SND_PCI_QUIRK(0x103c, 0x89c6, "Zbook Fury 17 G9", ALC245_FIXUP_CS35L41_SPI_2_HP_GPIO_LED),
 	SND_PCI_QUIRK(0x103c, 0x89ca, "HP", ALC236_FIXUP_HP_MUTE_LED_MICMUTE_VREF),
 	SND_PCI_QUIRK(0x103c, 0x89d3, "HP EliteBook 645 G9 (MB 89D2)", ALC236_FIXUP_HP_MUTE_LED_MICMUTE_VREF),
+	 $AUTO_PATCH_LINE
+  SND_PCI_QUIRK(0x103c, 0x8a06, "HP Dragonfly Folio 13.5 inch G3 2-in-1 Notebook PC", ALC245_FIXUP_CS35L41_SPI_2),
+  SND_PCI_QUIRK(0x103c, 0x8a29, "HP Envy x360 15-ew0xxx", ALC287_FIXUP_CS35L41_I2C_2),
+	SND_PCI_QUIRK(0x103c, 0x8a2c, "HP Envy 16-h0xxx", ALC287_FIXUP_CS35L41_I2C_2),
 	SND_PCI_QUIRK(0x103c, 0x8a78, "HP Dev One", ALC285_FIXUP_HP_LIMIT_INT_MIC_BOOST),
 	SND_PCI_QUIRK(0x103c, 0x8aa0, "HP ProBook 440 G9 (MB 8A9E)", ALC236_FIXUP_HP_GPIO_LED),
 	SND_PCI_QUIRK(0x103c, 0x8aa3, "HP ProBook 450 G9 (MB 8AA1)", ALC236_FIXUP_HP_GPIO_LED),
EOF

"${BIN_ABSPATH}/dkms-module_build.sh" "${KERNEL_MODULE_NAME}" "${DKMS_MODULE_VERSION}"
