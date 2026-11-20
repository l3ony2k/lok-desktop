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

    // lok (2026-11-20): one card per sensor, laid out like the dots; the card marker repeats its dot
    function stateWord(kind) {
        const st = Privacy[kind];
        return st === "active" ? Translation.tr("In use") : st === "idle" ? Translation.tr("Idle") : Translation.tr("Off");
    }
    function detailText(kind) {
        const st = Privacy[kind];
        if (st === "active") {
            const apps = kind === "mic" ? Privacy.micApps : kind === "camera" ? Privacy.cameraApps
                : kind === "screen" ? Privacy.screenApps : Privacy.remotePeers;
            return apps.length > 0 ? apps.join(", ") : Translation.tr("in use");
        }
        if (st === "off")
            return kind === "mic" ? Translation.tr("muted") : kind === "camera" ? Translation.tr("blocked") : Translation.tr("sshd stopped");
        return kind === "remote" ? Translation.tr("listening") : Translation.tr("not in use");
    }
    component SensorCard: LokPopupCard {
        required property string kind
        readonly property string st: Privacy[kind]
        value: root.stateWord(kind)
        detail: root.detailText(kind)
        dim: st !== "active"
        marker: st === "active" ? root.colours[kind] : st === "idle" ? Appearance.colors.colLokFrame : "transparent"
        markerHollow: st === "off"
    }
    StyledPopup {
        hoverTarget: root
        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8
            StyledPopupHeaderRow {
                icon: "shield"
                label: Translation.tr("Privacy")
            }
            GridLayout {
                columns: 2
                rowSpacing: 5
                columnSpacing: 5
                uniformCellWidths: true
                Layout.fillWidth: true
                SensorCard { kind: "mic"; symbol: "mic"; title: Translation.tr("Microphone") }
                SensorCard { kind: "camera"; symbol: "videocam"; title: Translation.tr("Camera") }
                SensorCard { kind: "remote"; symbol: "terminal"; title: Translation.tr("Remote") }
                SensorCard { kind: "screen"; symbol: "screen_record"; title: Translation.tr("Screen") }
            }
        }
    }
}
