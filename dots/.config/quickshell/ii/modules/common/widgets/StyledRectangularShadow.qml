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

    Rectangle {
        visible: Appearance.lok
        anchors.fill: parent
        anchors.margins: -1
        color: "transparent"
        border.width: 1
        border.color: Appearance.colors.colLayer0Border
    }
}
