import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.models

TabBar {
    id: root
    // lok: the active tab is marked by a flat 2 px strip (same as the selected-tile strip)
    property real indicatorPadding: Appearance.lok ? 0 : 8
    Layout.fillWidth: true

    background: Item {
        WheelHandler {
            onWheel: (event) => {
                if (event.angleDelta.y < 0) root.incrementCurrentIndex();
                else if (event.angleDelta.y > 0) root.decrementCurrentIndex();
            }
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        }

        Rectangle {
            id: activeIndicator
            z: 9999
            anchors.bottom: parent.bottom
            topLeftRadius: Appearance.lok ? 0 : height
            topRightRadius: Appearance.lok ? 0 : height
            bottomLeftRadius: 0
            bottomRightRadius: 0
            color: Appearance.lok ? Appearance.colors.colSelectedEdge : Appearance.colors.colAccent
            // Animation
            property real baseWidth: root.width / root.count
            AnimatedTabIndexPair {
                id: idxPair
                index: root.currentIndex
            }
            height: Appearance.lok ? 2 * Appearance.sizes.hairline : 3
            x: Math.min(idxPair.idx1, idxPair.idx2) * baseWidth + root.indicatorPadding
            width: ((Math.max(idxPair.idx1, idxPair.idx2) + 1) * baseWidth - root.indicatorPadding) - x
        }

        Rectangle { // Tabbar bottom border
            id: tabBarBottomBorder
            z: 9998
            anchors.bottom: parent.bottom
            height: Appearance.lok ? Appearance.sizes.hairline : 1
            anchors {
                left: parent.left
                right: parent.right
            }
            color: Appearance.lok ? Appearance.colors.colLokDivider : Appearance.colors.colOutlineVariant
        }
    }
}
