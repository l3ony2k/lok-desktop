import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import qs.modules.ii.bar as Bar

Item {
    id: root
    property bool borderless: Config.options.bar.borderless
    implicitHeight: column.implicitHeight
    implicitWidth: Appearance.sizes.verticalBarWidth

    readonly property string dateTimeString: DateTime.time
    readonly property bool hasAmPm: dateTimeString.toLowerCase().includes("am") || dateTimeString.toLowerCase().includes("pm")

    Column {
        id: column
        anchors.centerIn: parent
        spacing: root.hasAmPm ? 6 : 0

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: Appearance.lok ? -3 : -4

            Repeater {
                model: root.dateTimeString.split(/[: ]/)
                delegate: StyledText {
                    required property string modelData
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.pixelSize: {
                        if (modelData.match(/am|pm/i))
                            return Appearance.font.pixelSize.smaller;
                        else
                            // Smaller "am"/"pm" text
                            // lok: the horizontal clock's 15 px
                            return Appearance.lok ? Appearance.font.pixelSize.small : Appearance.font.pixelSize.large;
                    }
                    color: Appearance.colors.colOnLayer1
                    text: modelData.padStart(2, "0")
                }
            }
        }
        StyledText {
            visible: !Appearance.lok // lok: the date lives in the hover popup, as in the horizontal bar
            anchors.horizontalCenter: parent.horizontalCenter
            // lok: the date as the horizontal two-line clock draws it (12 px, secondary grey)
            font.pixelSize: Appearance.lok ? Appearance.font.pixelSize.smaller : Appearance.font.pixelSize.smallest
            color: Appearance.lok ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer1
            text: DateTime.shortDate
        }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: !Config.options.bar.tooltips.clickToShow

        Bar.ClockWidgetPopup {
            hoverTarget: mouseArea
        }
    }
}
