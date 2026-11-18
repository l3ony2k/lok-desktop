import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.modules.ii.bar as Bar

MouseArea {
    id: root
    property bool borderless: Config.options.bar.borderless
    readonly property var chargeState: Battery.chargeState
    readonly property bool isCharging: Battery.isCharging
    readonly property bool isPluggedIn: Battery.isPluggedIn
    readonly property real percentage: Battery.percentage
    readonly property bool isLow: percentage <= Config.options.battery.low / 100

    implicitHeight: Appearance.lok ? lokBattery.implicitHeight : batteryProgress.implicitHeight
    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    // lok: same item as the horizontal bar (Bar/BatteryIndicator.qml), stacked: the power-profile
    // glyph (click cycles it) over the charge
    cursorShape: Appearance.lok ? Qt.PointingHandCursor : Qt.ArrowCursor
    onClicked: {
        if (!Appearance.lok) return;
        if (PowerProfiles.hasPerformanceProfile) {
            switch (PowerProfiles.profile) {
                case PowerProfile.PowerSaver: PowerProfiles.profile = PowerProfile.Balanced; break;
                case PowerProfile.Balanced: PowerProfiles.profile = PowerProfile.Performance; break;
                case PowerProfile.Performance: PowerProfiles.profile = PowerProfile.PowerSaver; break;
            }
        } else {
            PowerProfiles.profile = PowerProfiles.profile == PowerProfile.Balanced ? PowerProfile.PowerSaver : PowerProfile.Balanced;
        }
    }

    Column {
        id: lokBattery
        visible: Appearance.lok
        anchors.centerIn: parent
        spacing: 0
        readonly property color tint: (root.isLow && !root.isCharging) ? Appearance.m3colors.m3error : Appearance.colors.colOnLayer1
        MaterialSymbol {
            anchors.horizontalCenter: parent.horizontalCenter
            iconSize: Appearance.font.pixelSize.larger
            color: (root.isLow && !root.isCharging) ? lokBattery.tint : Appearance.colors.colSubtext
            text: switch (PowerProfiles.profile) {
                case PowerProfile.PowerSaver: return "energy_savings_leaf";
                case PowerProfile.Performance: return "local_fire_department";
                default: return "airwave";
            }
        }
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: -1
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: Appearance.font.pixelSize.small
                color: lokBattery.tint
                text: Math.round(root.percentage * 100) + "%"
            }
            MaterialSymbol { // charging marker, as in the horizontal bar
                visible: root.isCharging
                anchors.verticalCenter: parent.verticalCenter
                iconSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                text: "bolt"
            }
        }
    }

    ClippedProgressBar {
        id: batteryProgress
        visible: !Appearance.lok
        anchors.centerIn: parent
        vertical: true
        valueBarWidth: 20
        valueBarHeight: 36
        value: percentage
        // value: 1
        highlightColor: (isLow && !isCharging) ? Appearance.m3colors.m3error : Appearance.colors.colOnSecondaryContainer

        font {
            pixelSize: 13
            weight: Font.DemiBold
        }

        textMask: Item {
            anchors.centerIn: parent
            width: batteryProgress.valueBarWidth
            height: batteryProgress.valueBarHeight

            Column {
                anchors.centerIn: parent
                spacing: -4

                MaterialSymbol {
                    id: boltIcon
                    anchors.horizontalCenter: parent.horizontalCenter
                    fill: 1
                    text: {
                        if (batteryProgress.value == 1) {
                            return "check";
                        } else if (root.isCharging) {
                            return "bolt";
                        } else {
                            return Icons.getBatteryIcon(Battery.percentage * 100);
                        }
                    }
                    iconSize: Appearance.font.pixelSize.normal
                    animateChange: true
                }
                StyledText {
                    visible: text.length <= 2
                    anchors.horizontalCenter: parent.horizontalCenter
                    font: batteryProgress.font
                    text: batteryProgress.text
                }
            }
        }
    }

    Bar.BatteryPopup {
        id: batteryPopup
        hoverTarget: root
    }
}
