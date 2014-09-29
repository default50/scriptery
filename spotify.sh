#!/bin/sh

/usr/bin/spotify >/dev/null 2>&1 &
SPOTIFY_PID=$!
/usr/local/bin/blockify -l /tmp/blockify.log -vvv >/dev/null 2>&1 &
BLOCKIFY_PID=$!

wait $SPOTIFY_PID
/bin/kill -15 $BLOCKIFY_PID
