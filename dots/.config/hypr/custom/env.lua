-- Input method: fcitx5 + rime (雾凇拼音)
-- Wayland-native apps (GTK3/4, Qt) use the text-input protocol instead, so
-- GTK_IM_MODULE is intentionally left unset (see ArchWiki Fcitx5#Wayland).
hl.env("XMODIFIERS", "@im=fcitx")
hl.env("QT_IM_MODULE", "fcitx")
hl.env("SDL_IM_MODULE", "fcitx")
-- Qt6.7+ picks the best available module; falls back to fcitx for Qt5 apps.
hl.env("QT_IM_MODULES", "wayland;fcitx")

-- Cursor: McMojave (installed user-local in ~/.local/share/icons, xcursor format)
hl.env("XCURSOR_THEME", "McMojave-cursors")
hl.env("XCURSOR_SIZE", "40") -- x1.333 = 53.3 -> the nominal-54 frames (72 px) added 2026-11-15; 45 -> 60 (80 px)

-- XDG home tidy (asus, 2026-11-24): CARGO_HOME, NVM_DIR, ... from the same file that
-- systemd --user and zsh read, so apps started from Hyprland (magpie looks up node via
-- NVM_DIR) see the same locations.
do
    local home = os.getenv("HOME")
    local f = io.open(home .. "/.config/environment.d/50-xdg-home.conf")
    if f then
        for line in f:lines() do
            local k, v = line:match("^([A-Z_][A-Z0-9_]*)=(.*)$")
            if k then hl.env(k, (v:gsub("%${HOME}", function() return home end))) end
        end
        f:close()
    end
end
