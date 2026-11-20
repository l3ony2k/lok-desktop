pragma Singleton
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Keep awake ("coffee"), v2 (2026-11-20).
 *
 * The old version asked Hyprland through a Wayland idle inhibitor on a 0x0 window; Hyprland
 * ignores inhibitors on invisible surfaces, so hypridle still locked and suspended with coffee on.
 * Now Quickshell holds logind inhibitor locks, which logind and hypridle both honour:
 *   - always while on:            sleep + handle-lid-switch  (no idle/lid suspend)
 *   - also with keepScreen:       idle                       (no idle lock / screen off)
 * Closing the lid still locks and turns the panel off (~/.local/bin/lid-coffee); the system runs.
 *
 * Timed: click = 1 h; the dialog picks 1/2/4/8/12 h or infinite (until = 0). The end time is a
 * timestamp in Persistent, so a Quickshell restart keeps the remaining time; a new Hyprland
 * session (reboot/login) starts with coffee off. Below 10 % battery on battery power it turns off.
 */
Singleton {
    id: root

    readonly property real defaultHours: 1
    readonly property real batteryFloor: 0.10

    property bool inhibit: false
    property real until: 0          // epoch ms; 0 = no end
    property real hours: 1          // length of the current/last timer; 0 = no end
    property bool keepScreen: false
    property real now: Date.now()

    readonly property real remainingMs: (inhibit && until > 0) ? Math.max(0, until - now) : 0
    readonly property string remainingText: {
        if (!inhibit) return "";
        if (until <= 0) return "∞";
        const m = Math.ceil(remainingMs / 60000);
        return m >= 60 ? `${Math.floor(m / 60)}:${String(m % 60).padStart(2, "0")}` : `${m}m`;
    }

    function save() {
        Persistent.states.idle.inhibit = root.inhibit;
        Persistent.states.idle.until = root.until;
        Persistent.states.idle.hours = root.hours;
        Persistent.states.idle.keepScreen = root.keepScreen;
    }

    // hours: number of hours, or 0 for no end
    function start(hours) {
        root.now = Date.now();
        root.hours = hours;
        root.until = hours > 0 ? root.now + hours * 3600000 : 0;
        root.inhibit = true;
        save();
    }

    function stop(reason) {
        if (!root.inhibit) return;
        root.inhibit = false;
        root.until = 0;
        save();
        if (reason)
            Quickshell.execDetached(["notify-send", "-a", "Shell", Translation.tr("Caffeine wore off"), reason]);
    }

    // Kept for existing callers: toggleInhibit() flips, toggleInhibit(true/false) sets.
    function toggleInhibit(active = null) {
        const on = active !== null ? active : !root.inhibit;
        if (on) { if (!root.inhibit) start(root.defaultHours); }
        else stop("");
    }

    function setKeepScreen(value) {
        root.keepScreen = value;
        save();
    }

    Connections {
        target: Persistent
        // Deferred: Persistent's own onReadyChanged must record previousHyprlandInstanceSignature
        // first, or isNewHyprlandInstance reads true and coffee was reset on every restart.
        function onReadyChanged() {
            if (Persistent.ready) Qt.callLater(root.restore);
        }
    }

    function restore() {
        {
            const s = Persistent.states.idle;
            root.keepScreen = s.keepScreen ?? false;
            if (!Persistent.isNewHyprlandInstance && s.inhibit) {
                root.until = s.until ?? 0;
                root.hours = s.hours ?? root.defaultHours;
                root.inhibit = true;
                root.check();
            } else {
                root.inhibit = false;
                root.until = 0;
                root.save();
            }
        }
    }

    function check() {
        root.now = Date.now();
        if (!root.inhibit) return;
        if (root.until > 0 && root.now >= root.until)
            stop(Translation.tr("The timer ran out."));
        else if (Battery.available && !Battery.isPluggedIn && Battery.percentage <= root.batteryFloor)
            stop(Translation.tr("Battery below %1%").arg(Math.round(root.batteryFloor * 100)));
    }

    Timer {
        interval: 15000
        repeat: true
        running: root.inhibit
        triggeredOnStart: true
        onTriggered: root.check()
    }

    // qs -c ii ipc call coffee start 2 | start 0 (no end) | stop | keepScreen true | status
    IpcHandler {
        target: "coffee"
        function start(hours: real): void { root.start(hours); }
        function stop(): void { root.stop(""); }
        function toggle(): void { root.toggleInhibit(); }
        function keepScreen(on: bool): void { root.setKeepScreen(on); }
        function status(): string {
            return root.inhibit ? `on ${root.remainingText}${root.keepScreen ? " screen" : ""}` : `off${root.keepScreen ? " (screen)" : ""}`;
        }
    }

    // logind locks. setpriv --pdeathsig: the lock dies with Quickshell (no orphans on restart).
    Process {
        id: sleepLock
        running: root.inhibit
        command: ["setpriv", "--pdeathsig", "TERM", "systemd-inhibit", "--what=sleep:handle-lid-switch",
            "--who=Quickshell coffee", "--why=Keep awake (coffee toggle)",
            "--mode=block", "sleep", "infinity"]
    }
    Process {
        id: screenLock
        running: root.inhibit && root.keepScreen
        command: ["setpriv", "--pdeathsig", "TERM", "systemd-inhibit", "--what=idle",
            "--who=Quickshell coffee screen", "--why=Keep the screen on (coffee toggle)",
            "--mode=block", "sleep", "infinity"]
    }
}
