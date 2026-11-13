import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

/**
 * Compact two-line monitor:  CPU 84%   ↑ 4 KB/s
 *                            MEM 84%   ↓ 34 KB/s
 * Values have fixed widths so the bar doesn't shift as numbers change.
 * Swap and details live in the hover popup.
 */
MouseArea {
    id: root
    implicitWidth: grid.implicitWidth + 8
    implicitHeight: Appearance.sizes.barHeight
    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    readonly property real fontSize: Appearance.font.pixelSize.smaller
    readonly property color colLabel: Appearance.colors.colSubtext
    readonly property color colValue: Appearance.colors.colOnLayer1
    readonly property color colWarn: Appearance.m3colors.m3error

    TextMetrics { id: pctMetrics; font.family: Appearance.font.family.main; font.pixelSize: root.fontSize; text: "100%" }
    TextMetrics { id: rateMetrics; font.family: Appearance.font.family.main; font.pixelSize: root.fontSize; text: "999 KB/s" }

    component Label: StyledText {
        font.pixelSize: root.fontSize
        color: root.colLabel
    }
    component Value: StyledText {
        font.pixelSize: root.fontSize
        horizontalAlignment: Text.AlignRight
    }

    GridLayout {
        id: grid
        anchors.centerIn: parent
        columns: 4
        rowSpacing: -2
        columnSpacing: 4

        Label { text: "CPU" }
        Value {
            Layout.preferredWidth: pctMetrics.advanceWidth
            text: Math.round(ResourceUsage.cpuUsage * 100) + "%"
            color: ResourceUsage.cpuUsage * 100 >= Config.options.bar.resources.cpuWarningThreshold ? root.colWarn : root.colValue
        }
        Label { text: "↑"; Layout.leftMargin: 8; Layout.rightMargin: -2 }
        Value {
            Layout.preferredWidth: rateMetrics.advanceWidth
            text: ResourceUsage.formatRate(ResourceUsage.netTxRate)
            color: root.colValue
        }

        Label { text: "MEM" }
        Value {
            Layout.preferredWidth: pctMetrics.advanceWidth
            text: Math.round(ResourceUsage.memoryUsedPercentage * 100) + "%"
            color: ResourceUsage.memoryUsedPercentage * 100 >= Config.options.bar.resources.memoryWarningThreshold ? root.colWarn : root.colValue
        }
        Label { text: "↓"; Layout.leftMargin: 8; Layout.rightMargin: -2 }
        Value {
            Layout.preferredWidth: rateMetrics.advanceWidth
            text: ResourceUsage.formatRate(ResourceUsage.netRxRate)
            color: root.colValue
        }
    }

    ResourcesPopup {
        hoverTarget: root
    }
}
