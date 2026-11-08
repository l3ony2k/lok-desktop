-- User overrides (loaded after hyprland/variables.lua, so these win)
-- See hyprland/variables.lua for the full list of overridable variables.

-- brave-origin is not matched by the default list (it checks for "brave"),
-- so it must be named explicitly.
browser = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'brave-origin' 'brave' 'google-chrome-stable' 'zen-browser' 'firefox' 'chromium' 'microsoft-edge-stable' 'opera' 'librewolf'"

-- kitty stays the default; Ghostty is installed as a fallback.
terminal = "~/.config/hypr/hyprland/scripts/launch_first_available.sh 'kitty -1' 'ghostty' 'foot' 'alacritty' 'wezterm' 'konsole' 'kgx' 'uxterm' 'xterm'"
