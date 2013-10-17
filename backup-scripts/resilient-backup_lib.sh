# 
# resilient-backup_lib.sh - ksh library of functions to make backups and log
# actions and errors, more difficult than it sounds under SCO Unix :'(
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

log() {
        echo $(date +%Y%m%d-%H:%M:%S): $@ >> $LOGFILE
}

trapErrors() {
        ERROR=$?
        if [[ ${ERROR} -ne 0 ]];
        then
		log "ERROR: code=$ERROR function=$1 line=$2"
		((ERRORCOUNT+=1))
        fi
}

# Function to capture error codes inside pipes
runPipe() {
	trap 'trapErrors runPipe $LINENO' ERR

        j=1
        while eval "\${pipestatus_$j+:} false"; do
          unset pipestatus_$j
          j=$(($j+1))
        done
        j=1 com= k=1 l=
        for a; do
          if [ "x$a" = 'x|' ]; then
            com="$com { $l "'3>&-
                        echo "pipestatus_'$j'=$?" >&3
                      } 4>&- |'
            j=$(($j+1)) l=
          else
            l="$l \"\$$k\""
          fi
          k=$(($k+1))
        done
        com="$com $l"' 3>&- >&4 4>&-
                   echo "pipestatus_'$j'=$?"'
        exec 4>&1
        eval "$(exec 3>&1; eval "$com")"
        exec 4>&-
        j=1
        while eval "\${pipestatus_$j+:} false"; do
          eval "[ \$pipestatus_$j -eq 0 ]" || return 1
          j=$(($j+1))
        done

        return 0
}

pathCheck() {
	trap 'trapErrors pathCheck $LINENO' ERR
	log "-- START pathCheck"
	index=0
	for i in ${BIN[@]}; do
		if [[ -x $(whence $i) ]]; then
			PBIN[$index]=$(whence $i)
			((index+=1))
		else
			log "--- ERROR: $i not present or non-executable"
			((ERRORCOUNT+=1))
			return 1
		fi
	done

	if [[ -x $(whence gzip) ]]; then
		ZIPPER="$(whence gzip) -c"
		UNZIPPER="$(whence gzip) -cd"
		BKPSUFF="gz"
	elif [[ -x $(whence compress) ]]; then
		ZIPPER="$(whence compress) -b 32 -H -c"
		UNZIPPER="$(whence compress) -b 32 -H -cd"
		BKPSUFF="Z"
	else
		log "--- ERROR: compress or gzip not present or non-executable"
		((ERRORCOUNT+=1))
		return 1
	fi

	log "-- END pathCheck"
	return 0
}

sanityChecks() {
	trap 'trapErrors sanityChecks $LINENO' ERR
	log "-- START sanityChecks"

	if [[ ! -s ${CONFIG} ]]; then
		log "--- ERROR: Configfile ${CONFIG} not present or empty"
		((ERRORCOUNT+=1))
		return 1
        else
		set +A BACKUPOBJS $(grep -E '^[^# ]' < $CONFIG)
	fi

	if [[ ! -w ${BKPDIR} ]]; then
		log "--- ERROR: ${BKPDIR} not present or non-writable"
		((ERRORCOUNT+=1))
		return 1
	fi

	if [[ ! -w ${LOGDIR} ]]; then
		log "--- ERROR: ${LOGDIR} not present or non-writable"
		((ERRORCOUNT+=1))
		return 1
	fi
	
	if [[ ! -w $(dirname $LOCKFILE) ]]; then
		log "--- ERROR: ${LOCKDIR} not present or non-writable"
		((ERRORCOUNT+=1))
		return 1
	fi
	
	index=0
	while [[ -n ${BACKUPOBJS[index]} ]]; do
		if [[ ! -r ${BACKUPOBJS[index]} ]]; then
			log "--- ERROR: ${BACKUPOBJS[index]} is unreadable, please check your $CONFIG file"
			((ERRORCOUNT+=1))
		else
			case ${BACKUPOBJS[index]} in
				*/ )
					log "--- ERROR: ${BACKUPOBJS[index]} ends in / and shouldn't, please check your $CONFIG."
					((ERRORCOUNT+=1))
					;;
				*.lg )
					log "--- NOTICE: Backup object ${BACKUPOBJS[index]} is a useless log file, I'm not backing it up."
					unset BACKUPOBJS[$index]
					;;
			esac
		fi
		((index+=1))
	done

	log "-- END sanityChecks"
	return 0
}

