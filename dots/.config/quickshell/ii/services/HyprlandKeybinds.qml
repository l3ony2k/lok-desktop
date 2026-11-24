pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

/**
 * A service that provides access to Hyprland keybinds.
 * Uses the `get_keybinds.py` script to parse comments in config files in a certain format and convert to JSON.
 */
Singleton {
    id: root
    property var keybinds: []
    property var keybindCategories: []

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name == "configreloaded") {
                getKeybinds.running = true
            }
        }
    }

    Process {
        id: getKeybinds
        running: true
        command: ["hyprctl", "binds", "-j"]
        
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(text)
                    const extraBinds = [
                        // fcitx5-vinput via keyd [capslock] -> f14/f15/f16 (XF86Launch5..7)
                        { modmask: 2, key: "V", description: "Voice: Dictation (tap toggle / hold PTT)" },
                        { modmask: 2, key: "M", description: "Voice: Command palette (/asr, /scene)" },
                        { modmask: 2, key: "C", description: "Voice: Voice command on selection" },

                        // keyd [capslock] & [altgr] Chromebook ergonomics (/etc/keyd/cros.conf)
                        { modmask: 0, key: "Caps", description: "Navigation: Escape (tap)" },
                        { modmask: 2, key: "E / D / S / F", description: "Navigation: Arrow ↑ / ↓ / ← / →" },
                        { modmask: 2, key: "T / B", description: "Navigation: Page ↑ / ↓ (10 lines)" },
                        { modmask: 2, key: "A / G", description: "Navigation: Word ← / →" },
                        { modmask: 2, key: "P / ;", description: "Navigation: Line Home / End" },
                        { modmask: 2, key: "I / K / J / L", description: "Navigation: Select ↑ / ↓ / ← / →" },
                        { modmask: 2, key: "H / .", description: "Navigation: Select word ← / →" },
                        { modmask: 2, key: "U / O", description: "Navigation: Select to line start / end" },
                        { modmask: 2, key: "W / R", description: "Navigation: Backspace / Delete" },
                        { modmask: 2, key: "BackSpace", description: "Navigation: Delete whole line" },
                        { modmask: 2, key: "Space", description: "Navigation: Enter (Ctrl+Space = IME)" },
                        { modmask: 8, key: "← / → / ↑ / ↓", description: "Navigation: Home / End / PgUp / PgDn (Right Alt)" },
                        { modmask: 8, key: "BackSpace", description: "Navigation: Delete (Right Alt)" },
                        { modmask: 8, key: "Brightness", description: "Navigation: Keyboard backlight (Right Alt)" }
                    ]
                    root.keybinds = parsed.concat(extraBinds)
                    var groups = []
                    for (var i = 0; i < root.keybinds.length; i++) {
                        var bind = root.keybinds[i].description
                        var group = bind.substring(0, bind.indexOf(":"))
                        if (!groups.includes(group) && group.length > 0) {
                            groups.push(group)
                        }
                    }
                    root.keybindCategories = groups
                } catch (e) {
                    console.error("[CheatsheetKeybinds] Error parsing keybinds:", e)
                }
            }
        }
    }
}

