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
hl.env("XCURSOR_SIZE", "32")
