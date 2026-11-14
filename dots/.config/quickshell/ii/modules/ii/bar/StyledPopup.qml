import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

LazyLoader {
    id: root

    property Item hoverTarget
    default property Item contentItem
    property real popupBackgroundMargin: 0

    active: hoverTarget && hoverTarget.containsMouse

    component: PanelWindow {
        id: popupWindow
        color: "transparent"

        anchors.left: !Config.options.bar.vertical || (Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.right: Config.options.bar.vertical && Config.options.bar.bottom
        anchors.top: Config.options.bar.vertical || (!Config.options.bar.vertical && !Config.options.bar.bottom)
        anchors.bottom: !Config.options.bar.vertical && Config.options.bar.bottom

        implicitWidth: popupBackground.implicitWidth + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin
        implicitHeight: popupBackground.implicitHeight + Appearance.sizes.elevationMargin * 2 + root.popupBackgroundMargin

        mask: Region {
            item: popupBackground
        }

        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        margins {
            // Centred under the hovered item, but kept on screen: items near the
            // screen edge (e.g. weather on the right) pushed the popup off-screen.
            left: {
                if (!Config.options.bar.vertical) {
                    const x = (root.QsWindow?.mapFromItem(
                        root.hoverTarget,
                        // lok: centre on the item's visible content (childrenRect), not on a box with trailing padding
                        (Appearance.lok && root.hoverTarget.childrenRect.width > 0)
                            ? root.hoverTarget.childrenRect.x + (root.hoverTarget.childrenRect.width - popupBackground.implicitWidth) / 2
                            : (root.hoverTarget.width - popupBackground.implicitWidth) / 2, 0
                    ).x ?? 0) - popupBackground.anchors.leftMargin; // centre the visible box, not the window
                    const screenW = popupWindow.screen?.width ?? (x + popupWindow.implicitWidth);
                    // lok: keep the visible box (not the window) on screen, with the sidebar gap at the edge
                    const maxX = Appearance.lok ? screenW - Appearance.sizes.popupGap - popupBackground.implicitWidth - popupBackground.anchors.leftMargin
                                                : screenW - popupWindow.implicitWidth;
                    return Math.max(0, Math.min(x, maxX));
                }
                return Appearance.sizes.verticalBarWidth
            }
            top: {
                if (!Config.options.bar.vertical) return Appearance.sizes.barHeight;
                const y = root.QsWindow?.mapFromItem(
                    root.hoverTarget,
                    (root.hoverTarget.height - popupBackground.implicitHeight) / 2, 0
                ).y ?? 0;
                const screenH = popupWindow.screen?.height ?? (y + popupWindow.implicitHeight);
                return Math.max(0, Math.min(y, screenH - popupWindow.implicitHeight));
            }
            right: Appearance.sizes.verticalBarWidth
            bottom: Appearance.sizes.barHeight
        }
        WlrLayershell.namespace: "quickshell:popup"
        WlrLayershell.layer: WlrLayer.Overlay

        StyledRectangularShadow {
            target: popupBackground
        }

        Rectangle {
            id: popupBackground
            readonly property real margin: 10
            anchors {
                fill: Appearance.lok ? undefined : parent
                leftMargin: Appearance.sizes.popupGap + root.popupBackgroundMargin * (!popupWindow.anchors.left)
                rightMargin: Appearance.sizes.popupGap + root.popupBackgroundMargin * (!popupWindow.anchors.right)
                topMargin: Appearance.sizes.popupGap + root.popupBackgroundMargin * (!popupWindow.anchors.top)
                bottomMargin: Appearance.sizes.popupGap + root.popupBackgroundMargin * (!popupWindow.anchors.bottom)
            }
            // lok: exactly its implicit size at the computed offset (filling the window made it 4 px wider, off-centre)
            x: anchors.leftMargin
            y: popupWindow.anchors.bottom ? parent.height - anchors.bottomMargin - implicitHeight : anchors.topMargin
            width: implicitWidth
            height: implicitHeight
            implicitWidth: root.contentItem.implicitWidth + margin * 2
            implicitHeight: root.contentItem.implicitHeight + margin * 2
            color: Appearance.lok ? Appearance.colors.colLokDialog : Appearance.m3colors.m3surfaceContainer
            radius: Appearance.rounding.small
            children: [root.contentItem]

            border.width: Appearance.lok ? 0 : 1 // lok: LokFrame below (border drops sides at 1.333 scale)

            LokFrame { visible: Appearance.lok; z: 99; color: parent?.border?.color ?? Appearance.colors.colLokFrame }
            border.color: Appearance.lok ? Appearance.colors.colLokFrame : Appearance.colors.colLayer0Border
        }
    }
}
