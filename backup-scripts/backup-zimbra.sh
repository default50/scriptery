#!/bin/bash

# backup-zimbra.sh uses LVM snapshots and duplicity to minimize downtime taking
# consistent backups.
# 
# Copyright (C) 2011 Sebastian Cruz <default50@gmail.com>
# 
# This program is free software: you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License along with
# this program. If not, see http://www.gnu.org/licenses/.

LOGFILE="/var/log/backup-zimbra.log"
#Should check that mktemp returns something valid or bad things can happen :-)
TEMPDIR=$(mktemp -dp /var/tmp zimbra-backup-XXXXX)
echo TEMPDIR="$TEMPDIR"
RSYNC_USER='backup-zimbra'
RSYNC_PASSWORD='SomePassword'
RSYNC_HOST='backup.mydomain.com::/backup-zimbra'
PASSPHRASE='SomePassphrase'
VERBOSE=4
RETENTION=2
VOLSIZE=2048

# what to backup
VG=zimbra
LV=opt_zimbra

# snapshot name
LV_SNAP=ZimbraBackup

DUPLICITY='/usr/bin/duplicity'
#Full backup if sunday
if [[ $(date +%u) = 7 ]]; then
	DUPOPTS="full -v$VERBOSE --tempdir $TEMPDIR --allow-source-mismatch --volsize $VOLSIZE --timeout 300 --asynchronous-upload"
	echo DUPOPTS=$DUPOPTS
else
	DUPOPTS="-v$VERBOSE --tempdir $TEMPDIR --allow-source-mismatch --volsize $VOLSIZE --timeout 300 --asynchronous-upload"
	echo DUPOPTS=$DUPOPTS
fi

export RSYNC_PASSWORD
export PASSPHRASE

# lvcreate and lvremove commands path
lvcreate_cmd="/sbin/lvcreate"
lvremove_cmd="/sbin/lvremove"
echo Backup started at `date`

# Stop the Zimbra services
echo "Stopping the Zimbra services..."
#/etc/init.d/zimbra stop || exit
/etc/init.d/zimbra stop || echo "ERROR stopping zimbra" 
#su -l zimbra -c "zmcontrol stop"
for i in `seq 10 10 60`; do
	sleep $i
	if [ ! -f /var/lock/subsys/zimbra ]; then
		echo "Zimbra apagado exitosamente $i"
		break
	fi
done
#su -l zimbra -c "zmcontrol status"
echo "Creating a snapshot called $LV_SNAP"

# depending on the time it takes to create the backup and the traffic of your server, you may need to increase the -LxxG value
$lvcreate_cmd -L10G -s -n $LV_SNAP /dev/$VG/$LV

# Create a mountpoint to mount the logical volume to
echo "Creating a mountpoint for the LV..."
mkdir -p $TEMPDIR/$LV_SNAP

# Mount the logical volume to the mountpoint
sleep 10
echo "Mounting the snapshot..."

# WARNING: if you use xfs you MUST add nouuid option here!
mount -o ro /dev/$VG/$LV_SNAP $TEMPDIR/$LV_SNAP/

# Start the Zimbra services
echo "Restarting the Zimbra services..."
sleep 60
/etc/init.d/zimbra start || echo "ERROR restarting zimbra"
##su -l zimbra -c "zmcontrol start"
sleep 10
/etc/init.d/zimbra status
if [ ! -f /var/lock/subsys/zimbra ]; then
	echo "Where's the file? (/var/lock/subsys/zimbra)"
fi

# Print duplicity repo status
echo "==== START duplicity repo status ===="
$DUPLICITY collection-status \
        rsync://$RSYNC_USER@$RSYNC_HOST/ 
echo -e "==== END duplicity repo status ====\n\n\n"

# Create the current backup

# Clean up incomplete backup archive files
echo "==== START duplicity cleanup ===="
$DUPLICITY cleanup --force --extra-clean -v$VERBOSE \
        rsync://$RSYNC_USER@$RSYNC_HOST/
echo -e "==== END duplicity cleanup ====\n\n\n"

# create new backup
echo "==== START duplicity backup ===="
$DUPLICITY $DUPOPTS \
        $TEMPDIR/$LV_SNAP/ \
        rsync://$RSYNC_USER@$RSYNC_HOST/
echo -e "==== END duplicity backup ====\n\n\n"

# remove old backup sets: keep only the last N full backups, where N is the value of $RETENTION
echo "==== START duplicity remove-all-but-n-full ===="
$DUPLICITY remove-all-but-n-full $RETENTION --force -v$VERBOSE \
        rsync://$RSYNC_USER@$RSYNC_HOST/
echo -e "==== END duplicity remove-all-but-n-full ====\n\n\n"


# Print duplicity repo status
echo "==== START duplicity repo status ===="
$DUPLICITY collection-status \
        rsync://$RSYNC_USER@$RSYNC_HOST/
echo -e "==== END duplicity repo status ====\n\n\n"

# Unmount /tmp/$lv_zimbra and remove the logical volume
echo "Unmounting and removing the snapshot."
umount /dev/$VG/$LV_SNAP

echo "-- LVS --"
/sbin/lvs
$lvremove_cmd --force /dev/$VG/$LV_SNAP
rm -Rf $TEMPDIR/$LV_SNAP
# Done!
echo Zimbra backed up on $RSYNC_HOST
echo Backup ended at `date`
