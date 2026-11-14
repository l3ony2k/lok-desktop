pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Services.Pipewire

/**
 * Left sidebar dashboard (lok task, 2026-11-14): a scratchpad on top (same file as the
 * Super+G Notes widget) and machine-monitor cards below. Data: ResourceUsage + MachineStats,
 * both always sampling, so graphs already have history when the sidebar opens.
 */
Item {
    id: root
    // lok: 9 logical = 12 device px at 1.333, so every inset and gap between cards is a whole pixel (same on both sidebars)
    readonly property real gap: Appearance.lok ? 9 : 8
    readonly property real pad: 12
    readonly property real minScratchHeight: 160
    // "" = card grid, otherwise the key of the card whose detail page is open
    property string detail: ""
    // heavier sampling (processes, per-core, meminfo...) only while the sidebar is open
    // parent check: the sidebar re-creates pages with createObject(); a replaced instance stops sampling
    readonly property bool live: GlobalStates.sidebarLeftOpen && root.parent !== null

    onActiveFocusChanged: if (activeFocus) scratchArea.focusEnd()
    onLiveChanged: if (!live) detail = ""
    // Esc leaves a detail page first; otherwise it falls through and closes the sidebar
    Keys.onEscapePressed: event => {
        if (root.detail !== "") { root.detail = ""; event.accepted = true; }
        else event.accepted = false;
    }

    ColumnLayout {
        anchors.fill: parent
        // lok: the sidebar's own padding is the margin (the page no longer sits on a layer of its own)
        anchors.margins: Appearance.lok ? 0 : root.gap
        spacing: root.gap

        // ---------- Scratchpad ----------
        Rectangle {
            id: scratchBox
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: root.minScratchHeight
            color: Appearance.colors.colLayer2
            LokFrame { color: scratchArea.activeFocus ? Appearance.colors.colLokFrame : Appearance.colors.colLokDivider }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: root.pad
                spacing: root.gap

                CardHeader {
                    icon: "notes"
                    title: Translation.tr("Scratchpad")
                    badge: saveDebounce.running ? Translation.tr("Saving") : Translation.tr("Saved")
                    badgeFramed: false
                }

                ScrollView {
                    id: scratchScroll
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    StyledTextArea {
                        id: scratchArea
                        anchors.left: parent.left
                        anchors.right: parent.right
                        padding: 0
                        background: null
                        wrapMode: TextEdit.Wrap
                        textFormat: TextEdit.PlainText
                        selectByMouse: true
                        persistentSelection: true
                        placeholderText: Translation.tr("Type anything. Saved as you go.")
                        font.family: Appearance.font.family.monospace
                        font.pixelSize: Appearance.font.pixelSize.small
                        onTextChanged: if (activeFocus) saveDebounce.restart()
                        function focusEnd() {
                            forceActiveFocus();
                            cursorPosition = text.length;
                        }
                    }
                }
            }
            MouseArea { // click anywhere in the box to type
                anchors.fill: parent
                z: -1
                onClicked: scratchArea.focusEnd()
            }
        }

        // ---------- Monitor ----------
        Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(monitorGrid.implicitHeight, root.height - root.minScratchHeight - root.gap * 3)
        Flickable {
            id: monitorFlick
            anchors.fill: parent
            contentHeight: monitorGrid.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            GridLayout {
                id: monitorGrid
                width: monitorFlick.width
                columns: 2
                rowSpacing: root.gap
                columnSpacing: root.gap

                // CPU
                Card {
                    icon: "memory"
                    detailKey: "cpu"
                    title: "CPU"
                    badge: `${Math.round(MachineStats.cpuTemp)}°C`
                    badgeAlert: MachineStats.cpuTemp >= 85
                    BigValue {
                        value: `${Math.round(ResourceUsage.cpuUsage * 100)}`
                        unit: "%"
                        alert: ResourceUsage.cpuUsage >= 0.9
                    }
                    BarHistory { values: ResourceUsage.cpuUsageHistory }
                    CardFooter { text: (ResourceUsage.cpuUsage < 0.1 ? Translation.tr("idle") : Translation.tr("busy")) + (MachineStats.cpuCores > 0 ? " · " + Translation.tr("%1 cores").arg(MachineStats.cpuCores) : "") }
                }
                // GPU
                Card {
                    icon: "monitor"
                    detailKey: "gpu"
                    title: "GPU"
                    badge: MachineStats.gpuFreq > 0 ? `${Math.round(MachineStats.gpuFreq)} MHz` : Translation.tr("RC6")
                    BigValue {
                        value: `${Math.round(MachineStats.gpuUsage * 100)}`
                        unit: "%"
                    }
                    LineHistory { values: MachineStats.gpuUsageHistory }
                    CardFooter { text: (MachineStats.gpuUsage < 0.1 ? Translation.tr("idle") : Translation.tr("busy")) + " · " + Translation.tr("max %1 MHz").arg(MachineStats.gpuMaxFreq) }
                }
                // Memory
                Card {
                    icon: "empty_dashboard"
                    detailKey: "mem"
                    title: "MEM"
                    badge: ResourceUsage.memoryUsedPercentage >= 0.85 ? Translation.tr("High") : ""
                    badgeAlert: true
                    BigValue {
                        value: `${Math.round(ResourceUsage.memoryUsedPercentage * 100)}`
                        unit: "%"
                        alert: ResourceUsage.memoryUsedPercentage >= 0.85
                    }
                    LineHistory { values: ResourceUsage.memoryUsageHistory }
                    CardFooter { text: `${(ResourceUsage.memoryUsed / 1048576).toFixed(1)} / ${(ResourceUsage.memoryTotal / 1048576).toFixed(0)} GB` }
                }
                // Disk
                Card {
                    icon: "save"
                    detailKey: "disk"
                    title: Translation.tr("Free space")
                    badge: MachineStats.formatBytes(MachineStats.diskTotal, 0)
                    BigValue {
                        readonly property var parts: MachineStats.formatBytes(MachineStats.diskFree, 0).split(" ")
                        value: parts[0]
                        unit: parts[1] ?? ""
                    }
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 32
                        Rectangle { // used fraction, flat meter
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: 6
                            color: Appearance.colors.colLokDivider
                            Rectangle {
                                width: parent.width * (MachineStats.diskTotal > 0 ? 1 - MachineStats.diskFree / MachineStats.diskTotal : 0)
                                height: parent.height
                                color: Appearance.colors.colMeterFill
                            }
                        }
                    }
                    CardFooter { text: `R ${MachineStats.formatBytes(MachineStats.diskReadRate, 0)}/s · W ${MachineStats.formatBytes(MachineStats.diskWriteRate, 0)}/s` }
                }
                // Network
                Card {
                    icon: Network.ethernet ? "lan" : "network_wifi"
                    detailKey: "net"
                    title: Translation.tr("Network")
                    badge: Network.ethernet ? "LAN" : (Network.networkName.length > 0 ? "Wi-Fi" : Translation.tr("Offline"))
                    BigValue {
                        readonly property var parts: MachineStats.formatBytes(ResourceUsage.netRxRate, 0).split(" ")
                        value: parts[0]
                        unit: `${parts[1] ?? ""}/s`
                    }
                    LineHistory {
                        readonly property real peak: Math.max(1024, ...Array.prototype.slice.call(MachineStats.netRxHistory))
                        values: Array.prototype.slice.call(MachineStats.netRxHistory).map(v => v / peak)
                    }
                    CardFooter { text: `↑ ${MachineStats.formatBytes(ResourceUsage.netTxRate, 0)}/s` }
                }
                // Fan
                Card {
                    icon: "air"
                    detailKey: "fan"
                    title: Translation.tr("Fan")
                    badge: MachineStats.fanMode === "max" ? "Max" : MachineStats.fanMode === "cool" ? "Cool" : "Auto"
                    BigValue {
                        value: `${MachineStats.fanRpm}`
                        unit: "RPM"
                    }
                    CardFooter {
                        // cool = temperature-driven boost (never quieter than auto); power profile shown
                        // because it decides how much heat there is (it never touches the fan here)
                        readonly property string profile: PowerProfiles.profile === PowerProfile.PowerSaver ? Translation.tr("saver")
                            : PowerProfiles.profile === PowerProfile.Performance ? Translation.tr("performance") : Translation.tr("balanced")
                        text: MachineStats.fanMode === "cool" ? Translation.tr("Boost %1% · until ≤ 50°C").arg(Math.max(0, MachineStats.fanDuty))
                            : MachineStats.fanMode === "max" ? Translation.tr("Forced 100%")
                            : Translation.tr("EC auto · %1").arg(profile)
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Repeater {
                            model: [["auto", "Auto"], ["cool", "Cool"], ["max", "Max"]]
                            DialogButton {
                                required property var modelData
                                readonly property bool selected: MachineStats.fanMode === modelData[0]
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                implicitHeight: 28
                                padding: 4
                                buttonText: modelData[1]
                                colBackground: selected ? Appearance.colors.colPrimary : Appearance.colors.colLayer2
                                colBackgroundHover: selected ? Appearance.colors.colPrimaryHover : Appearance.colors.colLayer2Hover
                                colText: selected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
                                borderColor: selected ? Appearance.colors.colSelectedEdge : Appearance.colors.colLokDivider
                                onClicked: MachineStats.setFanMode(modelData[0])
                            }
                        }
                    }
                }
                // Battery
                Card {
                    visible: MachineStats.hasBattery
                    Layout.columnSpan: 2
                    icon: MachineStats.batteryStatus === "Charging" ? "battery_charging_full" : "battery_android_full"
                    detailKey: "battery"
                    title: Translation.tr("Battery · %1 cycles").arg(MachineStats.batteryCycles)
                    badge: Translation.tr("%1% health").arg(Math.round(MachineStats.batteryHealth * 100))
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: root.pad
                        BigValue {
                            value: `${MachineStats.batteryPercent}`
                            unit: "%"
                            alert: MachineStats.batteryPercent <= 20 && MachineStats.batteryStatus === "Discharging"
                        }
                        Item { Layout.fillWidth: true }
                        StyledText {
                            visible: BatteryLimit.ready && BatteryLimit.limit > 0
                            text: Translation.tr("limit %1%").arg(BatteryLimit.limit)
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                    }
                    CardFooter {
                        readonly property real h: MachineStats.batteryHoursLeft
                        text: {
                            const w = MachineStats.batteryPower.toFixed(1) + " W";
                            if (MachineStats.batteryStatus === "Discharging")
                                return Translation.tr("Discharging %1").arg(w) + (h > 0 ? ` · ${Math.floor(h)}:${String(Math.round((h % 1) * 60)).padStart(2, "0")} ${Translation.tr("left")}` : "");
                            if (MachineStats.batteryStatus === "Charging" && MachineStats.batteryPower >= 0.5)
                                return Translation.tr("Charging %1").arg(w);
                            return Translation.tr("On AC · holding");
                        }
                    }
                }
                ProcessesCard { Layout.columnSpan: 2 }
                StatusRow { Layout.columnSpan: 2 }
            }
        }
        }
    }

    Timer {
        id: saveDebounce
        interval: 500
        onTriggered: Notes.save(scratchArea.text)
    }
    // follow the shared notes file (Super+G Notes, external edits) while not typing here
    Component.onCompleted: scratchArea.text = Notes.content
    Connections {
        target: Notes
        function onContentChanged() {
            if (!scratchArea.activeFocus && scratchArea.text !== Notes.content) scratchArea.text = Notes.content;
        }
    }

    // ---------- processes ----------
    component ProcessesCard: Rectangle {
        id: procCard
        readonly property string sort: TopApps.sort
        readonly property var info: TopApps.info
        function setSort(k) { TopApps.setSort(k); }
        // column widths measured in the real font from the widest values, not fixed pixels
        StyledText { id: memProbe; visible: false; text: "1023.99 MB"; font.pixelSize: Appearance.font.pixelSize.smallie }
        StyledText { id: memHeadProbe; visible: false; text: Translation.tr("Memory"); font.pixelSize: Appearance.font.pixelSize.smallie }
        StyledText { id: cpuProbe; visible: false; text: "100.0"; font.pixelSize: Appearance.font.pixelSize.smallie }
        StyledText { id: cpuHeadProbe; visible: false; text: "% CPU"; font.pixelSize: Appearance.font.pixelSize.smallie }
        readonly property real memCol: Math.ceil(Math.max(memProbe.implicitWidth, memHeadProbe.implicitWidth)) + 2
        readonly property real cpuCol: Math.ceil(Math.max(cpuProbe.implicitWidth, cpuHeadProbe.implicitWidth)) + 2
        property string menuFor: "" // app whose actions are showing
        property string confirmFor: "" // "<app>:<signal>" armed by a first click, fires on the second
        // ending these from here would take the session down with them
        readonly property var protectedNames: ["qs", "quickshell", "Hyprland", "Xwayland", "systemd", "pipewire", "pipewire-pulse",
            "wireplumber", "dbus-daemon", "dbus-broker", "greetd", "NetworkManager", "sddm", "kwin_wayland", "plasmashell"]
        function canEnd(app) { return app.mine && !protectedNames.includes(app.name); }
        Timer { id: confirmTimeout; interval: 3000; onTriggered: procCard.confirmFor = "" }
        Layout.fillWidth: true
        implicitHeight: procColumn.implicitHeight + root.pad * 2
        color: Appearance.colors.colLayer2
        LokFrame { color: Appearance.colors.colLokDivider }

        Process { id: killProc }
        function endApp(app, signal) {
            if (!canEnd(app)) return;
            const key = app.name + ":" + signal;
            if (procCard.confirmFor !== key) { procCard.confirmFor = key; confirmTimeout.restart(); return; }
            procCard.confirmFor = "";
            killProc.command = ["kill", "-" + signal, ...app.pids.map(String)];
            killProc.running = true;
            procCard.menuFor = "";
        }

        ColumnLayout {
            id: procColumn
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: root.pad }
            spacing: 2
            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 4
                spacing: root.gap
                MaterialSymbol { text: "list"; iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colSubtext }
                StyledText { Layout.fillWidth: true; text: Translation.tr("Top processes"); color: Appearance.colors.colSubtext; font.pixelSize: Appearance.font.pixelSize.smallie }
                SortHeader { label: Translation.tr("Memory"); key: "mem"; current: procCard.sort; onPicked: k => procCard.setSort(k); Layout.preferredWidth: procCard.memCol }
                SortHeader { label: "% CPU"; key: "cpu"; current: procCard.sort; onPicked: k => procCard.setSort(k); Layout.preferredWidth: procCard.cpuCol }
                Item { Layout.preferredWidth: 24 }
            }
            Repeater {
                model: procCard.info.top
                ColumnLayout {
                    id: procRow
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 2
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        spacing: root.gap
                        StyledText { Layout.fillWidth: true; text: procRow.modelData.name; elide: Text.ElideRight; font.pixelSize: Appearance.font.pixelSize.smallie }
                        StyledText { Layout.preferredWidth: procCard.memCol; horizontalAlignment: Text.AlignRight; text: MachineStats.formatBytes(procRow.modelData.mem, 2); font.pixelSize: Appearance.font.pixelSize.smallie }
                        StyledText {
                            Layout.preferredWidth: procCard.cpuCol; horizontalAlignment: Text.AlignRight
                            text: procRow.modelData.cpu.toFixed(1)
                            color: procRow.modelData.cpu >= 90 ? Appearance.colors.colError : Appearance.colors.colOnLayer2
                            font.pixelSize: Appearance.font.pixelSize.smallie
                        }
                        RippleButton {
                            Layout.preferredWidth: 24; Layout.preferredHeight: 24
                            toggled: procCard.menuFor === procRow.modelData.name
                            colBackground: "transparent"
                            onClicked: procCard.menuFor = toggled ? "" : procRow.modelData.name
                            contentItem: MaterialSymbol { anchors.centerIn: parent; text: "more_vert"; iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colSubtext }
                        }
                    }
                    RowLayout { // actions for this app
                        visible: procCard.menuFor === procRow.modelData.name
                        Layout.fillWidth: true
                        Layout.bottomMargin: 4
                        spacing: 4
                        StyledText {
                            Layout.fillWidth: true
                            text: !procRow.modelData.mine ? Translation.tr("not yours: can't end")
                                : procCard.protectedNames.includes(procRow.modelData.name) ? Translation.tr("protected")
                                : procCard.confirmFor.startsWith(procRow.modelData.name + ":") ? Translation.tr("click again to confirm")
                                : Translation.tr("%1 process(es)").arg(procRow.modelData.pids.length)
                            color: Appearance.colors.colSubtext
                            font.pixelSize: Appearance.font.pixelSize.smaller
                        }
                        SmallButton { label: procCard.confirmFor === procRow.modelData.name + ":TERM" ? Translation.tr("Confirm") : Translation.tr("End"); enabled: procCard.canEnd(procRow.modelData); onClicked: procCard.endApp(procRow.modelData, "TERM") }
                        SmallButton { label: procCard.confirmFor === procRow.modelData.name + ":KILL" ? Translation.tr("Confirm") : Translation.tr("Kill"); enabled: procCard.canEnd(procRow.modelData); alert: true; onClicked: procCard.endApp(procRow.modelData, "KILL") }
                    }
                }
            }
            CardFooter {
                Layout.topMargin: 4
                text: Translation.tr("%1 other processes using %2").arg(procCard.info.restCount).arg(MachineStats.formatBytes(procCard.info.restMem, 0))
            }
        }
    }

    component SortHeader: StyledText {
        id: sortHeader
        property string label
        property string key
        property string current
        signal picked(string key)
        text: label
        horizontalAlignment: Text.AlignRight
        font.pixelSize: Appearance.font.pixelSize.smaller
        color: current === key ? Appearance.colors.colOnLayer2 : Appearance.colors.colSubtext
        font.underline: current === key
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: sortHeader.picked(sortHeader.key)
        }
    }

    component SmallButton: DialogButton {
        id: smallButton
        property string label // not "text": AbstractButton.text is FINAL
        property bool alert: false
        implicitHeight: 24
        padding: 8
        buttonText: label
        colBackground: Appearance.colors.colLayer2
        colBackgroundHover: Appearance.colors.colLayer2Hover
        colText: !enabled ? Appearance.colors.colSubtext : alert ? Appearance.colors.colError : Appearance.colors.colOnLayer2
        borderColor: alert && enabled ? Appearance.colors.colError : Appearance.colors.colLokDivider
    }

    // ---------- status row: camera, mic, coffee, screen ----------
    component StatusRow: Rectangle {
        Layout.fillWidth: true
        implicitHeight: statusRowLayout.implicitHeight + root.pad
        color: Appearance.colors.colLayer2
        LokFrame { color: Appearance.colors.colLokDivider }
        readonly property bool micInUse: Pipewire.linkGroups.values.filter(g => g.source?.type === PwNodeType.AudioSource && g.target?.type === PwNodeType.AudioInStream).length > 0
        readonly property bool micMuted: Audio.source?.audio?.muted ?? false
        readonly property bool sharing: Pipewire.linkGroups.values.filter(g => g.source?.type === PwNodeType.VideoSource).length > 0
        RowLayout {
            id: statusRowLayout
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: root.pad / 2 }
            spacing: 4
            StatusCell {
                glyph: CameraCtl.icon
                label: CameraCtl.privacy ? Translation.tr("Blocked") : Translation.tr("Camera")
                onClicked: CameraCtl.toggle()
            }
            StatusCell {
                glyph: parent.parent.micMuted ? "mic_off" : "mic"
                label: parent.parent.micInUse ? Translation.tr("In use") : parent.parent.micMuted ? Translation.tr("Muted") : Translation.tr("Idle")
                alert: parent.parent.micInUse && !parent.parent.micMuted
                onClicked: Audio.toggleMicMute()
            }
            StatusCell {
                glyph: "coffee"
                label: Idle.inhibit ? Translation.tr("Awake") : Translation.tr("Sleep ok")
                selected: Idle.inhibit
                onClicked: Idle.toggleInhibit()
            }
            StatusCell {
                glyph: "screen_record"
                label: parent.parent.sharing ? Translation.tr("Sharing") : Translation.tr("Screen")
                alert: parent.parent.sharing
                interactive: false
            }
        }
    }
    component StatusCell: RippleButton {
        id: cell
        property string glyph // not "icon": AbstractButton.icon is FINAL
        property string label
        property bool selected: false
        property bool alert: false
        property bool interactive: true
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 32
        enabled: interactive
        toggled: selected
        colBackground: Appearance.colors.colLayer2
        colBackgroundHover: Appearance.colors.colLayer2Hover
        borderWidth: selected ? 1 : 0
        borderColor: Appearance.colors.colSelectedEdge
        contentItem: RowLayout {
            spacing: 6
            Item { Layout.fillWidth: true }
            MaterialSymbol { text: cell.glyph; iconSize: Appearance.font.pixelSize.normal; color: cell.alert ? Appearance.colors.colError : cell.selected ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext }
            StyledText { text: cell.label; font.pixelSize: Appearance.font.pixelSize.smaller; color: cell.alert ? Appearance.colors.colError : cell.selected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2 }
            Item { Layout.fillWidth: true }
        }
    }

    // ---------- detail pages ----------
    // A modal over the whole sidebar, the same WindowDialog the right sidebar's tile dialogs use:
    // click the scrim, press Esc or Done to dismiss. `kind` is held while the close animation runs.
    Loader {
        id: detailLoader
        anchors.fill: parent
        z: 10
        active: false
        property string kind: ""
        readonly property bool wanted: root.detail !== ""
        onWantedChanged: {
            if (wanted) {
                kind = root.detail;
                if (item) { item.show = true; item.forceActiveFocus(); } else active = true;
            } else if (item) item.show = false;
        }
        onLoaded: { item.show = true; item.forceActiveFocus(); }
        sourceComponent: DetailDialog { kind: detailLoader.kind }
        Connections {
            target: detailLoader.item
            function onDismiss() {
                root.detail = "";
                root.forceActiveFocus(); // back to the scratchpad
            }
            function onVisibleChanged() {
                if (!detailLoader.item.visible && root.detail === "") detailLoader.active = false;
            }
        }
    }

    component DetailDialog: WindowDialog {
        id: dv
        property string kind
        readonly property bool sampling: root.live && dv.show

        // per-kind extra sources, only while this page is open
        property var cores: [] // [{use, mhz}]
        property var prevCores: []
        property var memRows: []
        property var ifaces: [] // [{name, rx, tx}]
        property var prevIfaces: ({})
        property var ecTemps: [] // [{label, c}]
        Timer {
            interval: Config.options?.resources?.updateInterval ?? 3000
            running: dv.sampling
            repeat: true
            triggeredOnStart: true
            onTriggered: {
                if (dv.kind === "cpu") { statFile.reload(); if (!freqProc.running) freqProc.running = true; }
                else if (dv.kind === "mem") memFile.reload();
                else if (dv.kind === "net") netFile.reload();
                else if (dv.kind === "fan" && !ecProc.running) ecProc.running = true;
            }
        }
        FileView {
            id: statFile; printErrors: false
            // path only while its page is open: setting it loads the file (no load at creation)
            path: dv.sampling && dv.kind === "cpu" ? "/proc/stat" : ""
            onLoaded: {
                const lines = text().split("\n").filter(l => /^cpu\d+ /.test(l));
                const now = lines.map(l => { const f = l.trim().split(/\s+/).slice(1, 8).map(Number); return { total: f.reduce((a, b) => a + b, 0), idle: f[3] }; });
                dv.cores = now.map((c, i) => {
                    const p = dv.prevCores[i];
                    const use = p && c.total > p.total ? 1 - (c.idle - p.idle) / (c.total - p.total) : 0;
                    return { use: Math.max(0, Math.min(1, use)), mhz: dv.cores[i]?.mhz ?? 0 };
                });
                dv.prevCores = now;
            }
        }
        Process {
            id: freqProc
            command: ["bash", "-c", "cat /sys/devices/system/cpu/cpu[0-9]*/cpufreq/scaling_cur_freq"]
            stdout: StdioCollector { onStreamFinished: {
                const f = text.trim().split("\n").map(Number);
                dv.cores = dv.cores.map((c, i) => ({ use: c.use, mhz: (f[i] ?? 0) / 1000 }));
            } }
        }
        FileView {
            id: memFile; printErrors: false
            // path only while its page is open: setting it loads the file (no load at creation)
            path: dv.sampling && dv.kind === "mem" ? "/proc/meminfo" : ""
            onLoaded: {
                const t = text(), kb = k => Number(t.match(new RegExp("^" + k + ":\\s+(\\d+)", "m"))?.[1] ?? 0) * 1024;
                const total = kb("MemTotal"), avail = kb("MemAvailable");
                dv.memRows = [
                    [Translation.tr("Used"), MachineStats.formatBytes(total - avail)],
                    [Translation.tr("Available"), MachineStats.formatBytes(avail)],
                    [Translation.tr("Cached"), MachineStats.formatBytes(kb("Cached") + kb("Buffers"))],
                    [Translation.tr("Shared"), MachineStats.formatBytes(kb("Shmem"))],
                    [Translation.tr("Swap used"), `${MachineStats.formatBytes(kb("SwapTotal") - kb("SwapFree"))} / ${MachineStats.formatBytes(kb("SwapTotal"))}`],
                ];
            }
        }
        FileView {
            id: netFile; printErrors: false
            // path only while its page is open: setting it loads the file (no load at creation)
            path: dv.sampling && dv.kind === "net" ? "/proc/net/dev" : ""
            onLoaded: {
                const now = Date.now(), next = {}, rows = [];
                for (const line of text().split("\n")) {
                    const m = line.match(/^\s*([^:\s]+):\s*(\d+)(?:\s+\d+){7}\s+(\d+)/);
                    if (!m || m[1] === "lo") continue;
                    const cur = { rx: Number(m[2]), tx: Number(m[3]), t: now }, p = dv.prevIfaces[m[1]];
                    next[m[1]] = cur;
                    const dt = p ? (now - p.t) / 1000 : 0;
                    rows.push({ name: m[1], rx: dt > 0 ? (cur.rx - p.rx) / dt : 0, tx: dt > 0 ? (cur.tx - p.tx) / dt : 0 });
                }
                dv.prevIfaces = next;
                dv.ifaces = rows;
            }
        }
        Process {
            id: ecProc
            command: ["bash", "-c", `cd ${MachineStats.crosEcDir} 2>/dev/null && for l in temp*_label; do echo "$(cat $l) $(cat \${l%_label}_input)"; done`]
            stdout: StdioCollector { onStreamFinished: {
                dv.ecTemps = text.trim().split("\n").filter(l => l.length).map(l => { const p = l.split(" "); return { label: p[0], c: Number(p[1]) / 1000 }; });
            } }
        }

        StyledText { id: freqProbe; visible: false; text: "10.0 GHz"; font.pixelSize: Appearance.font.pixelSize.smaller }
        readonly property var titles: ({ cpu: "CPU", gpu: "GPU", mem: "MEM", disk: Translation.tr("Disk"), net: Translation.tr("Network"), fan: Translation.tr("Fan"), battery: Translation.tr("Battery") })
        function peakOf(list, floor) { return Math.max(floor, ...Array.prototype.slice.call(list)); }
        function norm(list, peak) { return Array.prototype.slice.call(list).map(v => v / peak); }

        WindowDialogTitle { text: dv.titles[dv.kind] ?? "" }
        WindowDialogSeparator {}

            Flickable {
                id: detailFlick
                Layout.fillWidth: true
                // content-sized; scrolls only when the page is taller than the sidebar allows
                Layout.preferredHeight: Math.min(detailColumn.implicitHeight, Math.max(160, dv.height - 220))
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                contentHeight: detailColumn.implicitHeight
                ColumnLayout {
                    id: detailColumn
                    width: detailFlick.width
                    spacing: root.gap * 1.5

                    // CPU
                    DetailGraph { visible: dv.kind === "cpu"; label: Translation.tr("Usage"); value: `${Math.round(ResourceUsage.cpuUsage * 100)}%`; values: ResourceUsage.cpuUsageHistory }
                    DetailGraph { visible: dv.kind === "cpu"; label: Translation.tr("Package temperature"); value: `${Math.round(MachineStats.cpuTemp)}°C`; values: MachineStats.cpuTempHistory }
                    GridLayout {
                        visible: dv.kind === "cpu"
                        Layout.fillWidth: true
                        columns: 2; columnSpacing: root.pad; rowSpacing: 6
                        Repeater {
                            model: dv.kind === "cpu" ? dv.cores : []
                            RowLayout {
                                id: coreRow
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                spacing: 6
                                StyledText { text: String(coreRow.index).padStart(2, "0"); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                                Rectangle {
                                    Layout.fillWidth: true; implicitHeight: 6; color: Appearance.colors.colLokDivider
                                    Rectangle { width: parent.width * coreRow.modelData.use; height: parent.height; color: coreRow.modelData.use >= 0.9 ? Appearance.colors.colError : Appearance.colors.colMeterFill }
                                }
                                StyledText { Layout.preferredWidth: freqProbe.implicitWidth + 2; horizontalAlignment: Text.AlignRight; text: `${(coreRow.modelData.mhz / 1000).toFixed(1)} GHz`; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                            }
                        }
                    }
                    // GPU
                    DetailGraph { visible: dv.kind === "gpu"; label: Translation.tr("Render busy"); value: `${Math.round(MachineStats.gpuUsage * 100)}%`; values: MachineStats.gpuUsageHistory }
                    DetailRows {
                        visible: dv.kind === "gpu"
                        rows: [[Translation.tr("Frequency"), MachineStats.gpuFreq > 0 ? `${Math.round(MachineStats.gpuFreq)} MHz` : Translation.tr("idle (RC6)")],
                               [Translation.tr("Max frequency"), `${MachineStats.gpuMaxFreq} MHz`],
                               [Translation.tr("Driver"), "xe"]]
                    }
                    // Memory
                    DetailGraph { visible: dv.kind === "mem"; label: Translation.tr("Used"); value: `${Math.round(ResourceUsage.memoryUsedPercentage * 100)}%`; values: ResourceUsage.memoryUsageHistory }
                    DetailRows { visible: dv.kind === "mem"; rows: dv.memRows }
                    // Disk
                    DetailGraph { visible: dv.kind === "disk"; label: Translation.tr("Read"); value: `${MachineStats.formatBytes(MachineStats.diskReadRate)}/s`; values: dv.norm(MachineStats.diskReadHistory, dv.peakOf(MachineStats.diskReadHistory, 1048576)) }
                    DetailGraph { visible: dv.kind === "disk"; label: Translation.tr("Write"); value: `${MachineStats.formatBytes(MachineStats.diskWriteRate)}/s`; values: dv.norm(MachineStats.diskWriteHistory, dv.peakOf(MachineStats.diskWriteHistory, 1048576)) }
                    DetailRows {
                        visible: dv.kind === "disk"
                        rows: [[Translation.tr("Device"), MachineStats.rootDisk],
                               [Translation.tr("Used"), MachineStats.formatBytes(MachineStats.diskTotal - MachineStats.diskFree)],
                               [Translation.tr("Free"), MachineStats.formatBytes(MachineStats.diskFree)],
                               [Translation.tr("Size"), MachineStats.formatBytes(MachineStats.diskTotal)]]
                    }
                    // Network
                    DetailGraph { visible: dv.kind === "net"; label: Translation.tr("Download"); value: `${MachineStats.formatBytes(ResourceUsage.netRxRate)}/s`; values: dv.norm(MachineStats.netRxHistory, dv.peakOf(MachineStats.netRxHistory, 1024)) }
                    DetailGraph { visible: dv.kind === "net"; label: Translation.tr("Upload"); value: `${MachineStats.formatBytes(ResourceUsage.netTxRate)}/s`; values: dv.norm(MachineStats.netTxHistory, dv.peakOf(MachineStats.netTxHistory, 1024)) }
                    DetailRows {
                        visible: dv.kind === "net"
                        rows: [[Translation.tr("Network"), Network.networkName.length > 0 ? `${Network.networkName} · ${Network.networkStrength}%` : Translation.tr("offline")],
                               ...dv.ifaces.map(i => [i.name, `↓ ${MachineStats.formatBytes(i.rx, 0)}/s  ↑ ${MachineStats.formatBytes(i.tx, 0)}/s`])]
                    }
                    // Fan
                    DetailGraph { visible: dv.kind === "fan"; label: Translation.tr("Speed"); value: `${MachineStats.fanRpm} RPM`; values: dv.norm(MachineStats.fanRpmHistory, 6500) }
                    DetailRows {
                        visible: dv.kind === "fan"
                        rows: [[Translation.tr("Mode"), MachineStats.fanMode === "cool" ? Translation.tr("Cool · %1%").arg(MachineStats.fanDuty) : MachineStats.fanMode === "max" ? Translation.tr("Max · 100%") : Translation.tr("EC automatic")],
                               [Translation.tr("CPU package"), `${Math.round(MachineStats.cpuTemp)}°C`],
                               ...dv.ecTemps.map(t => [Translation.tr("EC %1").arg(t.label), `${t.c.toFixed(0)}°C`])]
                    }
                    // Battery
                    DetailGraph { visible: dv.kind === "battery"; label: Translation.tr("Power"); value: `${MachineStats.batteryPower.toFixed(1)} W`; values: dv.norm(MachineStats.batteryPowerHistory, dv.peakOf(MachineStats.batteryPowerHistory, 15)) }
                    DetailRows {
                        visible: dv.kind === "battery"
                        rows: [[Translation.tr("Status"), MachineStats.batteryStatus],
                               [Translation.tr("Charge"), `${MachineStats.batteryPercent}%`],
                               [Translation.tr("Capacity"), `${Math.round(MachineStats.batteryChargeFull / 1000)} / ${Math.round(MachineStats.batteryChargeDesign / 1000)} mAh`],
                               [Translation.tr("Health"), `${Math.round(MachineStats.batteryHealth * 100)}%`],
                               [Translation.tr("Cycles"), `${MachineStats.batteryCycles}`],
                               [Translation.tr("Voltage"), `${(MachineStats.batteryVoltage / 1e6).toFixed(2)} V`],
                               [Translation.tr("Charge limit"), BatteryLimit.limit > 0 ? `${BatteryLimit.limit}%` : "—"]]
                    }
                }
            }

        WindowDialogSeparator {}
        WindowDialogButtonRow {
            Item { Layout.fillWidth: true }
            DialogButton {
                buttonText: Translation.tr("Done")
                onClicked: dv.dismiss()
            }
        }
    }

    component DetailGraph: ColumnLayout {
        id: dg
        property string label
        property string value
        property list<real> values
        Layout.fillWidth: true
        spacing: 4
        RowLayout {
            Layout.fillWidth: true
            StyledText { Layout.fillWidth: true; text: dg.label; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
            StyledText { text: dg.value; font.pixelSize: Appearance.font.pixelSize.smallie; color: Appearance.colors.colOnLayer2 }
        }
        LineHistory { values: dg.values; implicitHeight: 56 }
    }

    component DetailRows: ColumnLayout {
        id: dr
        property var rows: []
        Layout.fillWidth: true
        spacing: 0
        Repeater {
            model: dr.rows
            Item {
                id: drRow
                required property var modelData
                required property int index
                Layout.fillWidth: true
                implicitHeight: 28
                Rectangle { visible: drRow.index > 0; anchors.top: parent.top; width: parent.width; height: Appearance.sizes.hairline; color: Appearance.colors.colLokDivider }
                StyledText { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; text: drRow.modelData[0]; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                StyledText { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; text: drRow.modelData[1]; font.pixelSize: Appearance.font.pixelSize.smallie; color: Appearance.colors.colOnLayer2 }
            }
        }
    }

    // ---------- building blocks ----------
    component CardHeader: RowLayout {
        id: header
        property string icon
        property string title
        property string badge
        property bool badgeAlert: false
        property bool badgeFramed: true
        Layout.fillWidth: true
        spacing: 6
        MaterialSymbol {
            text: header.icon
            iconSize: Appearance.font.pixelSize.normal
            color: Appearance.colors.colSubtext
        }
        StyledText {
            Layout.fillWidth: true
            text: header.title
            elide: Text.ElideRight
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smallie
        }
        Rectangle {
            opacity: header.badge.length > 0 ? 1 : 0 // keep the row height when there is no badge
            implicitWidth: header.badge.length > 0 ? badgeText.implicitWidth + (header.badgeFramed ? 12 : 0) : 0
            implicitHeight: badgeText.implicitHeight + (header.badgeFramed ? 4 : 0)
            color: "transparent"
            LokFrame { visible: header.badgeFramed; color: header.badgeAlert ? Appearance.colors.colError : Appearance.colors.colLokDivider }
            StyledText {
                id: badgeText
                anchors.centerIn: parent
                text: header.badge
                color: header.badgeAlert ? Appearance.colors.colError : Appearance.colors.colSubtext
                font.pixelSize: Appearance.font.pixelSize.smaller
            }
        }
    }

    component Card: Rectangle {
        id: card
        property string detailKey: ""
        property alias icon: cardHeader.icon
        property alias title: cardHeader.title
        property alias badge: cardHeader.badge
        property alias badgeAlert: cardHeader.badgeAlert
        default property alias content: cardBody.data
        Layout.fillWidth: true
        Layout.fillHeight: true // same height as the other card in its row
        Layout.alignment: Qt.AlignTop
        Layout.preferredWidth: 1 // equal columns
        implicitHeight: cardColumn.implicitHeight + root.pad * 2
        color: cardMouse.containsMouse && detailKey.length > 0 ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2
        LokFrame { color: Appearance.colors.colLokDivider }
        MouseArea { // under the content, so buttons inside the card keep their own clicks
            id: cardMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: card.detailKey.length > 0
            cursorShape: Qt.PointingHandCursor
            onClicked: root.detail = card.detailKey
        }
        ColumnLayout {
            id: cardColumn
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: root.pad }
            spacing: root.gap
            CardHeader { id: cardHeader }
            ColumnLayout {
                id: cardBody
                Layout.fillWidth: true
                spacing: root.gap
            }
        }
    }

    component BigValue: Row {
        id: big
        property string value
        property string unit
        property bool alert: false
        spacing: 4
        StyledText {
            id: bigNumber
            text: big.value
            color: big.alert ? Appearance.colors.colError : Appearance.colors.colOnLayer2
            font.family: Appearance.font.family.numbers
            font.pixelSize: 26
            font.weight: Font.DemiBold
        }
        StyledText {
            anchors.baseline: bigNumber.baseline
            text: big.unit
            color: Appearance.colors.colSubtext
            font.pixelSize: Appearance.font.pixelSize.smallie
        }
    }

    component CardFooter: StyledText {
        Layout.fillWidth: true
        elide: Text.ElideRight
        color: Appearance.colors.colSubtext
        font.pixelSize: Appearance.font.pixelSize.smaller
    }

    component LineHistory: Item {
        id: line
        property list<real> values
        Layout.fillWidth: true
        implicitHeight: 32
        Rectangle { // baseline
            anchors.bottom: parent.bottom
            width: parent.width
            height: Appearance.sizes.hairline
            color: Appearance.colors.colLokDivider
        }
        Graph {
            anchors.fill: parent
            values: line.values
            points: MachineStats.historyLength
            alignment: Graph.Alignment.Right
            color: Appearance.colors.colMeterFill
            fillOpacity: 0.12
        }
    }

    component BarHistory: Item {
        id: bars
        property list<real> values
        readonly property int count: 16
        Layout.fillWidth: true
        implicitHeight: 32
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: Appearance.sizes.hairline
            color: Appearance.colors.colLokDivider
        }
        Row {
            anchors.fill: parent
            spacing: 2
            Repeater {
                model: bars.count
                Item {
                    required property int index
                    readonly property real v: {
                        const i = bars.values.length - bars.count + index;
                        return i >= 0 ? bars.values[i] : 0;
                    }
                    width: (bars.width - 2 * (bars.count - 1)) / bars.count
                    height: bars.height
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.max(Appearance.sizes.hairline, parent.height * parent.v)
                        color: parent.v >= 0.9 ? Appearance.colors.colError : Appearance.colors.colMeterFill
                    }
                }
            }
        }
    }
}
