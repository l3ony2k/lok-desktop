#!/usr/bin/env python3
# Silent fake MPRIS player for screenshots; exits after $1 seconds (default 600).
import sys
from gi.repository import Gio, GLib
XML = """<node><interface name="org.mpris.MediaPlayer2">
<property name="Identity" type="s" access="read"/><property name="CanQuit" type="b" access="read"/>
<property name="CanRaise" type="b" access="read"/><property name="HasTrackList" type="b" access="read"/>
<property name="DesktopEntry" type="s" access="read"/>
<method name="Raise"/><method name="Quit"/></interface>
<interface name="org.mpris.MediaPlayer2.Player">
<method name="PlayPause"/><method name="Play"/><method name="Pause"/><method name="Next"/><method name="Previous"/><method name="Stop"/>
<method name="Seek"><arg type="x" direction="in"/></method>
<method name="SetPosition"><arg type="o" direction="in"/><arg type="x" direction="in"/></method>
<property name="PlaybackStatus" type="s" access="read"/><property name="Metadata" type="a{sv}" access="read"/>
<property name="Position" type="x" access="read"/><property name="Volume" type="d" access="readwrite"/>
<property name="Rate" type="d" access="read"/>
<property name="CanPlay" type="b" access="read"/><property name="CanPause" type="b" access="read"/>
<property name="CanGoNext" type="b" access="read"/><property name="CanGoPrevious" type="b" access="read"/>
<property name="CanSeek" type="b" access="read"/><property name="CanControl" type="b" access="read"/>
</interface></node>"""
start = GLib.get_monotonic_time()
LEN = 214_000_000
def pos(): return min(LEN, 83_000_000 + (GLib.get_monotonic_time() - start))
meta = {"mpris:trackid": GLib.Variant("o", "/lokdemo/track/1"), "mpris:length": GLib.Variant("x", LEN),
        "xesam:title": GLib.Variant("s", "Hairline"), "xesam:artist": GLib.Variant("as", ["Square Corners"]),
        "xesam:album": GLib.Variant("s", "lok")}
P = {"Identity": GLib.Variant("s", "Music"), "CanQuit": GLib.Variant("b", True), "CanRaise": GLib.Variant("b", False),
     "HasTrackList": GLib.Variant("b", False), "DesktopEntry": GLib.Variant("s", "lokdemo"),
     "PlaybackStatus": GLib.Variant("s", "Playing"), "Metadata": GLib.Variant("a{sv}", meta), "Volume": GLib.Variant("d", 1.0),
     "Rate": GLib.Variant("d", 1.0), "CanPlay": GLib.Variant("b", True), "CanPause": GLib.Variant("b", True),
     "CanGoNext": GLib.Variant("b", True), "CanGoPrevious": GLib.Variant("b", True), "CanSeek": GLib.Variant("b", True),
     "CanControl": GLib.Variant("b", True)}
def get(conn, sender, path, iface, name):
    return GLib.Variant("x", pos()) if name == "Position" else P.get(name)
def call(conn, sender, path, iface, method, params, inv): inv.return_value(None)
node = Gio.DBusNodeInfo.new_for_xml(XML)
def acquired(conn, name):
    for i in node.interfaces: conn.register_object("/org/mpris/MediaPlayer2", i, call, get, None)
Gio.bus_own_name(Gio.BusType.SESSION, "org.mpris.MediaPlayer2.music", 0, acquired, None, None)
loop = GLib.MainLoop(); GLib.timeout_add_seconds(int(sys.argv[1]) if len(sys.argv) > 1 else 600, loop.quit); loop.run()
