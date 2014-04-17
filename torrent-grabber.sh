#!/bin/sh

CREDENTIALS="myuser:mypass"
RTGUI_URL="http://macumba.macumba-net.com.ar/rtgui/control.php"
POST_URL="$RTGUI_URL/control.php"

/usr/bin/curl --digest -u "${CREDENTIALS}" $POST_URL -F "uploadtorrent=@${1}"
/usr/bin/firefox -new-tab $RTGUI_URL
