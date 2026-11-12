import qs.services
import qs.modules.common
import qs.modules.common.widgets

QuickToggleModel {
    name: Translation.tr("Charge limit")
    icon: BatteryLimit.icon
    statusText: BatteryLimit.statusText
    toggled: BatteryLimit.active
    available: !BatteryLimit.busy && !BatteryLimit.setupMissing
    hasMenu: false
    tooltipText: Translation.tr("Battery charge limit: %1 (battery %2%)\nClick: 60% → 80% → 100%\nSaved, re-applied at boot").arg(BatteryLimit.statusText).arg(BatteryLimit.capacity)
    mainAction: () => BatteryLimit.cycle()
}
