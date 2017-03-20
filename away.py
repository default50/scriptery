#!/usr/bin/env python3
import dbus
from dbus.mainloop.glib import DBusGMainLoop
import subprocess
import psutil
from gi.repository.GObject import MainLoop


class Away:
    def __init__(self):
        DBusGMainLoop(set_as_default=True)
        self.mem = 'ActiveChanged'
        self.dest = 'org.gnome.ScreenSaver'
        self.bus = dbus.SessionBus()
        self.loop = MainLoop()
        self.bus.add_signal_receiver(self.catch, self.mem, self.dest)
        self.paused_before = False
        self.purple_prev = None

    def _is_running(self, name):
        processes = []
        for p in psutil.process_iter():
            try:
                if p.name() == name:
                    processes.append(p)
            except psutil.Error:
                pass
        if processes:
            return True
        else:
            return False

    def catch(self, away):
        # Check if Spotify is running and set dbus
        if self._is_running('spotify'):
            mpris_obj = self.bus.get_object(
                    'org.mpris.MediaPlayer2.spotify',
                    '/org/mpris/MediaPlayer2')
            mpris_manager = dbus.Interface(
                    mpris_obj, 'org.mpris.MediaPlayer2.Player')
            dbus_properties_manager = dbus.Interface(
                    mpris_obj, 'org.freedesktop.DBus.Properties')
            spotify_status = dbus_properties_manager.Get(
                    'org.mpris.MediaPlayer2.Player', 'PlaybackStatus')
        else:
            spotify_status = 'Not running'

        # Check if Pidgin is running and set dbus
        if self._is_running('pidgin.orig'):
            purple_obj = self.bus.get_object('im.pidgin.purple.PurpleService',
                                             '/im/pidgin/purple/PurpleObject')
            purple_manager = dbus.Interface(purple_obj,
                                            'im.pidgin.purple.PurpleInterface')
            purple_away = purple_manager.PurpleSavedstatusGetIdleaway()
            purple_current = purple_manager.PurpleSavedstatusGetCurrent()
            pidgin_status = 'Running'
        else:
            pidgin_status = 'Not running'

        if away == 1:  # Screensaver turned on
            print('INFO: Screen saver turned ON.')

            # Lock down Mac
            print('INFO: Locking down Mac.')
            subprocess.call(
                'ssh cruzseba-laptop.aka.amazon.com \'pmset displaysleepnow\'',
                shell=True)

            # Handle Spotify
            print('INFO: Spotify status: {}'.format(spotify_status))
            if spotify_status != 'Not running':
                if spotify_status == 'Playing':
                    self.paused_before = False
                    mpris_manager.PlayPause()
                else:
                    self.paused_before = True

            # Handle Hexchat
            if self._is_running('hexchat'):
                print('INFO: hexchat running, marking as AWAY')
                subprocess.call('hexchat -e -c AWAY', shell=True)

            # Handle Pidgin
            print('INFO: Pidgin status: {}'.format(pidgin_status))
            if pidgin_status != 'Not running':
                # STATUS_OFFLINE = 1
                # STATUS_AVAILABLE = 2
                # STATUS_UNAVAILABLE = 3
                # STATUS_INVISIBLE = 4
                # STATUS_AWAY = 5
                # STATUS_EXTENDED_AWAY = 6
                # STATUS_MOBILE = 7
                # STATUS_TUNE = 8
                # https://developer.pidgin.im/wiki/DbusHowto#CallingPidginmethods
                # Don't touch status when offline
                if purple_manager.PurpleSavedstatusGetType(
                        purple_current) >= 2:
                    self.purple_prev = purple_current
                    print('INFO: Pidgin status was: {}.'
                          ' Marking as AWAY'.format(self.purple_prev))
                    purple_manager.PurpleSavedstatusActivate(purple_away)
                else:
                    print('INFO: Pidgin status was: OFFLINE. '
                          'Not changing status.')

        else:  # Screensaver turned off
            print('INFO: Screen saver turned OFF.')

            # Handle Hexchat
            if self._is_running('hexchat'):
                print('INFO: hexchat running, marking as BACK')
                subprocess.call('hexchat -e -c BACK', shell=True)

            # Handle Spotify
            print('INFO: Spotify status: {}'.format(spotify_status))
            if spotify_status != 'Not running':
                if spotify_status == 'Paused' and not self.paused_before:
                    mpris_manager.PlayPause()

            # Handle Pidgin
            print('INFO: Pidgin status: {}'.format(pidgin_status))
            if pidgin_status != 'Not running':
                if self.purple_prev:
                    print('INFO: Pidgin status was: {}. Restoring {}'
                          .format(purple_current, self.purple_prev))
                    purple_manager.PurpleSavedstatusActivate(self.purple_prev)
                    self.purple_prev = None
                else:
                    print('INFO: Pidgin status was: OFFLINE. '
                          'Not changing status.')

            # Light up Mac's screen
            print('INFO: Lightning up Mac\'s screen.')
            subprocess.call(
                'ssh cruzseba-laptop.aka.amazon.com \'caffeinate -u -t 1\'',
                shell=True)


Away().loop.run()
