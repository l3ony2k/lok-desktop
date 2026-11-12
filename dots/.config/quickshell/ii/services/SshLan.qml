pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * LAN-wide SSH access, governed by ufw.
 *
 * All privileged work lives in /usr/local/bin/ssh-lan-toggle (installed by
 * ~/.local/share/ssh-lan-toggle/install.sh). That helper owns
 * /etc/ssh-lan-toggle.conf and the tagged ufw rule, and is the single source
 * of truth for both state and allowed range. This service only shells out to
 * it through `sudo -n`, which the sudoers drop-in restricts to that one
 * script.
 */
Singleton {
    id: root

    property string state: "checking"     // "checking" | "on" | "off" | "error"
    property string allowedRange: ""      // range the helper will allow
    property string activeFrom: ""        // from-address(es) ufw is allowing now
    property string sshdState: ""         // "active" | "inactive"
    property string rootLogin: ""         // "yes" | "no"
    property string rootPassword: ""      // "set" | "locked"
    property bool setupMissing: false     // helper or sudoers not installed
    property string lastError: ""
    property bool busy: false
    property string lanAddress: ""        // this machine's LAN IPv4, for the dialog

    readonly property bool active: state === "on"
    readonly property bool ready: state !== "checking"
    readonly property string icon: "terminal"
    readonly property string statusText: {
        if (setupMissing)
            return "Setup needed";
        if (!ready)
            return "Checking…";
        if (state === "error")
            return "Unavailable";
        if (busy)
            return active ? "Disabling…" : "Enabling…";
        return active ? "LAN open" : "Off";
    }

    // ---- Public API ----------------------------------------------------
    function refresh() {
        run(["status"]);
    }

    function enable() {
        if (busy)
            return;
        run(["on"]);
    }

    function disable() {
        if (busy)
            return;
        run(["off"]);
    }

    function toggle() {
        if (busy)
            return;
        run([active ? "off" : "on"]);
    }

    function setRange(cidr) {
        if (busy)
            return;
        const value = String(cidr ?? "").trim();
        if (value.length === 0) {
            lastError = "Enter a network range first, e.g. 192.168.1.0/24";
            return;
        }
        run(["set", value]);
    }

    function clearError() {
        lastError = "";
    }

    function run(args) {
        if (helperProc.running)
            return;
        helperProc.command = ["sudo", "-n", "/usr/local/bin/ssh-lan-toggle"].concat(args);
        // Status polls run every 10 s; they must not make the tile look busy.
        busy = args[0] !== "status";
        helperProc.running = true;
    }

    function applyStatus(text) {
        const parsed = {};
        for (const line of text.trim().split("\n")) {
            const i = line.indexOf("=");
            if (i > 0)
                parsed[line.slice(0, i)] = line.slice(i + 1).trim();
        }
        if (!("state" in parsed))
            return;
        root.state = parsed.state;
        if (parsed.range)
            root.allowedRange = parsed.range;
        root.activeFrom = parsed.active ?? "";
        root.sshdState = parsed.sshd ?? "";
        root.rootLogin = parsed.rootlogin ?? "";
        root.rootPassword = parsed["rootpw"] ?? "";
        root.setupMissing = false;
    }

    Process {
        id: helperProc
        stdout: StdioCollector {
            onStreamFinished: root.applyStatus(text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (!t)
                    return;
                root.lastError = t.split("\n").pop();
                if (/password is required|sudoers|No such file|not found/i.test(t)) {
                    root.setupMissing = true;
                    root.state = "error";
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.busy = false;
            if (exitCode !== 0) {
                if (root.state === "checking")
                    root.state = "error";
            } else {
                root.lastError = "";
            }
            if (!lanAddressProc.running)
                lanAddressProc.running = true;
        }
    }

    // LAN address of the default-route interface (not Tailscale/mihomo).
    Process {
        id: lanAddressProc
        running: true
        command: ["bash", "-c", "dev=$(ip route show default 2>/dev/null | awk '{print $5; exit}'); ip -4 -o addr show ${dev:+dev \"$dev\"} scope global 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | head -n1"]
        stdout: StdioCollector {
            onStreamFinished: root.lanAddress = text.trim()
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.busy)
                root.run(["status"]);
        }
    }
}
