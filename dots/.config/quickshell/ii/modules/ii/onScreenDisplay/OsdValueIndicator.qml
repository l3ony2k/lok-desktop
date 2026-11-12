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

    implicitWidth: (Appearance.lok ? 300 : Appearance.sizes.osdWidth) + 2 * Appearance.sizes.elevationMargin
    implicitHeight: valueIndicator.implicitHeight + 2 * Appearance.sizes.elevationMargin

    StyledRectangularShadow {
        target: valueIndicator
    }
    Rectangle {
        id: valueIndicator
        anchors {
            fill: parent
            margins: Appearance.sizes.elevationMargin
        }
        radius: Appearance.rounding.full
        // lok: a raised surface with a visible frame so it stands off any window
        color: Appearance.lok ? Appearance.colors.colLayer2 : Appearance.colors.colLayer0
        border.width: Appearance.lok ? 1 : 0
        border.color: Appearance.colors.colOutline

        implicitWidth: valueRow.implicitWidth
        implicitHeight: valueRow.implicitHeight

        RowLayout { // Icon on the left, stuff on the right
            id: valueRow
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
                        color: Appearance.lok ? Appearance.colors.colOnLayer2 : Appearance.colors.colOnLayer0
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
                    value: (root.value - valueProgressBar.from) / Math.max(0.0001, valueProgressBar.to - valueProgressBar.from)
                }
            }
        }
    }
}
