import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

/**
 * A container that supports GroupButton children for bounciness.
 * See https://m3.material.io/components/button-groups/overview
 */
Rectangle {
    id: root
    default property alias groupData: rowLayout.data
    property alias uniformCellSizes: rowLayout.uniformCellSizes
    property real spacing: 5
    property real padding: 0
    property alias clickIndex: rowLayout.clickIndex
    property alias childrenCount: rowLayout.childrenCount

    property real contentWidth: {
        let total = 0;
        let count = 0;
        for (let i = 0; i < rowLayout.children.length; ++i) {
            const child = rowLayout.children[i];
            if (!child.visible) continue;
            const w = child.baseWidth ?? child.implicitWidth ?? child.width;
            total += w;
            if (w > 0) count++;
        }
        // lok: spacing only between real items (a Repeater child added a phantom gap that the layout spread out)
        return total + rowLayout.spacing * ((Appearance?.lok ?? false) ? Math.max(0, count - 1) : (rowLayout.children.length - 1));
    }

    topLeftRadius: Appearance.lok ? 0 : rowLayout.children.length > 0 ? (rowLayout.children[0].radius + padding) : 
        Appearance?.rounding?.small
    bottomLeftRadius: Appearance.lok ? 0 : topLeftRadius
    topRightRadius: Appearance.lok ? 0 : rowLayout.children.length > 0 ? (rowLayout.children[rowLayout.children.length - 1].radius + padding) : 
        Appearance?.rounding?.small
    bottomRightRadius: Appearance.lok ? 0 : topRightRadius

    color: "transparent"
    width: root.contentWidth + padding * 2
    implicitHeight: rowLayout.implicitHeight + padding * 2
    implicitWidth: root.contentWidth + padding * 2
    
    children: [RowLayout {
        id: rowLayout
        anchors.fill: parent
        anchors.margins: root.padding
        spacing: root.spacing
        property int clickIndex: -1
        property int childrenCount: children.length
    }]
}
