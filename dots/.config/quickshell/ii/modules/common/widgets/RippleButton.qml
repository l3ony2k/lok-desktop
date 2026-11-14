import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls

/**
 * A button with ripple effect similar to in Material Design.
 */
Button {
    id: root
    property bool toggled
    // Shell font by default, so contentItems that copy `font: root.font` don't fall back to Qt's system font
    font.family: Appearance?.font.family.main ?? "sans-serif"
    property string buttonText
    property bool pointingHandCursor: true
    property real buttonRadius: Appearance?.rounding?.small ?? 4
    property real buttonRadiusPressed: buttonRadius
    // lok: square everywhere, whatever radius a subclass computes (e.g. height / 2)
    property real buttonEffectiveRadius: (Appearance?.lok ?? false) ? 0 : root.down ? root.buttonRadiusPressed : root.buttonRadius
    property int rippleDuration: 1200
    // lok style: no ripple; pressing fills the button with the press colour instead
    property bool rippleEnabled: !(Appearance?.lok ?? false)
    property var downAction // When left clicking (down)
    property var releaseAction // When left clicking (release)
    property var altAction // When right clicking
    property var middleClickAction // When middle clicking

    property color colBackground: ColorUtils.transparentize(Appearance?.colors.colLayer1Hover, 1) || "transparent"
    property color colBackgroundHover: Appearance?.colors.colLayer1Hover ?? "#E5DFED"
    property color colBackgroundToggled: Appearance?.colors.colPrimary ?? "#65558F"
    property color colBackgroundToggledHover: Appearance?.colors.colPrimaryHover ?? "#77699C"
    property color colRipple: Appearance?.colors.colLayer1Active ?? "#D6CEE2"
    property color colRippleToggled: Appearance?.colors.colPrimaryActive ?? "#D6CEE2"

    opacity: root.enabled ? 1 : 0.4
    property color buttonColor: ColorUtils.transparentize(
        ((Appearance?.lok ?? false) && root.down) ? root.rippleColor :
        root.toggled ? 
        // lok: selection wins over hover -- hovering a selected button keeps its selected fill, one step lighter
        (root.hovered ? ((Appearance?.lok ?? false) ? ColorUtils.mix(colBackgroundToggled, Appearance.m3colors.m3onSurface, 0.92) : colBackgroundToggledHover) : 
            colBackgroundToggled) :
        (root.hovered ? colBackgroundHover : 
            colBackground), root.enabled ? 0 : 1)
    property color rippleColor: root.toggled ? colRippleToggled : colRipple
    property real borderWidth: 0
    property color borderColor: "transparent"

    function startRipple(x, y) {
        const stateY = buttonBackground.y;
        rippleAnim.x = x;
        rippleAnim.y = y - stateY;

        const dist = (ox,oy) => ox*ox + oy*oy
        const stateEndY = stateY + buttonBackground.height
        rippleAnim.radius = Math.sqrt(Math.max(dist(0, stateY), dist(0, stateEndY), dist(width, stateY), dist(width, stateEndY)))

        rippleFadeAnim.complete();
        rippleAnim.restart();
    }

    component RippleAnim: NumberAnimation {
        duration: rippleDuration
        easing.type: Appearance?.animation.elementMoveEnter.type
        easing.bezierCurve: Appearance?.animationCurves.standardDecel
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: root.pointingHandCursor ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: (event) => { 
            if(event.button === Qt.RightButton) {
                if (root.altAction) root.altAction(event);
                return;
            }
            if(event.button === Qt.MiddleButton) {
                if (root.middleClickAction) root.middleClickAction();
                return;
            }
            root.down = true
            if (root.downAction) root.downAction();
            if (!root.rippleEnabled) return;
            const {x,y} = event
            startRipple(x, y)
        }
        onReleased: (event) => {
            root.down = false
            if (event.button != Qt.LeftButton) return;
            if (root.releaseAction) root.releaseAction();
            root.click() // Because the MouseArea already consumed the event
            if (!root.rippleEnabled) return;
            rippleFadeAnim.restart();
        }
        onCanceled: (event) => {
            root.down = false
            if (!root.rippleEnabled) return;
            rippleFadeAnim.restart();
        }
    }

    RippleAnim {
        id: rippleFadeAnim
        duration: rippleDuration * 2
        target: ripple
        property: "opacity"
        to: 0
    }

    SequentialAnimation {
        id: rippleAnim

        property real x
        property real y
        property real radius

        PropertyAction {
            target: ripple
            property: "x"
            value: rippleAnim.x
        }
        PropertyAction {
            target: ripple
            property: "y"
            value: rippleAnim.y
        }
        PropertyAction {
            target: ripple
            property: "opacity"
            value: 1
        }
        ParallelAnimation {
            RippleAnim {
                target: ripple
                properties: "implicitWidth,implicitHeight"
                from: 0
                to: rippleAnim.radius * 2
            }
        }
    }

    background: Rectangle {
        id: buttonBackground
        radius: (Appearance?.lok ?? false) ? 0 : root.buttonEffectiveRadius
        implicitHeight: 30

        color: root.buttonColor
        border.width: (Appearance?.lok ?? false) ? 0 : root.borderWidth // lok: LokFrame below
        LokFrame { visible: (Appearance?.lok ?? false) && root.borderWidth > 0; z: 99; color: root.borderColor }
        border.color: root.borderColor
        Behavior on color {
            animation: Appearance?.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        // lok: corners are square, so the rounded mask is useless, and its offscreen texture
        // snaps to device pixels and covers the right/bottom hairline of frames on the button
        layer.enabled: !(Appearance?.lok ?? false)
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: buttonBackground.width
                height: buttonBackground.height
                radius: (Appearance?.lok ?? false) ? 0 : root.buttonEffectiveRadius
            }
        }

        Item {
            id: ripple
            width: ripple.implicitWidth
            height: ripple.implicitHeight
            opacity: 0
            visible: width > 0 && height > 0

            property real implicitWidth: 0
            property real implicitHeight: 0

            Behavior on opacity {
                animation: Appearance?.animation.elementMoveFast.colorAnimation.createObject(this)
            }

            RadialGradient {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.rippleColor }
                    GradientStop { position: 0.3; color: root.rippleColor }
                    GradientStop { position: 0.5; color: Qt.rgba(root.rippleColor.r, root.rippleColor.g, root.rippleColor.b, 0) }
                }
            }

            transform: Translate {
                x: -ripple.width / 2
                y: -ripple.height / 2
            }
        }
    }

    contentItem: StyledText {
        text: root.buttonText
    }
}
