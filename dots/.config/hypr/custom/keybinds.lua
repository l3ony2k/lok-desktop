-- User keybinds. Sourced after hyprland/keybinds.lua, so these can replace
-- the shipped behaviour without editing the dots themselves.

hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Edit user keybinds"} )

-- Chromebook F3 position is the fullscreen key (KEY_FULL_SCREEN / XF86FullScreen).
-- keyd leaves it untouched, so bind it here to the same toggle as the
-- four-finger pinch gesture. Super+zoom still emits Super+F3 for apps.
hl.bind("XF86FullScreen", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }),
    { description = "Window: Fullscreen (F3 key)", dont_inhibit = true })
-- dont_inhibit: F3 still toggles fullscreen while a VM viewer has grabbed the
-- keyboard (otherwise every key, F3 included, goes to the guest).

-- Chromebook F4 position is the overview/scale key (KEY_SCALE / XF86LaunchA).
-- Opens the full overview; Super-tap only opens the search box.
hl.bind("XF86LaunchA", hl.dsp.global("quickshell:overviewWorkspacesToggle"),
    { description = "Overview: Toggle full overview (F4 key)" })

--##! Send window to workspace: SUPER+SHIFT+number
-- The dots bind this to SUPER+ALT+number (follow = false). Move it to the
-- KDE/GNOME-style SUPER+SHIFT+number and drop the ALT variants, including
-- the keypad ones, so both input methods behave the same.
for i = 1, 10 do
    local key = tostring(i % 10)
    hl.unbind("SUPER + ALT + " .. key)
    hl.bind("SUPER + SHIFT + " .. key, function()
        hl.dispatch(hl.dsp.window.move({ workspace = workspace_in_group(i), follow = false }))
    end, { description = "Window: Send to workspace " .. i })
end

local numpadkey = { 87, 88, 89, 83, 84, 85, 79, 80, 81, 90 }
for i = 1, 10 do
    hl.unbind("SUPER + ALT + code:" .. numpadkey[i])
    hl.bind("SUPER + SHIFT + code:" .. numpadkey[i], function()
        hl.dispatch(hl.dsp.window.move({ workspace = workspace_in_group(i), follow = false }))
    end, { description = "Window: Send to workspace " .. i .. " (keypad)" })
end

-- Power button (2026-11-08): short press toggles the Quickshell session menu
-- (same as Ctrl+Alt+Delete; press again to close it). logind ignores the short
-- press (HandlePowerKey=ignore) and powers off on a ~5 s hold
-- (HandlePowerKeyLongPress=poweroff), /etc/systemd/logind.conf.d/power-key.conf.
-- The ~10 s hardware force-off is done by the EC and is unaffected.
-- Debounced via ~/.local/bin/power-key-session (one press arrived twice).
hl.bind("XF86PowerOff", hl.dsp.exec_cmd("~/.local/bin/power-key-session"),
    { description = "Session: Toggle session menu (power button)" })
-- Lid (2026-11-08, coffee-lid): with the Quickshell coffee toggle on, logind
-- does not suspend on lid close (Quickshell holds a handle-lid-switch
-- inhibitor); lid-coffee locks the session and turns the panel off instead.
-- With coffee off logind suspends as usual and lid-coffee does nothing on close.
hl.bind("switch:on:Lid Switch", hl.dsp.exec_cmd("~/.local/bin/lid-coffee close"),
    { locked = true, description = "Lid closed: lock + panel off when coffee is on" })
hl.bind("switch:off:Lid Switch", hl.dsp.exec_cmd("~/.local/bin/lid-coffee open"),
    { locked = true, description = "Lid opened: panel on" })

--##! Search on Super+Space, not on a Super tap (2026-11-20)
-- Upstream opens search when Super is released. That release bind fired after any
-- Super combo Hyprland itself does not bind (e.g. keyd's Super+Refresh -> F2 for
-- renaming), stealing focus. Search moves to Super+Space (macOS Spotlight-style) and
-- a bare Super tap does nothing. Sent straight to the running shell (no qs client).
hl.unbind("SUPER + SUPER_L")
hl.unbind("SUPER + SUPER_R")
hl.bind("SUPER + Space", hl.dsp.global("quickshell:searchOnlyToggle"),
    { description = "Shell: Toggle search" })
--##! Ctrl+Super+R through ii-restart (2026-11-15)
-- The dots bind `killall qs; qs -c ii &`: one bad QML file and the bar is gone. ii-restart
-- qmllints the changed files first and leaves the running shell alone if they would not load.
hl.unbind("CTRL + SUPER + R")
hl.bind("CTRL + SUPER + R", hl.dsp.exec_cmd("~/.local/bin/ii-restart"), { description = "Shell: Restart widgets (checked)" })

--##! Send to scratchpad: SUPER+SHIFT+S, screen snip moves to SUPER+ALT+S (2026-11-16)
-- Unify with SUPER+SHIFT+<number> (send window to workspace N). The dots bind
-- "send to scratchpad" to SUPER+ALT+S and "Screen snip" to SUPER+SHIFT+S, so the
-- two are swapped here. The dots bind Screen snip twice (Quickshell global plus a
-- hyprshot fallback), hence the two unbinds on that combo.
hl.unbind("SUPER + ALT + S")
hl.unbind("SUPER + SHIFT + S")
hl.unbind("SUPER + SHIFT + S")
hl.bind("SUPER + SHIFT + S",
    hl.dsp.window.move({ workspace = "special:special", follow = false }),
    { description = "Window: Send to scratchpad" })
hl.bind("SUPER + ALT + S", hl.dsp.global("quickshell:regionScreenshot"),
    { description = "Utilities: Screen snip" })
hl.bind("SUPER + ALT + S",
    hl.dsp.exec_cmd("qs -c $qsConfig ipc call TEST_ALIVE || pidof slurp || hyprshot --freeze --clipboard-only --mode region --silent"))
