#!/bin/ksh

# resilient-backup.sh - ksh script to make backups and log actions and errors,
# more difficult than it sounds under SCO Unix :'(
#
# Depends on resilient-backup_lib.sh being in the same directory as this script.
# 
# (C) 2012 Sebastian Cruz <default50@gmail.com>
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

# Version 2.0.2

### START OF USER MODIFIABLE VARIABLES ###

# Backup storage directory
BKPDIR="/x/backup"
# Minimum number of log files to keep
LOGFILECOUNT="30"
# Keep log files newer than X (find command parameter - see man find)
LOGFILEEXPIRY="+30"

FTPSERVER=""
FTPUSER="myftpuser"
FTPASSWD="SomePassword"

### END OF USER MODIFIABLE VARIABLES ###
### DO NOT EDIT ANYTHING BELOW THIS LINE ###

umask 0022

export PATH="/bin:/etc:/usr/bin:/tcb/bin:/usr/local/bin"
LIBPATH=$(whence resilient-backup.sh)
LIBFILE="$(dirname $LIBPATH)/resilient-backup_lib.sh"
CONFIG="/etc/backup.cfg"
LOGDIR="/var/adm"
BKPPREFIX="resilient-backup"
BKPSUFF=""
ZIPPER=""
UNZIPPER=""
LOGFILE="$LOGDIR/$BKPPREFIX-$(date +%Y%m%d).log"
CHUNKSIZE="1024m"
LOCKFILE="/var/run/$BKPPREFIX.pid"
ERRORCOUNT=0

if [[ -r $LIBFILE ]]; then
	. $LIBFILE
else
	echo "$LIBFILE not readable or not present."
        echo $(date +%Y%m%d-%H:%M:%S): "ERROR: $LIBFILE not readable or not present." >> $LOGFILE
	exit 1
fi

set -A BACKUPOBJS
set -A BIN "grep find wc ap rm cp tar split basename mkdir lpstat visionfs divvy id md5 xtod cat ping ftp"
set -A PBIN

# Capture possible errors and log them
trap 'trapErrors main $LINENO' ERR

if [[ $(id -u) -ne 0 ]]; then
        echo "This script must be run as root"
	log "Tried to run with UID=$(id -u)"
        exit 1
fi

# Redirect all output to log file, including STDERR
exec >> $LOGFILE
exec 2>&1

case $1 in
	"dry-run")
		log "- START backup_job (dry-run)"
		addLockFile $LOCKFILE
		pathCheck
		sanityChecks
		logConfig
		pingTest
		ftpTest
		removeLockFile $LOCKFILE
		log "- END backup_job (dry-run)"
		;;
	"run")
		log "- START backup_job"
		addLockFile $LOCKFILE
		pathCheck
		retval1=$?

		sanityChecks
		retval2=$?

		logConfig

		if [[ $retval1 -ne 0 ]]; then
			log "ERROR: Script aborted because critical function pathCkeck didn't finish up correctly."
			log "- END backup_job"
			log "ERRORCOUNT=$ERRORCOUNT"
			log "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
			exit $ERRORCOUNT
		fi

		if [[ $retval2 -ne 0 ]]; then
			log "ERROR: Script aborted because critical function sanityCkecks didn't finish up correctly."
			log "- END backup_job"
			log "ERRORCOUNT=$ERRORCOUNT"
			log "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
			exit $ERRORCOUNT
		fi

		cleanBackups
		cleanLogs
		dbBackup
		usersBackup
		printersBackup
		sysconfBackup
		backupCheck
		createMD5SUMS
		pingTest
		ftpTest
		ftpTransfer
		removeLockFile $LOCKFILE
		log "- END backup_job"
		;;
	"ftp-run")
		log "- START backup_job (ftp-run)"
		addLockFile $LOCKFILE
		pathCheck
		sanityChecks
		logConfig
		pingTest
		ftpTest
		ftpTransfer
		removeLockFile $LOCKFILE
		log "- END backup_job (ftp-run)"
		;;
	*)
        	echo "Usage: $0 { run | dry-run }"
        	log "Tried to run with wrong parameters: $@"
		log "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
        	exit 1
		;;
esac

log "ERRORCOUNT=$ERRORCOUNT"
log "~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"

if [[ $ERRORCOUNT -ne 0 ]]; then
	exit $ERRORCOUNT
else
	exit 0
fi
