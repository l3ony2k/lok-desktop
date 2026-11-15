pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common

/**
 * lok, window gaps "none": neighbouring tiles overlap by their border (gaps_in -1), so there is
 * no gap pixel for Hyprland's resize_on_border to grab. This puts an invisible strip (Top layer,
 * `grab` px wide, centred on the line) over every seam between two tiled windows on each
 * monitor's active workspace. Hovering shows a resize cursor; dragging resizes the window on the
 * left/top by the pointer movement (hl.dsp.window.resize, relative), which moves the split.
 * Hidden whenever a sidebar, overview, session screen or lock is up (those share the Top layer),
 * and in the other gap modes, where Hyprland's own border drag works.
 */
Scope {
    id: root
    readonly property int grab: 6 // logical px: 3 on each side of the seam
    readonly property bool enabled: WindowGaps.flush && !GlobalStates.screenLocked
        && !GlobalStates.sidebarLeftOpen && !GlobalStates.sidebarRightOpen && !GlobalStates.overviewOpen
        && !GlobalStates.searchOpen && !GlobalStates.sessionOpen && !GlobalStates.regionSelectorOpen
        && !GlobalStates.wallpaperSelectorOpen && !GlobalStates.overlayOpen

    Variants {
        model: root.enabled ? Quickshell.screens : []

        Scope {
            id: screenScope
            required property ShellScreen modelData

            // id -> { vertical, x, y, length, addr } in this screen's logical coordinates
            readonly property var seams: {
                const mon = HyprlandData.monitors.find(m => m.name === screenScope.modelData.name);
                if (!mon || !mon.activeWorkspace) return ({});
                const wsId = mon.activeWorkspace.id;
                const all = HyprlandData.windowList.filter(w => w.workspace?.id === wsId && !w.hidden && w.mapped !== false);
                if (all.some(w => (w.fullscreen ?? 0) > 0)) return ({});
                const wins = all.filter(w => !w.floating);
                const out = {};
                for (const a of wins) {
                    const ax2 = a.at[0] + a.size[0], ay2 = a.at[1] + a.size[1];
                    for (const b of wins) {
                        if (a === b) continue;
                        const bx2 = b.at[0] + b.size[0], by2 = b.at[1] + b.size[1];
                        if (Math.abs(b.at[0] - ax2) <= 2) { // a | b
                            const y1 = Math.max(a.at[1], b.at[1]), y2 = Math.min(ay2, by2);
                            if (y2 - y1 > 2 * root.grab)
                                out[`v|${a.address}|${b.address}`] = { vertical: true, x: b.at[0] - mon.x, y: y1 - mon.y, length: y2 - y1, addr: a.address };
                        }
                        if (Math.abs(b.at[1] - ay2) <= 2) { // a over b
                            const x1 = Math.max(a.at[0], b.at[0]), x2 = Math.min(ax2, bx2);
                            if (x2 - x1 > 2 * root.grab)
                                out[`h|${a.address}|${b.address}`] = { vertical: false, x: x1 - mon.x, y: b.at[1] - mon.y, length: x2 - x1, addr: a.address };
                        }
                    }
                }
                return out;
            }

            Variants {
                model: Object.keys(screenScope.seams) // keyed, so a handle survives geometry updates mid-drag

                PanelWindow {
                    id: handle
                    required property string modelData
                    readonly property var seam: screenScope.seams[modelData] ?? null
                    readonly property bool vertical: seam?.vertical ?? true
                    readonly property int seamLeft: seam ? Math.round(vertical ? seam.x - root.grab / 2 : seam.x) : 0
                    readonly property int seamTop: seam ? Math.round(vertical ? seam.y : seam.y - root.grab / 2) : 0
                    property bool dragging: false
                    property int frozenLeft: 0
                    property int frozenTop: 0

                    screen: screenScope.modelData
                    visible: seam !== null
                    color: "transparent"
                    WlrLayershell.layer: WlrLayer.Top
                    WlrLayershell.namespace: "quickshell:seam"
                    exclusionMode: ExclusionMode.Ignore
                    exclusiveZone: 0
                    anchors {
                        top: true
                        left: true
                    }
                    // frozen while dragging: the pointer delta is then measured against a fixed origin
                    margins.left: dragging ? frozenLeft : seamLeft
                    margins.top: dragging ? frozenTop : seamTop
                    implicitWidth: seam ? (vertical ? root.grab : seam.length) : 1
                    implicitHeight: seam ? (vertical ? seam.length : root.grab) : 1

                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: handle.vertical ? Qt.SizeHorCursor : Qt.SizeVerCursor
                        property real last: 0
                        property real pending: 0

                        function apply() {
                            const d = Math.round(pending);
                            if (d === 0 || !handle.seam) return;
                            pending -= d;
                            Hyprland.dispatch(`hl.dsp.window.resize({x=${handle.vertical ? d : 0}, y=${handle.vertical ? 0 : d}, relative=true, window="address:${handle.seam.addr}"})`);
                        }
                        onPressed: mouse => {
                            handle.frozenLeft = handle.seamLeft;
                            handle.frozenTop = handle.seamTop;
                            handle.dragging = true;
                            last = handle.vertical ? mouse.x : mouse.y;
                            pending = 0;
                        }
                        onPositionChanged: mouse => {
                            if (!handle.dragging) return;
                            const cur = handle.vertical ? mouse.x : mouse.y;
                            pending += cur - last;
                            last = cur;
                            if (!flushTimer.running) flushTimer.start();
                        }
                        onReleased: {
                            flushTimer.stop();
                            apply();
                            handle.dragging = false;
                            HyprlandData.updateWindowList(); // a resize emits no event: fetch the new geometry
                        }
                        Timer {
                            id: flushTimer
                            interval: 25 // coalesce motion into ~40 dispatches/s
                            onTriggered: dragArea.apply()
                        }
                    }
                }
            }
        }
    }
}
