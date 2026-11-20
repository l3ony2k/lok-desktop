import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

RowLayout {
    id: root
    required property string icon
    required property string label
    required property string value
    spacing: Appearance.lok ? 8 : 4

    // lok: icon + label in secondary grey, value bright, so title / label / value read as three levels
    MaterialSymbol {
        text: root.icon
        color: Appearance.lok ? Appearance.colors.colSubtext : Appearance.colors.colOnSurfaceVariant
        iconSize: Appearance.font.pixelSize.large
        Layout.preferredWidth: Appearance.lok ? Appearance.font.pixelSize.large : implicitWidth
        horizontalAlignment: Text.AlignHCenter
    }
    StyledText {
        text: root.label
        color: Appearance.lok ? Appearance.colors.colSubtext : Appearance.colors.colOnSurfaceVariant
    }
    StyledText {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignRight
        visible: root.value !== ""
        color: Appearance.lok ? Appearance.colors.colOnLayer1 : Appearance.colors.colOnSurfaceVariant
        text: root.value
    }
}
