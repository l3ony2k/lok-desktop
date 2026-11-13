import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: button

    property string buttonIcon
    property string buttonText
    property bool keyboardDown: false
    property real size: 120

    buttonRadius: (button.focus || button.down) ? size / 2 : Appearance.rounding.verylarge
    // lok: same language as the quick toggles. Idle = dialog surface, dim
    // frame, grey icon. Selected (keyboard focus or hover) = raised fill,
    // bright frame, bright icon, 2 px status strip.
    // hover alone = one step raised fill + bright icon, no frame/strip (never a second selection)
    readonly property bool lokSelected: button.focus || button.down || button.keyboardDown
    colBackground: Appearance.lok ? (button.keyboardDown ? Appearance.colors.colPrimaryActive
            : button.focus ? Appearance.colors.colPrimary : Appearance.colors.colLokDialog)
        : button.keyboardDown ? Appearance.colors.colSecondaryContainerActive :
        button.focus ? Appearance.colors.colPrimary :
        Appearance.colors.colSecondaryContainer
    colBackgroundHover: Appearance.lok ? (button.focus ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer3) : Appearance.colors.colPrimary
    colRipple: Appearance.colors.colPrimaryActive
    property color colText: Appearance.lok ? ((button.lokSelected || button.hovered) ? Appearance.colors.colOnLayer0 : Appearance.colors.colSubtext)
        : (button.down || button.keyboardDown || button.focus || button.hovered) ?
        Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer0
    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
    background.implicitHeight: size
    background.implicitWidth: size

    Behavior on buttonRadius {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            keyboardDown = true
            button.clicked()
            event.accepted = true;
        }
    }
    Keys.onReleased: (event) => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            keyboardDown = false
            event.accepted = true;
        }
    }

    contentItem: MaterialSymbol {
        id: icon
        anchors.fill: parent
        color: button.colText
        horizontalAlignment: Text.AlignHCenter
        iconSize: 45
        text: buttonIcon
    }

    LokFrame {
        visible: Appearance.lok
        z: 2
        color: button.lokSelected ? Appearance.colors.colSelectedEdge : Appearance.colors.colLokDivider
    }
    Rectangle { // lok status strip
        visible: Appearance.lok && button.lokSelected
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        height: 2 * Appearance.sizes.hairline
        z: 2
        color: Appearance.colors.colSelectedEdge
    }
    StyledToolTip {
        text: buttonText
    }

}
