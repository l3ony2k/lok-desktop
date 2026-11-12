import qs.services
import qs.modules.common
import qs.modules.common.widgets

QuickToggleModel {
    name: Translation.tr("Tailscale")
    icon: Tailscale.icon
    statusText: Tailscale.statusText
    toggled: Tailscale.running
    available: !Tailscale.busy
    hasMenu: true
    tooltipText: Translation.tr("Tailscale: %1\nClick: start daemon / connect / disconnect\nClick text or right-click: peers").arg(Tailscale.statusText)
    mainAction: () => Tailscale.toggle()
}