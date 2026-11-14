pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.modules.common

/**
 * Top applications for the dashboard's process card (lok task, 2026-11-15), via ~/.local/bin/top-apps
 * (grouped by name, current %CPU from two samples ~0.4 s apart). Lives here rather than in the card
 * so a page instance the sidebar re-created can't keep its own poller running, and polls only while
 * the left sidebar is open.
 */
Singleton {
    id: root
    property string sort: "mem" // mem | cpu
    property int count: 5
    property var info: ({ top: [], restCount: 0, restMem: 0 })
    readonly property bool active: GlobalStates.sidebarLeftOpen
    property bool pending: false

    function setSort(k) {
        if (k === root.sort) return;
        root.sort = k;
        root.refresh();
    }
    // never restart a running sample (the new command would be dropped); run once more after it
    function refresh() {
        if (proc.running) { root.pending = true; return; }
        proc.command = [Quickshell.env("HOME") + "/.local/bin/top-apps", String(root.count), root.sort];
        proc.running = true;
    }

    Timer {
        interval: Config.options?.resources?.updateInterval ?? 3000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: { try { root.info = JSON.parse(text); } catch (e) {} }
        }
        onExited: if (root.pending) { root.pending = false; Qt.callLater(root.refresh); }
    }
}
