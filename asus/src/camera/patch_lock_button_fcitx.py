#!/usr/bin/env python3
"""Lock screen polish (ASUS 2026-11-09). Idempotent.
1. Unlock (confirm) button: disable the RippleButton background layer (+OpacityMask), whose mask
   edge is jagged at the 1.333 scale; the background Rectangle (radius clamped to height/2) is
   antialiased by itself. Ripple made transparent (it would no longer be clipped to the circle).
2. Hide the Fcitx tray icon on the lock screen (its own "A" image sits ~1.5 px low in the circle;
   the xkb layout code "us" stays)."""
import pathlib
home = pathlib.Path.home()
for p in [home/".config/quickshell/ii/modules/ii/lock/LockSurface.qml",
          home/"dots-hyprland/dots/.config/quickshell/ii/modules/ii/lock/LockSurface.qml"]:
    s = p.read_text()
    if "ASUS smooth confirm" in s:
        print("already", p); continue
    pairs = [
        ("            colBackgroundToggled: Appearance.colors.colPrimary\n\n            onClicked: root.context.tryUnlock()\n",
         "            colBackgroundToggled: Appearance.colors.colPrimary\n"
         "            // ASUS smooth confirm (2026-11-09): the RippleButton background goes through a\n"
         "            // layer + OpacityMask whose edge is jagged at the 1.333 scale. Without the layer the\n"
         "            // background Rectangle (radius clamped to height/2) is an antialiased circle.\n"
         "            // The ripple would no longer be clipped, so it is made transparent here.\n"
         "            rippleColor: \"transparent\"\n"
         "            Component.onCompleted: background.layer.enabled = false\n"
         "\n            onClicked: root.context.tryUnlock()\n"),
        ("            pinnedItems: SystemTray.items.values.filter(i => i.id == \"Fcitx\")\n            visible: pinnedItems.length > 0\n",
         "            pinnedItems: SystemTray.items.values.filter(i => i.id == \"Fcitx\")\n"
         "            // ASUS 2026-11-09: hidden on the lock screen (user); the Fcitx \"A\" image is off-centre.\n"
         "            visible: false\n"),
    ]
    for old, new in pairs:
        if s.count(old) != 1:
            raise SystemExit(f"{p}: pattern not found:\n{old}")
        s = s.replace(old, new)
    p.write_text(s); print("patched", p)
