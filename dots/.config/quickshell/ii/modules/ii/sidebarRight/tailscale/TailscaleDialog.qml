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
    backgroundHeight: 600

    WindowDialogTitle {
        text: Translation.tr("Tailscale")
    }

    WindowDialogSeparator {}

    // ---- This device ---------------------------------------------------
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            MaterialSymbol {
                iconSize: Appearance.font.pixelSize.larger
                color: Tailscale.running ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                text: Tailscale.icon
            }

            StyledText {
                Layout.fillWidth: true
                color: Appearance.colors.colOnSurface
                font.pixelSize: Appearance.font.pixelSize.small
                elide: Text.ElideRight
                text: Tailscale.hostName || Translation.tr("No device name")
            }

            StyledText {
                color: Tailscale.running ? Appearance.colors.colPrimary : Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
                text: Tailscale.statusText
            }
        }

        Loader {
            Layout.fillWidth: true
            active: Tailscale.selfAddresses.length > 0
            visible: active
            sourceComponent: StyledText {
                color: Appearance.colors.colOnSurfaceVariant
                font.pixelSize: Appearance.font.pixelSize.smaller
                elide: Text.ElideRight
                text: Tailscale.selfAddresses.join("  ·  ")
            }
        }

        Loader {
            Layout.fillWidth: true
            active: Tailscale.dnsName.length > 0
            visible: active
            sourceComponent: ConfigRow {
                MaterialSymbol {
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnSurfaceVariant
                    text: "public"
                }
                StyledText {
                    Layout.fillWidth: true
                    color: Appearance.colors.colOnSurfaceVariant
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    elide: Text.ElideRight
                    text: Tailscale.dnsName
                }
                IconToolbarButton {
                    Layout.fillHeight: false
                    text: "content_copy"
                    implicitWidth: 32
                    implicitHeight: 32
                    onClicked: Tailscale.copyText(Tailscale.dnsName)
                }
            }
        }

        WindowDialogParagraph {
            Layout.fillWidth: true
            visible: Tailscale.lastError.length > 0
            text: Tailscale.lastError
            color: Appearance.colors.colError
        }

        WindowDialogParagraph {
            Layout.fillWidth: true
            visible: !Tailscale.installed || !Tailscale.daemonActive || Tailscale.needsLogin
            text: !Tailscale.installed
                ? Translation.tr("The tailscale package is not installed. Run `sudo pacman -S --needed tailscale` to enable this toggle.")
                : !Tailscale.daemonActive
                ? Translation.tr("The tailscaled service is not running. Use the switch above to start it.")
                : Translation.tr("This node needs to log in. Run `sudo tailscale up` in a terminal (or use the switch).")
        }
    }

    WindowDialogSeparator {}

    // ---- Controls ------------------------------------------------------
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 4

        ConfigSwitch {
            buttonIcon: "power_settings_new"
            text: Translation.tr("tailscaled service")
            enabled: !Tailscale.busy && Tailscale.installed
            checked: Tailscale.daemonActive
            onClicked: {
                if (Tailscale.daemonActive)
                    Tailscale.stopDaemon();
                else
                    Tailscale.startDaemon();
            }
        }

        ConfigSwitch {
            buttonIcon: "link"
            text: Translation.tr("Connect to tailnet")
            enabled: !Tailscale.busy && Tailscale.daemonActive && Tailscale.installed
            checked: Tailscale.running
            onClicked: {
                if (Tailscale.running)
                    Tailscale.disconnectNow();
                else
                    Tailscale.connectNow();
            }
        }
    }

    WindowDialogSeparator {}

    // ---- Peers ---------------------------------------------------------
    WindowDialogSectionHeader {
        text: Translation.tr("Peers")
    }

    ListView {
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.topMargin: -15
        Layout.bottomMargin: -16
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large
        clip: true
        spacing: 0

        model: ScriptModel {
            values: Tailscale.peers
        }

        delegate: DialogListItem {
            id: peerItem
            required property var modelData
            width: ListView.view.width
            active: (modelData.connected ?? false) || false

            contentItem: RowLayout {
                spacing: 10

                MaterialSymbol {
                    iconSize: Appearance.font.pixelSize.larger
                    color: {
                        if (modelData.isSelf)
                            return Appearance.colors.colPrimary;
                        return modelData.online ? Appearance.colors.colOnSurface : Appearance.colors.colSubtext;
                    }
                    text: {
                        if (modelData.isSelf)
                            return "computer";
                        switch (modelData.os) {
                        case "android":
                        case "ios":
                            return "smartphone";
                        default:
                            return "devices";
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: -2

                    StyledText {
                        Layout.fillWidth: true
                        color: Appearance.colors.colOnSurface
                        font.pixelSize: Appearance.font.pixelSize.small
                        elide: Text.ElideRight
                        text: modelData.hostName + (modelData.isSelf ? "  •" : "")
                    }

                    StyledText {
                        Layout.fillWidth: true
                        color: Appearance.colors.colOnSurfaceVariant
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        elide: Text.ElideRight
                        text: {
                            if (modelData.isSelf)
                                return Translation.tr("this device");
                            const ips = modelData.ips ?? [];
                            const parts = [];
                            if (ips.length > 0)
                                parts.push(ips[0]);
                            if (modelData.online && modelData.relay)
                                parts.push(modelData.relay);
                            if (!modelData.online)
                                parts.push(Translation.tr("offline"));
                            return parts.join("  ·  ");
                        }
                    }
                }

                IconToolbarButton {
                    visible: (modelData.ips ?? []).length > 0
                    Layout.fillHeight: false
                    text: "content_copy"
                    implicitWidth: 32
                    implicitHeight: 32
                    onClicked: Tailscale.copyText((modelData.ips ?? [])[0])
                }
            }
        }
    }

    Loader {
        Layout.fillWidth: true
        active: Tailscale.daemonActive && Tailscale.peers.length <= 1
        visible: active
        sourceComponent: WindowDialogParagraph {
            Layout.fillWidth: true
            text: Translation.tr("No other devices yet. Add one at tailscale.com/admin or run `tailscale up` on another machine.")
        }
    }

    WindowDialogSeparator {}

    WindowDialogButtonRow {
        DialogButton {
            buttonText: Translation.tr("Refresh")
            onClicked: Tailscale.refresh()
        }

        Item {
            Layout.fillWidth: true
        }

        DialogButton {
            buttonText: Translation.tr("Done")
            onClicked: root.dismiss()
        }
    }
}