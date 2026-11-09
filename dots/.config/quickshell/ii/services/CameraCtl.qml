pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * IPU6 camera: privacy switch + post-hibernate recovery (ASUS, 2026-11-09).
 *
 * All privileged work lives in /usr/local/bin/camera-ctl, called through
 * `sudo -n` (sudoers drop-in /etc/sudoers.d/camera-ctl allows only that
 * script). After a privacy change WirePlumber is restarted so it drops or
 * re-opens the camera. Recovery only runs when the helper reports
 * health=broken (last IPU6 auth failed, i.e. after a hibernate resume);
 * on a working camera it is refused, because unbinding a working IPU6
 * crashes the driver.
 */
Singleton {
    id: root

    property bool privacy: false        // camera blocked by the user
    property bool applied: false        // node permissions match the block
    property string health: "unknown"   // "ok" | "broken" | "unknown"
    property bool busy: false
    property bool ready: false
    property bool setupMissing: false
    property bool syncedThisSession: false
    property string lastError: ""

    readonly property string icon: privacy ? "videocam_off" : (health === "broken" ? "no_photography" : "videocam")
    readonly property string statusText: {
        if (setupMissing)
            return "Setup needed";
        if (!ready)
            return "Checking…";
        if (busy)
            return "Working…";
        if (privacy)
            return "Blocked";
        if (health === "broken")
            return "Broken · right-click";
        return "On";
    }

    // ---- Public API ----------------------------------------------------
    function refresh() {
        run(["status"]);
    }
    function toggle() {
        if (busy)
            return;
        run([privacy ? "on" : "off"]);
    }
    function recover() {
        if (busy)
            return;
        if (health !== "broken") {
            notify("Camera is working", "Recovery is only needed after a hibernate resume breaks the camera.");
            return;
        }
        notify("Recovering camera…", "Audio may drop for a moment.");
        run(["recover"]);
    }

    // ---- Internals -----------------------------------------------------
    property var pending: null

    function notify(title, body) {
        Quickshell.execDetached(["notify-send", "-a", "Camera", "-i", "camera-video", title, body]);
    }
    function run(args) {
        if (helperProc.running) {
            root.pending = args;
            return;
        }
        helperProc.lastCmd = args[0];
        helperProc.command = ["sudo", "-n", "/usr/local/bin/camera-ctl"].concat(args);
        busy = args[0] !== "status";
        helperProc.running = true;
    }
    function parse(text) {
        const out = {};
        for (const tok of text.trim().split(/\s+/)) {
            const i = tok.indexOf("=");
            if (i > 0)
                out[tok.slice(0, i)] = tok.slice(i + 1);
        }
        return out;
    }
    function handle(cmd, text) {
        const p = parse(text);
        if ("privacy" in p)
            root.privacy = p.privacy === "on";
        if ("applied" in p)
            root.applied = p.applied === "yes";
        if ("health" in p && cmd === "status")
            root.health = p.health;
        if (cmd === "status") {
            root.ready = true;
            root.setupMissing = false;
            // udev resets the nodes at boot; re-apply a saved block once per session.
            if (root.privacy && !root.applied && !root.syncedThisSession) {
                root.syncedThisSession = true;
                root.pending = ["sync"];
            }
        } else if (cmd === "off" || cmd === "on" || cmd === "sync") {
            wpRestart.running = true;
            root.pending = ["status"];
        } else if (cmd === "recover") {
            if (p.result === "ok")
                notify("Camera recovered", "The camera works again.");
            else if (p.result === "skipped")
                notify("Camera is working", "Nothing to recover.");
            else
                notify("Camera recovery failed", "Reboot to get the camera back.");
            root.pending = ["status"];
        }
    }

    Process {
        id: helperProc
        property string lastCmd: ""
        stdout: StdioCollector {
            onStreamFinished: root.handle(helperProc.lastCmd, text)
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (!t)
                    return;
                root.lastError = t.split("\n").pop();
                if (/password is required|sudoers|No such file|not found/i.test(t))
                    root.setupMissing = true;
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.busy = false;
            if (root.pending) {
                const next = root.pending;
                root.pending = null;
                Qt.callLater(() => root.run(next));
            }
        }
    }

    Process {
        id: wpRestart
        command: ["systemctl", "--user", "restart", "wireplumber.service"]
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.busy)
                root.run(["status"]);
        }
    }
}
