# Sourced by startplasma (~/.config/plasma-workspace/env/). Added 2026-11-12.
# The systemd --user manager lingers (Linger=yes), so variables imported by
# other sessions (ShojiWM: qt6ct, Bibata-Modern-Ice, GLFW_IM_MODULE=ibus;
# Hyprland: HYPRLAND_CMD ...) survive into Plasma and reach every service it
# starts (plasmashell itself ran with QT_QPA_PLATFORMTHEME=qt6ct). Drop them.
# XCURSOR_* are re-exported by startplasma from kcminputrc afterwards.
_foreign="QT_QPA_PLATFORMTHEME XCURSOR_THEME XCURSOR_SIZE GLFW_IM_MODULE HYPRLAND_CMD HYPRLAND_INSTANCE_SIGNATURE SHOJIWM_SOCKET"
systemctl --user unset-environment $_foreign 2>/dev/null
dbus-update-activation-environment QT_QPA_PLATFORMTHEME= 2>/dev/null
for _v in $_foreign; do unset "$_v"; done
unset _v _foreign
