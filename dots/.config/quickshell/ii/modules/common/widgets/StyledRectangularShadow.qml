import QtQuick
import QtQuick.Effects
import qs.modules.common

RectangularShadow {
    required property var target
    anchors.fill: target
    radius: target.radius
    // lok style: no soft elevation. The shadow itself is transparent and a real
    // 1 px outline is drawn just outside the surface instead (a spread-1 shadow
    // lost its top/left edge under fractional scaling).
    blur: Appearance.lok ? 0 : 0.9 * Appearance.sizes.elevationMargin
    offset: Appearance.lok ? Qt.vector2d(0.0, 0.0) : Qt.vector2d(0.0, 1.0)
    spread: Appearance.lok ? 0 : 1
    color: Appearance.lok ? "transparent" : Appearance.colors.colShadow
    cached: true

    // lok: drawn on the surface edge (inside its bounds, stacked above it) so frame and
    // fill always share an edge; outside-and-below left 1 px gaps at fractional scale
    z: Appearance.lok ? (target?.z ?? 0) + 1 : 0
    Rectangle {
        visible: Appearance.lok
        anchors.fill: parent
        color: "transparent"
        border.width: Appearance.sizes.hairline
        border.color: Appearance.colors.colLayer0Border
    }
}
