##!/bin/bash
WAV="$1"
if [ -z "$WAV" ]; then
    echo "Usage: $0 OUTPUT.WAV" >&2
    exit 1
fi
rm -f "$WAV"
 
# Get sink monitor:
MONITOR=$(pactl list | egrep -A2 '^(\*\*\* )?Source #' | \
    grep 'Name: .*\.monitor$' | awk '{print $NF}' | tail -n1)
echo "set-source-mute ${MONITOR} false" | pacmd >/dev/null
 
# Record it raw, and convert to a wav
echo "Recording to $WAV ..."
echo "Close this window to stop"
#parec -d "$MONITOR" | sox -t raw -r 44k -sLb 16 -c 2 - "$WAV"
parec -d "$MONITOR" | sox -t raw -r 44100 -e signed-integer -Lb 16 -c 2 - "$WAV" silence 1 0.50 0.1% 1 2.0 0.1% : newfile : restart

#dbus-send --print-reply --session --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.freedesktop.DBus.Properties.Get string:'org.mpris.MediaPlayer2.Player' string:'Metadata'
