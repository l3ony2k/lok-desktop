pragma ComponentBehavior: Bound
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.panels.lock
import QtQuick
import Quickshell
import Quickshell.Hyprland

LockScreen {
    id: root

    // Monitor name -> workspace id to restore on unlock (set when locking)
    property var savedWorkspaces: ({})

    // While locked, each monitor is parked on workspace `tempWorkspaceBase - realId`
    // so no window contents are visible. That mapping is reversible on its own,
    // so a monitor can never be stranded there even if savedWorkspaces is lost
    // (e.g. Quickshell restarted while the screen was locked).
    readonly property int tempWorkspaceBase: 2147483647
    readonly property int tempWorkspaceFloor: 2000000000

    function isTempWorkspaceId(id) {
        return id !== undefined && id > root.tempWorkspaceFloor && id <= root.tempWorkspaceBase
    }

    function originalWorkspaceId(tempId) {
        var real = root.tempWorkspaceBase - tempId
        return (real >= 1 && real <= 100) ? real : -1
    }

    function restoreTargets() {
        var targets = {}
        var screenNames = Quickshell.screens.map(s => s.name)
        for (var mon in root.savedWorkspaces) {
            if (screenNames.includes(mon))
                targets[mon] = root.savedWorkspaces[mon]
        }
        for (var i = 0; i < HyprlandData.monitors.length; ++i) {
            var m = HyprlandData.monitors[i]
            var id = m?.activeWorkspace?.id
            if (root.isTempWorkspaceId(id)) {
                var real = root.originalWorkspaceId(id)
                if (real !== -1)
                    targets[m.name] = real
            }
        }
        return targets
    }

    // Windows opened while a monitor was parked (e.g. an app launched during
    // the lock) stay on the temp workspace when only the monitor is restored.
    function hasTempWorkspaceWindows() {
        for (var i = 0; i < HyprlandData.windowList.length; ++i) {
            if (root.isTempWorkspaceId(HyprlandData.windowList[i]?.workspace?.id))
                return true
        }
        return false
    }

    function restoreWorkspaces() {
        var targets = root.restoreTargets()
        var batch = ""
        // Move stray windows off every parked workspace, whether or not its
        // monitor is still stranded there.
        for (var i = 0; i < HyprlandData.windowList.length; ++i) {
            var win = HyprlandData.windowList[i]
            var tempId = win?.workspace?.id
            if (!root.isTempWorkspaceId(tempId))
                continue
            var real = root.originalWorkspaceId(tempId)
            if (real !== -1)
                batch += `hyprctl dispatch 'hl.dsp.window.move({workspace=${real}, follow=false, window="address:${win.address}"})';`
        }
        for (var mon in targets)
            batch += `hyprctl dispatch 'hl.dsp.focus({monitor="${mon}"})'; hyprctl dispatch 'hl.dsp.focus({workspace=${targets[mon]}})';`
        root.savedWorkspaces = {}
        if (batch.length > 0)
            Quickshell.execDetached(["bash", "-c", batch])
    }

    Timer {
        id: restoreTimer
        interval: 150
        repeat: false
        onTriggered: root.restoreWorkspaces()
    }

    // Heal a stale temp workspace left behind by a Quickshell restart while
    // locked: the in-memory map is gone, but the monitor still sits on
    // tempWorkspaceBase - realId. Wait for HyprlandData to be populated.
    Timer {
        id: startupRestoreTimer
        interval: 800
        repeat: true
        onTriggered: {
            if (HyprlandData.monitors.length === 0)
                return
            running = false
            if (GlobalStates.screenLocked)
                return
            if (Object.keys(root.restoreTargets()).length > 0 || root.hasTempWorkspaceWindows())
                root.restoreWorkspaces()
        }
    }

    Component.onCompleted: {
        if (!GlobalStates.screenLocked)
            startupRestoreTimer.start()
    }

    lockSurface: LockSurface {
        context: root.context
    }

    // Single batch for lock and unlock so we don't race multiple hyprctl calls
    Connections {
        target: GlobalStates
        function onScreenLockedChanged() {
            if (GlobalStates.screenLocked) {
                // lock.parkWorkspaces = false: lock in place, no workspace switch and
                // no slide-away animation. Unlock still runs restoreWorkspaces(),
                // which only acts on leftovers from earlier parked locks.
                if (!(Config.options?.lock?.parkWorkspaces ?? true)) {
                    root.savedWorkspaces = {}
                    return
                }
                // Lock: save workspace per monitor and move all to temp workspace in one batch
                var next = {}
                var batch = "keyword animation workspaces,1,7,menu_decel,slidevert; "
                for (var i = 0; i < Quickshell.screens.length; ++i) {
                    var mon = Quickshell.screens[i].name
                    var mData = HyprlandData.monitors.find(m => m.name === mon)
                    if (mData?.activeWorkspace == undefined) {
                        return;
                    }
                    var ws = (mData?.activeWorkspace?.id ?? 1)
                    // Already parked from a previous lock (lost restore): derive the real workspace.
                    if (root.isTempWorkspaceId(ws)) {
                        var real = root.originalWorkspaceId(ws)
                        ws = real !== -1 ? real : 1
                    }
                    next[mon] = ws
                    batch += `hyprctl dispatch 'hl.dsp.focus({monitor="${mon}"})'; hyprctl dispatch 'hl.dsp.focus({workspace=${root.tempWorkspaceBase - ws}})';`
                }
                root.savedWorkspaces = next
                Quickshell.execDetached(["bash", "-c", batch])
            } else {
                restoreTimer.start()
            }
        }
    }

    // Push everything down (visual only; workspace switch is in Connections above)
    Variants {
        model: Quickshell.screens
        delegate: Scope {
            required property ShellScreen modelData
            property bool shouldPush: GlobalStates.screenLocked
            property string targetMonitorName: modelData.name
            property int verticalMovementDistance: modelData.height
            property int horizontalSqueeze: modelData.width * 0.2
        }
    }
}
