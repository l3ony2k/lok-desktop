import QtQuick
import qs.modules.common

/**
 * Scales touchpad (pixel-delta) scrolling for a Flickable/ListView.
 *
 * Hyprland's touchpad scroll gain (custom scroll curve x scroll_factor) is tuned for
 * windows, and per-app scroll_touchpad rules can't reach layer surfaces, so Quickshell
 * lists got ~1/10 of the finger movement. This multiplies pixel deltas by
 * interactions.scrolling.touchpadPixelGain; mouse wheels (angle-only deltas) pass through.
 *
 * Usage: TouchpadScrollHandler { flickable: myListView }   (declare it inside the view)
 */
MouseArea {
    id: root
    required property Flickable flickable
    property real gain: Config?.options.interactions.scrolling.touchpadPixelGain ?? 1
    // True while touchpad deltas are arriving; owners can disable contentY animations with it
    property bool active: false

    parent: flickable
    anchors.fill: flickable
    z: 1000
    acceptedButtons: Qt.NoButton
    enabled: gain > 0 && gain !== 1

    onWheel: wheelEvent => {
        if (wheelEvent.pixelDelta.y === 0 || !flickable.interactive) {
            wheelEvent.accepted = false;
            return;
        }
        const f = root.flickable;
        const minY = f.originY - f.topMargin;
        const maxY = Math.max(minY, f.originY + f.contentHeight + f.bottomMargin - f.height);
        root.active = true;
        idle.restart();
        f.cancelFlick();
        f.contentY = Math.max(minY, Math.min(maxY, f.contentY - wheelEvent.pixelDelta.y * root.gain));
        wheelEvent.accepted = true;
    }

    Timer {
        id: idle
        interval: 150
        onTriggered: root.active = false
    }
}
