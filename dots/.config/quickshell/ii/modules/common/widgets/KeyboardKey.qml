import qs.modules.common
import QtQuick

Rectangle {
    id: root
    property string key

    property real horizontalPadding: 6
    property real verticalPadding: Appearance.lok ? 2 : 1
    // lok: flat square keycap with a 1 device px frame, no raised bottom edge
    property real borderWidth: Appearance.lok ? 0 : 1 // lok: LokFrame below draws the edge
    property real extraBottomBorderWidth: Appearance.lok ? 0 : 2
    property color borderColor: Appearance.lok ? Appearance.colors.colLokFrame : Appearance.colors.colOnLayer0
    property real borderRadius: Appearance.lok ? 0 : 5
    property real pixelSize: Appearance.font.pixelSize.smaller
    property color keyColor: Appearance.lok ? Appearance.colors.colLayer1 : Appearance.m3colors.m3surfaceContainerLow
    implicitWidth: keyFace.implicitWidth + borderWidth * 2
    implicitHeight: keyFace.implicitHeight + borderWidth * 2 + extraBottomBorderWidth
    radius: borderRadius
    color: Appearance.lok ? keyColor : borderColor
    LokFrame {
        visible: Appearance.lok
        z: 1
        color: root.borderColor
    }

    Rectangle {
        id: keyFace
        anchors {
            fill: parent
            topMargin: borderWidth
            leftMargin: borderWidth
            rightMargin: borderWidth
            bottomMargin: extraBottomBorderWidth + borderWidth
        }
        implicitWidth: keyText.implicitWidth + horizontalPadding * 2
        implicitHeight: keyText.implicitHeight + verticalPadding * 2
        color: keyColor
        radius: borderRadius - borderWidth

        StyledText {
            id: keyText
            anchors.centerIn: parent
            font.family: Appearance.font.family.monospace
            font.pixelSize: root.pixelSize
            // lok: the Super key is written out; the configured glyph (U+F268) is a
            // Chrome logo in Nerd Fonts and the default (U+F05B3) a Windows logo
            text: (Appearance.lok && (root.key === Config.options.cheatsheet.superKey || root.key === "\u{F05B3}")) ? "Super" : root.key
        }
    }
}
