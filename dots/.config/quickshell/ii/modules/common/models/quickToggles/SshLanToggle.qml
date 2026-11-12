import qs.services
import qs.modules.common
import qs.modules.common.widgets

QuickToggleModel {
    name: Translation.tr("SSH (LAN)")
    icon: SshLan.icon
    statusText: SshLan.statusText
    toggled: SshLan.active
    available: !SshLan.busy
    hasMenu: true
    tooltipText: Translation.tr("SSH over LAN: %1\nClick: allow / block\nRight-click: allowed range").arg(SshLan.statusText)
    mainAction: () => SshLan.toggle()
}
