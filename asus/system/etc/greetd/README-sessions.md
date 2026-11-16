# Login sessions shown by tuigreet

tuigreet lists only the session files in `/etc/greetd/sessions/` (set with
`--sessions /etc/greetd/sessions` in `config.toml`), not everything packages drop
into `/usr/share/wayland-sessions/`. This hides `hyprland-uwsm.desktop`, which the
`hyprland` package always ships but which cannot start here (uwsm is not installed).

To add a session (e.g. after installing another desktop):

    sudo ln -s /usr/share/wayland-sessions/<name>.desktop /etc/greetd/sessions/

To remove one, delete its link. The links follow the package files, so updates of
Hyprland/Plasma are picked up automatically. A broken link (package removed) just
disappears from the list. No greetd restart is needed; the change shows the next
time the login screen appears. Do not restart greetd from inside a session: it
ends the session.

Added 2026-11-16 (ASUS ops log: entries/2026-11-16-greetd-session-list.md).
