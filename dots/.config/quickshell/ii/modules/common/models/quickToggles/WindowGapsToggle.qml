import qs.services
import qs.modules.common
import qs.modules.common.widgets

QuickToggleModel {
    readonly property string modeName: WindowGaps.mode === "small" ? Translation.tr("Small")
        : WindowGaps.mode === "large" ? Translation.tr("Large") : Translation.tr("None")
    name: Translation.tr("Window gaps")
    icon: WindowGaps.mode === "none" ? "view_column" : "empty_dashboard" // lok-mapped (lokIcons.js)
    statusText: WindowGaps.mode === "none" ? modeName : `${modeName} · ${WindowGaps.outer}`
    toggled: WindowGaps.mode !== "none"
    available: WindowGaps.enabled
    hasMenu: true
    tooltipText: Translation.tr("Window gaps: %1\nClick: none → small → large\nRight-click: sizes").arg(statusText)
    mainAction: () => WindowGaps.cycle()
}
