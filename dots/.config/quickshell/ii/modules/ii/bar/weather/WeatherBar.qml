pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.widgets
import qs.services
import Quickshell
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    property bool hovered: false
    property bool vertical: false // vertical bar: glyph over temperature
    implicitWidth: vertical ? Appearance.sizes.verticalBarWidth : rowLayout.implicitWidth + (Appearance.lok ? 0 : 10 * 2)
    implicitHeight: vertical ? rowLayout.implicitHeight : Appearance.sizes.barHeight

    acceptedButtons: Qt.LeftButton | Qt.RightButton
    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    onPressed: {
        if (mouse.button === Qt.RightButton) {
            Weather.getData();
            Quickshell.execDetached(["notify-send", 
                Translation.tr("Weather"), 
                Translation.tr("Refreshing (manually triggered)")
                , "-a", "Shell"
            ])
            mouse.accepted = false
        }
    }

    GridLayout {
        id: rowLayout
        anchors.centerIn: parent
        columns: root.vertical ? 1 : -1
        rowSpacing: 0
        columnSpacing: Appearance.lok ? 4 : 5

        MaterialSymbol {
            fill: 0
            text: Icons.getWeatherIcon(Weather.data.wCode) ?? "cloud"
            iconSize: Appearance.lok ? Appearance.font.pixelSize.larger : Appearance.font.pixelSize.large
            color: Appearance.lok ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer1
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
        }

        StyledText {
            visible: true
            font.pixelSize: root.vertical ? Appearance.font.pixelSize.smaller : Appearance.font.pixelSize.small // vertical: 12 px, clear of the bar edges
            color: Appearance.colors.colOnLayer1
            text: Weather.data?.temp ?? "--°"
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
        }
    }

    WeatherPopup {
        id: weatherPopup
        hoverTarget: root
    }
}
