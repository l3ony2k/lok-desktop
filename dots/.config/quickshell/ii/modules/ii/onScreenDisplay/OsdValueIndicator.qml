import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

Item {
    id: root
    required property real value
    required property string icon
    required property string name
    property bool rotateIcon: false
    property bool scaleIcon: false
    property alias from: valueProgressBar.from
    property alias to: valueProgressBar.to

    property real valueIndicatorVerticalPadding: 9
    property real valueIndicatorLeftPadding: 10
    property real valueIndicatorRightPadding: 20 // An icon is circle ish, a column isn't, hence the extra padding

    implicitWidth: (Appearance.lok ? 280 : Appearance.sizes.osdWidth) + 2 * Appearance.sizes.elevationMargin
    implicitHeight: valueIndicator.implicitHeight + 2 * Appearance.sizes.elevationMargin

    StyledRectangularShadow {
        target: valueIndicator
        visible: !Appearance.lok // lok draws its own 1 px frame below
    }
    Rectangle {
        id: valueIndicator
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        radius: Appearance.rounding.full
        // lok: a raised surface with a visible frame so it stands off any window
        // lok: topmost surface. Dark mode lifts it to the brightest layer grey,
        // light mode to white; the outline comes from the shadow component.
        // lok: same surface + frame as every other floating dialog
        color: Appearance.lok ? Appearance.colors.colLokDialog : Appearance.colors.colLayer0
        border.width: 0 // lok: LokFrame below (border drops sides at 1.333 scale)
        LokFrame { visible: Appearance.lok; z: 99; color: parent.border.color }
        border.color: Appearance.colors.colLokFrame

        implicitWidth: Appearance.lok ? lokRow.implicitWidth + 2 * lokRow.anchors.margins : valueRow.implicitWidth
        implicitHeight: Appearance.lok ? lokRow.implicitHeight + 2 * lokRow.anchors.margins : valueRow.implicitHeight

        // lok: one row -- icon | slider-styled bar | value. The bar uses the
        // sidebar slider's pieces: fill, 2 px handle, track, 2 px gaps between.
        RowLayout {
            id: lokRow
            visible: Appearance.lok
            anchors {
                fill: parent
                margins: Appearance.roundingSpace.normal
            }
            spacing: Appearance.roundingSpace.normal

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                text: root.icon
                iconSize: 18
                color: Appearance.colors.colOnLayer0
            }

            Item {
                id: lokBar
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                implicitHeight: 24
                readonly property real frac: Math.max(0, Math.min(1,
                    (root.value - root.from) / Math.max(0.0001, root.to - root.from)))
                property real shownFrac: frac
                Behavior on shownFrac {
                    animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                }
                readonly property real trackHeight: 18
                readonly property real gap: 2
                readonly property real handleWidth: 2
                readonly property real handleX: shownFrac * (width - handleWidth)

                Rectangle { // filled part
                    anchors.verticalCenter: parent.verticalCenter
                    x: 0
                    width: Math.max(0, lokBar.handleX - lokBar.gap)
                    height: lokBar.trackHeight
                    color: root.value > root.to ? Appearance.colors.colError : Appearance.colors.colMeterFill
                }
                Rectangle { // remaining track
                    anchors.verticalCenter: parent.verticalCenter
                    x: lokBar.handleX + lokBar.handleWidth + lokBar.gap
                    width: Math.max(0, lokBar.width - x)
                    height: lokBar.trackHeight
                    color: Appearance.colors.colSecondaryContainer
                }
                Rectangle { // handle
                    x: lokBar.handleX
                    width: lokBar.handleWidth
                    height: parent.height
                    color: Appearance.colors.colAccent
                }
            }

            StyledText {
                id: lokValue
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: lokValueMetrics.width
                horizontalAlignment: Text.AlignRight
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnLayer0
                text: Math.round(root.value * 100) + "%"
            }
            TextMetrics {
                id: lokValueMetrics
                font.family: lokValue.font.family
                font.pixelSize: lokValue.font.pixelSize
                font.weight: lokValue.font.weight
                text: "100%"
            }
        }

        RowLayout { // Icon on the left, stuff on the right
            id: valueRow
            visible: !Appearance.lok
            Layout.margins: 10
            anchors.fill: parent
            spacing: 10

            Item {
                implicitWidth: 30
                implicitHeight: 30
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: valueIndicatorLeftPadding
                Layout.topMargin: valueIndicatorVerticalPadding
                Layout.bottomMargin: valueIndicatorVerticalPadding

                MaterialSymbol { // Icon
                    anchors {
                        centerIn: parent
                        alignWhenCentered: !root.rotateIcon
                    }
                    color: Appearance.colors.colOnLayer0
                    renderType: Text.QtRendering

                    text: root.icon
                    // lok style: fixed size, no rotation
                    iconSize: Appearance.lok ? 22 : 20 + 10 * (root.scaleIcon ? value : 1)
                    rotation: Appearance.lok ? 0 : 180 * (root.rotateIcon ? value : 0)

                    Behavior on iconSize {
                        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                    }
                    Behavior on rotation {
                        animation: Appearance.animation.elementMoveEnter.numberAnimation.createObject(this)
                    }
                
                }
            }
            ColumnLayout { // Stuff
                Layout.alignment: Qt.AlignVCenter
                Layout.rightMargin: valueIndicatorRightPadding
                spacing: 5

                RowLayout { // Name fill left, value on the right end
                    Layout.leftMargin: valueProgressBar.height / 2 // Align text with progressbar radius curve's left end
                    Layout.rightMargin: valueProgressBar.height / 2 // Align text with progressbar radius curve's left end
                    spacing: 8 // Keep the mono label clear of the number

                    StyledText {
                        color: Appearance.lok ? Appearance.colors.colOnLayer4 : Appearance.colors.colOnLayer0
                        font.pixelSize: Appearance.lok ? Appearance.font.pixelSize.smaller : Appearance.font.pixelSize.small
                        font.letterSpacing: Appearance.lok ? 1 : 0
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        text: Appearance.lok ? root.name.toUpperCase() : root.name
                    }

                    StyledText {
                        color: Appearance.colors.colOnLayer0
                        font.pixelSize: Appearance.lok ? Appearance.font.pixelSize.larger : Appearance.font.pixelSize.small
                        font.weight: Appearance.lok ? Font.DemiBold : Font.Normal
                        Layout.fillWidth: false
                        // lok: zero-padded like the boot screen counter ("078")
                        text: Appearance.lok ? String(Math.round(root.value * 100)).padStart(3, "0") : Math.round(root.value * 100)
                    }
                }
                
                StyledProgressBar {
                    id: valueProgressBar
                    visible: !Appearance.lok
                    Layout.fillWidth: true
                    value: root.value
                }

                LokMeter {
                    visible: Appearance.lok
                    Layout.fillWidth: true
                    Layout.leftMargin: valueProgressBar.height / 2
                    Layout.rightMargin: valueProgressBar.height / 2
                    colEmpty: Appearance.m3colors.darkmode ? Appearance.colors.colLayer1 : Appearance.m3colors.m3outlineVariant
                    value: (root.value - valueProgressBar.from) / Math.max(0.0001, valueProgressBar.to - valueProgressBar.from)
                }
            }
        }
    }
}
