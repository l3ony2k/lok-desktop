import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.modules.common
import qs.modules.common.widgets

// Popup section title. lok (2026-11-20): bright bold title over a 1 device-px divider, so the
// title reads as a header and not as one more row. A title at the top of the popup draws the
// divider edge to edge across the popup (several side-by-side titles share one line); a title
// further down (e.g. GPU under CPU) draws it across its own column only.
Item {
    id: root
    required property var icon
    required property var label

    readonly property real gapBelowTitle: Appearance.lok ? 6 : 0
    readonly property real gapBelowLine: Appearance.lok ? 3 : 0
    readonly property real gapAbove: (Appearance.lok && popupBg && !atTop) ? 8 : 0 // a section further down gets air above it
    readonly property real hairline: 1 / (root.QsWindow.window?.devicePixelRatio ?? Appearance.dpr)

    implicitWidth: row.implicitWidth
    implicitHeight: gapAbove + row.implicitHeight + (Appearance.lok ? gapBelowTitle + hairline + gapBelowLine : 0)
    Layout.fillWidth: Appearance.lok

    Row {
        id: row
        y: root.gapAbove
        spacing: Appearance.lok ? 8 : 5

        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            fill: 0
            width: Appearance.lok ? Appearance.font.pixelSize.large : implicitWidth
            horizontalAlignment: Text.AlignHCenter
            font.weight: Font.DemiBold
            text: root.icon
            iconSize: Appearance.font.pixelSize.large
            color: Appearance.lok ? Appearance.colors.colOnLayer1 : Appearance.colors.colOnSurfaceVariant
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            font {
                weight: Font.DemiBold
                pixelSize: Appearance.font.pixelSize.normal
            }
            color: Appearance.lok ? Appearance.colors.colOnLayer1 : Appearance.colors.colOnSurfaceVariant
        }
    }

    // ---- lok divider: find the popup background, bleed to its edges when at the top ----
    property Item popupBg: null
    property real bleedX: 0
    property bool atTop: false
    function relayout() {
        if (!Appearance.lok) return;
        let p = root.parent;
        while (p && p.objectName !== "styledPopupBackground") p = p.parent;
        root.popupBg = p;
        if (!p) return;
        const pos = root.mapToItem(p, 0, 0);
        root.bleedX = pos.x;
        root.atTop = pos.y <= (p.margin ?? 10) + 2;
    }
    // The popup's content is reparented into the popup window only when it first opens, so look
    // again whenever the window / visibility / size changes, and once more after layout settles.
    readonly property var hostWindow: root.QsWindow.window
    onHostWindowChanged: settle.restart()
    onVisibleChanged: if (visible) settle.restart()
    onWidthChanged: settle.restart()
    Component.onCompleted: settle.restart()
    Timer { id: settle; interval: 30; onTriggered: root.relayout() }
    Connections {
        target: root.popupBg
        function onWidthChanged() { settle.restart(); }
        function onVisibleChanged() { settle.restart(); }
    }

    Rectangle {
        visible: Appearance.lok
        y: root.gapAbove + row.implicitHeight + root.gapBelowTitle
        x: (root.atTop && root.popupBg) ? -root.bleedX : 0
        width: (root.atTop && root.popupBg) ? root.popupBg.width : (root.parent?.width ?? root.width)
        height: root.hairline
        color: Appearance.colors.colLokDivider
    }
}
