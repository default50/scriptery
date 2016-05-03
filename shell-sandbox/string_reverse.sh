#!/bin/bash

# Function for reversing a string, then call the function for each line of input
# Also accepts from STDIN
# E.gs:
# $ ./string_reverse.sh "How are you doing?"
# $ head -n2 apache-httpd.log | ./string_reverse.sh

#set -x

function reverse() {
  # Obtain length of string
  len=${#1}
  
  while [ $len -ge 0 ]; do
    # Substring expansion. Obtain 1 char from decreasing offset
    rstr="${rstr}${1:$len:1}"
    len=$((len-1))
  done
  
  printf '%s\n' "${rstr}"
  # Clear variable for further runs
  unset rstr
}

# Read line by line disabling separation of words (IFS=) and escape chars (-r)
while IFS= read -r line; do
  reverse "${line}"
# The input for the loop is STDIN if no parameters or the parameter
done <<< "$([ $# -eq 0 ] && cat "${@}" || echo "${1}")"
