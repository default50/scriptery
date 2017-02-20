#!/system/bin/sh

# To be placed under /system/etc/init.d/ as 99cifs-mount
# Tested on Minix X7

exec > /data/local/tmp/cifs-mount.log
exec 2>&1

# Make sure networking is up before mounting
while : ; do
    check_if_up=($(netcfg | grep -e "eth0" -e "wlan0" | busybox awk '{print $2}'))
    if [[ ("${check_if_up[0]}" = "UP") || ("${check_if_up[1]}" = "UP") ]]; then
        break
    fi
    sleep 1
done
#setenforce permissive

# Switch rootfs to read / write
# Be carful after this. Misplaced commands may
# brick your system
#mount -t ext4 -o rw,remount /dev/block/mtd/by-name/system
mount -t rootfs -o rw,remount /

# Create Mount Points // Edit this part to suit your needs
busybox mkdir -p -m 0755 /mnt/cifs/toshiba

# Switch rootfs to read only
#mount -t ext4 -o ro,remount /dev/block/mtd/by-name/system
mount -t rootfs -o ro,remount /

#SMB Auto Mount // Edit this part to suit your need
busybox mount -t cifs -o user="my_user",password="my_pass",iocharset=utf8 //192.168.0.254/toshiba /mnt/cifs/toshiba
