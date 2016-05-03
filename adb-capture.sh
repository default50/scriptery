# Do network capture of mobile traffic through ADB
# http://code.tutsplus.com/tutorials/analyzing-android-network-traffic--mobile-10663
adb kill-server
adb root
adb shell "tcpdump -n -s 0 -w - | nc -l -p 12345"
adb forward tcp:54321 tcp:12345
nc 127.0.0.1 54321 | wireshark -k -S -i -
