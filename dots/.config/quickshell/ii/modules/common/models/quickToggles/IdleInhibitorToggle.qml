import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

QuickToggleModel {
    name: Translation.tr("Caffeine")

    toggled: Idle.inhibit
    icon: "coffee"
    statusText: Idle.inhibit ? (Idle.keepScreen ? Translation.tr("%1 · screen on").arg(Idle.remainingText) : Idle.remainingText) : ""
    hasMenu: true
    mainAction: () => {
        Idle.toggleInhibit()
    }
    tooltipText: Idle.inhibit
        ? Translation.tr("Caffeine: %1\nClick: off\nRight-click: duration, screen").arg(Idle.remainingText)
        : Translation.tr("Caffeine (decaf)\nClick: on for 1 h\nRight-click: duration, screen")
}
