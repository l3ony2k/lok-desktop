import qs.services
import qs.modules.common
import qs.modules.common.widgets

// ASUS 2026-11-09: IPU6 camera tile. Click = block / allow (privacy).
// Right-click (or long press) = recover after a hibernate resume broke the
// camera; refused while the camera works.
QuickToggleModel {
    name: Translation.tr("Camera")
    icon: CameraCtl.icon
    statusText: CameraCtl.statusText
    toggled: !CameraCtl.privacy
    available: !CameraCtl.busy
    tooltipText: Translation.tr("Camera: %1\nClick: block / allow\nRight-click: recover after hibernate (only when broken)").arg(CameraCtl.statusText)
    mainAction: () => CameraCtl.toggle()
    altAction: () => CameraCtl.recover()
}
