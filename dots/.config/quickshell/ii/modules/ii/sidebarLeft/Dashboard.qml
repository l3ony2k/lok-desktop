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

/**
 * Left sidebar dashboard (lok task, 2026-11-14): a scratchpad on top (same file as the
 * Super+G Notes widget) and machine-monitor cards below. Data: ResourceUsage + MachineStats,
 * both always sampling, so graphs already have history when the sidebar opens.
 */
Item {
    id: root
    readonly property real gap: 8
    readonly property real pad: 12
    readonly property real minScratchHeight: 160

    onActiveFocusChanged: if (activeFocus) scratchArea.focusEnd()

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.gap
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
        Flickable {
            id: monitorFlick
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(monitorGrid.implicitHeight, root.height - root.minScratchHeight - root.gap * 3)
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
            }
        }
    }

    Timer {
        id: saveDebounce
        interval: 500
        onTriggered: noteFile.setText(scratchArea.text)
    }
    FileView {
        id: noteFile
        path: Qt.resolvedUrl(Directories.notesPath)
        watchChanges: true
        onFileChanged: if (!scratchArea.activeFocus) reload()
        // next tick, and skip instances the sidebar already replaced (contentChildren re-creates pages)
        onLoaded: Qt.callLater(() => { if (!scratchArea.activeFocus) if (typeof noteFile.text === "function") scratchArea.text = noteFile.text(); })
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) noteFile.setText(""); }
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
        color: Appearance.colors.colLayer2
        LokFrame { color: Appearance.colors.colLokDivider }
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
