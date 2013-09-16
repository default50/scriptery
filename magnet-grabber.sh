#!/bin/sh

RTGUI_URL="http://macumba.macumba-net.com.ar/rtgui/control.php"
POST_URL="$RTGUI_URL/control.php"

/usr/bin/curl $POST_URL --data "addurl=${1}"
/usr/bin/firefox -new-tab $RTGUI_URL
