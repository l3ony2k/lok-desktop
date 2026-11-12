pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Battery charge limit (ASUS CX54, 2026-11-12): 60 / 80 / 100 %.
 *
 * All privileged work lives in /usr/local/bin/battery-limit, called through
 * `sudo -n` (sudoers drop-in /etc/sudoers.d/battery-limit allows only that
 * script). The EC forgets the limit on every boot; the helper saves the choice
 * in /etc/battery-charge-limit and battery-charge-threshold.service re-applies
 * it. Charging resumes 5 points below the limit. Reading state needs no root.
 */
Singleton {
    id: root

    property int limit: 0          // current EC end threshold
    property int savedLimit: 0     // value re-applied at boot
    property int capacity: 0
    property string batteryStatus: ""
    property bool onAc: false
    property bool busy: false
    property bool ready: false
    property bool setupMissing: false
    property string lastError: ""

    readonly property bool active: limit > 0 && limit < 100
    readonly property string icon: limit >= 100 ? "battery_charging_full"
        : limit >= 80 ? "battery_charging_80" : "battery_charging_60"
    readonly property string statusText: {
        if (setupMissing)
            return "Setup needed";
        if (!ready)
            return "Checking…";
        if (busy)
            return "Working…";
        return limit >= 100 ? "No limit" : `Limit ${limit}%`;
    }

    function refresh() {
        run(["status"]);
    }

    // 60 -> 80 -> 100 -> 60
    function cycle() {
        run(["cycle"]);
    }

    function setLimit(value) {
        run(["set", String(value)]);
    }

    function run(args) {
        if (helperProc.running)
            return;
        const privileged = args[0] !== "status";
        helperProc.command = (privileged ? ["sudo", "-n"] : []).concat(["/usr/local/bin/battery-limit"]).concat(args);
        busy = privileged;
        helperProc.running = true;
    }

    function applyStatus(text) {
        const parsed = {};
        for (const line of text.trim().split("\n")) {
            const i = line.indexOf("=");
            if (i > 0)
                parsed[line.slice(0, i)] = line.slice(i + 1).trim();
        }
        if (!("limit" in parsed))
            return;
        root.limit = parseInt(parsed.limit) || 0;
        root.savedLimit = parseInt(parsed.saved) || 0;
        root.capacity = parseInt(parsed.capacity) || 0;
        root.batteryStatus = parsed.status ?? "";
        root.onAc = parsed.ac === "1";
        root.ready = true;
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
                if (/password is required|sudoers|No such file|not found/i.test(t))
                    root.setupMissing = true;
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.busy = false;
            if (exitCode !== 0)
                Quickshell.execDetached(["notify-send", "-a", "Shell", "Battery limit",
                    `Could not change the charge limit (exit ${exitCode}). ${root.lastError}`]);
            else
                root.lastError = "";
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!root.busy)
                root.run(["status"]);
        }
    }
}
