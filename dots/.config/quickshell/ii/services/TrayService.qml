pragma Singleton

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

Singleton {
    id: root

    property bool smartTray: Config.options.tray.filterPassive
    property list<var> itemsInUserList: SystemTray.items.values.filter(i => (Config.options.tray.pinnedItems.includes(i.id) && (!smartTray || i.status !== Status.Passive)))
    property list<var> itemsNotInUserList: SystemTray.items.values.filter(i => (!Config.options.tray.pinnedItems.includes(i.id) && (!smartTray || i.status !== Status.Passive)))

    property bool invertPins: Config.options.tray.invertPinnedItems
    property list<var> pinnedItems: invertPins ? itemsNotInUserList : itemsInUserList
    property list<var> unpinnedItems: invertPins ? itemsInUserList : itemsNotInUserList

    function getTooltipForItem(item) {
        var result = item.tooltipTitle.length > 0 ? item.tooltipTitle
                : (item.title.length > 0 ? item.title : item.id);
        if (item.tooltipDescription.length > 0) result += " • " + item.tooltipDescription;
        if (Config.options.tray.showItemId) result += "\n[" + item.id + "]";
        return result;
    }

    // Pinning
    function pin(itemId) {
        var pins = Config.options.tray.pinnedItems;
        if (pins.includes(itemId)) return;
        Config.options.tray.pinnedItems.push(itemId);
    }
    function unpin(itemId) {
        Config.options.tray.pinnedItems = Config.options.tray.pinnedItems.filter(id => id !== itemId);
    }
    function isPinned(itemId) {
        for (var i = 0; i < root.pinnedItems.length; i++) {
            if (root.pinnedItems[i].id === itemId)
                return true;
        }
        return false;
    }

    // Esc for tray menus. A tray menu is an xdg popup without keyboard focus (giving it a grab
    // fights the tray's HyprlandFocusGrab and closes it at once), so Esc is caught by Hyprland:
    // a bare Escape bind exists only while a tray menu or the overflow is open (refcounted
    // across bars) and is removed again on close and at startup.
    signal escapePressed()
    property int escHolders: 0
    function holdEscape(hold) {
        const before = root.escHolders > 0;
        root.escHolders = Math.max(0, root.escHolders + (hold ? 1 : -1));
        const after = root.escHolders > 0;
        if (before !== after)
            root.setEscapeBind(after);
    }
    function setEscapeBind(on) {
        const lua = on ? 'hl.bind("Escape", hl.dsp.global("quickshell:trayMenuEscape"))' : 'hl.unbind("Escape")';
        Quickshell.execDetached(["hyprctl", "eval", lua]);
    }
    Component.onCompleted: root.setEscapeBind(false) // drop a bind left behind by a crashed instance
    GlobalShortcut {
        name: "trayMenuEscape"
        description: "Close the open tray menu (bound only while one is open)"
        onPressed: root.escapePressed()
    }

    function togglePin(itemId) {
        var pins = Config.options.tray.pinnedItems;
        if (pins.includes(itemId)) {
            unpin(itemId)
        } else {
            pin(itemId)
        }
    }

}
