import QtQuick
import qs.modules.common

/**
 * lok style meter: a row of square cells, filled up to `value` (0..1).
 * Used by the OSD instead of the Material progress bar.
 */
Item {
    id: root
    property real value: 0
    property int segments: 20
    property real gap: 2
    property color colFilled: Appearance.colors.colOnLayer0
    property color colEmpty: Appearance.colors.colOutlineVariant
    property color colOver: Appearance.colors.colError // above 100 % (e.g. volume boost)
    implicitHeight: 8
    implicitWidth: 200

    readonly property real cellWidth: (width - gap * (segments - 1)) / segments
    readonly property int filled: Math.round(Math.max(0, Math.min(1, value)) * segments)

    Row {
        anchors.fill: parent
        spacing: root.gap
        Repeater {
            model: root.segments
            Rectangle {
                required property int index
                width: root.cellWidth
                height: root.height
                color: index < root.filled ? (root.value > 1 ? root.colOver : root.colFilled) : root.colEmpty
                Behavior on color {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }
            }
        }
    }
}
