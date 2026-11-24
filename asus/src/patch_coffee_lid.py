#!/usr/bin/env python3
"""Coffee toggle also blocks lid sleep (2026-11-08).

1. Quickshell services/Idle.qml: while `inhibit` is on, run
   `systemd-inhibit --what=handle-lid-switch ... sleep infinity`, so logind
   does not suspend on lid close. The process (and the inhibitor) ends when the
   toggle goes off or Quickshell exits.
2. Hyprland custom/keybinds.lua: lid switch on/off -> ~/.local/bin/lid-coffee
   (locks + panel off while coffee is on; panel on when opened).
Patches the installed copies and the private dots repo copies. Idempotent.
"""
import pathlib

home = pathlib.Path.home()
MARK = "coffee-lid"


def patch(paths, pairs, append=None):
    for p in paths:
        if not p.exists():
            print("missing", p)
            continue
        s = p.read_text()
        if MARK in s:
            print("already patched", p)
            continue
        for old, new in pairs:
            if s.count(old) != 1:
                raise SystemExit(f"{p}: pattern not found exactly once:\n{old}")
            s = s.replace(old, new)
        if append:
            s = s.rstrip("\n") + "\n" + append
        p.write_text(s)
        print("patched", p)


idle = [
    home / ".config/quickshell/ii/services/Idle.qml",
    home / ".dotfiles/dots/.config/quickshell/ii/services/Idle.qml",
]
patch(idle, [
    ("import Quickshell.Wayland\n", "import Quickshell.Wayland\nimport Quickshell.Io\n"),
    (
        "    IdleInhibitor {\n",
        "    // ASUS coffee-lid (2026-11-08): while coffee is on, also stop logind from\n"
        "    // suspending on lid close. ~/.local/bin/lid-coffee then locks the session\n"
        "    // and turns the panel off instead. Ends with the toggle or with Quickshell.\n"
        "    Process {\n"
        "        id: lidInhibitor\n"
        "        running: root.inhibit\n"
        "        command: [\"systemd-inhibit\", \"--what=handle-lid-switch\",\n"
        "            \"--who=Quickshell coffee\", \"--why=Keep awake (coffee toggle)\",\n"
        "            \"--mode=block\", \"sleep\", \"infinity\"]\n"
        "    }\n"
        "\n"
        "    IdleInhibitor {\n",
    ),
])

keybinds = [
    home / ".config/hypr/custom/keybinds.lua",
    home / ".dotfiles/dots/.config/hypr/custom/keybinds.lua",
]
patch(keybinds, [], append=(
    "-- Lid (2026-11-08, coffee-lid): with the Quickshell coffee toggle on, logind\n"
    "-- does not suspend on lid close (Quickshell holds a handle-lid-switch\n"
    "-- inhibitor); lid-coffee locks the session and turns the panel off instead.\n"
    "-- With coffee off logind suspends as usual and lid-coffee does nothing on close.\n"
    "hl.bind(\"switch:on:Lid Switch\", hl.dsp.exec_cmd(\"~/.local/bin/lid-coffee close\"),\n"
    "    { locked = true, description = \"Lid closed: lock + panel off when coffee is on\" })\n"
    "hl.bind(\"switch:off:Lid Switch\", hl.dsp.exec_cmd(\"~/.local/bin/lid-coffee open\"),\n"
    "    { locked = true, description = \"Lid opened: panel on\" })\n"
))
