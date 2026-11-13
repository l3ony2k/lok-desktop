import qs.modules.common.widgets
import qs.modules.common
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

RippleButton {
    id: root
    property string buttonIcon
    property alias iconSize: iconWidget.iconSize

    Layout.fillWidth: true
    implicitHeight: contentItem.implicitHeight + 8 * 2
    font.pixelSize: Appearance.font.pixelSize.small
    // lok: icon, label and switch sit on the content edges like every other dialog row;
    // the 10 px padding (hover fill) bleeds outwards instead of indenting the content
    Binding on leftPadding { when: Appearance.lok; value: 10 }
    Binding on rightPadding { when: Appearance.lok; value: 10 }
    Layout.leftMargin: Appearance.lok ? -10 : 0
    Layout.rightMargin: Appearance.lok ? -10 : 0
    
    onClicked: checked = !checked

    contentItem: RowLayout {
        spacing: 10
        OptionalMaterialSymbol {
            id: iconWidget
            icon: root.buttonIcon
            opacity: root.enabled ? 1 : 0.4
            iconSize: Appearance.font.pixelSize.larger
        }
        StyledText {
            id: labelWidget
            Layout.fillWidth: true
            text: root.text
            font.pixelSize: root.font.pixelSize
            wrapMode: Text.Wrap
            color: Appearance.colors.colOnSecondaryContainer
            opacity: root.enabled ? 1 : 0.4
        }
        StyledSwitch {
            id: switchWidget
            down: root.down
            Layout.fillWidth: false
            Layout.alignment: Qt.AlignVCenter
            checked: root.checked
            onClicked: root.clicked()
        }
    }
}

