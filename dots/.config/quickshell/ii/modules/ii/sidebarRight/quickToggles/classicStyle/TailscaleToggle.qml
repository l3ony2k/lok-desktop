import qs.services
import qs.modules.common
import qs.modules.common.widgets

QuickToggleButton {
    id: root
    buttonIcon: Tailscale.icon
    toggled: Tailscale.running
    enabled: !Tailscale.busy
    onClicked: Tailscale.toggle()
    // The blank button has no text column, so right-click is the only
    // gesture left for the dialog. AbstractQuickPanel already exposes
    // openTailscaleDialog() for the panel to relay.
    altAction: () => root.openMenu()

    signal openMenu()

    StyledToolTip {
        text: "Tailscale: " + Tailscale.statusText + "\nClick: start/connect/disconnect\nRight-click: peers"
    }
}