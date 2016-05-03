#!/bin/bash

# Providing an IP address, a network and the CIDR prefix, define if the IP belongs to the range.
# $1 = IP (e.g. 10.0.0.8)
# $2 = Network IP (e.g. 10.0.0.0)
# $3 = CIDR prefix (e.g. 24)

#set -x

# Function to print binary representation of decimal using bc, bash would struggle with the method below for 32 bits
function binprint () {
  # 32 chars long string, padded with 0s
  printf '%032s\n' $(bc <<< "obase=2;$1")
}

# Assign each octet into variables
IFS=. read -r i1 i2 i3 i4 <<< "${1}"
IFS=. read -r n1 n2 n3 n4 <<< "${2}"

# Convert CIDR mask into binary form
# Bitshift to the left 32 - $3 (CIDR prefix)
# Then trim the longer shifted mask by &ing it with the full mask (32 bits)
mask=$((0xffffffff & (0xffffffff << (32 - ${3}))))

# Array filled with all binary numbers from 0 to 2^8 (255). Used brace expansion.
o2b=({0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1})

# Obtain binary representation as text of IP and network and save it in binary format
# Done by searching each decimal octet as the index of the binary array "o2b"
ip=$((2#$(printf '%s%s%s%s\n' "${o2b[$i1]}" "${o2b[$i2]}" "${o2b[$i3]}" "${o2b[$i4]}")))
net=$((2#$(printf '%s%s%s%s\n' "${o2b[$n1]}" "${o2b[$n2]}" "${o2b[$n3]}" "${o2b[$n4]}")))

printf 'Network\t%s\n' $(binprint $net)
printf 'Mask\t\t\t\t%s\n' $(binprint $mask)
printf 'IP\t\t\t\t%s\n' $(binprint $ip)

# Check that network portions match after masking
if [ $((ip & mask)) != $((net & mask)) ]; then
  printf "\n\nIP does NOT belong! (The network part is different)\n"
  exit 1
else 
  printf "\n\nIP is part of network! (The network part matches)\n"
  exit 0
fi
