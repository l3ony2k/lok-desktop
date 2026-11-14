import qs.modules.common.models.quickToggles

AndroidQuickToggleButton {
    // Right-click and the expanded text column are wired to openMenu() by
    // AndroidQuickToggleButton whenever the model has a menu; the panel sends
    // that signal to the sidebar, which shows the peers dialog.
    toggleModel: TailscaleToggle {}
}