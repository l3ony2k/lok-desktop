import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.bar as Bar
import qs.modules.ii.bar.weather as BarWeather

Item { // Bar content region
    id: root

    property var screen: root.QsWindow.window?.screen
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen)

    component HorizontalBarSeparator: Rectangle {
        visible: !Appearance.lok
        Layout.leftMargin: Appearance.sizes.baseBarHeight / 3
        Layout.rightMargin: Appearance.sizes.baseBarHeight / 3
        Layout.fillWidth: true
        implicitHeight: 1
        color: Appearance.colors.colOutlineVariant
    }

    // Background shadow
    Loader {
        active: Config.options.bar.showBackground && Config.options.bar.cornerStyle === 1
        anchors.fill: barBackground
        sourceComponent: StyledRectangularShadow {
            anchors.fill: undefined // The loader's anchors act on this, and this should not have any anchor
            target: barBackground
        }
    }
    // Background
    Rectangle {
        id: barBackground
        anchors {
            fill: parent
            margins: Config.options.bar.cornerStyle === 1 ? (Appearance.sizes.hyprlandGapsOut) : 0 // idk why but +1 is needed
            // lok: stop 1 px short of the inner edge; that column belongs to the windows' side border /
            // the line under them (Background.qml), as with the top bar
            rightMargin: (Appearance.sizes.lokVBarLineBelow && !Config.options.bar.bottom) ? 1 : (Config.options.bar.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut : 0)
            leftMargin: (Appearance.sizes.lokVBarLineBelow && Config.options.bar.bottom) ? 1 : (Config.options.bar.cornerStyle === 1 ? Appearance.sizes.hyprlandGapsOut : 0)
        }
        color: Config.options.bar.showBackground ? Appearance.colors.colLayer0 : "transparent"
        radius: Config.options.bar.cornerStyle === 1 ? Appearance.rounding.windowRounding : 0
        border.width: Config.options.bar.cornerStyle === 1 ? 1 : 0
        border.color: Appearance.colors.colLayer0Border
    }
    Rectangle { // lok: hairline on the inner edge when the background can't draw it (auto-hide)
        visible: Appearance.lok && Config.options.bar.showBackground && Config.options.bar.cornerStyle !== 1
            && !Appearance.sizes.lokVBarLineBelow
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: Config.options.bar.bottom ? undefined : parent.right
        anchors.left: Config.options.bar.bottom ? parent.left : undefined
        width: Appearance.sizes.hairline
        color: Appearance.colors.colLokDivider
    }

    FocusedScrollMouseArea { // Top section | scroll to change brightness
        id: barTopSectionMouseArea
        anchors.top: parent.top
        implicitHeight: topSectionColumnLayout.implicitHeight
        implicitWidth: Appearance.sizes.baseVerticalBarWidth
        height: (root.height - middleSection.height) / 2
        width: Appearance.sizes.verticalBarWidth

        onScrollDown: Brightness.decreaseBrightness()
        onScrollUp: Brightness.increaseBrightness()
        onMovedAway: GlobalStates.osdBrightnessOpen = false
        onPressed: event => {
            if (event.button === Qt.LeftButton)
                GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
        }

        ColumnLayout { // Content
            id: topSectionColumnLayout
            anchors.fill: parent
            spacing: 10

            Bar.LeftSidebarButton { // Left sidebar button
                id: leftSidebarButton
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Appearance.lok ? 20 : (Appearance.sizes.baseVerticalBarWidth - implicitWidth) / 2 + Appearance.sizes.hyprlandGapsOut
                colBackground: (barTopSectionMouseArea.hovered && !Appearance.lok) ? Appearance.colors.colLayer1Hover : ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
            }

            // lok: the horizontal centre-clock layout turned on its side: workspaces from the top
            // edge (20 px in, as from the left edge there), then the media glyph
            Loader {
                active: Appearance.lok
                visible: active
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: leftSidebarButton.visible ? -2 : 19 // hidden items take no spacing; box at 28 device px, as from the left edge
                sourceComponent: Bar.Workspaces {
                    vertical: true
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton
                        onPressed: GlobalStates.overviewOpen = !GlobalStates.overviewOpen
                    }
                }
            }
            VerticalMedia {
                visible: Appearance.lok && !!MprisController.activePlayer
                Layout.topMargin: 6
                Layout.fillWidth: true
                Layout.fillHeight: false
            }

            Item {
                Layout.fillHeight: true
            }
            
        }
    }

    Column { // Middle section
        id: middleSection
        anchors.centerIn: parent
        spacing: 4

        Bar.BarGroup {
            visible: !Appearance.lok
            vertical: true
            padding: 8
            Resources {
                Layout.fillWidth: true
                Layout.fillHeight: false
            }
            
            HorizontalBarSeparator {}

            VerticalMedia {
                Layout.fillWidth: true
                Layout.fillHeight: false
            }
        }

        HorizontalBarSeparator {
            visible: Config.options?.bar.borderless && !Appearance.lok
        }

        Bar.BarGroup {
            id: middleCenterGroup
            visible: !Appearance.lok
            vertical: true
            padding: 6

            Bar.Workspaces {
                id: workspacesWidget
                vertical: true
                MouseArea {
                    // Right-click to toggle overview
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton

                    onPressed: event => {
                        if (event.button === Qt.RightButton) {
                            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
                        }
                    }
                }
            }
        }

        HorizontalBarSeparator {
            visible: Config.options?.bar.borderless && !Appearance.lok
        }

        Bar.BarGroup {
            vertical: true
            padding: 8
            
            VerticalClockWidget {
                Layout.fillWidth: true
                Layout.fillHeight: false
            }

            HorizontalBarSeparator {
                visible: Battery.available && !Appearance.lok
            }

            BatteryIndicator {
                visible: Battery.available && !Appearance.lok
                Layout.fillWidth: true
                Layout.fillHeight: false
            }
            
        }
    }

    FocusedScrollMouseArea { // Bottom section | scroll to change volume
        id: barBottomSectionMouseArea

        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        implicitWidth: Appearance.sizes.baseVerticalBarWidth
        implicitHeight: bottomSectionColumnLayout.implicitHeight
        
        onScrollDown: Audio.decrementVolume();
        onScrollUp: Audio.incrementVolume();
        onMovedAway: GlobalStates.osdVolumeOpen = false;
        onPressed: event => {
            if (event.button === Qt.LeftButton) {
                GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
            }
        }

        ColumnLayout {
            id: bottomSectionColumnLayout
            anchors.fill: parent
            spacing: Appearance.lok ? 10 : 4

            Item { 
                Layout.fillWidth: true
                Layout.fillHeight: true 
            }

            // lok: same items, colours and order as the horizontal right-hand status cluster
            VerticalSystemMonitor {
                visible: Appearance.lok
                Layout.alignment: Qt.AlignHCenter
            }
            Bar.UtilButtons {
                vertical: true
                visible: Appearance.lok && Config.options.bar.verbose && hasContent
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: -3 // the 26 px buttons pad their glyphs
            }
            BatteryIndicator {
                visible: Appearance.lok && Battery.available
                Layout.fillWidth: true
                Layout.topMargin: -2
            }
            Loader {
                active: Appearance.lok && Config.options.bar.weather.enable
                visible: active
                Layout.alignment: Qt.AlignHCenter
                sourceComponent: BarWeather.WeatherBar {
                    vertical: true
                }
            }

            Bar.SysTray {
                vertical: true
                Layout.topMargin: Appearance.lok ? -8 : 0 // the 24 px chevron button pads its glyph
                Layout.fillWidth: true
                Layout.fillHeight: false
                invertSide: Config?.options.bar.bottom
            }

            RippleButton { // Right sidebar button
                id: rightSidebarButton

                Layout.alignment: Qt.AlignBottom | Qt.AlignHCenter
                // lok: 20 px from the bottom edge, as the horizontal bar's last item is from the right
                Layout.bottomMargin: Appearance.lok ? 22 : Appearance.roundingSpace.screenRounding // last glyph 40 device px from the edge, as on the right of the top bar
                Layout.topMargin: Appearance.lok ? -11 : 0 // its 6 px padding is part of the gap
                Layout.fillHeight: false

                implicitHeight: indicatorsColumnLayout.implicitHeight + (Appearance.lok ? 6 : 4) * 2
                implicitWidth: indicatorsColumnLayout.implicitWidth + 6 * 2

                buttonRadius: Appearance.rounding.full
                // lok: the whole area is clickable anyway; no hover fill
                colBackground: (barBottomSectionMouseArea.hovered && !Appearance.lok) ? Appearance.colors.colLayer1Hover : ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1)
                colBackgroundHover: Appearance.lok ? ColorUtils.transparentize(Appearance.colors.colLayer1Hover, 1) : Appearance.colors.colLayer1Hover
                colRipple: Appearance.colors.colLayer1Active
                colBackgroundToggled: Appearance.colors.colSecondaryContainer
                colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                colRippleToggled: Appearance.colors.colSecondaryContainerActive
                toggled: GlobalStates.sidebarRightOpen
                // lok: indicator glyphs use the same secondary grey as the other status glyphs
                property color colText: toggled ? Appearance.m3colors.m3onSecondaryContainer : (Appearance.lok ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer0)

                Behavior on colText {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }

                onPressed: {
                    GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
                }

                ColumnLayout {
                    id: indicatorsColumnLayout
                    anchors.centerIn: parent
                    property real realSpacing: Appearance.lok ? 12 : 6
                    spacing: 0

                    Revealer { // Keep awake (coffee): shown only while on (lok, as in the horizontal bar)
                        vertical: true
                        reveal: Appearance.lok && Idle.inhibit && (Config.options.bar.indicators.keepAwake ?? true)
                        Layout.fillWidth: true
                        Layout.bottomMargin: reveal ? indicatorsColumnLayout.realSpacing : 0
                        Behavior on Layout.bottomMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        MaterialSymbol {
                            text: "coffee"
                            iconSize: Appearance.font.pixelSize.larger
                            color: rightSidebarButton.colText
                        }
                    }
                    Revealer {
                        vertical: true
                        reveal: (Audio.sink?.audio?.muted ?? false) && (Config.options.bar.indicators.volumeMute ?? true)
                        Layout.fillWidth: true
                        Layout.bottomMargin: reveal ? indicatorsColumnLayout.realSpacing : 0
                        Behavior on Layout.bottomMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        MaterialSymbol {
                            text: "volume_off"
                            iconSize: Appearance.font.pixelSize.larger
                            color: rightSidebarButton.colText
                        }
                    }
                    Revealer {
                        vertical: true
                        reveal: (Audio.source?.audio?.muted ?? false) && (Config.options.bar.indicators.micMute ?? true)
                        Layout.fillWidth: true
                        Layout.bottomMargin: reveal ? indicatorsColumnLayout.realSpacing : 0
                        Behavior on Layout.topMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        MaterialSymbol {
                            text: "mic_off"
                            iconSize: Appearance.font.pixelSize.larger
                            color: rightSidebarButton.colText
                        }
                    }
                    Bar.HyprlandXkbIndicator {
                        vertical: true
                        Layout.alignment: Qt.AlignHCenter
                        Layout.bottomMargin: indicatorsColumnLayout.realSpacing
                        color: rightSidebarButton.colText
                    }
                    Revealer {
                        vertical: true
                        reveal: (Notifications.silent && (Config.options.bar.indicators.notificationsSilent ?? true)) || (!Notifications.silent && Notifications.unread > 0)
                        Layout.fillWidth: true
                        Layout.bottomMargin: reveal ? indicatorsColumnLayout.realSpacing : 0
                        implicitHeight: reveal ? notificationUnreadCount.implicitHeight : 0
                        implicitWidth: reveal ? notificationUnreadCount.implicitWidth : 0
                        Behavior on Layout.bottomMargin {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        Bar.NotificationUnreadCount {
                            id: notificationUnreadCount
                        }
                    }
                    MaterialSymbol {
                        text: Network.materialSymbol
                        iconSize: Appearance.font.pixelSize.larger
                        color: rightSidebarButton.colText
                    }
                    MaterialSymbol {
                        Layout.topMargin: indicatorsColumnLayout.realSpacing
                        visible: BluetoothStatus.available && (Config.options.bar.indicators.bluetooth === "always" || (Config.options.bar.indicators.bluetooth === "connected" && BluetoothStatus.connected))
                        text: BluetoothStatus.connected ? "bluetooth_connected" : BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
                        iconSize: Appearance.font.pixelSize.larger
                        color: rightSidebarButton.colText
                    }
                }
            }
        }
    }
}
