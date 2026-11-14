pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Machine stats for the left-sidebar dashboard and the bar resource popup (lok task, 2026-11-14).
 * Everything here is a plain sysfs/procfs read on the same tick as ResourceUsage (3 s), so it
 * always runs and the graphs have history the moment the sidebar opens. CPU and RAM history
 * come from ResourceUsage; this adds GPU (xe idle residency), temperatures, fan, disk, battery
 * and network history. Fan modes go through /usr/local/bin/fan-mode (sudoers rule).
 */
Singleton {
    id: root

    readonly property int historyLength: Config?.options.resources.historyLength ?? 60

    // Paths found once at startup (hwmon numbers move between boots)
    property string coretempDir: ""
    property string crosEcDir: ""
    property string gtDir: ""
    property string rootDisk: ""

    // CPU
    property real cpuTemp: 0
    property int cpuCores: 0
    property list<real> cpuTempHistory: []
    // GPU (render GT)
    property real gpuUsage: 0
    property real gpuFreq: 0
    property real gpuMaxFreq: 0
    property list<real> gpuUsageHistory: []
    property var previousGpu
    // Fan
    property int fanRpm: 0
    property string fanMode: "auto" // auto | cool | max
    property int fanDuty: -1 // forced duty in cool/max, -1 = EC automatic
    // Disk (root filesystem)
    property real diskTotal: 0
    property real diskFree: 0
    property real diskReadRate: 0
    property real diskWriteRate: 0
    property var previousDisk
    // Battery
    property bool hasBattery: false
    property int batteryPercent: 0
    property string batteryStatus: ""
    property real batteryCurrent: 0 // uA
    property real batteryVoltage: 0 // uV
    property real batteryChargeNow: 0
    property real batteryChargeFull: 0
    property real batteryChargeDesign: 0
    property int batteryCycles: 0
    readonly property real batteryPower: batteryCurrent * batteryVoltage / 1e12 // W
    readonly property real batteryHealth: batteryChargeDesign > 0 ? batteryChargeFull / batteryChargeDesign : 0
    readonly property real batteryHoursLeft: (batteryStatus === "Discharging" && batteryCurrent > 0) ? batteryChargeNow / batteryCurrent : -1
    // Network history (bytes/s), rates themselves come from ResourceUsage
    property list<real> netRxHistory: []
    property list<real> netTxHistory: []

    function push(list, value) {
        const next = [...list, value];
        if (next.length > historyLength) next.shift();
        return next;
    }
    function num(text) {
        const n = Number(String(text).trim());
        return isNaN(n) ? 0 : n;
    }
    function setFanMode(mode) {
        // Clicking the active mode again cancels it (back to automatic)
        const target = (mode === root.fanMode && mode !== "auto") ? "auto" : mode;
        fanProc.command = ["sudo", "-n", "/usr/local/bin/fan-mode", target];
        fanProc.running = true;
        root.fanMode = target; // optimistic; the state file confirms on the next tick
    }
    function formatBytes(bytes, digits = 1) {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let v = Math.max(0, bytes), i = 0;
        while (v >= 1000 && i < units.length - 1) { v /= 1024; i++; }
        return (i === 0 ? Math.round(v) : v.toFixed(digits)) + " " + units[i];
    }

    Process {
        id: discoverProc
        running: true
        command: ["bash", "-c", "for h in /sys/class/hwmon/hwmon*; do echo \"hwmon $(cat $h/name) $h\"; done; "
            + "g=$(ls -d /sys/class/drm/card*/device/tile0/gt0 2>/dev/null | head -1); echo \"gt $g\"; "
            + "echo \"cores $(nproc)\"; echo \"disk $(basename $(findmnt -no SOURCE / | sed 's/\\[.*//'))\""]
        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const p = line.split(" ");
                    if (p[0] === "hwmon" && p[1] === "coretemp") root.coretempDir = p[2];
                    else if (p[0] === "hwmon" && p[1] === "cros_ec") root.crosEcDir = p[2];
                    else if (p[0] === "gt") root.gtDir = p[1] ?? "";
                    else if (p[0] === "cores") root.cpuCores = Number(p[1]) || 0;
                    else if (p[0] === "disk") root.rootDisk = p[1] ?? "";
                }
                if (root.gtDir.length > 0) gpuMaxFreqFile.reload();
                dfProc.running = true;
            }
        }
    }

    // Each tick only asks every file to reload; values are set in each file's onLoaded, so they
    // are this tick's values (reload() is async: text() right after it returns the previous read).
    Timer {
        interval: Config.options?.resources?.updateInterval ?? 3000
        running: true
        repeat: true
        onTriggered: {
            for (const f of [cpuTempFile, gpuIdleFile, gpuFreqFile, fanFile, fanModeFile, fanDutyFile, diskStatsFile,
                             batCapacity, batStatus, batCurrent, batVoltage, batNow, batFull, batFullDesign, batCycles])
                if (f.path.length > 0) f.reload();
            root.netRxHistory = root.push(root.netRxHistory, ResourceUsage.netRxRate);
            root.netTxHistory = root.push(root.netTxHistory, ResourceUsage.netTxRate);
        }
    }

    // Free space changes slowly; df every 30 s
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: dfProc.running = true
    }
    Process {
        id: dfProc
        command: ["df", "-B1", "--output=size,avail", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split("\n").pop().trim().split(/\s+/);
                root.diskTotal = Number(p[0]) || 0;
                root.diskFree = Number(p[1]) || 0;
            }
        }
    }
    Process { id: fanProc }

    component SysFile: FileView {
        printErrors: false
        signal value(string text)
        onLoaded: value(text())
    }
    SysFile { id: cpuTempFile; path: root.coretempDir.length > 0 ? `${root.coretempDir}/temp1_input` : ""
        onValue: t => { root.cpuTemp = root.num(t) / 1000; root.cpuTempHistory = root.push(root.cpuTempHistory, Math.min(1, root.cpuTemp / 100)); } }
    SysFile { id: gpuIdleFile; path: root.gtDir.length > 0 ? `${root.gtDir}/gtidle/idle_residency_ms` : ""
        onValue: t => {
            const idle = root.num(t), now = Date.now();
            if (root.previousGpu && now > root.previousGpu.t)
                root.gpuUsage = Math.max(0, Math.min(1, 1 - (idle - root.previousGpu.idle) / (now - root.previousGpu.t)));
            root.previousGpu = { idle, t: now };
            root.gpuUsageHistory = root.push(root.gpuUsageHistory, root.gpuUsage);
        } }
    SysFile { id: gpuFreqFile; path: root.gtDir.length > 0 ? `${root.gtDir}/freq0/act_freq` : ""; onValue: t => root.gpuFreq = root.num(t) }
    SysFile { id: gpuMaxFreqFile; path: root.gtDir.length > 0 ? `${root.gtDir}/freq0/rp0_freq` : ""; onValue: t => root.gpuMaxFreq = root.num(t) }
    SysFile { id: fanFile; path: root.crosEcDir.length > 0 ? `${root.crosEcDir}/fan1_input` : ""; onValue: t => root.fanRpm = root.num(t) }
    SysFile { id: fanModeFile; path: "/run/fan-mode/mode"; onValue: t => root.fanMode = t.trim() || "auto" }
    SysFile { id: fanDutyFile; path: "/run/fan-mode/duty"; onValue: t => root.fanDuty = root.num(t) }
    SysFile { id: diskStatsFile; path: "/proc/diskstats"
        onValue: t => {
            if (root.rootDisk.length === 0) return;
            const line = t.split("\n").find(l => l.trim().split(/\s+/)[2] === root.rootDisk);
            if (!line) return;
            const f = line.trim().split(/\s+/), now = Date.now();
            const rd = Number(f[5]) * 512, wr = Number(f[9]) * 512;
            if (root.previousDisk && now > root.previousDisk.t) {
                const dt = (now - root.previousDisk.t) / 1000;
                root.diskReadRate = Math.max(0, (rd - root.previousDisk.rd) / dt);
                root.diskWriteRate = Math.max(0, (wr - root.previousDisk.wr) / dt);
            }
            root.previousDisk = { rd, wr, t: now };
        } }
    SysFile { id: batCapacity; path: "/sys/class/power_supply/BAT0/capacity"
        onValue: t => { root.hasBattery = t.trim().length > 0; root.batteryPercent = root.num(t); } }
    SysFile { id: batStatus; path: "/sys/class/power_supply/BAT0/status"; onValue: t => root.batteryStatus = t.trim() }
    SysFile { id: batCurrent; path: "/sys/class/power_supply/BAT0/current_now"; onValue: t => root.batteryCurrent = root.num(t) }
    SysFile { id: batVoltage; path: "/sys/class/power_supply/BAT0/voltage_now"; onValue: t => root.batteryVoltage = root.num(t) }
    SysFile { id: batNow; path: "/sys/class/power_supply/BAT0/charge_now"; onValue: t => root.batteryChargeNow = root.num(t) }
    SysFile { id: batFull; path: "/sys/class/power_supply/BAT0/charge_full"; onValue: t => root.batteryChargeFull = root.num(t) }
    SysFile { id: batFullDesign; path: "/sys/class/power_supply/BAT0/charge_full_design"; onValue: t => root.batteryChargeDesign = root.num(t) }
    SysFile { id: batCycles; path: "/sys/class/power_supply/BAT0/cycle_count"; onValue: t => root.batteryCycles = root.num(t) }
}
