-- put former exec commands outside the func and former exec-once commands inside
hl.on("hyprland.start", function()
    -- Input method framework (rime / 雾凇拼音 runs inside it)
    hl.exec_cmd("fcitx5 -d --replace")

    -- Cursor: overrides the dots' default Bibata setcursor in hyprland/execs.lua
    hl.exec_cmd("hyprctl setcursor McMojave-cursors 40")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-theme McMojave-cursors")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface cursor-size 40")

end)
