import qs.services
import qs.modules.common
import qs.modules.common.widgets

QuickToggleModel {
    name: Translation.tr("Mihomo")
    icon: Mihomo.icon
    statusText: Mihomo.statusText
    toggled: Mihomo.active
    available: !Mihomo.busy
    hasMenu: true
    tooltipText: Translation.tr("Mihomo: %1\nClick: start/stop service\nClick text or right-click: open Zashboard").arg(Mihomo.statusText)
    mainAction: () => Mihomo.toggle()
}