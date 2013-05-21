#!/bin/bash

# multi-region-RDS.sh is a utility for temporarily dumping a MySQL database from
# an RDS instance and reloading it in a different one to enable a warm stand-by
# instance in a different region.
#
# - It drops destination DBs before recreating them.
# - It can ignore specified tables, which would be replicated in structure but
#   without data.
# - Source and destination DBs (with the correspondig connection string) have to
#   be defined in "paired arrays".
#
# Copyright (C) 2012 Sebastian Cruz <default50@gmail.com>
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

SILENT="yes"
#SILENT="no"
WORKDIR=/tmp/${0##*/}.temp.$$
CONFIG="$HOME/.multi-region-RDS.rc"
DUMP_OPTS="--single-transaction --compress --add-drop-database --routines"

# Create WORKDIR if not present or not a directory
if [ ! -e $WORKDIR ]; then
        mkdir $WORKDIR
else
        echo "ERROR: $WORKDIR already exists. Aborting."
        exit 1
fi

if [ -f "$CONFIG" ]; then
        if [ ! -O "$CONFIG" -o ! "$(stat -c %a $CONFIG)" -eq "600" ]; then
                echo "ERROR: $CONFIG is not owned by $USER or its permissions are not 600. Aborting."
                exit 1
        else
                . $CONFIG
        fi
else
        echo "ERROR: $CONFIG file does not exist. Aborting."
        exit 1
fi

# Check if at least we have the same amount of sources and destinations
if [ "${#dbs_src[@]}" -ne "${#dbs_dst[@]}" ]; then
        echo "ERROR: Source and destination DBs not paired. Aborting."
        exit 1
fi

# Declare array to store references to the dump files in the order they were created
declare -a dbs_tmp=()

# Function to dump the DB.
dumpDB () {
        eval "declare -A db="${1#*=}
        local -a ignore=()
        local index
        # Check if we have some tables we should ignore
        for index in "${!db[@]}"; do
                if [ "$index" == "ignore" ]; then
                        for i in ${db[$index]}; do
                                ignore=("${ignore[@]}" "--ignore-table=${db[name]}.$i")
                        done
                fi
        done
        # Dump, ignoring if necessary
        mysqldump -h ${db[host]} -u ${db[user]} -p${db[pass]} $DUMP_OPTS ${ignore[@]} --databases ${db[name]} | gzip > $WORKDIR/${db[name]}.gz
        # If we ignored something add it to the dump but without data
        if [ ${#ignore[@]} -gt 0 ]; then
                mysqldump -h ${db[host]} -u ${db[user]} -p${db[pass]} $DUMP_OPTS --no-data ${db[name]} --tables ${db[ignore]} | gzip >> $WORKDIR/${db[name]}.gz
        fi
        # Save generated dump filename for reloading it afterwards
        dbs_tmp=("${dbs_tmp[@]}" "$WORKDIR/${db[name]}.gz")
}

# Function to reload the DB
reloadDB () {
        eval "declare -A db="${1#*=}
        # Reload the dump passed as argument
        zcat ${dbs_tmp[$2]} | mysql -h ${db[host]} -u ${db[user]} -p${db[pass]} --compress
}

# Iterate dumping and reloading each pair of instances
element_count=${#dbs_src[@]}
index=0
while [ "$index" -lt "$element_count" ]; do
        [ $SILENT != "yes" ] && echo -n "Starting dump of "$(eval echo '${'"${dbs_src[index]}"'[name]}')" at "$(date +%Y%m%d-%H%M%S)
        dumpDB "$(declare -p ${dbs_src[index]})"
        [ $SILENT != "yes" ] && echo " -> Done at "$(date +%Y%m%d-%H%M%S)". Dump size: "$(du -h ${dbs_tmp[index]} | cut -f1)
        [ $SILENT != "yes" ] && echo -n "Starting reload of "$(eval echo '${'"${dbs_src[index]}"'[name]}')" at "$(date +%Y%m%d-%H%M%S)
        reloadDB "$(declare -p ${dbs_dst[index]})" "$index"
        [ $SILENT != "yes" ] && echo " -> Done at "$(date +%Y%m%d-%H%M%S)"."
        ((index++))
done

# Clean up WORKDIR
rm -Rf $WORKDIR
