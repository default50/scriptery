#!/bin/bash

set -x

# Script to flash the Nexus 6 from a factory image
# https://developers.google.com/android/nexus/images
# TWRP
# https://dl.twrp.me/shamu/

if [ -z ${1} ]; then
  echo "ERROR: Please specify image.tgz as parameter!"
  exit 1
fi

# Image name is always the first part of the filename (device-version) before "-factory....tgz"
IMG="${1//-factory*/}"
# Device name is first part of string up to first "-", remove from the end
DEVICE="${IMG%-*}"
# Version is 6 chars long, remove from the beginning
VERSION="${IMG#*-}"

# Unzip/Untar bundle
tar zxvf ${1} -k

# Unzip image
unzip -n -d $IMG $IMG/image-$IMG.zip 

adb reboot bootloader

cd ${IMG}
bootloader=$(ls bootloader-${DEVICE}*.img)
radio=$(ls radio-${DEVICE}*.img)

fastboot flash bootloader ${bootloader}
fastboot reboot-bootloader
sleep 5
fastboot flash radio ${radio}
fastboot reboot-bootloader
sleep 5

fastboot flash boot boot.img
fastboot erase cache
fastboot flash cache cache.img
fastboot flash system system.img

# Flash recovery because it always break
fastboot flash recovery twrp-3.0.2-0-shamu.img

# Would need to find a way to install SuperSU here, maybe sideloading the zip and then issuing a TWRP command?

#reboot?
fastboot reboot

cd ..

# Need to do clean-up

# Need to test if this can be done immediately after flashing system, without reboot
#fastboot flash recovery twrp-3.0.2-0-shamu.img
# Also need to check how to install SuperSU from here
#http://forum.xda-developers.com/apps/supersu
