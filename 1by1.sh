#!/bin/sh

fastboot flash bootloader $1
fastboot reboot-bootloader
sleep 5
fastboot flash radio $2
fastboot reboot-bootloader
sleep 5
fastboot reboot-bootloader

#fastboot flash recovery $3/recovery.img
fastboot flash boot $3/boot.img
fastboot flash system $3/system.img