logConfig() {
	trap 'trapErrors logConfig $LINENO' ERR
	log "-- START configuration_variables"
	log "--- BKPDIR = $BKPDIR"
	log "--- LOGFILECOUNT = $LOGFILECOUNT"
	log "--- LOGFILEEXPIRY = $LOGFILEEXPIRY"
	log "--- FTPSERVER = $FTPSERVER"
	log "--- FTPUSER = $FTPUSER"
	log "--- FTPASSWD = $FTPASSWD"
	log "--- PATH = $PATH"
	log "--- LIBPATH = $LIBPATH"
	log "--- LIBFILE = $LIBFILE"
	log "--- CONFIG = $CONFIG"
	log "--- LOGDIR = $LOGDIR"
	log "--- BKPPREFIX = $BKPPREFIX"
	log "--- BKPSUFF = $BKPSUFF"
	log "--- ZIPPER = $ZIPPER"
	log "--- UNZIPPER = $UNZIPPER"
	log "--- LOGFILE = $LOGFILE"
	log "--- CHUNKSIZE = $CHUNKSIZE"
	log "--- LOCKFILE = $LOCKFILE"
	log "--- BACKUPOBJS = ${BACKUPOBJS[@]}"
	log "--- BIN = ${BIN[@]}"
	log "--- PBIN = ${PBIN[@]}"
	log "-- END configuration_variables"
}

cleanLogs() {
	trap 'trapErrors cleanLogs $LINENO' ERR
	# Clean logfiles older than $LOGFILEEXPIRY but keeping at least $LOGFILECOUNT available
	log "-- START cleanLogs"
	COUNT=$(find $LOGDIR -name $BKPPREFIX\* -type f | wc -l)
	if [[ $COUNT -ge $LOGFILECOUNT ]]; then
		find $LOGDIR -name $BKPPREFIX\* -type f -mtime $LOGFILEEXPIRY -exec rm -f "{}" \;
	fi
	log "-- END cleanLogs"
}

cleanBackups() {
	trap 'trapErrors cleanBackups $LINENO' ERR
	log "-- START cleanBackups"
	find $BKPDIR \( -name $BKPPREFIX\* -o -name MD5SUMS\* \) -type f -exec rm -f "{}" \;
	log "-- END cleanBackups"
}

