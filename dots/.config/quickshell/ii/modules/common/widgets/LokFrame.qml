import QtQuick
import qs.modules.common

/**
 * lok hairline frame: four filled lines, exactly 1 device px thick, on the inside edge of the
 * parent (Appearance.sizes.hairline = 1 / the window's real render scale). Inside, so a
 * clipping parent or the window edge can never cut the right/bottom side off.
 */
Item {
    id: root
    property color color: Appearance.colors.colLokFrame
    property real thickness: Appearance.sizes.hairline
    anchors.fill: parent
    Rectangle { color: root.color; x: 0; y: 0; width: root.width; height: root.thickness }
    Rectangle { color: root.color; x: 0; y: root.height - root.thickness; width: root.width; height: root.thickness }
    Rectangle { color: root.color; x: 0; y: 0; width: root.thickness; height: root.height }
    Rectangle { color: root.color; x: root.width - root.thickness; y: 0; width: root.thickness; height: root.height }
}
