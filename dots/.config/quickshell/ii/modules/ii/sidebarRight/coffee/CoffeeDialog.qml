import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

// Keep awake (coffee) settings: duration and whether the screen stays on too. See services/Idle.qml.
WindowDialog {
    id: root

    WindowDialogTitle {
        text: Translation.tr("Keep awake")
    }

    WindowDialogSeparator {}

    WindowDialogSectionHeader {
        text: Idle.inhibit
            ? (Idle.until > 0 ? Translation.tr("On · %1 left").arg(Idle.remainingText) : Translation.tr("On · no time limit"))
            : Translation.tr("Off · pick a duration to start")
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 3
        rowSpacing: 4
        columnSpacing: 4

        Repeater {
            model: [[1, "1 h"], [2, "2 h"], [4, "4 h"], [8, "8 h"], [12, "12 h"], [0, "∞"]]

            DialogButton {
                required property var modelData
                readonly property bool selected: Idle.inhibit && Idle.hours === modelData[0]
                Layout.fillWidth: true
                Layout.preferredWidth: 1 // equal segments
                buttonText: modelData[1]
                colBackground: selected ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colLayer3)
                colBackgroundHover: selected ? Appearance.colors.colPrimaryHover
                    : (Appearance.lok ? Appearance.colors.colLokDialogHover : Appearance.colors.colLayer3Hover)
                colText: selected ? Appearance.colors.colOnPrimary : Appearance.colors.colAccent
                borderColor: (Appearance.lok && selected) ? Appearance.colors.colSelectedEdge : Appearance.colors.colLokFrame
                onClicked: Idle.start(modelData[0])
            }
        }
    }

    WindowDialogSeparator {}

    ConfigSwitch {
        Layout.fillWidth: true
        iconSize: Appearance.font.pixelSize.larger
        buttonIcon: "monitor"
        text: Translation.tr("Keep the screen on")
        checked: Idle.keepScreen
        onCheckedChanged: if (checked !== Idle.keepScreen) Idle.setKeepScreen(checked)
    }

    WindowDialogParagraph {
        Layout.fillWidth: true
        text: Idle.keepScreen
            ? Translation.tr("The system and the screen stay on. Closing the lid still locks and turns the screen off; the system keeps running.")
            : Translation.tr("The system stays on; the screen still locks and turns off when idle. Closing the lid locks and turns the screen off; the system keeps running.")
            + " " + Translation.tr("Turns off by itself below 10% battery.")
    }

    WindowDialogSeparator { // footer divider like the other dialogs
        visible: Appearance.lok
    }
    WindowDialogButtonRow {
        DialogButton {
            buttonText: Translation.tr("Turn off")
            visible: Idle.inhibit
            onClicked: Idle.stop("")
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
