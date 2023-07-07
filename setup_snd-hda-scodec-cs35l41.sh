#!/bin/sh

# see https://www.collabora.com/news-and-blog/blog/2021/05/05/quick-hack-patching-kernel-module-using-dkms/

# make the script stop on error
set -e

BIN_ABSPATH="$(dirname "$(readlink -f "${0}")")"

KERNEL_MODULE_NAME='snd-hda-scodec-cs35l41'
DKMS_MODULE_VERSION='0.1'

"${BIN_ABSPATH}/dkms-module_prepare.sh"

# set up the actual DKMS module -------------------------------------------------------------------

"${BIN_ABSPATH}/dkms-module_create.sh" "${KERNEL_MODULE_NAME}" "${DKMS_MODULE_VERSION}"

# create the patch file to apply to the source of the snd-hda-scodec-cs35l41 kernel module
sudo tee "/usr/src/${KERNEL_MODULE_NAME}-${DKMS_MODULE_VERSION}/cs35l41_hda.patch" <<'EOF'
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

"${BIN_ABSPATH}/dkms-module_build.sh" "${KERNEL_MODULE_NAME}" "${DKMS_MODULE_VERSION}"
