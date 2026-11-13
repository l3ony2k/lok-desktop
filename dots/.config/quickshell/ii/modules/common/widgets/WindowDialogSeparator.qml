import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Rectangle {
    // lok: Layouts round item sizes up to whole logical px (1 logical = 1.33 device px, so 2 px
    // lines), so the layout only sees a 1 px slot and the real line is drawn inside it
    implicitHeight: 1
    color: Appearance.lok ? "transparent" : Appearance.colors.colOutline
    Rectangle {
        visible: Appearance.lok
        x: 0; y: 0
        width: parent.width
        height: Appearance.sizes.hairline
        color: Appearance.colors.colLokDivider
    }
    Layout.fillWidth: true
    Layout.leftMargin: -Appearance.roundingSpace.large + (Appearance.lok ? Appearance.sizes.hairline : 0)
    Layout.rightMargin: -Appearance.roundingSpace.large + (Appearance.lok ? Appearance.sizes.hairline : 0)
    Layout.topMargin: -8
    Layout.bottomMargin: -8
}