dbBackup() {
	trap 'trapErrors dbBackup $LINENO' ERR
	log "-- START dbBackup"
	errpipe=/tmp/${0##*/}.errpipe.$$
	tar -clAf - ${BACKUPOBJS[@]} 2>>$errpipe | $ZIPPER 2>>$errpipe | split -b $CHUNKSIZE - $BKPDIR/$BKPPREFIX.tar.$BKPSUFF. 2>>$errpipe
	if [[ -s $errpipe ]]; then
		log "--- ERROR: The DB backup could not be created. Please check manually!"
		log "--- The error file said: $(cat $errpipe)"
		((ERRORCOUNT+=1))
		rm -f $errpipe
		return 1
	fi
	rm -f $errpipe
	log "-- END dbBackup"
}

usersBackup() {
	trap 'trapErrors usersBackup $LINENO' ERR
	log "-- START usersBackup"
	ap -dg > $BKPDIR/$BKPPREFIX-system_users.txt
	log "-- END usersBackup"
}

printersBackup() {
	trap 'trapErrors printersBackup $LINENO' ERR
	log "-- START printersBackup"
	mkdir $BKPDIR/$BKPPREFIX-printers-tmp
	lpstat -p > $BKPDIR/$BKPPREFIX-printers-tmp/lpstat-p.txt
	visionfs print --list > $BKPDIR/$BKPPREFIX-printers-tmp/vision-printers.txt
	cp /etc/printcap $BKPDIR/$BKPPREFIX-printers-tmp/printcap
	cp /etc/hosts $BKPDIR/$BKPPREFIX-printers-tmp/hosts
	runPipe tar -clAf - $BKPDIR/$BKPPREFIX-printers-tmp \| $ZIPPER > $BKPDIR/$BKPPREFIX-printers.tar.$BKPSUFF
	for i in $pipestatus_1 $pipestatus_2 $pipestatus_3 ; do
		if [[ $i -ne 0 ]]; then
			log "--- ERROR: Something went wrong creating the printers backup!"
		fi
	done
	rm -Rf $BKPDIR/$BKPPREFIX-printers-tmp
	log "-- END printersBackup"
}

sysconfBackup() {
	trap 'trapErrors sysconfBackup $LINENO' ERR
	log "-- START sysconfBackup"
	mkdir $BKPDIR/$BKPPREFIX-sys-tmp
	divvy -P -N > $BKPDIR/$BKPPREFIX-sys-tmp/divvy.txt
	runPipe tar -clAf - $BKPDIR/$BKPPREFIX-sys-tmp \| $ZIPPER > $BKPDIR/$BKPPREFIX-sys.tar.$BKPSUFF
	for i in $pipestatus_1 $pipestatus_2 $pipestatus_3 ; do
		if [[ $i -ne 0 ]]; then
			log "--- ERROR: Something went wrong creating the system configuration backup!"
		fi
	done
	rm -Rf $BKPDIR/$BKPPREFIX-sys-tmp
	log "-- END sysconfBackup"
}

backupCheck() {
	trap 'trapErrors backupCheck $LINENO' ERR
	log "-- START backupCheck"
	set -A dbtars $(find $BKPDIR -name $BKPPREFIX\*.tar.$BKPSUFF.\* -type f)
	set -A misctars $(find $BKPDIR -name $BKPPREFIX\*.tar.$BKPSUFF -type f)
	errpipe=/tmp/${0##*/}.errpipe.$$
	if [[ -n ${dbtars} ]]; then
		cat ${dbtars[@]} | $UNZIPPER 2>>$errpipe | tar -tf - 2>>$errpipe 1>/dev/null
		if [[ -s $errpipe ]]; then
			log "--- ERROR: The DB backup [ ${dbtars[@]} ] could not be verified. Please check manually!"
			((ERRORCOUNT+=1))
			rm -f $errpipe
			return 1
		fi
		rm -f $errpipe
	else
		log "--- ERROR: Couldn't find any DB backup to verify."
		((ERRORCOUNT+=1))
		return 1
	fi
	if [[ -n ${misctars[@]} ]]; then
		for i in ${misctars[@]}; do
			runPipe cat $i \| $UNZIPPER \| tar -tf - > /dev/null
			for j in $pipestatus_1 $pipestatus_2 $pipestatus_3 ; do
				if [[ $j -ne 0 ]]; then
					log "--- ERROR: $i could not be verified. Please check manually!"
					((ERRORCOUNT+=1))
					return 1
				fi
			done
		done
	else
		log "--- ERROR: Couldn't find any other backup to verify."
		((ERRORCOUNT+=1))
		return 1
	fi
	log "-- END backupCheck"
}

createMD5SUMS() {
	trap 'trapErrors createMD5SUMS $LINENO' ERR
	log "-- START createMD5SUMS"
	typeset -l MD5TMP
	find $BKPDIR -name $BKPPREFIX\* -type f | while read line; do
		MD5TMP=$(md5 $line)
		printf "$MD5TMP *$(basename $line)\n" >> $BKPDIR/MD5SUMS
	done
	xtod $BKPDIR/MD5SUMS > $BKPDIR/MD5SUMS.md5
	log "-- END createMD5SUMS"
}

addLockFile() {
	trap 'trapErrors addLockFile $LINENO' ERR
	log "-- START addLockFile"
	if [ -e "$1" ]; then
		log "-- NOTICE: Lockfile ($LOCKFILE) exists before running. Probably something went wrong last time."
		# Lockfile exists - ensure that it's readable
		[ -r "$1" ] || { log "-- ERROR: Lockfile ($LOCKFILE) is not readable."; ((ERRORCOUNT+=1)); exit 1; }
		# Ensure that process that created lockfile is no longer running
		kill -0 $(cat "$1") 2>/dev/null && { log "ERROR: An instance of this script is already running. Bye!"; ((ERRORCOUNT+=1)); exit 1; }
		# Delete lockfile
		rm -f "$1" || { log "-- ERROR: Failed to delete lockfile ($LOCKFILE)."; ((ERRORCOUNT+=1)); exit 1; }
	fi

	# Create lockfile
	echo $$ >"$1" || { log "-- ERROR: Failed to create lockfile ($LOCKFILE). "; ((ERRORCOUNT+=1)); exit 1; }
	log "-- END addLockFile"
}

removeLockFile() {
	trap 'trapErrors removeLockFile $LINENO' ERR
	log "-- START removeLockFile"
	rm -f "$1" || { log "-- ERROR: Failed to delete lockfile ($LOCKFILE)."; ((ERRORCOUNT+=1)); exit 1; }
	log "-- END removeLockFile"
}

pingTest() {
	trap 'trapErrors pingTest $LINENO' ERR
	log "-- START pingTest"
	ping -c3 $FTPSERVER >/dev/null 2>/dev/null || { log "-- NOTICE: FTP server $FTPSERVER is not responding to pings. Maybe host is down?"; }
	log "-- END pingTest"
}

ftpTest() {
	trap 'trapErrors ftpTest $LINENO' ERR
	log "-- START ftpTest"
	FTPCTL=/tmp/backupsas-ftpTest.pid
	if [[ -e $FTPCTL ]]; then
		rm -f $FTPCTL
	fi
	echo $$ > $FTPCTL
	set -A FTPCMDS "open $FTPSERVER\n"
	set -A FTPCMDS "${FTPCMDS[@]}" "user $FTPUSER $FTPASSWD\n"
	set -A FTPCMDS "${FTPCMDS[@]}" "binary\n"
	set -A FTPCMDS "${FTPCMDS[@]}" "put $FTPCTL $(basename $FTPCTL)\n"
	set -A FTPCMDS "${FTPCMDS[@]}" "!rm -f $FTPCTL\n"
	set -A FTPCMDS "${FTPCMDS[@]}" "get $(basename $FTPCTL) $FTPCTL\n"
	set -A FTPCMDS "${FTPCMDS[@]}" "del $(basename $FTPCTL)\n"
	set -A FTPCMDS "${FTPCMDS[@]}" "bye\n"
	FTPRESULT=$(echo ${FTPCMDS[@]} | ftp -niv 2>/dev/null | grep -E '(^4..|^5..)' | wc -l )
	if [[ $FTPRESULT -ne 0 || $(cat $FTPCTL) -ne $$ ]]; then
		log "-- ERROR: Could not test FTP server $FTPSERVER"
		log "-- ERROR: Possible errors include FTP user problems (non existent or wrong password) or server side permissions."
		rm -f $FTPCTL
		((ERRORCOUNT+=1))
		return 1
	fi
	rm -f $FTPCTL
	log "-- END ftpTest"
}

ftpTransfer() {
	trap 'trapErrors ftpTransfer $LINENO' ERR
	log "-- START ftpTransfer"
	set -A FTPOBJS $(ls $BKPDIR)
	set -A FTPCMDS "open $FTPSERVER\n"
	set -A FTPCMDS "${FTPCMDS[@]}" "user $FTPUSER $FTPASSWD\n"
	set -A FTPCMDS "${FTPCMDS[@]}" "binary\n"
	set -A FTPCMDS "${FTPCMDS[@]}" "mdel *\n"
	set -A FTPCMDS "${FTPCMDS[@]}" "lcd $BKPDIR\n"
	for i in ${FTPOBJS[@]}; do set -A FTPCMDS "${FTPCMDS[@]}" "put $i\n"; done
	set -A FTPCMDS "${FTPCMDS[@]}" "bye\n"
	FTPRESULT=$(echo ${FTPCMDS[@]} | ftp -niv 2>/dev/null | grep -E '(^4..|^5..)' | wc -l )
	if [[ $FTPRESULT -ne 0 ]]; then
		log "-- ERROR: Something happened while transferring files through FTP. Please check manually!"
		((ERRORCOUNT+=1))
		return 1
	fi
	log "-- END ftpTransfer"
}
