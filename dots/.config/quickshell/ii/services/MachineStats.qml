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
    property real batteryPower: 0 // W
    property real batteryHealth: 0 // 0..1
    property int batteryCycles: 0
    property real batteryHoursLeft: -1
    // Network history (bytes/s), rates themselves come from ResourceUsage
    property list<real> netRxHistory: []
    property list<real> netTxHistory: []

    function push(list, value) {
        const next = [...list, value];
        if (next.length > historyLength) next.shift();
        return next;
    }
    function readNum(file) {
        file.reload();
        const n = Number(file.text().trim());
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
                if (root.gtDir.length > 0) root.gpuMaxFreq = root.readNum(gpuMaxFreqFile);
                dfProc.running = true;
            }
        }
    }

    Timer {
        interval: Config.options?.resources?.updateInterval ?? 3000
        running: true
        repeat: true
        onTriggered: {
            if (root.coretempDir.length > 0) {
                root.cpuTemp = root.readNum(cpuTempFile) / 1000;
                root.cpuTempHistory = root.push(root.cpuTempHistory, Math.min(1, root.cpuTemp / 100));
            }
            if (root.gtDir.length > 0) {
                const idle = root.readNum(gpuIdleFile), now = Date.now();
                if (root.previousGpu && now > root.previousGpu.t) {
                    const busy = 1 - (idle - root.previousGpu.idle) / (now - root.previousGpu.t);
                    root.gpuUsage = Math.max(0, Math.min(1, busy));
                }
                root.previousGpu = { idle, t: now };
                root.gpuFreq = root.readNum(gpuFreqFile);
                root.gpuUsageHistory = root.push(root.gpuUsageHistory, root.gpuUsage);
            }
            if (root.crosEcDir.length > 0) root.fanRpm = root.readNum(fanFile);
            fanModeFile.reload();
            root.fanMode = fanModeFile.text().trim() || "auto";

            if (root.rootDisk.length > 0) {
                diskStatsFile.reload();
                const line = diskStatsFile.text().split("\n").find(l => l.trim().split(/\s+/)[2] === root.rootDisk);
                if (line) {
                    const f = line.trim().split(/\s+/), now = Date.now();
                    const rd = Number(f[5]) * 512, wr = Number(f[9]) * 512;
                    if (root.previousDisk && now > root.previousDisk.t) {
                        const dt = (now - root.previousDisk.t) / 1000;
                        root.diskReadRate = Math.max(0, (rd - root.previousDisk.rd) / dt);
                        root.diskWriteRate = Math.max(0, (wr - root.previousDisk.wr) / dt);
                    }
                    root.previousDisk = { rd, wr, t: now };
                }
            }

            batCapacity.reload();
            root.hasBattery = batCapacity.text().trim().length > 0;
            if (root.hasBattery) {
                root.batteryPercent = Number(batCapacity.text().trim());
                batStatus.reload();
                root.batteryStatus = batStatus.text().trim();
                const amps = root.readNum(batCurrent), volts = root.readNum(batVoltage);
                root.batteryPower = amps * volts / 1e12;
                const full = root.readNum(batFull), design = root.readNum(batFullDesign);
                root.batteryHealth = design > 0 ? full / design : 0;
                root.batteryCycles = root.readNum(batCycles);
                const now = root.readNum(batNow);
                root.batteryHoursLeft = (root.batteryStatus === "Discharging" && amps > 0) ? now / amps : -1;
            }

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

    component SysFile: FileView { blockLoading: true; printErrors: false } // sync: text() must be this tick's value
    SysFile { id: cpuTempFile; path: root.coretempDir.length > 0 ? `${root.coretempDir}/temp1_input` : "" }
    SysFile { id: gpuIdleFile; path: root.gtDir.length > 0 ? `${root.gtDir}/gtidle/idle_residency_ms` : "" }
    SysFile { id: gpuFreqFile; path: root.gtDir.length > 0 ? `${root.gtDir}/freq0/act_freq` : "" }
    SysFile { id: gpuMaxFreqFile; path: root.gtDir.length > 0 ? `${root.gtDir}/freq0/rp0_freq` : "" }
    SysFile { id: fanFile; path: root.crosEcDir.length > 0 ? `${root.crosEcDir}/fan1_input` : "" }
    SysFile { id: fanModeFile; path: "/run/fan-mode/mode" }
    SysFile { id: diskStatsFile; path: "/proc/diskstats" }
    SysFile { id: batCapacity; path: "/sys/class/power_supply/BAT0/capacity" }
    SysFile { id: batStatus; path: "/sys/class/power_supply/BAT0/status" }
    SysFile { id: batCurrent; path: "/sys/class/power_supply/BAT0/current_now" }
    SysFile { id: batVoltage; path: "/sys/class/power_supply/BAT0/voltage_now" }
    SysFile { id: batNow; path: "/sys/class/power_supply/BAT0/charge_now" }
    SysFile { id: batFull; path: "/sys/class/power_supply/BAT0/charge_full" }
    SysFile { id: batFullDesign; path: "/sys/class/power_supply/BAT0/charge_full_design" }
    SysFile { id: batCycles; path: "/sys/class/power_supply/BAT0/cycle_count" }
}
