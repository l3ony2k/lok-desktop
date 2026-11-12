import qs.services
import qs.modules.common
import qs.modules.common.widgets

QuickToggleButton {
    id: root
    buttonIcon: Mihomo.icon
    toggled: Mihomo.active
    enabled: !Mihomo.busy
    onClicked: Mihomo.toggle()
    altAction: () => root.openMenu()

    signal openMenu()

    StyledToolTip {
        text: "Mihomo: " + Mihomo.statusText + "\nClick: start/stop service\nRight-click: info"
    }
}