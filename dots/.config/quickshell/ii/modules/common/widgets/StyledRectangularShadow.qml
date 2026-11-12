import QtQuick
import QtQuick.Effects
import qs.modules.common

RectangularShadow {
    required property var target
    anchors.fill: target
    radius: target.radius
    // lok style: no soft elevation; the "shadow" becomes a 1 px hairline around the
    // surface (spread 1, no blur, no offset), so every floating surface gets a border.
    blur: Appearance.lok ? 0 : 0.9 * Appearance.sizes.elevationMargin
    offset: Appearance.lok ? Qt.vector2d(0.0, 0.0) : Qt.vector2d(0.0, 1.0)
    spread: 1
    color: Appearance.lok ? Appearance.colors.colLayer0Border : Appearance.colors.colShadow
    cached: true
}
