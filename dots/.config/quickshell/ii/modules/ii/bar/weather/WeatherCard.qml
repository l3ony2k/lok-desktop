import QtQuick
import QtQuick.Layouts

import qs.modules.common
import qs.modules.common.widgets

Rectangle {
    id: root
    radius: Appearance.rounding.small
    color: Appearance.colors.colSurfaceContainerHigh
    implicitWidth: columnLayout.implicitWidth + (Appearance.lok ? 8 : 14) * 2 // lok: narrower so the popup centres under its item
    implicitHeight: columnLayout.implicitHeight + 14 * 2
    Layout.fillWidth: parent

    property alias title: title.text
    property alias value: value.text
    property alias symbol: symbol.text

    ColumnLayout {
        id: columnLayout
        anchors.fill: parent
        spacing: -10
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            MaterialSymbol {
                id: symbol
                fill: 0
                iconSize: Appearance.font.pixelSize.normal
                color: Appearance.colors.colOnSurfaceVariant
            }
            StyledText {
                id: title
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnSurfaceVariant
            }
        }
        StyledText {
            id: value
            Layout.alignment: Qt.AlignHCenter
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnSurfaceVariant
        }
    }
}
