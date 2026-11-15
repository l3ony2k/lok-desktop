import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

WindowDialog {
    id: root

    WindowDialogTitle {
        text: Translation.tr("Window gaps")
    }

    WindowDialogSeparator {}

    WindowDialogSectionHeader {
        text: Translation.tr("Mode")
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Repeater {
            model: [["none", Translation.tr("None")], ["small", Translation.tr("Small")], ["large", Translation.tr("Large")]]

            DialogButton {
                required property var modelData
                readonly property bool selected: WindowGaps.mode === modelData[0]
                Layout.fillWidth: true
                Layout.preferredWidth: 1 // equal segments
                buttonText: modelData[1]
                enabled: WindowGaps.enabled
                colBackground: selected ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colLayer3)
                colBackgroundHover: selected ? Appearance.colors.colPrimaryHover
                    : (Appearance.lok ? Appearance.colors.colLokDialogHover : Appearance.colors.colLayer3Hover)
                colText: selected ? Appearance.colors.colOnPrimary : Appearance.colors.colAccent
                borderColor: (Appearance.lok && selected) ? Appearance.colors.colSelectedEdge
                    : (enabled ? Appearance.colors.colLokFrame : Appearance.colors.colLokDivider)
                onClicked: WindowGaps.setMode(modelData[0])
            }
        }
    }

    WindowDialogSeparator {}

    WindowDialogSectionHeader {
        text: Translation.tr("Sizes")
    }

    ConfigSpinBox {
        icon: "empty_dashboard"
        text: Translation.tr("Small (px)")
        enabled: WindowGaps.enabled
        from: 1
        to: 96
        stepSize: 1
        value: Config.options.windowGaps.small
        onValueChanged: WindowGaps.setSize("small", value)
    }

    ConfigSpinBox {
        icon: "empty_dashboard"
        text: Translation.tr("Large (px)")
        enabled: WindowGaps.enabled
        from: 1
        to: 96
        stepSize: 1
        value: Config.options.windowGaps.large
        onValueChanged: WindowGaps.setSize("large", value)
    }

    WindowDialogParagraph {
        Layout.fillWidth: true
        text: WindowGaps.enabled
            ? Translation.tr("None: neighbouring windows share one border line. Small and Large: the gap to the screen edges and the bar, and about the same between windows. Small 27 lines windows up with the workspace indicator.")
            : Translation.tr("Only used with the lok palette.")
    }

    WindowDialogSeparator { // footer divider like the other dialogs
        visible: Appearance.lok
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
