#!/usr/bin/env python
from dbus import SessionBus
from dbus.mainloop.glib import DBusGMainLoop
import subprocess
from gi.repository import TelepathyGLib as Tp
from gi.repository.GObject import MainLoop

class Away:
    def __init__(self):
        DBusGMainLoop(set_as_default=True)
        self.mem='ActiveChanged'
        self.dest='org.gnome.ScreenSaver'
        self.bus=SessionBus()
        self.loop=MainLoop()
        self.bus.add_signal_receiver(self.catch,self.mem,self.dest)
    def catch(self,away):
        am = Tp.AccountManager.dup()
        am.prepare_async(None, lambda *args: loop.quit(), None)
        if away == 1: #Screensaver turned on
            print "Screen saver turned ON"
            subprocess.call("dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.PlayPause", shell=True)
            subprocess.call("xchat -e -c AWAY", shell=True)
            am.set_all_requested_presences(Tp.ConnectionPresenceType.OFFLINE, 'Offline', "")
        else: #Screensaver turned off
            subprocess.call("xchat -e -c BACK", shell=True)
            subprocess.call("dbus-send --print-reply --dest=org.mpris.MediaPlayer2.spotify /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player.PlayPause", shell=True)
            am.set_all_requested_presences(Tp.ConnectionPresenceType.AVAILABLE, 'Available', "")
            print "Screen saver turned OFF"

Away().loop.run()
