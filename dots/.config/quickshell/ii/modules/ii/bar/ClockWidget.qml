import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool borderless: Config.options.bar.borderless
    property bool showDate: Config.options.bar.verbose
    // lok: time over date, same 12 px two-line rhythm as the monitor and media
    readonly property bool twoLine: Appearance.lok
    implicitWidth: twoLine ? twoLineLayout.implicitWidth : rowLayout.implicitWidth
    implicitHeight: Appearance.sizes.barHeight

    ColumnLayout {
        id: twoLineLayout
        visible: root.twoLine
        anchors.centerIn: parent
        spacing: -2
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colOnLayer1
            text: DateTime.time
        }
        StyledText {
            visible: root.showDate
            Layout.alignment: Qt.AlignHCenter
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
            text: DateTime.longDate
        }
    }

    RowLayout {
        id: rowLayout
        visible: !root.twoLine
        anchors.centerIn: parent
        spacing: Appearance.lok ? 12 : 4

        StyledText {
            font.pixelSize: 14
            color: Appearance.colors.colOnLayer1
            text: DateTime.time
        }

        StyledText {
            visible: root.showDate && !Appearance.lok
            font.pixelSize: 14
            color: Appearance.colors.colOnLayer1
            text: "•"
        }

        StyledText {
            visible: root.showDate
            font.pixelSize: 14
            color: Appearance.lok ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer1
            text: DateTime.longDate
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: !Config.options.bar.tooltips.clickToShow

        ClockWidgetPopup {
            hoverTarget: mouseArea
        }
    }
}
