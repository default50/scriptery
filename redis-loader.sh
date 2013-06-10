#!/bin/bash

# redis-loader.sh is a utility for loading compressed files into a redis server
# using on-the-fly decompression.
# 
# This script depends on lnp2redis.rb being in the same path.
#
# Copyright (C) 2013 Sebastian Cruz <default50@gmail.com>
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

#set -x

# Run it in concole like this:
# ruby redis_migration.rb ../0000000-9999999.27-05-2013043500.00-00-0000000000.99-99-9999999999 | redis-cli --pipe
WORKDIR=/tmp/${0##*/}.temp.$$
FIFO=$WORKDIR/redis-loader.fifo
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LNP2REDIS=$DIR/lnp2redis.rb

# Create WORKDIR and FIFO if not present
if [ ! -e $WORKDIR ]; then
	mkdir $WORKDIR
	mkfifo $FIFO
else
	echo "ERROR: $WORKDIR already exists. Aborting."
	exit 1
fi

# Create WORKDIR and FIFO if not present
if [ ! -x $LNP2REDIS ]; then
	echo "ERROR: Could not find lnp2redis.rb in the same directory. Aborting."
	exit 1
fi

# Copy every argument into our own array
declare -a argv=${@}
# Iterate over each element
for i in ${argv[@]}; do
	# Try to read from the $FIFO and inject it into redis, it'll block reading as it's empty
	# but go to the background so the job can continue
	$LNP2REDIS $FIFO | redis-cli --pipe &
	# Feed the $FIFO with uncompressed data
	gzip -d -c $i > $FIFO
done

# Clean up WORKDIR
rm -Rf $WORKDIR
