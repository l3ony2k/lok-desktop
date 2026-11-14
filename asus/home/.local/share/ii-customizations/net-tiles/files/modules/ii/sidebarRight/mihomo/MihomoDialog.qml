import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

WindowDialog {
    id: root
    backgroundHeight: 520

    component InfoRow: RowLayout {
        required property string icon
        required property string label
        required property string value

        Layout.fillWidth: true
        spacing: 10

        MaterialSymbol {
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colOnSurfaceVariant
            text: icon
        }

        StyledText {
            Layout.fillWidth: true
            color: Appearance.colors.colOnSurfaceVariant
            font.pixelSize: Appearance.font.pixelSize.smaller
            elide: Text.ElideRight
            text: label
        }

        StyledText {
            color: Appearance.colors.colOnSurface
            font.pixelSize: Appearance.font.pixelSize.smaller
            elide: Text.ElideRight
            text: value
        }
    }

    WindowDialogTitle {
        text: Translation.tr("Mihomo")
    }

    WindowDialogSeparator {}

    // ---- Status --------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        MaterialSymbol {
            iconSize: Appearance.font.pixelSize.larger
            color: Mihomo.active ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
            text: Mihomo.icon
        }

        StyledText {
            Layout.fillWidth: true
            color: Appearance.colors.colOnSurface
            font.pixelSize: Appearance.font.pixelSize.small
            elide: Text.ElideRight
            text: Mihomo.version.length > 0 ? "Mihomo " + Mihomo.version : "Mihomo"
        }

        StyledText {
            color: Mihomo.active ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smaller
            text: Mihomo.statusText
        }
    }

    // ---- Info ----------------------------------------------------------
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4
        visible: Mihomo.active && Mihomo.infoReady

        InfoRow {
            icon: "tune"
            label: Translation.tr("Mode")
            value: Mihomo.mode
        }
        InfoRow {
            icon: "vpn_lock"
            label: Translation.tr("TUN")
            value: Mihomo.tunEnabled ? Translation.tr("On") : Translation.tr("Off")
        }
        InfoRow {
            icon: "lan"
            label: Translation.tr("HTTP port")
            value: Mihomo.port > 0 ? String(Mihomo.port) : "—"
        }
        InfoRow {
            icon: "public"
            label: Translation.tr("Current node")
            value: Mihomo.currentNode || "—"
        }
        InfoRow {
            icon: "link"
            label: Translation.tr("Connections")
            value: String(Mihomo.connectionCount)
        }
        InfoRow {
            icon: "swap_vert"
            label: Translation.tr("Traffic")
            value: "↑ " + Mihomo.formatBytes(Mihomo.uploadTotal) + "   ↓ " + Mihomo.formatBytes(Mihomo.downloadTotal)
        }
    }

    WindowDialogParagraph {
        Layout.fillWidth: true
        visible: !Mihomo.installed
        text: Translation.tr("The mihomo package is not installed. Run `sudo pacman -S --needed mihomo` to enable this toggle.")
    }

    WindowDialogParagraph {
        Layout.fillWidth: true
        visible: Mihomo.installed && !Mihomo.active
        text: Translation.tr("The mihomo service is not running. Use the switch below to start it.")
    }

    WindowDialogSeparator {}

    // ---- Quick actions -------------------------------------------------
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6

        StyledText {
            color: Appearance.colors.colOnSurfaceVariant
            font.pixelSize: Appearance.font.pixelSize.smaller
            text: Translation.tr("Routing mode")
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
                model: [["rule", Translation.tr("Rule")], ["global", Translation.tr("Global")], ["direct", Translation.tr("Direct")]]

                DialogButton {
                    required property var modelData
                    Layout.fillWidth: true
                    buttonText: modelData[1]
                    enabled: Mihomo.active
                    colBackground: Mihomo.mode === modelData[0]
                        ? Appearance.colors.colPrimary
                        : ColorUtils.transparentize(Appearance.colors.colLayer3)
                    colBackgroundHover: Mihomo.mode === modelData[0]
                        ? Appearance.colors.colPrimaryHover
                        : Appearance.colors.colLayer3Hover
                    colText: Mihomo.mode === modelData[0]
                        ? Appearance.colors.colOnPrimary
                        : Appearance.colors.colPrimary
                    onClicked: Mihomo.setMode(modelData[0])
                }
            }
        }

        ConfigSwitch {
            buttonIcon: "power_settings_new"
            text: Translation.tr("mihomo service")
            enabled: !Mihomo.busy && Mihomo.installed
            checked: Mihomo.active
            onClicked: Mihomo.toggle()
        }
    }

    WindowDialogSeparator {}

    WindowDialogButtonRow {
        DialogButton {
            buttonText: Translation.tr("Refresh")
            onClicked: Mihomo.refresh()
        }

        Item {
            Layout.fillWidth: true
        }

        DialogButton {
            buttonText: Translation.tr("Open dashboard")
            enabled: Mihomo.active
            onClicked: {
                Mihomo.openDashboard();
                root.dismiss();
            }
        }

        DialogButton {
            buttonText: Translation.tr("Done")
            onClicked: root.dismiss()
        }
    }
}