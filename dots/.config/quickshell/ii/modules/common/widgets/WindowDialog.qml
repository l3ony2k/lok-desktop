import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Rectangle {
    id: root

    property bool show: false
    default property alias contentData: contentColumn.data
    // content-sized unless a dialog sets a fixed height; the screen caps it only when this
    // item has a size (polkit centres a zero-size WindowDialog, which hid the dialog entirely)
    property real backgroundHeight: root.height > 0 ? Math.min(dialogBackground.naturalHeight, root.height) : dialogBackground.naturalHeight
    property real backgroundWidth: 350
    property real backgroundAnimationMovementDistance: 60
    
    signal dismiss()
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            root.dismiss();
            event.accepted = true;
        }
    }

    color: root.show ? Appearance.colors.colScrim : ColorUtils.transparentize(Appearance.colors.colScrim)
    Behavior on color {
        animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
    }
    visible: dialogBackground.implicitHeight > 0

    onShowChanged: {
        dialogBackgroundHeightAnimation.easing.bezierCurve = (show ? Appearance.animationCurves.emphasizedDecel : Appearance.animationCurves.emphasizedAccel)
    }

    radius: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1

    MouseArea { // Clicking outside the dialog should dismiss
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        hoverEnabled: true
        onPressed: root.dismiss()
    }

    Rectangle {
        id: dialogBackground
        anchors.horizontalCenter: parent.horizontalCenter
        radius: Appearance.rounding.large
        color: Appearance.lok ? Appearance.colors.colLokDialog : Appearance.m3colors.m3surfaceContainerHigh // Use opaque version of layer3
        
        property real targetY: root.height / 2 - root.backgroundHeight / 2
        y: root.show ? targetY : (targetY - root.backgroundAnimationMovementDistance)
        // At least backgroundWidth, wider when the content needs it (wider fonts, translations), never past the screen
        readonly property real wantedWidth: Math.max(root.backgroundWidth, contentColumn.implicitWidth + dialogBackground.padding * 2)
        implicitWidth: root.width > 0 ? Math.min(root.width - 2 * Appearance.sizes.hyprlandGapsOut, wantedWidth) : wantedWidth
        clip: true
        property real padding: Appearance.lok ? Appearance.roundingSpace.large : dialogBackground.radius
        // Declarative so the dialog keeps following its content (wrapped or changing text) while open
        property real naturalHeight: contentColumn.implicitHeight + dialogBackground.padding * 2
        implicitHeight: root.show ? root.backgroundHeight : 0
        border.width: Appearance.lok ? Appearance.sizes.hairline : 0
        border.color: Appearance.colors.colLokFrame
        Behavior on implicitHeight {
            NumberAnimation {
                id: dialogBackgroundHeightAnimation
                duration: Appearance.animation.elementMoveFast.duration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.emphasizedDecel
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: dialogBackgroundHeightAnimation.duration
                easing.type: dialogBackgroundHeightAnimation.easing.type
                easing.bezierCurve: dialogBackgroundHeightAnimation.easing.bezierCurve
            }
        }

        MouseArea { // So clicking inside the dialog won't dismiss
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true
        }

        ColumnLayout {
            id: contentColumn
            anchors {
                fill: parent
                margins: dialogBackground.padding
            }
            spacing: 16
            opacity: root.show ? 1 : 0
            Behavior on opacity {
                animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
            }

        }
    }
}
