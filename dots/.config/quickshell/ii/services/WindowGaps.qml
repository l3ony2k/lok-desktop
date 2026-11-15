pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common

/**
 * Window gaps in lok (Hyprland general:gaps_in / gaps_out), set at runtime with `hyprctl eval`.
 *   none   tiles overlap by their 1 px border (gaps_in -1, gaps_out 0) and the bar reserves 1 px
 *          less, so neighbours show one line (the upper, i.e. focused, window's) instead of two.
 *   small  gaps_out = Config.options.windowGaps.small (default 27: windows line up with the bar's
 *          workspace indicator), gaps_in = half of it (Hyprland applies gaps_in on both sides).
 *   large  the same with Config.options.windowGaps.large (default 36).
 * custom/lok.lua carries the "none" values, so this is re-applied after every Hyprland reload.
 * Outside lok nothing is touched (the Material gaps in custom/general.lua stay in charge).
 */
Singleton {
    id: root

    readonly property list<string> modes: ["none", "small", "large"]
    readonly property bool enabled: Appearance.lok
    readonly property string mode: modes.includes(Config.options.windowGaps.mode) ? Config.options.windowGaps.mode : "none"
    readonly property int outer: mode === "small" ? Config.options.windowGaps.small
        : mode === "large" ? Config.options.windowGaps.large : 0
    readonly property int inner: mode === "none" ? -1 : Math.ceil(outer / 2)
    readonly property bool flush: enabled && mode === "none"

    function setMode(m: string): void {
        if (modes.includes(m))
            Config.options.windowGaps.mode = m;
    }
    function cycle(): void {
        setMode(modes[(modes.indexOf(mode) + 1) % modes.length]);
    }
    function setSize(which: string, value: int): void {
        const v = Math.max(1, Math.min(96, Math.round(value)));
        if (which === "small" && Config.options.windowGaps.small !== v)
            Config.options.windowGaps.small = v;
        else if (which === "large" && Config.options.windowGaps.large !== v)
            Config.options.windowGaps.large = v;
    }
    function apply(): void {
        if (!root.enabled || !Config.ready)
            return;
        Quickshell.execDetached(["hyprctl", "eval",
            `hl.config({general={gaps_in=${root.inner},gaps_out=${root.outer}}})`]);
    }

    onInnerChanged: applyTimer.restart()
    onOuterChanged: applyTimer.restart()
    onEnabledChanged: applyTimer.restart()

    Timer { // coalesce mode + size changes, and wait for the config to load
        id: applyTimer
        interval: 60
        onTriggered: root.apply()
    }
    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready)
                applyTimer.restart();
        }
    }
    Connections {
        target: HyprlandConfig
        function onReloaded() { // a reload restores lok.lua's "none" values
            applyTimer.restart();
        }
    }
    Component.onCompleted: applyTimer.restart()
}
