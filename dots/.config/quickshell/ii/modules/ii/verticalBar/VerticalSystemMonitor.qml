import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import qs.modules.ii.bar as Bar

/**
 * lok, vertical bar: the horizontal two-line monitor (Bar/SystemMonitor.qml) stacked into one
 * column, label over value:   CPU / 3%   MEM / 28%   ↑ / 2 KB   ↓ / 2 KB
 * Same colours and size as the horizontal one; rates drop one size step only if "999 KB" would
 * not fit the bar's width. Swap and details live in the same hover popup.
 */
MouseArea {
    id: root
    implicitWidth: Appearance.sizes.verticalBarWidth
    implicitHeight: column.implicitHeight
    hoverEnabled: !Config.options.bar.tooltips.clickToShow

    readonly property real fontSize: Appearance.font.pixelSize.smaller
    readonly property real rateFontSize: rateMetrics.advanceWidth <= Appearance.sizes.verticalBarWidth - 6
        ? fontSize : Appearance.font.pixelSize.smallest
    readonly property color colLabel: Appearance.colors.colSubtext
    readonly property color colValue: Appearance.colors.colOnLayer1
    readonly property color colWarn: Appearance.m3colors.m3error

    TextMetrics { id: rateMetrics; font.family: Appearance.font.family.main; font.pixelSize: root.fontSize; text: "999 KB" }

    component Pair: Column {
        id: pair
        property string label
        property string value
        property color valueColor: root.colValue
        property real valueSize: root.fontSize
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: -2
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: root.fontSize
            color: root.colLabel
            text: pair.label
        }
        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            font.pixelSize: pair.valueSize
            color: pair.valueColor
            text: pair.value
        }
    }

    Column {
        id: column
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 6

        Pair {
            label: "CPU"
            value: Math.round(ResourceUsage.cpuUsage * 100) + "%"
            valueColor: ResourceUsage.cpuUsage * 100 >= Config.options.bar.resources.cpuWarningThreshold ? root.colWarn : root.colValue
        }
        Pair {
            label: "MEM"
            value: Math.round(ResourceUsage.memoryUsedPercentage * 100) + "%"
            valueColor: ResourceUsage.memoryUsedPercentage * 100 >= Config.options.bar.resources.memoryWarningThreshold ? root.colWarn : root.colValue
        }
        Pair {
            label: "↑"
            value: ResourceUsage.formatRate(ResourceUsage.netTxRate)
            valueSize: root.rateFontSize
        }
        Pair {
            label: "↓"
            value: ResourceUsage.formatRate(ResourceUsage.netRxRate)
            valueSize: root.rateFontSize
        }
    }

    Bar.ResourcesPopup {
        hoverTarget: root
    }
}
