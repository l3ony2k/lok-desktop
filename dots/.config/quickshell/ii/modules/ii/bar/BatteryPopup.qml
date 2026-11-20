import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower

StyledPopup {
    id: root

    function formatTime(seconds) {
        var h = Math.floor(seconds / 3600);
        var m = Math.floor((seconds % 3600) / 60);
        return h > 0 ? `${h}h ${m}m` : `${m}m`;
    }
    readonly property bool full: Battery.chargeState == 4
    readonly property real timeLeft: Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty
    readonly property bool hasTime: !(full || timeLeft <= 0 || Battery.energyRate <= 0.01)
    readonly property string stateText: full ? Translation.tr("Full")
        : Battery.isCharging ? Translation.tr("Charging")
        : Battery.isPluggedIn ? Translation.tr("Plugged in")
        : Translation.tr("On battery")

    // lok (2026-11-20): title over cards, same family as the resources popup. Material keeps the list.
    Loader {
        anchors.centerIn: parent
        sourceComponent: Appearance.lok ? root.lokContent : root.classicContent
    }

    property Component lokContent: Component {
        ColumnLayout {
            spacing: 8
            StyledPopupHeaderRow {
                icon: "battery_android_full"
                label: Translation.tr("Battery")
            }
            GridLayout {
                columns: 2
                rowSpacing: 5
                columnSpacing: 5
                uniformCellWidths: true
                Layout.fillWidth: true

                LokPopupCard {
                    symbol: Battery.isCharging ? "battery_charging_full" : "battery_android_full"
                    title: Translation.tr("Charge")
                    value: `${Math.round(Battery.percentage * 100)}%`
                    detail: root.stateText
                    fraction: Battery.percentage
                    warn: Battery.isLowAndNotCharging
                }
                LokPopupCard {
                    symbol: "schedule"
                    title: Battery.isCharging ? Translation.tr("To full") : Translation.tr("Remaining")
                    value: root.hasTime ? root.formatTime(root.timeLeft) : "—"
                    dim: !root.hasTime
                    detail: root.hasTime ? (Battery.isCharging ? Translation.tr("until full") : Translation.tr("at this rate")) : root.stateText
                }
                LokPopupCard {
                    symbol: "bolt"
                    title: Translation.tr("Power")
                    value: Battery.energyRate > 0.01 ? `${Battery.energyRate.toFixed(1)} W` : "—"
                    dim: Battery.energyRate <= 0.01
                    detail: Battery.energyRate <= 0.01 ? Translation.tr("idle") : Battery.isCharging ? Translation.tr("charging in") : Translation.tr("draw")
                }
                LokPopupCard {
                    readonly property int prof: PowerProfiles.profile
                    symbol: prof === PowerProfile.PowerSaver ? "energy_savings_leaf" : prof === PowerProfile.Performance ? "speed" : "balance"
                    title: Translation.tr("Power mode")
                    value: prof === PowerProfile.PowerSaver ? Translation.tr("Saver")
                        : prof === PowerProfile.Performance ? Translation.tr("Performance")
                        : Translation.tr("Balanced")
                    detail: prof === PowerProfile.PowerSaver ? Translation.tr("saves power")
                        : prof === PowerProfile.Performance ? Translation.tr("full speed")
                        : Translation.tr("default")
                }
            }
            StyledText { // health: a quiet footer, not a tile
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("Health %1% of design").arg(Math.round(Battery.health))
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }
    }

    property Component classicContent: Component {
        ColumnLayout {
            spacing: 4
            StyledPopupHeaderRow {
                icon: "battery_android_full"
                label: Translation.tr("Battery")
            }
            StyledPopupValueRow {
                visible: root.hasTime
                icon: "schedule"
                label: Battery.isCharging ? Translation.tr("Time to full:") : Translation.tr("Time to empty:")
                value: root.formatTime(root.timeLeft)
            }
            StyledPopupValueRow {
                visible: !(Battery.chargeState != 4 && Battery.energyRate == 0)
                icon: "bolt"
                label: root.full ? Translation.tr("Fully charged") : Battery.chargeState == 1 ? Translation.tr("Charging:") : Translation.tr("Discharging:")
                value: root.full ? "" : `${Battery.energyRate.toFixed(2)}W`
            }
            StyledPopupValueRow {
                icon: "heart_check"
                label: Translation.tr("Health:")
                value: `${(Battery.health).toFixed(1)}%`
            }
        }
    }
}
