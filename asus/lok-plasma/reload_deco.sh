#!/bin/bash
# Force KWin to reload the lok Aurorae decoration (it caches the SVG while the theme name is unchanged)
export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
cur=$(kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme)
set_deco(){ for g in org.kde.kdecoration2 org.kde.kdecoration3; do kwriteconfig6 --file kwinrc --group $g --key library "$1"; kwriteconfig6 --file kwinrc --group $g --key theme "$2"; done; qdbus6 org.kde.KWin /KWin reconfigure; }
set_deco org.kde.breeze Breeze; sleep 1
set_deco org.kde.kwin.aurorae "$cur"; sleep 1.5
