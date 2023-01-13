#!/bin/bash

musakansio="/home/crux/spotirec/"
abitrate="192"

control_c() {
        killall -q arecord lame
        exit 0
}

trap control_c SIGINT
trap control_c SIGTERM

cd "$musakansio"
echo "" > .sp

while true
do

        currsong="`xwininfo -root -tree|grep -o "Spotify - .*:" |sed 's/Spotify - //' |sed 's/\"://' |sed 's/ /_/g'`"
        filesong="`cat .sp`"

        if [[ "$currsong" != "$filesong" && "$currsong" != "" ]]; then
                tempsong="`echo $currsong |sed 's/–/-/g'`"
                if [ ! -f "$tempsong.mp3" ]; then
                        artist="`echo $tempsong |cut -d '-' -f1 |sed 's/_/ /g'`"
                        song="`echo $tempsong |cut -d '-' -f2- |sed 's/_/ /g' |sed 's/ //'`"
                        killall -q arecord
                        echo "$currsong" > .sp
                        echo -ne "                                                                                                                                           \r"
                        echo -ne "Recording $currsong \r"
                        echo "$tempsong" >> "$musakansio/biisit.txt"
                        arecord -q -f dat | lame --quiet --ta "$artist" --tt "$song" -m j -V 4 -q 3 --lowpass 17 --abr "$abitrate" - "$tempsong.mp3" > /dev/null &1>/dev/null
                fi
        fi

        sleep 0.5

done

#gst-launch-1.0 pulsesrc device=$(pactl list | egrep -A2 '^(\*\*\* )?Source #'|grep 'Name: .*\.monitor$'| cut -d" " -f2 | tail -n1) ! queue ! audio/x-raw,format=S16LE,rate=44100,channels=2 ! audioconvert ! lamemp3enc target=quality quality=2 ! filesink location=dump.mp3
