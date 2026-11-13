import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

MouseArea {
    id: root
    property bool borderless: Config.options.bar.borderless
    readonly property var chargeState: Battery.chargeState
    readonly property bool isCharging: Battery.isCharging
    readonly property bool isPluggedIn: Battery.isPluggedIn
    readonly property real percentage: Battery.percentage
    readonly property bool isLow: percentage <= Config.options.battery.low / 100

    implicitWidth: Appearance.lok ? lokBattery.implicitWidth : batteryProgress.implicitWidth
    implicitHeight: Appearance.sizes.barHeight

    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    // lok: battery and power mode are one item. The glyph is the power profile and a
    // click cycles it; the text is the charge.
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

    RowLayout { // lok: quiet text until it matters
        id: lokBattery
        visible: Appearance.lok
        anchors.centerIn: parent
        spacing: 4
        readonly property color tint: (root.isLow && !root.isCharging) ? Appearance.m3colors.m3error : Appearance.colors.colOnLayer1
        MaterialSymbol {
            Layout.alignment: Qt.AlignVCenter
            iconSize: Appearance.font.pixelSize.larger
            color: (root.isLow && !root.isCharging) ? lokBattery.tint : Appearance.colors.colSubtext
            text: switch (PowerProfiles.profile) {
                case PowerProfile.PowerSaver: return "energy_savings_leaf";
                case PowerProfile.Performance: return "local_fire_department";
                default: return "airwave";
            }
        }
        StyledText {
            Layout.alignment: Qt.AlignVCenter
            font.pixelSize: Appearance.font.pixelSize.small
            color: lokBattery.tint
            text: Math.round(root.percentage * 100) + "%"
        }
        MaterialSymbol { // charging marker
            visible: root.isCharging
            Layout.alignment: Qt.AlignVCenter
            Layout.leftMargin: -2
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colSubtext
            text: "bolt"
        }
    }

    ClippedProgressBar {
        id: batteryProgress
        visible: !Appearance.lok
        anchors.centerIn: parent
        value: percentage
        highlightColor: (isLow && !isCharging) ? Appearance.m3colors.m3error : Appearance.colors.colOnSecondaryContainer

        Item {
            anchors.centerIn: parent
            width: batteryProgress.valueBarWidth
            height: batteryProgress.valueBarHeight

            RowLayout {
                anchors {
                    horizontalCenter: parent.horizontalCenter
                    bottom: parent.bottom
                    bottomMargin: (parent.height - height) / 2
                }
                spacing: 0

                MaterialSymbol {
                    id: boltIcon
                    Layout.alignment: Qt.AlignVCenter
                    font.hintingPreference: Font.PreferFullHinting
                    Layout.leftMargin: -2
                    Layout.rightMargin: -2
                    fill: 1
                    text: "bolt"
                    iconSize: Appearance.font.pixelSize.smaller
                    visible: isCharging && percentage < 1 // TODO: animation
                }
                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    font.pixelSize: batteryProgress.font.pixelSize
                    font.weight: batteryProgress.font.weight
                    font.family: Appearance.font.family.numbers
                    text: batteryProgress.text
                }
            }
        }
    }

    BatteryPopup {
        id: batteryPopup
        hoverTarget: root
    }
}
