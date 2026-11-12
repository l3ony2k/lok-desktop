import qs.services
import qs.modules.common
import qs.modules.common.widgets

QuickToggleButton {
    id: root
    buttonIcon: SshLan.icon
    toggled: SshLan.active
    enabled: !SshLan.busy
    onClicked: SshLan.toggle()
    altAction: () => root.openMenu()

    signal openMenu()

    StyledToolTip {
        text: "SSH over LAN: " + SshLan.statusText + "\nClick: allow/block\nRight-click: allowed range"
    }
}
