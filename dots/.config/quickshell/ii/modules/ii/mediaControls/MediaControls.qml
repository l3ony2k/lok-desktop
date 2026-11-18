pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    property bool visible: false
    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property var realPlayers: MprisController.players
    readonly property var meaningfulPlayers: filterDuplicatePlayers(realPlayers)
    readonly property real osdWidth: Appearance.sizes.osdWidth
    readonly property real widgetWidth: Appearance.sizes.mediaControlsWidth
    readonly property real widgetHeight: Appearance.sizes.mediaControlsHeight
    property real popupRounding: Appearance.rounding.screenRounding - Appearance.sizes.hyprlandGapsOut + 1
    property list<real> visualizerPoints: []

    // Hover preview: the bar's media indicator opens this while the pointer is on it,
    // and it stays open while the pointer is over the popup itself. Clicking the
    // indicator pins it (mediaControlsOpen) until a click outside dismisses it.
    readonly property bool hoverShown: GlobalStates.mediaControlsHovered || GlobalStates.mediaControlsPopupHovered

    Timer {
        id: hoverHideTimer
        interval: 220
        repeat: false
    }

    onHoverShownChanged: {
        if (hoverShown) {
            hoverHideTimer.stop();
        } else if (mediaControlsLoader.active && !GlobalStates.mediaControlsOpen) {
            hoverHideTimer.restart();
        }
    }

    function filterDuplicatePlayers(players) {
        let filtered = [];
        let used = new Set();

        for (let i = 0; i < players.length; ++i) {
            if (used.has(i))
                continue;
            let p1 = players[i];
            let group = [i];

            // Find duplicates by trackTitle prefix
            for (let j = i + 1; j < players.length; ++j) {
                let p2 = players[j];
                if (p1.trackTitle && p2.trackTitle && (p1.trackTitle.includes(p2.trackTitle) || p2.trackTitle.includes(p1.trackTitle)) || (p1.position - p2.position <= 2 && p1.length - p2.length <= 2)) {
                    group.push(j);
                }
            }

            // Pick the one with non-empty trackArtUrl, or fallback to the first
            let chosenIdx = group.find(idx => players[idx].trackArtUrl && players[idx].trackArtUrl.length > 0);
            if (chosenIdx === undefined)
                chosenIdx = group[0];

            filtered.push(players[chosenIdx]);
            group.forEach(idx => used.add(idx));
        }
        return filtered;
    }

    Process {
        id: cavaProc
        running: mediaControlsLoader.active
        onRunningChanged: {
            if (!cavaProc.running) {
                root.visualizerPoints = [];
            }
        }
        command: ["cava", "-p", `${FileUtils.trimFileProtocol(Directories.scriptPath)}/cava/raw_output_config.txt`]
        stdout: SplitParser {
            onRead: data => {
                // Parse `;`-separated values into the visualizerPoints array
                let points = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p));
                root.visualizerPoints = points;
            }
        }
    }

    Loader {
        id: mediaControlsLoader
        active: GlobalStates.mediaControlsOpen || root.hoverShown || hoverHideTimer.running
        onActiveChanged: {
            if (!mediaControlsLoader.active) {
                GlobalStates.mediaControlsPopupHovered = false;
                hoverHideTimer.stop();
                if (root.realPlayers.length === 0) {
                    GlobalStates.mediaControlsOpen = false;
                }
            }
        }

        sourceComponent: PanelWindow {
            id: panelWindow
            visible: true

            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            implicitWidth: Math.max(root.widgetWidth, playerColumnLayout.implicitWidth)
            implicitHeight: playerColumnLayout.implicitHeight
            color: "transparent"
            WlrLayershell.namespace: "quickshell:mediaControls"

            anchors {
                top: !Config.options.bar.bottom || Config.options.bar.vertical
                bottom: Config.options.bar.bottom && !Config.options.bar.vertical
                left: !(Config.options.bar.vertical && Config.options.bar.bottom)
                right: Config.options.bar.vertical && Config.options.bar.bottom
            }
            margins {
                top: {
                    if (!Config.options.bar.vertical)
                        return Appearance.sizes.barHeight;
                    // vertical bar: line the card's top edge up with the media indicator, on screen
                    const anchorY = GlobalStates.mediaControlsAnchorY;
                    if (Appearance.lok && anchorY >= 0) {
                        const y = anchorY - Appearance.sizes.elevationMargin;
                        const screenH = panelWindow.screen?.height ?? (y + panelWindow.implicitHeight);
                        return Math.max(0, Math.min(y, screenH - panelWindow.implicitHeight));
                    }
                    return (panelWindow.screen.height / 2) - widgetHeight * 1.5;
                }
                bottom: Appearance.sizes.barHeight
                left: {
                    if (Config.options.bar.vertical) // lok: the card starts right at the bar's edge, as it does under the top bar
                        return Appearance.lok ? Appearance.sizes.baseVerticalBarWidth : Appearance.sizes.barHeight;
                    const anchorX = GlobalStates.mediaControlsAnchorX;
                    if (anchorX >= 0) {
                        // PlayerControl insets its visible card by elevationMargin inside the
                        // window; align the card's left edge with the media indicator, and
                        // keep the window on screen.
                        const x = anchorX - Appearance.sizes.elevationMargin;
                        const screenW = panelWindow.screen?.width ?? (x + panelWindow.implicitWidth);
                        return Math.max(0, Math.min(x, screenW - panelWindow.implicitWidth));
                    }
                    return (panelWindow.screen.width / 2) - (osdWidth / 2) - widgetWidth;
                }
                right: (Config.options.bar.vertical && Appearance.lok) ? Appearance.sizes.baseVerticalBarWidth : Appearance.sizes.barHeight
            }

            mask: Region {
                item: playerColumnLayout
            }

            // Only a pinned popup grabs focus/handles outside clicks; a hover preview
            // must not intercept clicks elsewhere.
            function syncFocusGrab() {
                if (GlobalStates.mediaControlsOpen)
                    GlobalFocusGrab.addDismissable(panelWindow);
                else
                    GlobalFocusGrab.removeDismissable(panelWindow);
            }
            Component.onCompleted: syncFocusGrab()
            Component.onDestruction: GlobalFocusGrab.removeDismissable(panelWindow)
            Connections {
                target: GlobalStates
                function onMediaControlsOpenChanged() { syncFocusGrab(); }
            }
            Connections {
                target: GlobalFocusGrab
                function onDismissed() {
                    GlobalStates.mediaControlsOpen = false;
                }
            }

            ColumnLayout {
                id: playerColumnLayout
                anchors.fill: parent
                spacing: -Appearance.sizes.elevationMargin // Shadow overlap okay

                // Keep the hover preview open while the pointer is over the popup
                // (including the trip from the bar item down to it).
                HoverHandler {
                    onHoveredChanged: GlobalStates.mediaControlsPopupHovered = hovered
                }

                Repeater {
                    model: ScriptModel {
                        values: root.meaningfulPlayers
                    }
                    delegate: PlayerControl {
                        required property MprisPlayer modelData
                        player: modelData
                        visualizerPoints: root.visualizerPoints
                        implicitWidth: root.widgetWidth
                        implicitHeight: root.widgetHeight
                        radius: root.popupRounding
                    }
                }

                Item {
                    // No player placeholder
                    Layout.alignment: {
                        if (panelWindow.anchors.left)
                            return Qt.AlignLeft;
                        if (panelWindow.anchors.right)
                            return Qt.AlignRight;
                        return Qt.AlignHCenter;
                    }
                    Layout.leftMargin: Appearance.sizes.hyprlandGapsOut
                    Layout.rightMargin: Appearance.sizes.hyprlandGapsOut
                    visible: root.meaningfulPlayers.length === 0
                    implicitWidth: placeholderBackground.implicitWidth + Appearance.sizes.elevationMargin
                    implicitHeight: placeholderBackground.implicitHeight + (Appearance.lok ? 2 * Appearance.sizes.popupGap : Appearance.sizes.elevationMargin)

                    StyledRectangularShadow {
                        target: placeholderBackground
                    }

                    Rectangle {
                        id: placeholderBackground
                        anchors.centerIn: parent
                        color: Appearance.lok ? Appearance.colors.colLokDialog : Appearance.colors.colLayer0
                        radius: root.popupRounding
                        property real padding: Appearance.lok ? 12 : 20
                        LokFrame { visible: Appearance.lok; z: 1 }
                        implicitWidth: placeholderLayout.implicitWidth + padding * 2
                        implicitHeight: placeholderLayout.implicitHeight + padding * 2

                        ColumnLayout {
                            id: placeholderLayout
                            anchors.centerIn: parent

                            StyledText {
                                text: Translation.tr("No active player")
                                font.pixelSize: Appearance.font.pixelSize.large
                            }
                            StyledText {
                                color: Appearance.colors.colSubtext
                                text: Translation.tr("Make sure your player has MPRIS support\nor try turning off duplicate player filtering")
                                font.pixelSize: Appearance.font.pixelSize.small
                            }
                        }
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "mediaControls"

        function toggle(): void {
            mediaControlsLoader.active = !mediaControlsLoader.active;
            if (mediaControlsLoader.active)
                Notifications.timeoutAll();
        }

        function close(): void {
            mediaControlsLoader.active = false;
        }

        function open(): void {
            mediaControlsLoader.active = true;
            Notifications.timeoutAll();
        }
    }

    GlobalShortcut {
        name: "mediaControlsToggle"
        description: "Toggles media controls on press"

        onPressed: {
            GlobalStates.mediaControlsOpen = !GlobalStates.mediaControlsOpen;
        }
    }
    GlobalShortcut {
        name: "mediaControlsOpen"
        description: "Opens media controls on press"

        onPressed: {
            GlobalStates.mediaControlsOpen = true;
        }
    }
    GlobalShortcut {
        name: "mediaControlsClose"
        description: "Closes media controls on press"

        onPressed: {
            GlobalStates.mediaControlsOpen = false;
        }
    }
}
