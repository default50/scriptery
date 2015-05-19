#!/usr/bin/env python
from gobject import MainLoop
from dbus import SessionBus
from dbus.mainloop.glib import DBusGMainLoop
import subprocess

class Away:
    def __init__(self):
        DBusGMainLoop(set_as_default=True)
        self.mem='ActiveChanged'
        self.dest='org.gnome.ScreenSaver'
        self.bus=SessionBus()
        self.loop=MainLoop()
        self.bus.add_signal_receiver(self.catch,self.mem,self.dest)
    def catch(self,away):
        if away == 1: #Screensaver turned on
            print "Screen saver turned ON"
            subprocess.call("dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.PlayPause", shell=True)
            subprocess.call("xchat -e -c AWAY", shell=True)
        else: #Screensaver turned off
            subprocess.call("xchat -e -c BACK", shell=True)
            subprocess.call("dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.PlayPause", shell=True)
            print "Screen saver turned OFF"

Away().loop.run()
