import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower

Item {
    id: root
    property bool borderless: Config.options.bar.borderless
    // all buttons can be switched off; an empty group must not keep its padding
    property bool vertical: false // vertical bar: one column
    readonly property bool hasContent: rowLayout.implicitWidth > 0
    // lok: no extra side padding; the 26 px buttons already pad their glyphs
    implicitWidth: vertical ? rowLayout.implicitWidth : (hasContent ? rowLayout.implicitWidth + (Appearance.lok ? 0 : rowLayout.spacing * 2) : 0)
    implicitHeight: (vertical && !hasContent) ? 0 : rowLayout.implicitHeight

    GridLayout {
        id: rowLayout

        readonly property real spacing: 4
        columns: root.vertical ? 1 : -1
        rowSpacing: spacing
        columnSpacing: spacing
        anchors.centerIn: parent

        Loader {
            active: Config.options.bar.utilButtons.showScreenSnip
            visible: Config.options.bar.utilButtons.showScreenSnip
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                onClicked: Quickshell.execDetached(["qs", "-p", Quickshell.shellPath(""), "ipc", "call", "region", "screenshot"]);
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 1
                    text: "screenshot_region"
                    // lok: this glyph draws ~2 px smaller than its neighbours at the same size
                    iconSize: Appearance.lok ? Appearance.font.pixelSize.larger + 2 : Appearance.font.pixelSize.large
                    color: Appearance.lok ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer2 // lok: same status-glyph look as battery/weather
                }
            }
        }

        Loader {
            active: Config.options.bar.utilButtons.showScreenRecord
            visible: Config.options.bar.utilButtons.showScreenRecord
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                onClicked: Quickshell.execDetached([Directories.recordScriptPath])
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 1
                    text: "videocam"
                    iconSize: Appearance.lok ? Appearance.font.pixelSize.larger : Appearance.font.pixelSize.large
                    color: Appearance.lok ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer2 // lok: same status-glyph look as battery/weather
                }
            }
        }

        Loader {
            active: Config.options.bar.utilButtons.showColorPicker
            visible: Config.options.bar.utilButtons.showColorPicker
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                onClicked: Quickshell.execDetached(["hyprpicker", "-a"])
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 1
                    text: "colorize"
                    iconSize: Appearance.lok ? Appearance.font.pixelSize.larger : Appearance.font.pixelSize.large
                    color: Appearance.lok ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer2 // lok: same status-glyph look as battery/weather
                }
            }
        }

        Loader {
            active: Config.options.bar.utilButtons.showKeyboardToggle
            visible: Config.options.bar.utilButtons.showKeyboardToggle
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                onClicked: GlobalStates.oskOpen = !GlobalStates.oskOpen
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 0
                    text: "keyboard"
                    iconSize: Appearance.lok ? Appearance.font.pixelSize.larger : Appearance.font.pixelSize.large
                    color: Appearance.lok ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer2 // lok: same status-glyph look as battery/weather
                }
            }
        }

        Loader {
            active: Config.options.bar.utilButtons.showMicToggle
            visible: Config.options.bar.utilButtons.showMicToggle
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                onClicked: Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_SOURCE@", "toggle"])
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 0
                    text: Pipewire.defaultAudioSource?.audio?.muted ? "mic_off" : "mic"
                    iconSize: Appearance.lok ? Appearance.font.pixelSize.larger : Appearance.font.pixelSize.large
                    color: Appearance.lok ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer2 // lok: same status-glyph look as battery/weather
                }
            }
        }

        Loader {
            active: Config.options.bar.utilButtons.showDarkModeToggle
            visible: Config.options.bar.utilButtons.showDarkModeToggle
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                onClicked: event => {
                    if (Appearance.m3colors.darkmode) {
                        Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --mode light --noswitch`])
                    } else {
                        Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --mode dark --noswitch`])
                    }
                }
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 0
                    text: Appearance.m3colors.darkmode ? "light_mode" : "dark_mode"
                    iconSize: Appearance.lok ? Appearance.font.pixelSize.larger : Appearance.font.pixelSize.large
                    color: Appearance.lok ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer2 // lok: same status-glyph look as battery/weather
                }
            }
        }

        Loader {
            // lok merges the power mode into the battery item (when a battery exists)
            readonly property bool merged: Appearance.lok && Battery.available
            active: Config.options.bar.utilButtons.showPerformanceProfileToggle && !merged
            visible: active
            sourceComponent: CircleUtilButton {
                Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                onClicked: event => {
                    if (PowerProfiles.hasPerformanceProfile) {
                        switch(PowerProfiles.profile) {
                            case PowerProfile.PowerSaver: PowerProfiles.profile = PowerProfile.Balanced
                            break;
                            case PowerProfile.Balanced: PowerProfiles.profile = PowerProfile.Performance
                            break;
                            case PowerProfile.Performance: PowerProfiles.profile = PowerProfile.PowerSaver
                            break;
                        }
                    } else {
                        PowerProfiles.profile = PowerProfiles.profile == PowerProfile.Balanced ? PowerProfile.PowerSaver : PowerProfile.Balanced
                    }
                }
                MaterialSymbol {
                    horizontalAlignment: Qt.AlignHCenter
                    fill: 0
                    text: switch(PowerProfiles.profile) {
                        case PowerProfile.PowerSaver: return "energy_savings_leaf"
                        case PowerProfile.Balanced: return "airwave"
                        case PowerProfile.Performance: return "local_fire_department"
                    }
                    iconSize: Appearance.lok ? Appearance.font.pixelSize.larger : Appearance.font.pixelSize.large
                    color: Appearance.lok ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer2 // lok: same status-glyph look as battery/weather
                }
            }
        }
    }
}
