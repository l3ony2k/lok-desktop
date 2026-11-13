#!/bin/bash
# Regenerate the lok Plasma theme and reload it (clears KSvg caches, restarts plasmashell)
export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus
python3 ~/.local/share/lok-plasma/make_lok_plasma_theme.py
rm -rf ~/.cache/plasma_theme_*.kcache ~/.cache/ksvg-elements* 2>/dev/null
systemctl --user restart plasma-plasmashell.service
sleep 5
