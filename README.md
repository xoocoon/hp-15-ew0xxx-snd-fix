# hp-15-ew0xxx-snd-fix
DKMS module for fixing the sound on Linux for HP models Envy x360 15-ew0xxx

## Purpose
The HP Envy x360 15-ew0xxx laptop models dating from 2022 seem to be quite compatible with Linux, except the sound from built-in speakers. This repo contains two DKMS modules for fixing this issue on Ubuntu Linux 23.04 (kernel 6.2) and the exact model 15-ew0776ng.

It might also work on other Debian-based distributions with a kernel from 6.1 onwards, as well as with other HP models in the x360 15-ew/15-ey range. Hardware prerequisites are the Cirrus Logic smart amplifier chipset CSC3551 and the Realtek HDA codec ALC245. Please leave any comments or commit any code to make it work for other models than 15-ew0776ng.

**This module comes without any warranty, so installing and testing it on your own hardware is at your own risk.**

## The snd-hda-scodec-cs35l41 module
The snd-hda-scodec-cs35l41 DKMS module included in this repo is intended to supersede the mainline kernel module of the same name.

Mainline source code: https://github.com/torvalds/linux/blob/master/sound/pci/hda/cs35l41_hda.c

This module is used to activate the smart amplifiers on the I2C bus, but the exact wiring on a hardware level is model-specific. That is why the mentioned HP models and probably many other need a model-specific fix of the kernel module.
The shell script `setup_snd-hda-scodec-cs35l41.sh` is intended to setup DKMS and the DKMS module for snd-hda-scodec-cs35l41 on your machine. Tested on Ubuntu 23.04. only.

First, make the script executable, then execute it:
```
sudo chown u+x setup_snd-hda-scodec-cs35l41.sh
./setup_snd-hda-scodec-cs35l41.sh
```

Instead of executing the entire script you might execute each shell command step by step to see whether it works.

To verify if the module works on your machine, you can query the kernel messages as follows:
```
sudo dmesg | grep cs35l41-hda
```

If the module does not work on your machine, the output is similar to the following:
```
cs35l41-hda i2c-CSC3551:00-cs35l41-hda.0: Error: ACPI _DSD Properties are missing for HID CSC3551.
cs35l41-hda i2c-CSC3551:00-cs35l41-hda.0: error -EINVAL: Platform not supported
cs35l41-hda: probe of i2c-CSC3551:00-cs35l41-hda.0 failed with error -22
cs35l41-hda i2c-CSC3551:00-cs35l41-hda.1: Error: ACPI _DSD Properties are missing for HID CSC3551.
cs35l41-hda i2c-CSC3551:00-cs35l41-hda.1: error -EINVAL: Platform not supported
cs35l41-hda: probe of i2c-CSC3551:00-cs35l41-hda.1 failed with error -22
```

If it does work, the output is similar to the following:
```
cs35l41-hda i2c-CSC3551:00-cs35l41-hda.0: Cirrus Logic CS35L41 (35a40), Revision: B2
cs35l41-hda i2c-CSC3551:00-cs35l41-hda.1: Reset line busy, assuming shared reset
cs35l41-hda i2c-CSC3551:00-cs35l41-hda.1: Cirrus Logic CS35L41 (35a40), Revision: B2
```

## The snd-hda-codec-realtek module
The snd-hda-codec-realtek DKMS module included in this repo is intended to supersede the mainline kernel module of the same name.

This module provides fixes for several HDA codecs provided by Realtek, e.g. ALC245, ALC269 and ALC287. However, the codec id itself is not enough to enable the speakers on a specific HP Envy x360 15-ew0xxx model. Hence the need to adjust it for each model with a new hardware setup.

Mainline source code: https://github.com/torvalds/linux/blob/master/sound/pci/hda/patch_realtek.c

The shell script `snd-hda-codec-realtek.sh` is intended to setup DKMS and the DKMS module for snd-hda-codec-realtek on your machine. Tested on Ubuntu 23.04. only.

First, make the script executable, then execute it:
```
sudo chown u+x snd-hda-codec-realtek.sh
./snd-hda-codec-realtek.sh
```

Instead of executing the entire script you might execute each shell command step by step to see whether it works.

To verify if the module works on your machine, you can query the kernel messages as follows:
```
sudo dmesg | grep cs35l41-hda
```

If it works, the following or similar lines are included in the output:
```
cs35l41-hda i2c-CSC3551:00-cs35l41-hda.0: DSP1: Firmware version: 3
cs35l41-hda i2c-CSC3551:00-cs35l41-hda.0: DSP1: cirrus/cs35l41-dsp1-spk-prot.wmfw: Fri 24 Jun 2022 14:55:56 GMT Daylight Time
cs35l41-hda i2c-CSC3551:00-cs35l41-hda.0: DSP1: Firmware: 400a4 vendor: 0x2 v0.58.0, 2 algorithms
cs35l41-hda i2c-CSC3551:00-cs35l41-hda.0: DSP1: 0: ID cd v29.78.0 XM@94 YM@e
cs35l41-hda i2c-CSC3551:00-cs35l41-hda.0: DSP1: 1: ID f20b v0.1.0 XM@17c YM@0
```

## The general approach
What both `setup_snd-hda-scodec-cs35l41` and `snd-hda-codec-realtek` do is that they generate a configuration for a DKMS module, build it and install it. In the build process, the following happens:
1. The entire kernel source code for the currently installed kernel gets downloaded from https://mirrors.edge.kernel.org as a tarball.
2. Only the module in question is extracted from the tarball. That is, snd-hda-scodec-cs35l41 and snd-hda-codec-realtek, respectively.
3. A patch is applied to the relevant source code files.
4. The patched kernel module is built via `make` and `gcc`.

Step 3. is where you can add your own patches to support your laptop model.
Once the modules are built and installed via DKMS they should supersede the modules of the same name in the mainline kernel. This should also work with Secure Boot as the DKMS build process signs the modules with the MOK key on your system. Of course, as a prerequisite, this MOK key must be registered in the BIOS/UEFI of your machine beforehand.

## Troubleshooting
### DKMS status
To check whether the built DKMS modules are loaded after a reboot, execute the following command:
```
dkms status
```

A successful output looks like this:
```
snd-hda-codec-realtek/0.1, 6.2.0-20-generic, x86_64: installed
snd-hda-scodec-cs35l41/0.1, 6.2.0-20-generic, x86_64: installed
```

### Readelf
The `dkms` command might yield readelf error messages, but these can be ignored, obviously.

## Tweaking it for your distro and model
The main reason why the script only works on Debian-based distros is the usage of the apt package manager. You might want to replace the apt calls with the package manager of your distro and adjust the package names. Pull requests to make the scripts more versatile are highly appreciated!

Furthermore, to provide a patch for your model, you need its audio subsystem ID, i.e. 0x103c for the manufacturer HP and another 4 hex digits for the actual subsystem. The latter is 0x8a29 in my case. You can find it out with the following command:
```
cat /sys/class/sound/hwC0D0/subsystem_id
```

Generally. a good resource for debugging HDA audio problems is: https://docs.kernel.org/sound/hd-audio/notes.html
