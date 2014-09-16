#!/bin/sh

# This script can be used by "open-with" Firefox's extension
# https://addons.mozilla.org/en-US/firefox/addon/open-with/
# You can use it play http://open.spotify.com/ URLs on the native player via DBUS interface

/usr/bin/dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.OpenUri string:${@%\?*}
