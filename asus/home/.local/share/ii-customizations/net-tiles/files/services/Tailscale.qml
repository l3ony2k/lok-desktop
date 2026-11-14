pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

/**
 * Tailscale state for the quick toggle and the peers dialog.
 *
 * Two layers of state are tracked separately, because they fail independently:
 *   - daemon:  tailscaled.service (systemd, needs root to start/stop)
 *   - backend: `tailscale status --json` BackendState (NeedsLogin, Running, Stopped, ...)
 *
 * `tailscale up` / `down` need root or an operator, so every privileged action
 * goes through pkexec. Reading state does not.
 */
Singleton {
    id: root

    // ---- Daemon --------------------------------------------------------
    property string daemonState: "checking"
    property string loadState: ""           // "loaded", "not-found", ...
    readonly property bool daemonActive: daemonState === "active"
    // `systemctl show tailscaled.service` answers even when the package is
    // missing, so LoadState is the only trustworthy "is it installed" probe.
    readonly property bool installed: loadState !== "not-found" && loadState !== ""

    // ---- Backend -------------------------------------------------------
    property bool jsonReady: false
    property string backendState: ""        // "Running", "Stopped", "NeedsLogin", ...
    property string hostName: ""
    property string dnsName: ""
    property var selfAddresses: []
    property var peers: []                  // see applyStatus() for the shape
    property string lastError: ""
    // `tailscale status` needs root or an operator. Without one it fails with
    // "access denied"; the tile still works, it just cannot show peers.
    property bool statusAccessDenied: false

    // ---- Action bookkeeping --------------------------------------------
    property string pendingAction: ""       // "", "start", "stop", "up", "down"
    readonly property bool busy: pendingAction !== "" || pkexecRunning

    // Cheap, honest read of what the user is going to care about.
    readonly property bool running: daemonActive && backendState === "Running"
    readonly property bool needsLogin: backendState === "NeedsLogin" || backendState === "NeedsMachineAuth"
    readonly property int peersOnline: peers.filter(p => p.online).length

    readonly property string statusText: {
        if (!installed)
            return "Not installed";
        if (!jsonReady && !daemonActive)
            return "Checking…";
        if (!daemonActive)
            return daemonState === "failed" ? "Failed" : daemonState === "checking" ? "Checking…" : "Off";
        if (pendingAction === "start")
            return "Starting…";
        if (pendingAction === "stop")
            return "Stopping…";
        if (pendingAction === "up")
            return "Connecting…";
        if (pendingAction === "down")
            return "Disconnecting…";
        if (!jsonReady)
            return statusAccessDenied ? "Running (no access)" : "Reading state…";
        if (backendState === "NeedsLogin")
            return "Needs login";
        if (backendState === "NeedsMachineAuth")
            return "Awaiting approval";
        if (backendState === "Starting")
            return "Starting…";
        if (backendState === "Running")
            return peersOnline > 0 ? `${peersOnline} online` : "No peers online";
        if (backendState === "Stopped")
            return "Disconnected";
        return backendState || "Unknown";
    }

    readonly property string icon: {
        if (!installed)
            return "vpn_key_off";
        if (!daemonActive)
            return "vpn_lock";
        if (running)
            return "vpn_lock_2";
        if (needsLogin)
            return "link_off";
        return "vpn_key";
    }

    // ---- Public API ----------------------------------------------------
    function refresh() {
        if (!daemonProc.running)
            daemonProc.running = true;
        if (daemonActive && !statusProc.running)
            statusProc.running = true;
    }

    /**
     * Start the daemon if it is not running, otherwise flip the backend
     * up/down. Uses pkexec so it works without an operator install.
     */
    function toggle() {
        if (busy)
            return;
        if (!installed) {
            notifyInstall();
            return;
        }
        if (!daemonActive) {
            pendingAction = "start";
            runPrivileged("start");
        } else if (running) {
            pendingAction = "down";
            runPrivileged("down");
        } else {
            pendingAction = "up";
            runPrivileged("up");
        }
    }

    function startDaemon() {
        if (busy || daemonActive)
            return;
        pendingAction = "start";
        runPrivileged("start");
    }

    function stopDaemon() {
        if (busy || !daemonActive)
            return;
        pendingAction = "stop";
        runPrivileged("stop");
    }

    function connectNow() {
        if (busy || running)
            return;
        pendingAction = "up";
        runPrivileged("up");
    }

    function disconnectNow() {
        if (busy || !running)
            return;
        pendingAction = "down";
        runPrivileged("down");
    }

    function notifyInstall() {
        Quickshell.execDetached([
            "notify-send", "-a", "Shell",
            "Tailscale",
            "tailscaled is not installed. Run `sudo pacman -S --needed tailscale` first."
        ]);
    }

    function copyText(text) {
        if (!text)
            return;
        Quickshell.execDetached(["wl-copy", text]);
    }

    // ---- Counter for pkexec child processes ----------------------------
    property bool pkexecRunning: false

    function runPrivileged(action) {
        let args;
        if (action === "start" || action === "stop") {
            args = ["pkexec", "/usr/bin/systemctl", action, "tailscaled.service"];
        } else {
            // `tailscale set --operator=$USER` (done on this machine) lets the
            // CLI run unprivileged, so up/down need no password prompt.
            // `--accept-dns=false` keeps mihomo in charge of DNS; flip it to
            // true if you ever want Tailscale to own resolv.conf instead.
            args = action === "up"
                ? ["/usr/bin/tailscale", "up", "--accept-dns=false"]
                : ["/usr/bin/tailscale", "down"];
        }
        lastError = "";
        pkexecRunning = true;
        controlProc.command = args;
        controlProc.running = true;
    }

    // ---- Daemon probing ------------------------------------------------
    Process {
        id: daemonProc
        // `systemctl show` gives state without the coloured output of status.
        command: ["systemctl", "show", "-p", "ActiveState", "-p", "LoadState", "tailscaled.service"]
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
                root.daemonState = props.ActiveState || "unknown";
                const state = root.daemonState;
                if (state === "active") {
                    if (!statusProc.running)
                        statusProc.running = true;
                } else {
                    root.jsonReady = false;
                    root.backendState = "";
                    root.peers = [];
                }
            }
        }
    }

    Process {
        id: statusProc
        command: ["tailscale", "status", "--json"]
        stderr: StdioCollector {
            onStreamFinished: {
                const err = text.trim();
                if (!err)
                    return;
                root.statusAccessDenied = /access denied|permission denied|operation not permitted/i.test(err);
                root.lastError = root.statusAccessDenied
                    ? "Cannot read Tailscale state as this user. Run `sudo tailscale set --operator=$USER` once to allow it."
                    : err;
            }
        }
        stdout: StdioCollector {
            id: statusCollector
            onStreamFinished: {
                if (!text.trim())
                    return;
                try {
                    root.applyStatus(JSON.parse(text));
                } catch (e) {
                    root.jsonReady = false;
                    root.lastError = "Could not parse tailscale status: " + e;
                }
            }
        }
    }

    function applyStatus(status) {
        root.jsonReady = true;
        root.backendState = status.BackendState ?? "";
        root.hostName = status.Self?.HostName ?? "";
        root.dnsName = status.Self?.DNSName ?? "";
        root.selfAddresses = status.Self?.TailscaleIPs ?? [];

        const seen = new Set();
        const list = [];
        const raw = status.Peer ?? {};

        // nuc, phone, ... plus the magic "self" entry the dialog can render.
        if (status.Self) {
            list.push({
                id: status.Self.ID ?? "self",
                hostName: status.Self.HostName ?? "this device",
                dnsName: status.Self.DNSName ?? "",
                os: status.Self.OS ?? "",
                ips: status.Self.TailscaleIPs ?? [],
                online: true,
                relay: "",
                connected: true,
                isSelf: true
            });
            seen.add(status.Self.ID);
        }

        for (const key in raw) {
            const peer = raw[key];
            if (!peer || seen.has(peer.ID))
                continue;
            seen.add(peer.ID);
            list.push({
                id: peer.ID ?? key,
                hostName: peer.HostName ?? key,
                dnsName: peer.DNSName ?? "",
                os: peer.OS ?? "",
                ips: peer.TailscaleIPs ?? [],
                online: !!peer.Online,
                relay: peer.Relay ?? "",
                rxBytes: peer.RxBytes ?? 0,
                txBytes: peer.TxBytes ?? 0,
                exitNode: !!peer.ExitNode,
                exitNodeOption: !!peer.ExitNodeOption,
                connected: false,
                isSelf: false
            });
        }

        list.sort((a, b) => {
            if (a.isSelf !== b.isSelf)
                return a.isSelf ? -1 : 1;
            if (a.online !== b.online)
                return a.online ? -1 : 1;
            return a.hostName.localeCompare(b.hostName);
        });
        root.peers = list;
    }

    // ---- Privileged action runner --------------------------------------
    Process {
        id: controlProc
        onExited: (exitCode, exitStatus) => {
            root.pkexecRunning = false;
            const action = root.pendingAction;
            root.pendingAction = "";
            // pkexec returns 126 when the authentication dialog is dismissed.
            if (exitCode !== 0 && exitCode !== 126) {
                Quickshell.execDetached([
                    "notify-send", "-a", "Shell",
                    "Tailscale",
                    `Could not ${action || "change"} Tailscale (exit ${exitCode}). Check \`systemctl status tailscaled\` or \`tailscale status\`.`
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