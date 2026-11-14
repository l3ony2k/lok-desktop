import QtQuick
import Quickshell
import qs.modules.common

/**
 * lok hairline frame: four filled lines, exactly 1 device px thick, on the inside edge of the
 * parent (1 / the real render scale of the window it is in). Inside, so a
 * clipping parent or the window edge can never cut the right/bottom side off.
 */
Item {
    id: root
    property color color: Appearance.colors.colLokFrame
    // this frame's own window scale: right on every screen (an external monitor at another scale)
    // and without a bar; outside Quickshell windows (settings app) it falls back to the global value
    readonly property real windowDpr: root.QsWindow.window?.devicePixelRatio ?? 0
    property real thickness: !Appearance.lok ? Appearance.sizes.hairline : 1 / (root.windowDpr > 0 ? root.windowDpr : Appearance.dpr)
    anchors.fill: parent
    Rectangle { color: root.color; x: 0; y: 0; width: root.width; height: root.thickness }
    Rectangle { color: root.color; x: 0; y: root.height - root.thickness; width: root.width; height: root.thickness }
    Rectangle { color: root.color; x: 0; y: 0; width: root.thickness; height: root.height }
    Rectangle { color: root.color; x: root.width - root.thickness; y: 0; width: root.thickness; height: root.height }
}
