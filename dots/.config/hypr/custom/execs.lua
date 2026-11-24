-- put former exec commands outside the func and former exec-once commands inside
hl.on("hyprland.start", function()
    -- Magpie: tray at login. Its own "autostart" only writes an XDG .desktop,
    -- which this Hyprland/UWSM session never runs (xdg-desktop-autostart.target
    -- is not pulled in), so start it here instead.
    hl.exec_cmd("magpie tray")

    -- Input method framework (rime / 雾凇拼音 runs inside it)
    hl.exec_cmd("fcitx5 -d --replace")

    -- Cursor: overrides the dots' default Bibata setcursor in hyprland/execs.lua
    hl.exec_cmd("hyprctl setcursor McMojave-cursors 40")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme McMojave-cursors")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size 40")

end)
