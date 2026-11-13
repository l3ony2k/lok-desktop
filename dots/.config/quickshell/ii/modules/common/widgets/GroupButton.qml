import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * Material 3 button with expressive bounciness. 
 * See https://m3.material.io/components/button-groups/overview
 */
Button {
    id: root
    property bool toggled
    property string buttonText
    property real buttonRadius: Appearance?.rounding?.small ?? 8
    property real buttonRadiusPressed: Appearance?.rounding?.small ?? 6
    property var downAction // When left clicking (down)
    property var releaseAction // When left clicking (release)
    property var altAction // When right clicking
    property var middleClickAction // When middle clicking
    property bool bounce: !(Appearance?.lok ?? false) // lok style: no expressive bounce
    property real baseWidth: contentItem.implicitWidth + horizontalPadding * 2
    property real baseHeight: contentItem.implicitHeight + verticalPadding * 2
    property bool enableImplicitWidthAnimation: true
    property bool enableImplicitHeightAnimation: true
    property real clickedWidth: baseWidth + (isAtSide ? 10 : 20)
    property real clickedHeight: baseHeight
    property var parentGroup: root.parent
    property int indexInParent: parentGroup?.children.indexOf(root) ?? -1
    property int clickIndex: parentGroup?.clickIndex ?? -1
    property bool isAtSide: indexInParent === 0 || indexInParent === (parentGroup?.childrenCount - 1)

    // The press-and-neighbours fill is part of the bounce; without bounce it just made the last-clicked cells wider
    Layout.fillWidth: bounce && (clickIndex - 1 <= indexInParent && indexInParent <= clickIndex + 1)
    Layout.fillHeight: bounce && (clickIndex - 1 <= indexInParent && indexInParent <= clickIndex + 1)
    implicitWidth: (root.down && bounce) ? clickedWidth : baseWidth
    implicitHeight: (root.down && bounce) ? clickedHeight : baseHeight

    property color colBackground: ColorUtils.transparentize(colBackgroundHover, 1) || "transparent"
    property color colBackgroundHover: Appearance?.colors.colLayer1Hover ?? "#E5DFED"
    property color colBackgroundActive: Appearance?.colors.colLayer1Active ?? "#D6CEE2"
    property bool lokStatusStrip: false // lok: show the status strip when toggled
    property color colBackgroundToggled: Appearance?.colors.colPrimary ?? "#65558F"
    property color colBackgroundToggledHover: Appearance?.colors.colPrimaryHover ?? "#77699C"
    property color colBackgroundToggledActive: Appearance?.colors.colPrimaryActive ?? "#D6CEE2"

    // lok: square everywhere, whatever radius a subclass computes (e.g. height / 2)
    readonly property bool lokSquare: Appearance?.lok ?? false
    property real radius: lokSquare ? 0 : root.down ? root.buttonRadiusPressed : root.buttonRadius
    property real leftRadius: lokSquare ? 0 : root.down ? root.buttonRadiusPressed : root.buttonRadius
    property real rightRadius: lokSquare ? 0 : root.down ? root.buttonRadiusPressed : root.buttonRadius
    property color color: root.enabled ? (root.toggled ? 
        (root.down ? colBackgroundToggledActive : 
            root.hovered ? colBackgroundToggledHover : 
            colBackgroundToggled) :
        (root.down ? colBackgroundActive : 
            root.hovered ? colBackgroundHover : 
            colBackground)) : colBackground

    onDownChanged: {
        if (root.down) {
            if (root.parent.clickIndex !== undefined) {
                root.parent.clickIndex = parent.children.indexOf(root)
            }
        }
    }

    Behavior on implicitWidth {
        enabled: root.enableImplicitWidthAnimation
        animation: Appearance.animation.clickBounce.numberAnimation.createObject(this)
    }

    Behavior on implicitHeight {
        enabled: root.enableImplicitHeightAnimation
        animation: Appearance.animation.clickBounce.numberAnimation.createObject(this)
    }

    Behavior on leftRadius {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }
    Behavior on rightRadius {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    property alias mouseArea: buttonMouseArea
    MouseArea {
        id: buttonMouseArea
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onPressed: (event) => { 
            if(event.button === Qt.RightButton) {
                if (root.altAction) root.altAction();
                return;
            }
            if(event.button === Qt.MiddleButton) {
                if (root.middleClickAction) root.middleClickAction();
                return;
            }
            root.down = true
            if (root.downAction) root.downAction();
        }
        onReleased: (event) => {
            root.down = false
            if (event.button != Qt.LeftButton) return;
            if (root.releaseAction) root.releaseAction();
        }
        onClicked: (event) => {
            if (event.button != Qt.LeftButton) return;
            root.click()
        }
        onCanceled: (event) => {
            root.down = false
        }

        onPressAndHold: () => {
            altAction(); 
            root.down = false; 
            root.clicked = false;
        };
    }

    property bool tabbedTo: root.focus && (focusReason === Qt.TabFocusReason || focusReason === Qt.BacktabFocusReason)
    background: Rectangle {
        id: buttonBackground
        // lok: square at the point of drawing, whatever radius a subclass sets
        topLeftRadius: (Appearance?.lok ?? false) ? 0 : root.leftRadius
        topRightRadius: (Appearance?.lok ?? false) ? 0 : root.rightRadius
        bottomLeftRadius: (Appearance?.lok ?? false) ? 0 : root.leftRadius
        bottomRightRadius: (Appearance?.lok ?? false) ? 0 : root.rightRadius
        implicitHeight: 50

        color: root.color
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        // lok style: hairline frame. Transparent buttons show it only on hover (like lok's
        // header buttons); filled ones keep it. Toggled ones are a raised surface
        // (colPrimary) with a brighter frame and a 2 px status strip along the bottom.
        readonly property bool lok: Appearance?.lok ?? false
        readonly property bool lokFrame: lok && (root.toggled
            || root.hovered || root.down || root.colBackground.a > 0.01)
        border.width: root.tabbedTo ? 2 : 0 // lok: LokFrame below (border drops sides at 1.333 scale)
        LokFrame { visible: !root.tabbedTo && parent.lokFrame; z: 99; color: parent?.border?.color ?? Appearance.colors.colLokFrame }
        border.color: root.tabbedTo ? Appearance.colors.colSecondary
            : (lok && root.toggled) ? Appearance.colors.colSelectedEdge
            : (root.hovered || root.down) ? (lok ? Appearance.colors.colLokFrame : Appearance.colors.colOutline)
            : (lok ? Appearance.colors.colLokDivider : Appearance.colors.colOutlineVariant)

        Rectangle {
            visible: parent.lok && root.toggled && root.lokStatusStrip
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 1 }
            height: Appearance.lok ? 2 * Appearance.sizes.hairline : 2
            color: Appearance.colors.colOnPrimary
        }
    }

    contentItem: StyledText {
        text: root.buttonText
    }
}
