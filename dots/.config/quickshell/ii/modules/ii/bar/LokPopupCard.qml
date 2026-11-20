import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

/**
 * lok bar-popup card (2026-11-20), shared by every bar hover popup so they read as one family:
 *   [marker] icon  Title          small grey caption
 *        Value                    big, bright (red when warn)
 *        detail                   small grey
 *   ━━━━━━━━━━━━                  optional thin usage bar (fraction 0..1)
 *   <extra content>               optional, e.g. a to-do list
 * wide: true lays caption left and value right on one row (for full-width summary cards).
 * marker: a small square before the caption (privacy colours); markerHollow draws it as an outline.
 */
Rectangle {
    id: card
    property string symbol: ""
    property string title: ""
    property string value: ""
    property string detail: ""
    property real fraction: -1 // < 0 = no bar
    property bool warn: false
    property bool dim: false // value in secondary grey (idle / off states)
    property bool wide: false
    property color marker: "transparent"
    property bool markerHollow: false
    readonly property bool hasMarker: marker.a > 0 || markerHollow
    readonly property color valueColor: warn ? Appearance.colors.colError : dim ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer1
    default property alias content: extra.children

    color: Appearance.colors.colLokDialogHover
    radius: Appearance.rounding.small
    Layout.fillWidth: true
    Layout.fillHeight: !wide
    implicitWidth: wide ? wideRow.implicitWidth + 12 * 2 : Math.max(118, cardColumn.implicitWidth + 12 * 2)
    implicitHeight: (wide ? wideRow.implicitHeight + 9 * 2 : cardColumn.implicitHeight + 10 * 2)
        + (extra.children.length > 0 ? extra.implicitHeight + 8 : 0)

    component Caption: RowLayout {
        spacing: 4
        Rectangle { // marker
            visible: card.hasMarker
            implicitWidth: 6
            implicitHeight: 6
            Layout.rightMargin: 2
            color: card.markerHollow ? "transparent" : card.marker
            LokFrame { visible: card.markerHollow; color: Appearance.colors.colSubtext }
        }
        MaterialSymbol {
            visible: card.symbol !== ""
            fill: 0
            text: card.symbol
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colSubtext
        }
        StyledText {
            text: card.title
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }
    }

    // stacked card (grid cells)
    ColumnLayout {
        id: cardColumn
        visible: !card.wide
        anchors { left: parent.left; right: parent.right; verticalCenter: extra.children.length > 0 ? undefined : parent.verticalCenter; top: extra.children.length > 0 ? parent.top : undefined; topMargin: 10; leftMargin: 12; rightMargin: 12 }
        spacing: 2
        Caption { Layout.alignment: Qt.AlignHCenter }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: card.width - 12 * 2
            visible: card.value !== ""
            text: card.value
            font.pixelSize: Appearance.font.pixelSize.larger
            fontSizeMode: Text.HorizontalFit // long values ("Performance") shrink to fit the tile
            minimumPixelSize: Appearance.font.pixelSize.small
            horizontalAlignment: Text.AlignHCenter
            color: card.valueColor
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: card.width - 12 * 2 // wrap inside the card instead of running past it
            visible: card.detail !== ""
            text: card.detail
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }
        Item { // usage bar
            visible: card.fraction >= 0
            Layout.fillWidth: true
            Layout.topMargin: 6
            implicitHeight: 3
            Rectangle { anchors.fill: parent; color: Appearance.colors.colLokFrame }
            Rectangle {
                width: parent.width * Math.max(0, Math.min(1, card.fraction))
                height: parent.height
                color: card.warn ? Appearance.colors.colError : Appearance.colors.colOnLayer1
                Behavior on width { NumberAnimation { duration: 200 } }
            }
        }
    }

    // one-row card (full-width summaries)
    RowLayout {
        id: wideRow
        visible: card.wide
        anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 9; leftMargin: 12; rightMargin: 12 }
        spacing: 8
        Caption {}
        Item { Layout.fillWidth: true }
        StyledText {
            visible: card.detail !== ""
            text: card.detail
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }
        StyledText {
            visible: card.value !== ""
            text: card.value
            color: card.valueColor
        }
    }

    ColumnLayout { // extra content under the header
        id: extra
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 10; leftMargin: 12; rightMargin: 12 }
        spacing: 4
    }
}
