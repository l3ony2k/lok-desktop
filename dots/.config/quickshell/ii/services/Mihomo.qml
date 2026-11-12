pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

/**
 * Mihomo state for the quick toggle.
 *
 * Mirrors the tile documented in the end4 migration notes: click toggles
 * mihomo.service through pkexec, right-click (or the expanded text column)
 * opens Zashboard.
 */
Singleton {
    id: root

    property string activeState: "checking"
    property string loadState: ""
    // `systemctl show` answers for missing units too, so LoadState is the
    // only reliable "is it installed" probe.
    readonly property bool installed: loadState !== "not-found" && loadState !== ""
    readonly property bool active: activeState === "active"
    readonly property bool busy: pendingAction !== "" || pkexecRunning

    property string pendingAction: ""       // "", "start", "stop"
    property bool pkexecRunning: false
    property string lastError: ""

    // ---- Live info from the external controller (127.0.0.1:9090) --------
    property bool infoReady: false
    property string version: ""
    property string mode: ""                // rule / global / direct
    property bool tunEnabled: false
    property int port: 0
    property string currentNode: ""
    property int connectionCount: 0
    property real downloadTotal: 0
    property real uploadTotal: 0

    readonly property string statusText: {
        if (!installed)
            return "Not installed";
        if (pkexecRunning)
            return pendingAction === "stop" ? "Stopping…" : "Starting…";
        switch (activeState) {
        case "active":
            return "Running";
        case "activating":
            return "Starting…";
        case "deactivating":
            return "Stopping…";
        case "failed":
            return "Failed";
        case "checking":
            return "Checking…";
        case "inactive":
            return "Stopped";
        default:
            return activeState || "Unknown";
        }
    }

    // Keep the icon the WARP tile used so the slot looks unchanged; gpp_bad
    // marks "not installed" so a missing package does not look like a
    // healthy stopped service.
    readonly property string icon: installed ? "cloud_lock" : "gpp_bad"

    function refresh() {
        if (!stateProc.running)
            stateProc.running = true;
        if (active && !infoProc.running)
            infoProc.running = true;
    }

    function setMode(newMode) {
        if (!active || mode === newMode)
            return;
        modeProc.command = ["curl", "-s", "-X", "PATCH", "-d", `{"mode":"${newMode}"}`,
                            "http://127.0.0.1:9090/configs"];
        modeProc.running = true;
    }

    function formatBytes(bytes) {
        if (!bytes || bytes <= 0)
            return "0 B";
        const units = ["B", "KB", "MB", "GB", "TB"];
        let value = bytes;
        let unit = 0;
        while (value >= 1024 && unit < units.length - 1) {
            value /= 1024;
            unit++;
        }
        return (value >= 100 ? value.toFixed(0) : value.toFixed(1)) + " " + units[unit];
    }

    function toggle() {
        if (busy)
            return;
        if (!installed) {
            notifyInstall();
            return;
        }
        pendingAction = active ? "stop" : "start";
        lastError = "";
        pkexecRunning = true;
        controlProc.command = ["pkexec", "/usr/bin/systemctl", pendingAction, "mihomo.service"];
        controlProc.running = true;
    }

    function openDashboard() {
        if (!active) {
            Quickshell.execDetached([
                "notify-send", "-a", "Shell",
                "Mihomo",
                !installed
                    ? "Mihomo is not installed. Run `sudo pacman -S --needed mihomo` first."
                    : "Start Mihomo using the tile first, then the dashboard becomes available."
            ]);
            return;
        }
        Quickshell.execDetached(["xdg-open", "http://127.0.0.1:9090/ui/"]);
    }

    function notifyInstall() {
        Quickshell.execDetached([
            "notify-send", "-a", "Shell",
            "Mihomo",
            "Mihomo is not installed. Run `sudo pacman -S --needed mihomo` first."
        ]);
    }

    // One round-trip for everything the dialog shows. The four endpoints are
    // separated by a marker line so no jq dependency is needed.
    Process {
        id: infoProc
        command: ["bash", "-c",
            'for p in configs connections proxies/PROXY version; do ' +
            'curl -s --max-time 2 "http://127.0.0.1:9090/$p"; echo; echo "---"; done']
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("---").map(s => s.trim()).filter(s => s.length > 0);
                if (parts.length < 4) {
                    root.infoReady = false;
                    return;
                }
                try {
                    const cfg = JSON.parse(parts[0]);
                    const conns = JSON.parse(parts[1]);
                    const proxy = JSON.parse(parts[2]);
                    const ver = JSON.parse(parts[3]);
                    root.mode = cfg.mode ?? "";
                    root.tunEnabled = cfg.tun?.enable ?? false;
                    root.port = cfg.port ?? 0;
                    root.version = ver.version ?? "";
                    root.downloadTotal = conns.downloadTotal ?? 0;
                    root.uploadTotal = conns.uploadTotal ?? 0;
                    root.connectionCount = (conns.connections ?? []).length;
                    root.currentNode = proxy.now ?? "";
                    root.infoReady = true;
                } catch (e) {
                    root.infoReady = false;
                }
            }
        }
    }

    Process {
        id: modeProc
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                Quickshell.execDetached(["notify-send", "-a", "Shell", "Mihomo",
                    "Could not change mode. Is the external controller reachable on 127.0.0.1:9090?"]);
            }
            root.refresh();
        }
    }

    Process {
        id: stateProc
        command: ["systemctl", "show", "-p", "ActiveState", "-p", "LoadState", "mihomo.service"]
        stdout: StdioCollector {
            onStreamFinished: {
                // systemctl prints properties alphabetically, not in the
                // order they were requested, so parse key=value pairs.
                const props = {};
                for (const line of text.trim().split("\n")) {
                    const i = line.indexOf("=");
                    if (i > 0)
                        props[line.slice(0, i)] = line.slice(i + 1).trim();
                }
                root.loadState = props.LoadState ?? "";
                root.activeState = props.ActiveState || "unknown";
            }
        }
    }

    Process {
        id: controlProc
        onExited: (exitCode, exitStatus) => {
            root.pkexecRunning = false;
            const action = root.pendingAction;
            root.pendingAction = "";
            // 126 means the pkexec authentication dialog was dismissed.
            if (exitCode !== 0 && exitCode !== 126) {
                Quickshell.execDetached([
                    "notify-send", "-a", "Shell",
                    "Mihomo",
                    `Could not ${action || "change"} mihomo.service (exit ${exitCode}). Check \`systemctl status mihomo\`.`
                ]);
            }
            root.refresh();
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}