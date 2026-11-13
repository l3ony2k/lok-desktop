import qs.modules.common
import QtQuick
import QtQuick.Controls.Material
import QtQuick.Controls

ProgressBar {
    id: root
    indeterminate: true
    Material.accent: Appearance.lok ? Appearance.colors.colMeterFill : Appearance.colors.colPrimary

    // lok: no Material bar. The dialog divider stays in place (same 1 px, so nothing shifts
    // when scanning starts or stops) and a bright segment sweeps along it.
    property Item lokTrack: Item {
        implicitHeight: 1
        Rectangle { x: 0; y: 0; width: parent.width; height: Appearance.sizes.hairline; color: Appearance.colors.colLokDivider }
    }
    property Item lokBar: Item {
        implicitHeight: 1
        clip: true
        Rectangle {
            id: segment
            width: parent.width * 0.3
            y: 0
            height: Appearance.sizes.hairline
            color: Appearance.colors.colMeterFill
            NumberAnimation on x {
                running: Appearance.lok && root.visible
                loops: Animation.Infinite
                from: -segment.width
                to: segment.parent.width
                duration: 1100
                easing.type: Easing.InOutQuad
            }
        }
    }
    Binding on background { when: Appearance.lok; value: root.lokTrack }
    Binding on contentItem { when: Appearance.lok; value: root.lokBar }
    Binding on implicitHeight { when: Appearance.lok; value: 1 }
}
