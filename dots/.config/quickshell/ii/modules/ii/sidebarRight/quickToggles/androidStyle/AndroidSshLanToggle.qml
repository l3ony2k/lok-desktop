import qs.modules.common.models.quickToggles

AndroidQuickToggleButton {
    // android-style toggles always expose right-click as openMenu(), and the
    // panel relays it to the sidebar, which shows SshLanDialog.
    toggleModel: SshLanToggle {}
}
