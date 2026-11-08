-- User overrides. Sourced after hyprland/general.lua, so the more specific
-- output rule below wins over the base `scale = 1.25` rule.
--
-- Panel: BOE NE140QDM-NX5, 2560x1600 @ 120Hz, 300x190mm (~13.98", 215.9 PPI)
-- Scale 1.3333 (4/3) -> 1920x1200 logical -> 161.9 effective PPI.
--
-- Hyprland snaps scale to rungs that yield an integer logical resolution, so
-- only these are actually valid on this panel:
--   1.25 -> 2048x1280   1.3333 -> 1920x1200   1.6 -> 1600x1000
--   1.6667 -> 1536x960  2.0    -> 1280x800
-- (1.5 is NOT valid: 2560/1.5 = 1706.67, and it silently snaps to 1.6.)
-- bitdepth = 10: Hyprland 0.57 enables wide color gamut whenever a fullscreen
-- surface (e.g. YouTube via wp-color-management-v1) declares BT2020, but the
-- DRM format defaults to 8-bit (XRGB8888) -> "wide color gamut is enabled but
-- the display is not in 10-bit mode" warning on every fullscreen video.
-- The panel (EDID) reports 10 bits per primary channel + BT2020, so ask for it.
hl.config({
    -- Disable automatic HDR for now. Brave's ordinary SDR fullscreen surface
    -- switches eDP-1 to BT2020 and visibly darkens the screen.
    render = {
        cm_auto_hdr = 0
    },
    -- Keep tearing disabled; Game mode's allow_tearing override is temporary.
    general = {
        allow_tearing = false,
        -- Tighter gaps, paired with rounding below. Invariant with Quickshell:
        -- screenRounding(13) - hyprlandGapsOut(3) + 1 == windowRounding(11).
        gaps_in = 2,
        gaps_out = 3
    },
    decoration = {
        rounding = 11
    },
    misc = {
        -- 2 = VRR only for fullscreen apps. i915 cannot run PSR (panel self
        -- refresh) while VRR is active, so vrr = 1 kept PSR off on the desktop.
        vrr = 2
    },
    input = {
        touchpad = {
            -- Match the documented Dolphin/Qt baseline; app-specific rules
            -- below compensate Chromium and kitty separately.
            scroll_factor = 0.3,
            -- Native three-finger drag; three-finger swipe/pinch are unset
            -- below so they do not compete with the drag gesture.
            drag_3fg = 1
        }
    }
})

-- Native three-finger click-drag instead of compositor window movement.
hl.gesture({
    fingers = 3,
    direction = "swipe",
    action = "unset"
})

-- Reserve pinch fullscreen for four fingers.
hl.gesture({
    fingers = 3,
    direction = "pinch",
    action = "unset"
})
hl.gesture({
    fingers = 4,
    direction = "pinch",
    action = "fullscreen"
})

-- Chromium Wayland scroll deltas are near-raw, so damp them to match Qt apps.
hl.window_rule({
    match = { class = "^brave-origin$" },
    scroll_touchpad = 0.15
})
hl.window_rule({
    match = { class = "^WorkFlowy$" },
    scroll_touchpad = 0.15
})

hl.monitor({
    output = "eDP-1",
    mode = "2560x1600@120",
    position = "0x0",
    scale = 1.3333334,
    bitdepth = 10
})
