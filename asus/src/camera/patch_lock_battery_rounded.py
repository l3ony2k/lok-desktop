#!/usr/bin/env python3
"""Lock screen battery icon: Material Symbols Rounded (ASUS 2026-11-09).
The global icon font is Material Symbols Sharp (fonts-and-icons, 2026-11-05), which
draws battery_android_full as a hard rectangle. Only this icon goes back to Rounded.
Idempotent; patches the installed copy and the private repo copy."""
import pathlib
home = pathlib.Path.home()
for p in [home/".config/quickshell/ii/modules/ii/lock/LockSurface.qml",
          home/"dots-hyprland/dots/.config/quickshell/ii/modules/ii/lock/LockSurface.qml"]:
    s = p.read_text()
    if "iconFamily" in s:
        print("already", p); continue
    pairs = [
        ("        property color color: Appearance.colors.colOnSurfaceVariant\n\n        spacing: 4\n",
         "        property color color: Appearance.colors.colOnSurfaceVariant\n"
         "        // ASUS 2026-11-09: per-icon font override (battery uses Rounded; global icons are Sharp)\n"
         "        property string iconFamily: Appearance.font.family.iconMaterial\n\n        spacing: 4\n"),
        ("            text: pair.icon\n            iconSize: Appearance.font.pixelSize.huge\n",
         "            text: pair.icon\n            font.family: pair.iconFamily\n            iconSize: Appearance.font.pixelSize.huge\n"),
        ("            icon: Battery.isCharging ? \"bolt\" : \"battery_android_full\"\n",
         "            icon: Battery.isCharging ? \"bolt\" : \"battery_android_full\"\n"
         "            iconFamily: \"Material Symbols Rounded\"\n"),
    ]
    for old, new in pairs:
        if s.count(old) != 1:
            raise SystemExit(f"{p}: pattern not found:\n{old}")
        s = s.replace(old, new)
    p.write_text(s); print("patched", p)
