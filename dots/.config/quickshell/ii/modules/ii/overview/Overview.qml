import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import Qt.labs.synchronizer
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: overviewScope
    property bool dontAutoCancelSearch: false
    // Super-tap opens the search box alone; the Chromebook F4/overview key
    // sets this true to reveal the full overview widget.
    property bool showOverviewWidget: true

    PanelWindow {
        id: panelWindow
        property string searchingText: ""
        readonly property HyprlandMonitor monitor: Hyprland.monitorFor(panelWindow.screen)
        property bool monitorIsFocused: (Hyprland.focusedMonitor?.id == monitor?.id)
        visible: GlobalStates.overviewOpen

        WlrLayershell.namespace: "quickshell:overview"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: GlobalStates.overviewOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        color: "transparent"

        mask: Region {
            item: GlobalStates.overviewOpen ? columnLayout : null
        }

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Connections {
            target: GlobalStates
            function onOverviewOpenChanged() {
                if (!GlobalStates.overviewOpen) {
                    // Clipboard/emoji opens set a prefix themselves; don't carry that into the next Super-tap
                    searchWidget.rememberSearch(!overviewScope.dontAutoCancelSearch);
                    searchWidget.disableExpandAnimation();
                    overviewScope.dontAutoCancelSearch = false;
                    overviewScope.showOverviewWidget = true;
                    GlobalFocusGrab.dismiss();
                } else {
                    if (!overviewScope.dontAutoCancelSearch) {
                        searchWidget.cancelSearch();
                    }
                    GlobalFocusGrab.addDismissable(panelWindow);
                }
            }
        }

        Connections {
            target: GlobalFocusGrab
            function onDismissed() {
                GlobalStates.overviewOpen = false;
            }
        }
        implicitWidth: columnLayout.implicitWidth
        implicitHeight: columnLayout.implicitHeight

        function setSearchingText(text) {
            searchWidget.setSearchingText(text);
            searchWidget.focusFirstItem();
        }

        Column {
            id: columnLayout
            visible: GlobalStates.overviewOpen
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
            }
            spacing: -8

            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    GlobalStates.overviewOpen = false;
                }
            }

            Binding {
                target: LauncherSearch
                property: "listAppsWhenEmpty"
                value: GlobalStates.overviewOpen && !overviewScope.showOverviewWidget
            }

            SearchWidget {
                id: searchWidget
                anchors.horizontalCenter: parent.horizontalCenter
                Synchronizer on searchingText {
                    property alias source: panelWindow.searchingText
                }
            }

            Loader {
                id: overviewLoader
                anchors.horizontalCenter: parent.horizontalCenter
                active: GlobalStates.overviewOpen && overviewScope.showOverviewWidget && (Config?.options.overview.enable ?? true)
                visible: (panelWindow.searchingText == "")
                sourceComponent: OverviewWidget {
                    screen: panelWindow.screen
                }
            }
        }
    }

    function toggleClipboard() {
        if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.overviewOpen = false;
            return;
        }
        overviewScope.dontAutoCancelSearch = true;
        panelWindow.setSearchingText(Config.options.search.prefix.clipboard);
        GlobalStates.overviewOpen = true;
    }

    function toggleEmojis() {
        if (GlobalStates.overviewOpen && overviewScope.dontAutoCancelSearch) {
            GlobalStates.overviewOpen = false;
            return;
        }
        overviewScope.dontAutoCancelSearch = true;
        panelWindow.setSearchingText(Config.options.search.prefix.emojis);
        GlobalStates.overviewOpen = true;
    }

    IpcHandler {
        target: "search"

        // Upstream (457ef250) binds Super-tap to `qs ipc call search toggle` on
        // release; keep this machine's behaviour: Super-tap = search box only.
        function toggle() {
            if (GlobalStates.overviewOpen) {
                GlobalStates.overviewOpen = false;
            } else {
                overviewScope.showOverviewWidget = false;
                GlobalStates.overviewOpen = true;
            }
        }
        function workspacesToggle() {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
        function close() {
            GlobalStates.overviewOpen = false;
        }
        function open() {
            GlobalStates.overviewOpen = true;
        }
        function toggleReleaseInterrupt() {
            GlobalStates.superReleaseMightTrigger = false;
        }
        function clipboardToggle() {
            overviewScope.toggleClipboard();
        }
    }

    GlobalShortcut {
        // Super-tap: search box only. Bound via hl.dsp.global so the key goes straight
        // into this process; `qs ipc call` spawned a whole Quickshell client per tap
        // (~130 ms warm, close to 1 s cold).
        name: "searchOnlyToggle"
        description: "Toggles the search box (no workspace overview) on press"

        // custom/keybinds.lua binds this on Super *release* only (same trigger as
        // the dots' `qs ipc call search toggle` bind it replaces). Hyprland
        // delivers a release bind as a "released" event, so act there.
        onReleased: {
            if (GlobalStates.overviewOpen) {
                GlobalStates.overviewOpen = false;
            } else {
                overviewScope.showOverviewWidget = false;
                GlobalStates.overviewOpen = true;
            }
        }
    }
    GlobalShortcut {
        name: "searchToggle"
        description: "Toggles search on press"

        onPressed: {
            GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
        }
    }
    GlobalShortcut {
        name: "overviewWorkspacesClose"
        description: "Closes overview on press"

        onPressed: {
            GlobalStates.overviewOpen = false;
        }
    }
    GlobalShortcut {
        name: "overviewWorkspacesToggle"
        description: "Toggles overview on press"

        onPressed: {
            if (GlobalStates.overviewOpen && !overviewScope.showOverviewWidget) {
                // Upgrade a Super-tap search into the full overview.
                overviewScope.showOverviewWidget = true;
            } else {
                overviewScope.showOverviewWidget = true;
                GlobalStates.overviewOpen = !GlobalStates.overviewOpen;
            }
        }
    }
    GlobalShortcut {
        name: "searchToggleRelease"
        description: "Toggles search on release"

        onPressed: {
            GlobalStates.superReleaseMightTrigger = true;
        }

        onReleased: {
            if (!GlobalStates.superReleaseMightTrigger) {
                GlobalStates.superReleaseMightTrigger = true;
                return;
            }
            if (GlobalStates.overviewOpen) {
                GlobalStates.overviewOpen = false;
            } else {
                // Super-tap: search box only, no overview grid.
                overviewScope.showOverviewWidget = false;
                GlobalStates.overviewOpen = true;
            }
        }
    }
    GlobalShortcut {
        name: "searchToggleReleaseInterrupt"
        description: "Interrupts possibility of search being toggled on release. " + "This is necessary because GlobalShortcut.onReleased in quickshell triggers whether or not you press something else while holding the key. " + "To make sure this works consistently, use binditn = MODKEYS, catchall in an automatically triggered submap that includes everything."

        onPressed: {
            GlobalStates.superReleaseMightTrigger = false;
        }
    }
    GlobalShortcut {
        name: "overviewClipboardToggle"
        description: "Toggle clipboard query on overview widget"

        onPressed: {
            overviewScope.toggleClipboard();
        }
    }

    GlobalShortcut {
        name: "overviewEmojiToggle"
        description: "Toggle emoji query on overview widget"

        onPressed: {
            overviewScope.toggleEmojis();
        }
    }
}
