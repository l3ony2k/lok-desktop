import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Row {
    id: root
    required property var icon
    required property var label
    spacing: Appearance.lok ? 8 : 5

    MaterialSymbol {
        anchors.verticalCenter: parent.verticalCenter
        fill: 0
        width: Appearance.lok ? Appearance.font.pixelSize.large : implicitWidth
        horizontalAlignment: Text.AlignHCenter
        font.weight: Font.DemiBold
        text: root.icon
        iconSize: Appearance.font.pixelSize.large
        color: Appearance.colors.colOnSurfaceVariant
    }

    StyledText {
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        font {
            weight: Font.DemiBold
            pixelSize: Appearance.font.pixelSize.normal
        }
        color: Appearance.colors.colOnSurfaceVariant
    }
}