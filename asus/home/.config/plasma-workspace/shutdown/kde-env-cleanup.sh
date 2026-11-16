#!/bin/sh
# Run by Plasma at logout (~/.config/plasma-workspace/shutdown/). Added 2026-11-12.
# Remove Plasma-only variables from the lingering systemd --user manager so they
# do not leak into the next Hyprland session.
systemctl --user unset-environment KDE_FULL_SESSION KDE_SESSION_UID KDE_SESSION_VERSION \
  KDE_APPLICATIONS_AS_SCOPE SESSION_MANAGER ICEAUTHORITY XDG_MENU_PREFIX \
  QT_WAYLAND_RECONNECT 2>/dev/null
exit 0
