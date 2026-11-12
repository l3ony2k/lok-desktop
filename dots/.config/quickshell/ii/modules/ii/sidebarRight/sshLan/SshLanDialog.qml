import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

WindowDialog {
    id: root
    backgroundHeight: 500

    onShowChanged: {
        if (root.show)
            SshLan.clearError();
    }

    WindowDialogTitle {
        text: Translation.tr("SSH over LAN")
    }

    WindowDialogSeparator {}

    // ---- Status --------------------------------------------------------
    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        MaterialSymbol {
            Layout.alignment: Qt.AlignTop
            iconSize: Appearance.font.pixelSize.larger
            color: SshLan.active ? Appearance.colors.colAccent : Appearance.colors.colSubtext
            text: "terminal"
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2

            StyledText {
                Layout.fillWidth: true
                color: Appearance.colors.colOnSurface
                font.pixelSize: Appearance.font.pixelSize.small
                text: SshLan.statusText
            }

            StyledText {
                Layout.fillWidth: true
                color: Appearance.colors.colOnSurfaceVariant
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.Wrap
                text: {
                    if (SshLan.setupMissing)
                        return Translation.tr("Root helper is not installed.");
                    if (SshLan.active)
                        return Translation.tr("tcp/22 allowed from %1").arg(SshLan.activeFrom || SshLan.allowedRange);
                    return Translation.tr("No ufw rule for tcp/22 from the local network.");
                }
            }

            StyledText {
                Layout.fillWidth: true
                color: SshLan.rootLogin === "yes" && SshLan.rootPassword === "locked"
                    ? Appearance.colors.colError
                    : Appearance.colors.colOnSurfaceVariant
                font.pixelSize: Appearance.font.pixelSize.smaller
                wrapMode: Text.Wrap
                text: {
                    if (SshLan.rootLogin !== "yes")
                        return Translation.tr("Root password login: off (enabled with the toggle above)");
                    if (SshLan.rootPassword === "locked")
                        return Translation.tr("Root password login: on, but root has no password — run sudo passwd root");
                    return Translation.tr("Root password login: on, allowed from the range above");
                }
            }
        }
    }

    ConfigSwitch {
        buttonIcon: "power_settings_new"
        text: Translation.tr("Allow SSH from the local network")
        enabled: !SshLan.busy && !SshLan.setupMissing
        checked: SshLan.active
        onClicked: {
            if (SshLan.active)
                SshLan.disable();
            else
                SshLan.enable();
        }
    }

    WindowDialogSeparator {}

    // ---- Allowed range -------------------------------------------------
    WindowDialogSectionHeader {
        text: Translation.tr("Allowed range")
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        MaterialTextField {
            id: rangeField
            Layout.fillWidth: true
            placeholderText: "192.168.1.0/24"
            Component.onCompleted: text = SshLan.allowedRange
            onAccepted: SshLan.setRange(text)
        }

        DialogButton {
            buttonText: Translation.tr("Apply")
            enabled: !SshLan.busy
            onClicked: SshLan.setRange(rangeField.text)
        }
    }

    WindowDialogParagraph {
        Layout.fillWidth: true
        text: Translation.tr("Private ranges only: 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16, 100.64.0.0/10 (Tailscale).")
    }

    WindowDialogParagraph {
        Layout.fillWidth: true
        visible: SshLan.lastError.length > 0
        color: Appearance.colors.colError
        text: SshLan.lastError
    }

    WindowDialogParagraph {
        Layout.fillWidth: true
        visible: SshLan.setupMissing
        color: Appearance.colors.colError
        text: Translation.tr("Run once: sudo ~/.local/share/ssh-lan-toggle/install.sh")
    }

    WindowDialogParagraph {
        Layout.fillWidth: true
        visible: SshLan.lanAddress.length > 0 && SshLan.sshdState === "active"
        text: Translation.tr("From another device: ssh %1@%2").arg(Quickshell.env("USER") || "leon").arg(SshLan.lanAddress)
    }

    WindowDialogButtonRow {
        Item {
            Layout.fillWidth: true
        }

        DialogButton {
            buttonText: Translation.tr("Done")
            onClicked: root.dismiss()
        }
    }
}
