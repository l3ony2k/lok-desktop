pragma Singleton
import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

/**
 * A nice wrapper for date and time strings.
 */
Singleton {
    id: root

    property alias inhibit: idleInhibitor.enabled
    inhibit: false

    Connections {
        target: Persistent
        function onReadyChanged() {
            if (!Persistent.isNewHyprlandInstance) {
                root.inhibit = Persistent.states.idle.inhibit;
            } else {
                Persistent.states.idle.inhibit = root.inhibit;
            }
        }
    }

    function toggleInhibit(active = null) {
        if (active !== null) {
            root.inhibit = active;
        } else {
            root.inhibit = !root.inhibit;
        }
        Persistent.states.idle.inhibit = root.inhibit;
    }

    // ASUS coffee-lid (2026-11-08): while coffee is on, also stop logind from
    // suspending on lid close. ~/.local/bin/lid-coffee then locks the session
    // and turns the panel off instead. Ends with the toggle or with Quickshell.
    Process {
        id: lidInhibitor
        running: root.inhibit
        // setpriv --pdeathsig: the inhibitor dies with Quickshell, so a killall/restart
        // can't leave an orphan blocking lid suspend after coffee is turned off
        command: ["setpriv", "--pdeathsig", "TERM", "systemd-inhibit", "--what=handle-lid-switch",
            "--who=Quickshell coffee", "--why=Keep awake (coffee toggle)",
            "--mode=block", "sleep", "infinity"]
    }

    IdleInhibitor {
        id: idleInhibitor
        window: PanelWindow {
            // Inhibitor requires a "visible" surface
            // Actually not lol
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            // Just in case...
            anchors {
                right: true
                bottom: true
            }
            // Make it not interactable
            mask: Region {
                item: null
            }
        }
    }
}
