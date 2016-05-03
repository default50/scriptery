#!/bin/bash

# Providing an IP address, a network and the CIDR prefix, define if the IP belongs to the range.
# $1 = IP (e.g. 10.0.0.8)
# $2 = Network IP (e.g. 10.0.0.0)
# $3 = CIDR prefix (e.g. 24)

#set -x

# Function to print binary representation of decimal using bc, bash can't do it alone
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

# Function to convert an octect into binary
d2b=({0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1}{0..1})

# Obtain binary representation of IP and network
bip=$(printf '%s%s%s%s\n' "${d2b[$i1]}" "${d2b[$i2]}" "${d2b[$i3]}" "${d2b[$i4]}")
bnet=$(printf '%s%s%s%s\n' "${d2b[$n1]}" "${d2b[$n2]}" "${d2b[$n3]}" "${d2b[$n4]}")

printf 'Network\t%s\n' $(binprint $((2#$bnet)))
printf 'Mask\t%s\n' $(binprint $mask)
printf 'IP\t%s\n' $(binprint $((2#$bip)))

# Obtain decimal representation of IP, network and mask to be able to make binary operations
dip=$((2#$bip))
dnet=$((2#$bnet))

# Obtain network address by &ing with the mask
mip=$((dip & mask))
mnet=$((dnet & mask))

# Check that network portions match after masking
if [ ${mip} != ${mnet} ]; then
  printf "\n\nIP does NOT belong! (The network part is different)"
  exit 1
else 
  printf "\n\nIP is part of network! (The network part matches)"
  exit 0
fi
