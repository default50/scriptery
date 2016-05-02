#!/bin/bash

#set -x

function reverse() {
  str="${1}"
  len=${#str}
  
  while [ $len -ge 0 ]; do
    rstr="${rstr}${str:$len:1}"
    len=$((len-1))
  done
  
  printf '%s\n' "${rstr}"
}

while IFS= read -r line; do
  reverse "${line}"
done < <(cat "${@}")
