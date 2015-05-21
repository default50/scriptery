#!/usr/bin/env python
import dbus
from dbus.mainloop.glib import DBusGMainLoop
import subprocess
from gi.repository import TelepathyGLib as Tp
from gi.repository.GObject import MainLoop

class Away:
    def __init__(self):
        DBusGMainLoop(set_as_default=True)
        self.mem='ActiveChanged'
        self.dest='org.gnome.ScreenSaver'
        self.bus=dbus.SessionBus()
        self.loop=MainLoop()
        self.bus.add_signal_receiver(self.catch,self.mem,self.dest)

    def catch(self,away):
        am = Tp.AccountManager.dup()
        proxy_new = self.bus.get_object("org.mpris.MediaPlayer2.spotify", "/org/mpris/MediaPlayer2")
        event_manager = dbus.Interface(proxy_new, 'org.mpris.MediaPlayer2.Player')
        properties_manager = dbus.Interface(proxy_new, 'org.freedesktop.DBus.Properties')
        if away == 1: #Screensaver turned on
            print "Screen saver turned ON"
            event_manager.PlayPause()
            subprocess.call("xchat -e -c AWAY", shell=True)
            am.set_all_requested_presences(Tp.ConnectionPresenceType.OFFLINE, 'Offline', "")
        else: #Screensaver turned off
            subprocess.call("xchat -e -c BACK", shell=True)
            event_manager.PlayPause()
            am.set_all_requested_presences(Tp.ConnectionPresenceType.AVAILABLE, 'Available', "")
            print "Screen saver turned OFF"

Away().loop.run()
