pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

/**
 * The notes file (Directories.notesPath), shared by the Super+G Notes overlay and the left-sidebar
 * scratchpad (lok task, 2026-11-15). One owner, so a widget that stayed open can't write stale text
 * over the other's edits: widgets push edits with save() and follow `content` while they aren't
 * being typed in. External edits to the file are picked up too.
 */
Singleton {
    id: root
    property string content: ""
    property bool loaded: false

    function save(text) {
        if (!root.loaded || text === root.content) return; // never write before the file was read
        root.content = text;
        echoGuard.restart();
        file.setText(text);
    }

    // our own writes come back as fileChanged; a reload in that window could read a half-way
    // version and briefly roll the other widget back, so ignore them
    Timer { id: echoGuard; interval: 1000 }

    FileView {
        id: file
        path: Qt.resolvedUrl(Directories.notesPath)
        watchChanges: true
        onFileChanged: if (!echoGuard.running) reload()
        onLoaded: {
            const t = file.text();
            if (t !== root.content) root.content = t;
            root.loaded = true;
        }
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound) return;
            root.loaded = true;
            file.setText("");
        }
    }
}
