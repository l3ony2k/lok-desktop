pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * How often (and how recently) apps were launched from the search box.
 * Used to order the full app list shown when the search query is empty.
 * Stored as { "<desktop id>": { "count": n, "last": epochMs } }.
 */
Singleton {
    id: root
    property string filePath: FileUtils.trimFileProtocol(`${Directories.state}/user/launcher-frequency.json`)
    property var entries: ({}) // not `data`: that shadows QtObject's default property

    function record(id) {
        if (!id) return;
        const next = Object.assign({}, root.entries);
        const prev = next[id] ?? { count: 0, last: 0 };
        next[id] = { count: prev.count + 1, last: Date.now() };
        root.entries = next;
        fileView.setText(JSON.stringify(root.entries));
    }

    // Launch count, discounted by how long ago the app was last used (halves every ~2 weeks of disuse)
    function score(id) {
        const e = root.entries[id];
        if (!e) return 0;
        const days = Math.max(0, (Date.now() - (e.last ?? 0)) / 86400000);
        return e.count / (1 + days / 14);
    }

    FileView {
        id: fileView
        path: root.filePath
        onLoaded: {
            try { root.entries = JSON.parse(fileView.text()) ?? {}; } catch (e) { root.entries = {}; }
        }
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                root.entries = {};
                fileView.setText("{}");
            }
        }
    }
}
