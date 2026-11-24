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
    bitdepth = 10,
    -- Panel EDID is ~Display P3 (139% sRGB area, D65 white). Hyprland's
    -- default `cm = srgb` sends sRGB values straight to the wide-gamut panel,
    -- which stretches every colour -> visibly oversaturated. Tell the
    -- compositor the panel's real gamut so sRGB content is converted to P3.
    cm = "dp3"
})

-- macOS pointer acceleration. Apple's IOHIDParametricAcceleration curve was
-- exported from macOS 15.7.9 on a 14" M1 Pro at tracking speed 0.875, then
-- sampled into libinput's custom profile (64 points, linear interpolation)
-- for this machine:
--   ELAN touchpad: 3987 units / 128 mm = 31.15 units/mm
--   panel: 2560x1600 @ 1.3333, 300 mm wide -> 1.27496 logical px per Mac point
-- Slow movement stays near 0.75:1 for precision, then accelerates early and
-- smoothly. libinput's adaptive touchpad curve instead decelerates below
-- 7 mm/s, holds 0.9 * 0.2968 up to 130 mm/s, then ramps steeply.
-- Custom profiles ignore `sensitivity`; rescale the point values to tune speed.
hl.device({
    name = "elan-touchpad",
    accel_profile = "custom 0.1646 0.000000 0.026812 0.059383 0.097720 0.141828 0.191715 0.247387 0.308851 0.376113 0.449180 0.528058 0.612754 0.703275 0.799627 0.901816 1.009850 1.123735 1.243477 1.369084 1.500560 1.637914 1.781152 1.930280 2.085305 2.246234 2.413073 2.585828 2.764506 2.949115 3.139659 3.336147 3.538584 3.746977 3.961333 4.181659 4.407960 4.640243 4.878516 5.122784 5.373054 5.629333 5.891628 6.159944 6.434289 6.714669 7.001090 7.293560 7.592084 7.896670 8.207323 8.524051 8.846861 9.175758 9.510749 9.851841 10.199040 10.552354 10.911788 11.277349 11.649044 12.026879 12.410861 12.800994 13.194040",
    -- libinput's custom profile needs a separate scroll curve. This reproduces
    -- the previous adaptive finger-scroll gain (0.9 * 0.2968 * 1000/787.4 =
    -- 0.339243), so scroll_factor and the per-app scroll_touchpad rules above
    -- keep exactly the same feel.
    scroll_points = "1.0 0.0 0.339243"
})

-- matugen palette (hyprland colours), generated into custom/ so exp-update
-- cannot delete it; output path set in ~/.config/matugen/config.toml.
-- Loaded after hyprland/colors.lua and before custom.lok, so lok's border
-- colours still win.
pcall(require, "custom.colors")

-- lok style decoration overrides, generated by quickshell ii scripts/colors/lok/apply-lok.sh
pcall(require, "custom.lok")
