pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import Qt5Compat.GraphicalEffects
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

MouseArea {
    id: root
    required property SystemTrayItem item
    property bool targetMenuOpen: false

    signal menuOpened(qsWindow: var)
    signal menuClosed()

    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    // lok: 18 px; tray pixmaps carry their own margin, so this puts their ink at the
    // ~20 device-px height of the Material status glyphs next to them
    implicitWidth: Appearance.lok ? 18 : 20
    implicitHeight: Appearance.lok ? 18 : 20
    onPressed: (event) => {
        switch (event.button) {
        case Qt.LeftButton:
            item.activate();
            break;
        case Qt.RightButton:
            if (item.hasMenu)
                if (menu.active && menu.item && typeof menu.item.close === "function")
                    menu.item.close();
                else 
                    menu.open();
            break;
        }
        event.accepted = true;
    }
    onEntered: {
        tooltip.text = TrayService.getTooltipForItem(root.item);
    }

    Loader {
        id: menu
        function open() {
            menu.active = true;
        }
        active: false
        sourceComponent: SysTrayMenu {
            Component.onCompleted: this.open();
            trayItemMenuHandle: root.item.menu
            trayItemId: root.item.id
            anchor {
                window: root.QsWindow.window
                item: root
                gravity: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
                edges: Config.options.bar.vertical
                    ? (Config.options.bar.bottom ? Edges.Left : Edges.Right)
                    : (Config.options.bar.bottom ? Edges.Top : Edges.Bottom)
            }
            onMenuOpened: (window) => root.menuOpened(window);
            onMenuClosed: {
                root.menuClosed();
                menu.active = false;
            }
        }
    }

    IconImage {
        id: trayIcon
        // lok draws the icon through the ColorOverlay below
        visible: !Config.options.tray.monochromeIcons && !Appearance.lok
        source: root.item.icon
        anchors.centerIn: parent
        width: parent.width
        height: parent.height
    }

    // lok: every tray icon is drawn in the secondary text colour, like the Material status glyphs.
    // Dark mode maps brightness: tray icons are drawn for dark panels, so light parts become the
    // grey glyph and dark outlines melt into the bar (Slack keeps the gaps of its "#").
    // Light mode uses the icon's shape only: some apps keep sending white icons (Slack), others
    // swap to a black icon on a light theme (magpie), and a brightness rule would hide one of them.
    Loader {
        active: Appearance.lok && Appearance.m3colors.darkmode
        anchors.fill: trayIcon
        sourceComponent: Item {
            Desaturate {
                id: lokGrey
                visible: false
                anchors.fill: parent
                source: trayIcon
                desaturation: 1.0
            }
            LevelAdjust {
                anchors.fill: lokGrey
                source: lokGrey
                // alpha is mapped too: low end transparent, high end opaque
                readonly property color barCol: Appearance.colors.colLayer0
                readonly property color sub: Appearance.colors.colSubtext
                minimumOutput: Qt.rgba(barCol.r, barCol.g, barCol.b, 0)
                maximumOutput: Qt.rgba(sub.r, sub.g, sub.b, 1)
            }
        }
    }
    ColorOverlay {
        visible: Appearance.lok && !Appearance.m3colors.darkmode
        anchors.fill: trayIcon
        source: trayIcon
        color: Appearance.colors.colSubtext
    }

    Loader {
        active: Config.options.tray.monochromeIcons && !Appearance.lok
        anchors.fill: trayIcon
        sourceComponent: Item {
            Desaturate {
                id: desaturatedIcon
                visible: false // There's already color overlay
                anchors.fill: parent
                source: trayIcon
                desaturation: 0.8 // 1.0 means fully grayscale
            }
            ColorOverlay {
                anchors.fill: desaturatedIcon
                source: desaturatedIcon
                color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.9)
            }
        }
    }

    PopupToolTip {
        id: tooltip
        extraVisibleCondition: root.containsMouse
        alternativeVisibleCondition: extraVisibleCondition
        anchorEdges: (!Config.options.bar.bottom && !Config.options.bar.vertical) ? Edges.Bottom : Edges.Top
    }

}
