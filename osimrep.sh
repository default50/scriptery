#!/bin/bash

set -e

if [ ! $# == 2 ]; then
	echo "Uso: $0 <filepermissions> <dirpermission>"
	exit
fi

find ./ -type f -exec chmod $1 "{}" \;
find ./ -type d -exec chmod $2 "{}" \;
