-- User keybinds. Sourced after hyprland/keybinds.lua, so these can replace
-- the shipped behaviour without editing the dots themselves.

hl.bind("CTRL+SUPER+ALT+Slash", hl.dsp.exec_cmd("xdg-open ~/.config/hypr/custom/keybinds.lua"), {description = "Edit user keybinds"} )

-- Chromebook F3 position is the fullscreen key (KEY_FULL_SCREEN / XF86FullScreen).
-- keyd leaves it untouched, so bind it here to the same toggle as the
-- four-finger pinch gesture. Super+zoom still emits Super+F3 for apps.
hl.bind("XF86FullScreen", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }),
    { description = "Window: Fullscreen (F3 key)" })

-- Chromebook F4 position is the overview/scale key (KEY_SCALE / XF86LaunchA).
-- Opens the full overview; Super-tap only opens the search box.
hl.bind("XF86LaunchA", hl.dsp.global("quickshell:overviewWorkspacesToggle"),
    { description = "Overview: Toggle full overview (F4 key)" })

--##! Super-tap search/overview: interrupt on key press
-- Upstream binds SUPER+SUPER_L to `quickshell:searchToggleRelease`, which
-- opens overview on Super release unless an earlier key press "interrupts" it.
-- The interrupt is supposed to come from a `catchall` bind in an automatically
-- triggered submap, which this config never defines -- so holding Super and
-- pressing Return still toggles overview on release.
--
-- Hyprland 0.57 has no catchall binds, but it does emit `input.keyboard.key`.
-- Re-arm the interrupt there instead: any non-modifier key pressed while Super
-- is held cancels the release-triggered overview. A plain Super tap still opens
-- search, because no such key was pressed.
-- The event is positional: (keycode, time, state), where state 1 = press and
-- 0 = release, and keycode is the raw evdev/Linux input code, not an xkb name.
local modifier_keycodes = {
    [29] = true, [97] = true,   -- Control_L / Control_R
    [42] = true, [54] = true,   -- Shift_L / Shift_R
    [56] = true, [100] = true,  -- Alt_L / Alt_R
    [125] = true, [126] = true, -- Super_L / Super_R
}

hl.on("input.keyboard.key", function(keycode, _time, state)
    if state == 1 and not modifier_keycodes[keycode] then
        hl.dispatch(hl.dsp.global("quickshell:searchToggleReleaseInterrupt"))
    end
end)

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

--##! Super-tap search without spawning a process (2026-11-13)
-- The dots bind Super-tap to `qs -c ii ipc call search toggle`, which starts a
-- full Quickshell client on every tap (~130 ms warm, up to ~1 s cold) before
-- the search box can open. Send it straight to the running shell instead.
-- (Loses the dots' fuzzel fallback for when Quickshell is not running.)
hl.unbind("SUPER + SUPER_L")
hl.unbind("SUPER + SUPER_R")
hl.bind("SUPER + SUPER_L", hl.dsp.global("quickshell:searchOnlyToggle"),
    { release = true, description = "Shell: Toggle search" })
hl.bind("SUPER + SUPER_R", hl.dsp.global("quickshell:searchOnlyToggle"), { release = true })
