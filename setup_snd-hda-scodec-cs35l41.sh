#!/bin/bash

# see https://www.collabora.com/news-and-blog/blog/2021/05/05/quick-hack-patching-kernel-module-using-dkms/

# make the script stop on error
set -e

BIN_ABSPATH="$(dirname "$(readlink -f "${0}")")"

KERNEL_MODULE_NAME='snd-hda-scodec-cs35l41'
DKMS_MODULE_VERSION='0.1'

. kernel-version_get.sh

if [ $SOURCE_MAJOR_VERSION = 6 ] && [ $SOURCE_MINOR_VERSION = 8 ]; then
  echo "Patch ${KERNEL_MODULE_NAME} not required for your kernel version."
  exit 0
fi

if [ ! $SOURCE_MAJOR_VERSION = 6 ]; then
  echo "Patch is only applicable to kernel versions 6.x"
  exit 1
fi

if [[ ! $EUID = 0 ]]; then
  echo "Only root can perform this setup. Aborting."
  exit 1
fi

# set up the actual DKMS module -------------------------------------------------------------------

"${BIN_ABSPATH}/dkms-module_create.sh" "${KERNEL_MODULE_NAME}" "${DKMS_MODULE_VERSION}"

# create the patch file to apply to the source of the snd-hda-scodec-cs35l41 kernel module
tee "/usr/src/${KERNEL_MODULE_NAME}-${DKMS_MODULE_VERSION}/cs35l41_hda_property.patch" <<'EOF'
--- sound/pci/hda/cs35l41_hda_property.c.orig
+++ sound/pci/hda/cs35l41_hda_property.c
@@ -38,4 +38,8 @@
 		hw_cfg->bst_type = CS35L41_EXT_BOOST;
 		hw_cfg->gpio1.func = CS35l41_VSPK_SWITCH;
 		hw_cfg->gpio1.valid = true;
+  } else if (strncmp(hid, "CSC3551", 7) == 0) {
+     hw_cfg->bst_type = CS35L41_EXT_BOOST;
+     hw_cfg->gpio1.func = CS35l41_VSPK_SWITCH;
+     hw_cfg->gpio1.valid = true;
 	}
EOF

"${BIN_ABSPATH}/dkms-module_build.sh" "${KERNEL_MODULE_NAME}" "${DKMS_MODULE_VERSION}"
