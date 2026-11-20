import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/**
 * Privacy indicators: a 2x2 block of square dots, one icon in size (2026-11-20). See services/Privacy.qml.
 *   mic (orange)       camera (green)
 *   remote/SSH (blue)  screen capture (purple)
 * Each dot: hollow (icon grey outline) = the feature is off; dim grey block = on, not in use;
 * colour = in use (in use wins over off: a muted mic held open still shows orange).
 * Sizes are whole device pixels at 1.333: 6 logical = 8 px dots, 3 logical = 4 px gaps, 20 px block.
 */
MouseArea {
    id: root
    property bool vertical: false
    readonly property real dot: 6
    readonly property real gap: 3
    implicitWidth: vertical ? Appearance.sizes.verticalBarWidth : grid.implicitWidth + 8
    implicitHeight: vertical ? grid.implicitHeight + 8 : Appearance.sizes.barHeight
    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    // macOS-like system colours; slightly deeper in light mode so they hold on a pale bar
    readonly property bool dark: Appearance.m3colors.darkmode
    readonly property var colours: ({
        "mic": dark ? "#ff9f0a" : "#f08c00",
        "camera": dark ? "#30d158" : "#28b14c",
        "remote": dark ? "#0a84ff" : "#007aff",
        "screen": dark ? "#bf5af2" : "#a64fd6"
    })

    component Dot: Rectangle {
        id: d
        required property string kind
        readonly property string state_: Privacy[kind]
        implicitWidth: root.dot
        implicitHeight: root.dot
        color: state_ === "active" ? root.colours[kind]
            : state_ === "idle" ? Appearance.colors.colLokFrame // a solid block reads brighter than line icons in colSubtext
            : "transparent"
        LokFrame { // hollow square for "off": a 1 device-px outline in the idle grey
            visible: d.state_ === "off"
            color: Appearance.colors.colSubtext
        }
        Behavior on color { ColorAnimation { duration: 150 } }
    }

    GridLayout {
        id: grid
        anchors.centerIn: parent
        columns: 2
        rowSpacing: root.gap
        columnSpacing: root.gap
        Dot { kind: "mic" }
        Dot { kind: "camera" }
        Dot { kind: "remote" }
        Dot { kind: "screen" }
    }

    StyledPopup {
        hoverTarget: root
        Column {
            anchors.centerIn: parent
            spacing: 4
            StyledPopupHeaderRow {
                icon: "shield"
                label: Translation.tr("Privacy")
            }
            StyledPopupValueRow { icon: "mic"; label: Translation.tr("Microphone:"); value: Privacy.describe("mic") }
            StyledPopupValueRow { icon: "videocam"; label: Translation.tr("Camera:"); value: Privacy.describe("camera") }
            StyledPopupValueRow { icon: "terminal"; label: Translation.tr("Remote:"); value: Privacy.describe("remote") }
            StyledPopupValueRow { icon: "screen_record"; label: Translation.tr("Screen:"); value: Privacy.describe("screen") }
        }
    }
}
