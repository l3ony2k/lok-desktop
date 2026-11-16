import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    implicitWidth: gridLayout.implicitWidth
    implicitHeight: gridLayout.implicitHeight
    property bool vertical: false
    property bool invertSide: false
    property bool trayOverflowOpen: false
    property bool showSeparator: true
    property bool showOverflowMenu: true
    property var activeMenu: null

    property list<var> pinnedItems: TrayService.pinnedItems
    property list<var> unpinnedItems: TrayService.unpinnedItems
    onUnpinnedItemsChanged: {
        if (unpinnedItems.length == 0) root.closeOverflowMenu();
    }

    function grabFocus() {
        focusGrab.active = true;
    }

    function setExtraWindowAndGrabFocus(window) {
        if (root.activeMenu && root.activeMenu !== window) {
            if (typeof root.activeMenu.close === "function")
                root.activeMenu.close();
            root.activeMenu = null;
        }
        root.activeMenu = window;
        root.grabFocus();
    }

    function releaseFocus() {
        focusGrab.active = false;
        root.activeMenu = null;
    }

    // Esc: submenu -> back, menu -> close, overflow alone -> close (see TrayService)
    readonly property bool escArmed: root.activeMenu !== null || root.trayOverflowOpen
    property bool escHeld: false
    onEscArmedChanged: {
        if (root.escArmed !== root.escHeld) {
            root.escHeld = root.escArmed;
            TrayService.holdEscape(root.escArmed);
        }
    }
    Component.onDestruction: if (root.escHeld) TrayService.holdEscape(false)
    Connections {
        target: TrayService
        enabled: root.escHeld
        function onEscapePressed() {
            if (root.activeMenu && typeof root.activeMenu.handleEscape === "function")
                root.activeMenu.handleEscape();
            else if (root.trayOverflowOpen)
                focusGrab.active = false, root.trayOverflowOpen = false;
        }
    }

    function closeOverflowMenu() {
        focusGrab.active = false;
    }

    onTrayOverflowOpenChanged: {
        if (root.trayOverflowOpen) {
            root.grabFocus();
        }
    }

    HyprlandFocusGrab {
        id: focusGrab
        active: false
        windows: [trayOverflowLayout.QsWindow?.window, root.activeMenu]
        onCleared: {
            root.trayOverflowOpen = false;
            if (root.activeMenu) {
                root.activeMenu.close();
                root.activeMenu = null;
            }
        }
    }

    GridLayout {
        id: gridLayout
        columns: root.vertical ? 1 : -1
        anchors.fill: parent
        rowSpacing: 8
        // lok: icon-to-icon ink gap of ~22 device px, the gap used across the rest of the status area
        columnSpacing: Appearance.lok ? 11 : 15

        RippleButton {
            id: trayOverflowButton
            visible: root.showOverflowMenu && root.unpinnedItems.length > 0
            toggled: root.trayOverflowOpen
            property bool containsMouse: hovered

            downAction: () => root.trayOverflowOpen = !root.trayOverflowOpen

            Layout.fillHeight: !root.vertical
            Layout.fillWidth: root.vertical
            // lok: the 24 px button already pads the chevron; take that padding out of the gap
            Layout.rightMargin: Appearance.lok && !root.vertical ? -8 : 0
            background.implicitWidth: 24
            background.implicitHeight: 24
            background.anchors.centerIn: this
            colBackgroundToggled: Appearance.colors.colSecondaryContainer
            colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
            colRippleToggled: Appearance.colors.colSecondaryContainerActive

            contentItem: MaterialSymbol {
                anchors.centerIn: parent
                iconSize: Appearance.font.pixelSize.larger
                text: "expand_more"
                horizontalAlignment: Text.AlignHCenter
                color: root.trayOverflowOpen ? Appearance.colors.colOnSecondaryContainer : (Appearance.lok ? Appearance.colors.colSubtext : Appearance.colors.colOnLayer2)
                rotation: (root.trayOverflowOpen ? 180 : 0) - (90 * root.vertical) + (180 * root.invertSide)
                Behavior on rotation {
                    animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                }
            }

            StyledPopup {
                id: overflowPopup
                hoverTarget: trayOverflowButton
                active: root.trayOverflowOpen && root.unpinnedItems.length > 0

                GridLayout {
                    id: trayOverflowLayout
                    anchors.centerIn: parent
                    columns: Math.ceil(Math.sqrt(root.unpinnedItems.length))
                    columnSpacing: 10
                    rowSpacing: 10

                    Repeater {
                        model: root.unpinnedItems

                        delegate: SysTrayItem {
                            required property SystemTrayItem modelData
                            item: modelData
                            Layout.fillHeight: !root.vertical
                            Layout.fillWidth: root.vertical
                            onMenuClosed: root.releaseFocus();
                            onMenuOpened: (qsWindow) => root.setExtraWindowAndGrabFocus(qsWindow);
                        }
                    }
                }
            }
        }

        Repeater {
            model: ScriptModel {
                values: root.pinnedItems
            }

            delegate: SysTrayItem {
                required property SystemTrayItem modelData
                item: modelData
                Layout.fillHeight: !root.vertical
                Layout.fillWidth: root.vertical
                onMenuClosed: root.releaseFocus();
                onMenuOpened: (qsWindow) => {
                    root.setExtraWindowAndGrabFocus(qsWindow);
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
            font.pixelSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colSubtext
            text: "•"
            visible: false
        }
    }
}
