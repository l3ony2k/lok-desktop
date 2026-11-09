#!/usr/bin/env python3
"""Fix the sink-change grace (v1 used onTargetChanged inside Connections, which
handles the TARGET's signal, so it never fired). v2 detects a new sink by its
PipeWire id inside onVolumeChanged. Idempotent; works on v1-patched files."""
import pathlib
home = pathlib.Path.home()
for p in [home/".config/quickshell/ii/services/Audio.qml",
          home/"dots-hyprland/dots/.config/quickshell/ii/services/Audio.qml"]:
    s = p.read_text()
    if "lastSinkId" in s:
        print("already v2", p); continue
    old_v1 = ("        property real graceUntil: 0\n"
              "        function onTargetChanged() {\n"
              "            lastReady = false;\n"
              "            graceUntil = Date.now() + 3000;\n"
              "        }\n")
    new_v2 = ("        property real graceUntil: 0\n"
              "        property int lastSinkId: -1\n")
    old_chk = ("            if (!lastReady || Date.now() < graceUntil) {\n")
    new_chk = ("            const sinkId = sink?.id ?? -1;\n"
               "            if (sinkId !== lastSinkId) {\n"
               "                lastSinkId = sinkId;\n"
               "                graceUntil = Date.now() + 3000;\n"
               "            }\n"
               "            if (!lastReady || Date.now() < graceUntil) {\n")
    for old, new in ((old_v1, new_v2), (old_chk, new_chk)):
        if s.count(old) != 1:
            raise SystemExit(f"{p}: pattern not found:\n{old}")
        s = s.replace(old, new)
    p.write_text(s); print("patched v2", p)
