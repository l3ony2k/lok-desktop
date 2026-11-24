-- User overrides (loaded after hyprland/variables.lua, so these win)
-- See hyprland/variables.lua for the full list of overridable variables.

-- brave-origin is not matched by the default list (it checks for "brave"),
-- so it must be named explicitly.
browser = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'brave-origin' 'brave' 'google-chrome-stable' 'zen-browser' 'firefox' 'chromium' 'microsoft-edge-stable' 'opera' 'librewolf'"

-- kitty stays the default; Ghostty is installed as a fallback.
terminal = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'kitty -1' 'ghostty' 'foot' 'alacritty' 'wezterm' 'konsole' 'kgx' 'uxterm' 'xterm'"

-- fish is not installed (asus 2026-11-24): the dots' last-resort fallbacks use zsh instead.
fileManager = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'dolphin' 'nautilus' 'nemo' 'thunar' 'kitty -1 zsh -ic yazi'"
taskManager = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'gnome-system-monitor' 'plasma-systemmonitor --page-name Processes' 'command -v btop && kitty -1 zsh -ic btop'"
