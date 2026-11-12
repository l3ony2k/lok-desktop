import qs.services
import qs.modules.common
import qs.modules.common.widgets

QuickToggleButton {
    id: root
    buttonIcon: BatteryLimit.icon
    toggled: BatteryLimit.active
    enabled: !BatteryLimit.busy && !BatteryLimit.setupMissing
    onClicked: BatteryLimit.cycle()

    StyledToolTip {
        text: "Battery charge limit: " + BatteryLimit.statusText + " (battery " + BatteryLimit.capacity + "%)\nClick: 60% → 80% → 100%"
    }
}
