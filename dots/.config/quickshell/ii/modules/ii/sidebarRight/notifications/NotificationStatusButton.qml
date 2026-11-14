import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

GroupButton {
    id: button
    property string buttonIcon: ""
    property string buttonText: ""

    baseHeight: 36
    baseWidth: content.implicitWidth + 46
    clickedWidth: baseWidth + 6

    buttonRadius: Appearance.lok ? 0 : baseHeight / 2
    buttonRadiusPressed: Appearance.rounding.small
    colBackground: Appearance.lok ? "transparent" : Appearance.colors.colLayer2 // lok: outlined inside the card
    lokOutline: true
    colBackgroundHover: Appearance.lok ? Appearance.colors.colLayer3 : Appearance.colors.colLayer2Hover
    colBackgroundActive: Appearance.colors.colLayer2Active
    property color colText: toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1

    contentItem: Item {
        id: content
        anchors.fill: parent
        implicitWidth: contentRowLayout.implicitWidth
        implicitHeight: contentRowLayout.implicitHeight
        RowLayout {
            id: contentRowLayout
            anchors.centerIn: parent
            spacing: 5
            MaterialSymbol {
                visible: buttonIcon !== ""
                text: buttonIcon
                iconSize: Appearance.font.pixelSize.huge
                color: button.colText
            }
            StyledText {
                visible: buttonText !== ""
                text: buttonText
                font.pixelSize: Appearance.font.pixelSize.small
                color: button.colText
            }
        }
    }

}