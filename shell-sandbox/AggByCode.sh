#!/bin/bash

# Given an input file full of these:
# 10.0.83.3 - - [31/Oct/1994:14:00:00 +0000] "GET /finance/call.php?key=CigwAY-qQe HTTP/1.1" 404 431
# Obtain the amount of bytes per IP and per return code

#set -x

# If less than 2 parameters were given exit
[ ${#} -lt 2 ] && printf '%sERROR: Parameter missing!' && exit 1

# Pure awk magic
# -v OFS='\t' « Set output separator to tabs
# -v code="${2}" « Pass shell variable $2 into awk's 'code' variable
# '$9~ code « Filter every line with provided code
# {a[$1]; b[$1]+=$10} « Create an associative array based on field $1 (IP) and aggregate field $10
# END { for (i in a) print i, b[i] }' Print the IP and the corresponding counter on END block
# "${1}" | sort -nr -k2 | head « Anyone should be able to know what this does :)

awk -v OFS='\t' -v code="${2}" '$9~ code {a[$1]; b[$1]+=$10} END { for (i in a) print i, b[i] }' "${1}" | sort -nr -k2 | head
