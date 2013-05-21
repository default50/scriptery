#!/bin/bash

# Script to play a sound and pop up system notifications on Linux when a certain regex matches a message's content.

# Make regex case insensitive
shopt -s nocasematch

REGEX=".*(crux|seba.*|rati).*"
PLAYER="paplay"
SOUND="/usr/share/sounds/freedesktop/stereo/message.oga"

if [[ "${1}" =~ $REGEX ]]; then
	$PLAYER ${SOUND} &
	# This ↓ turned out to be too nagging
	#notify-send "Mentioned!" "$2 mentioned you." -i skype -t 15000
fi
