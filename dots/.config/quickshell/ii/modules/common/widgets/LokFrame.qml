import QtQuick
import qs.modules.common

/**
 * lok hairline frame: four filled lines exactly 1 device px thick around the parent.
 * At fractional scale Qt drops a sub-logical-px line whose start is fractional
 * (e.g. x = width - 0.75), which is why Rectangle.border lost its right/bottom side.
 * So every line starts on the item edge: left/top lie just inside, right/bottom
 * just outside, and all four render as exactly one pixel row/column.
 */
Item {
    id: root
    property color color: Appearance.colors.colLokFrame
    property real thickness: Appearance.sizes.hairline
    anchors.fill: parent
    Rectangle { color: root.color; x: 0; y: 0; width: root.width + root.thickness; height: root.thickness }
    Rectangle { color: root.color; x: 0; y: root.height; width: root.width + root.thickness; height: root.thickness }
    Rectangle { color: root.color; x: 0; y: 0; width: root.thickness; height: root.height }
    Rectangle { color: root.color; x: root.width; y: 0; width: root.thickness; height: root.height }
}
