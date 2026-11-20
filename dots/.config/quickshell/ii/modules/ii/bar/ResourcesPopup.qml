import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    // Helper function to format KB to GB
    function formatKB(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    // lok (2026-11-20): a title over a grid of cards like the weather popup, one card per
    // resource: small grey title, big value, grey detail line, thin usage bar (red past the
    // warning threshold). Material keeps the original three-column list.
    Loader {
        anchors.centerIn: parent
        sourceComponent: Appearance.lok ? root.lokContent : root.classicContent
    }

    // (Components as properties: anything declared bare inside StyledPopup goes to its Item slot)
    property Component lokContent: Component {
        ColumnLayout {
            spacing: 8
            StyledPopupHeaderRow {
                icon: "memory"
                label: Translation.tr("Resources")
            }
            GridLayout {
                columns: 2
                rowSpacing: 5
                columnSpacing: 5
                uniformCellWidths: true
                Layout.fillWidth: true

                LokPopupCard {
                    symbol: "memory"
                    title: "CPU"
                    value: `${Math.round(ResourceUsage.cpuUsage * 100)}%`
                    detail: MachineStats.coretempDir.length > 0 ? `${Math.round(MachineStats.cpuTemp)}°C` : ""
                    fraction: ResourceUsage.cpuUsage
                    warn: ResourceUsage.cpuUsage * 100 >= Config.options.bar.resources.cpuWarningThreshold
                }
                LokPopupCard {
                    visible: MachineStats.gtDir.length > 0
                    symbol: "monitor"
                    title: "GPU"
                    value: `${Math.round(MachineStats.gpuUsage * 100)}%`
                    detail: MachineStats.gpuFreq > 0 ? `${Math.round(MachineStats.gpuFreq)} MHz` : Translation.tr("idle")
                    fraction: MachineStats.gpuUsage
                }
                LokPopupCard {
                    symbol: "empty_dashboard"
                    title: Translation.tr("Memory")
                    value: ResourceUsage.kbToGbString(ResourceUsage.memoryUsed)
                    detail: Translation.tr("of %1").arg(ResourceUsage.kbToGbString(ResourceUsage.memoryTotal))
                    fraction: ResourceUsage.memoryUsedPercentage
                    warn: ResourceUsage.memoryUsedPercentage * 100 >= Config.options.bar.resources.memoryWarningThreshold
                }
                LokPopupCard {
                    visible: ResourceUsage.swapTotal > 0
                    symbol: "swap_horiz"
                    title: Translation.tr("Swap")
                    value: ResourceUsage.kbToGbString(ResourceUsage.swapUsed)
                    detail: Translation.tr("of %1").arg(ResourceUsage.kbToGbString(ResourceUsage.swapTotal))
                    fraction: ResourceUsage.swapUsedPercentage
                    warn: ResourceUsage.swapUsedPercentage * 100 >= Config.options.bar.resources.swapWarningThreshold
                }
                Rectangle { // network: one wide row
                    Layout.columnSpan: 2
                    Layout.fillWidth: true
                    color: Appearance.colors.colLokDialogHover
                    radius: Appearance.rounding.small
                    implicitHeight: netRow.implicitHeight + 9 * 2
                    RowLayout {
                        id: netRow
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        spacing: 4
                        MaterialSymbol { fill: 0; text: "swap_vert"; iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colSubtext }
                        StyledText { text: Translation.tr("Network"); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                        Item { Layout.fillWidth: true }
                        StyledText { text: "↑"; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                        StyledText { text: `${ResourceUsage.formatRate(ResourceUsage.netTxRate)}/s`; color: Appearance.colors.colOnLayer1; Layout.rightMargin: 8 }
                        StyledText { text: "↓"; font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colSubtext }
                        StyledText { text: `${ResourceUsage.formatRate(ResourceUsage.netRxRate)}/s`; color: Appearance.colors.colOnLayer1 }
                    }
                }
            }
        }
    }

    property Component classicContent: Component {
        Row {
            spacing: 12

            Column {
                anchors.top: parent.top
                spacing: 8

                StyledPopupHeaderRow {
                    icon: "memory"
                    label: "CPU"
                }
                Column {
                    spacing: 4
                    StyledPopupValueRow {
                        icon: "bolt"
                        label: Translation.tr("Load:")
                        value: `${Math.round(ResourceUsage.cpuUsage * 100)}%`
                    }
                    StyledPopupValueRow {
                        visible: MachineStats.coretempDir.length > 0
                        icon: "device_thermostat"
                        label: Translation.tr("Temp:")
                        value: `${Math.round(MachineStats.cpuTemp)}°C`
                    }
                }

                // GPU (MachineStats, xe idle residency)
                StyledPopupHeaderRow {
                    visible: MachineStats.gtDir.length > 0
                    icon: "monitor"
                    label: "GPU"
                }
                Column {
                    visible: MachineStats.gtDir.length > 0
                    spacing: 4
                    StyledPopupValueRow {
                        icon: "bolt"
                        label: Translation.tr("Load:")
                        value: `${Math.round(MachineStats.gpuUsage * 100)}%`
                    }
                    StyledPopupValueRow {
                        icon: "speed"
                        label: Translation.tr("Freq:")
                        value: MachineStats.gpuFreq > 0 ? `${Math.round(MachineStats.gpuFreq)} MHz` : Translation.tr("idle")
                    }
                }
            }

            Column {
                anchors.top: parent.top
                spacing: 8

                StyledPopupHeaderRow {
                    icon: "empty_dashboard"
                    label: "RAM"
                }
                Column {
                    spacing: 4
                    StyledPopupValueRow {
                        icon: "clock_loader_60"
                        label: Translation.tr("Used:")
                        value: ResourceUsage.kbToGbString(ResourceUsage.memoryUsed)
                    }
                    StyledPopupValueRow {
                        icon: "check_circle"
                        label: Translation.tr("Free:")
                        value: ResourceUsage.kbToGbString(ResourceUsage.memoryFree)
                    }
                    StyledPopupValueRow {
                        icon: "empty_dashboard"
                        label: Translation.tr("Total:")
                        value: ResourceUsage.kbToGbString(ResourceUsage.memoryTotal)
                    }
                }
            }

            Column {
                visible: ResourceUsage.swapTotal > 0
                anchors.top: parent.top
                spacing: 8

                StyledPopupHeaderRow {
                    icon: "swap_horiz"
                    label: "Swap"
                }
                Column {
                    spacing: 4
                    StyledPopupValueRow {
                        icon: "clock_loader_60"
                        label: Translation.tr("Used:")
                        value: ResourceUsage.kbToGbString(ResourceUsage.swapUsed)
                    }
                    StyledPopupValueRow {
                        icon: "check_circle"
                        label: Translation.tr("Free:")
                        value: ResourceUsage.kbToGbString(ResourceUsage.swapFree)
                    }
                    StyledPopupValueRow {
                        icon: "empty_dashboard"
                        label: Translation.tr("Total:")
                        value: ResourceUsage.kbToGbString(ResourceUsage.swapTotal)
                    }
                }
            }
        }
    }
}
