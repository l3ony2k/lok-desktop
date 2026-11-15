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
 * no gap pixel for Hyprland's resize_on_border to grab. This puts invisible handles (Top layer)
 * on each monitor's active workspace:
 *   seams    a `grab` px strip centred on every line between two tiled windows; dragging resizes
 *            the window on the left/top (hl.dsp.window.resize, relative), which moves the split
 *   corners  a `corner` px square on every point where a horizontal line ends on a vertical one;
 *            dragging moves both lines at once (x on the left window, y on the upper window)
 * Seam strips stop corner/2 short of their ends so they never overlap a corner square.
 * Hidden whenever a sidebar, overview, session screen or lock is up (those share the Top layer),
 * and in the other gap modes, where Hyprland's own border drag works.
 */
Scope {
    id: root
    readonly property int grab: 6     // logical px: 3 on each side of a line
    readonly property int corner: 12  // logical px square on a junction
    readonly property bool enabled: WindowGaps.flush && !GlobalStates.screenLocked
        && !GlobalStates.sidebarLeftOpen && !GlobalStates.sidebarRightOpen && !GlobalStates.overviewOpen
        && !GlobalStates.searchOpen && !GlobalStates.sessionOpen && !GlobalStates.regionSelectorOpen
        && !GlobalStates.wallpaperSelectorOpen && !GlobalStates.overlayOpen

    Variants {
        model: root.enabled ? Quickshell.screens : []

        Scope {
            id: screenScope
            required property ShellScreen modelData

            // id -> { x, y, w, h (handle rect, screen logical px), addrX, addrY, cursor }
            readonly property var handles: {
                const mon = HyprlandData.monitors.find(m => m.name === screenScope.modelData.name);
                if (!mon || !mon.activeWorkspace) return ({});
                const wsId = mon.activeWorkspace.id;
                const all = HyprlandData.windowList.filter(w => w.workspace?.id === wsId && !w.hidden && w.mapped !== false);
                if (all.some(w => (w.fullscreen ?? 0) > 0)) return ({});
                const wins = all.filter(w => !w.floating);
                const g = root.grab, c = root.corner;
                const vs = [], hs = [], out = {};
                for (const a of wins) {
                    const ax2 = a.at[0] + a.size[0], ay2 = a.at[1] + a.size[1];
                    for (const b of wins) {
                        if (a === b) continue;
                        const bx2 = b.at[0] + b.size[0], by2 = b.at[1] + b.size[1];
                        if (Math.abs(b.at[0] - ax2) <= 2) { // a | b
                            const y1 = Math.max(a.at[1], b.at[1]), y2 = Math.min(ay2, by2);
                            if (y2 - y1 > 2 * c) vs.push({ id: `v|${a.address}|${b.address}`, X: b.at[0] - mon.x, y1: y1 - mon.y, y2: y2 - mon.y, addr: a.address });
                        }
                        if (Math.abs(b.at[1] - ay2) <= 2) { // a over b
                            const x1 = Math.max(a.at[0], b.at[0]), x2 = Math.min(ax2, bx2);
                            if (x2 - x1 > 2 * c) hs.push({ id: `h|${a.address}|${b.address}`, Y: b.at[1] - mon.y, x1: x1 - mon.x, x2: x2 - mon.x, addr: a.address });
                        }
                    }
                }
                for (const v of vs)
                    out[v.id] = { x: v.X - g / 2, y: v.y1 + c / 2, w: g, h: v.y2 - v.y1 - c, addrX: v.addr, addrY: "", cursor: Qt.SizeHorCursor };
                for (const h of hs)
                    out[h.id] = { x: h.x1 + c / 2, y: h.Y - g / 2, w: h.x2 - h.x1 - c, h: g, addrX: "", addrY: h.addr, cursor: Qt.SizeVerCursor };
                for (const h of hs) for (const v of vs) {
                    const startsHere = Math.abs(h.x1 - v.X) <= 2, endsHere = Math.abs(h.x2 - v.X) <= 2;
                    if (!(startsHere || endsHere) || h.Y < v.y1 - 2 || h.Y > v.y2 + 2) continue;
                    const key = `c|${Math.round(v.X)}|${Math.round(h.Y)}`;
                    if (out[key]) continue; // a T-junction touches two vertical seams: one corner
                    out[key] = { x: v.X - c / 2, y: h.Y - c / 2, w: c, h: c, addrX: v.addr, addrY: h.addr,
                                 cursor: startsHere ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor };
                }
                return out;
            }

            Variants {
                model: Object.keys(screenScope.handles) // keyed, so a handle survives geometry updates mid-drag

                PanelWindow {
                    id: handle
                    required property string modelData
                    readonly property var spec: screenScope.handles[modelData] ?? null
                    property bool dragging: false
                    property int frozenLeft: 0
                    property int frozenTop: 0

                    screen: screenScope.modelData
                    visible: spec !== null
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
                    margins.left: dragging ? frozenLeft : Math.round(spec?.x ?? 0)
                    margins.top: dragging ? frozenTop : Math.round(spec?.y ?? 0)
                    implicitWidth: Math.max(1, Math.round(spec?.w ?? 1))
                    implicitHeight: Math.max(1, Math.round(spec?.h ?? 1))

                    MouseArea {
                        id: dragArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: handle.spec?.cursor ?? Qt.ArrowCursor
                        property real lastX: 0
                        property real lastY: 0
                        property real pendingX: 0
                        property real pendingY: 0

                        function apply() {
                            if (!handle.spec) return;
                            const dx = handle.spec.addrX ? Math.round(pendingX) : 0;
                            const dy = handle.spec.addrY ? Math.round(pendingY) : 0;
                            if (dx !== 0) {
                                pendingX -= dx;
                                Hyprland.dispatch(`hl.dsp.window.resize({x=${dx}, y=0, relative=true, window="address:${handle.spec.addrX}"})`);
                            }
                            if (dy !== 0) {
                                pendingY -= dy;
                                Hyprland.dispatch(`hl.dsp.window.resize({x=0, y=${dy}, relative=true, window="address:${handle.spec.addrY}"})`);
                            }
                        }
                        onPressed: mouse => {
                            handle.frozenLeft = handle.margins.left;
                            handle.frozenTop = handle.margins.top;
                            handle.dragging = true;
                            lastX = mouse.x; lastY = mouse.y;
                            pendingX = 0; pendingY = 0;
                        }
                        onPositionChanged: mouse => {
                            if (!handle.dragging) return;
                            pendingX += mouse.x - lastX; pendingY += mouse.y - lastY;
                            lastX = mouse.x; lastY = mouse.y;
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
