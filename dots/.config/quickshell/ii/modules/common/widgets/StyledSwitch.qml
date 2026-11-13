import qs.modules.common
import QtQuick
import QtQuick.Controls

/**
 * Material 3 switch. See https://m3.material.io/components/switch/overview
 */
Switch {
    id: root
    property real scale: 0.75 // Default in m3 spec is huge af
    implicitHeight: 32 * root.scale
    implicitWidth: 52 * root.scale
    property color activeColor: Appearance?.colors.colPrimary ?? "#685496"
    property color inactiveColor: Appearance?.colors.colSurfaceContainerHighest ?? "#45464F"
    // lok: off = hollow frame + grey knob left; on = raised fill + bright frame + bright knob right
    readonly property bool lok: Appearance?.lok ?? false
    readonly property real lokKnob: 14 * root.scale / 0.75
    readonly property real lokInset: 5 * root.scale / 0.75

    PointingHandInteraction {}

    // Custom track styling
    background: Rectangle {
        width: parent.width
        height: parent.height
        radius: Appearance?.rounding.full ?? 9999
        color: root.lok ? (root.checked ? Appearance.colors.colPrimary : "transparent") : (root.checked ? root.activeColor : root.inactiveColor)
        border.width: root.lok ? Appearance.sizes.hairline : 2 * root.scale
        border.color: root.lok ? (root.checked ? Appearance.colors.colAccent : Appearance.m3colors.m3outline) : (root.checked ? root.activeColor : Appearance.m3colors.m3outline)

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
        Behavior on border.color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }

    // Custom thumb styling
    indicator: Rectangle {
        width: root.lok ? root.lokKnob : (root.pressed || root.down) ? (28 * root.scale) : root.checked ? (24 * root.scale) : (16 * root.scale)
        height: width
        radius: Appearance.rounding.full
        color: root.lok ? (root.checked ? Appearance.colors.colAccent : Appearance.m3colors.m3outline) : (root.checked ? Appearance.m3colors.m3onPrimary : Appearance.m3colors.m3outline)
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: root.lok ? (root.checked ? parent.width - root.lokKnob - root.lokInset : root.lokInset) : root.checked ? ((root.pressed || root.down) ? (22 * root.scale) : 24 * root.scale) : ((root.pressed || root.down) ? (2 * root.scale) : 8 * root.scale)

        Behavior on anchors.leftMargin {
            NumberAnimation {
                duration: Appearance.animationCurves.expressiveFastSpatialDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }
        Behavior on width {
            NumberAnimation {
                duration: Appearance.animationCurves.expressiveFastSpatialDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: Appearance.animationCurves.expressiveFastSpatialDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
            }
        }
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }
}
