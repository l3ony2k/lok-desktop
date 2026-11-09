#!/usr/bin/env python3
"""Quickshell Audio.qml: 3 s grace after the default sink object changes (ASUS 2026-11-09).

Why: on a WirePlumber restart (camera privacy toggle, recovery) the sink node is
recreated; its volume reads 0 for a moment, then WirePlumber restores the saved
value. The earbang protection (maxAllowedIncrease 10 %) saw 0 -> 0.6 as an
"Illegal increment", forced 0, and WirePlumber then saved 0. Same cause as the
"speaker volume reset to 0 after a wireplumber restart" seen on 2026-11-08.
Fix: when the sink changes, accept every volume change for 3 s. Idempotent.
"""
import pathlib
home = pathlib.Path.home()
MARK = "sink-change grace"
for p in [home/".config/quickshell/ii/services/Audio.qml",
          home/"dots-hyprland/dots/.config/quickshell/ii/services/Audio.qml"]:
    if not p.exists():
        print("missing", p); continue
    s = p.read_text()
    if MARK in s:
        print("already patched", p); continue
    old1 = ("        property bool lastReady: false\n"
            "        property real lastVolume: 0\n")
    new1 = ("        property bool lastReady: false\n"
            "        property real lastVolume: 0\n"
            "        // ASUS 2026-11-09 sink-change grace: a recreated sink (WirePlumber restart,\n"
            "        // device switch) first reads 0, then gets its saved volume restored; do not\n"
            "        // treat that restore as an illegal increment.\n"
            "        property real graceUntil: 0\n"
            "        function onTargetChanged() {\n"
            "            lastReady = false;\n"
            "            graceUntil = Date.now() + 3000;\n"
            "        }\n")
    old2 = ("            if (!lastReady) {\n"
            "                lastVolume = newVolume;\n"
            "                lastReady = true;\n"
            "                return;\n"
            "            }\n")
    new2 = ("            if (!lastReady || Date.now() < graceUntil) {\n"
            "                lastVolume = newVolume;\n"
            "                lastReady = true;\n"
            "                return;\n"
            "            }\n")
    for old, new in ((old1, new1), (old2, new2)):
        if s.count(old) != 1:
            raise SystemExit(f"{p}: pattern not found:\n{old}")
        s = s.replace(old, new)
    p.write_text(s); print("patched", p)
