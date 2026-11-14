#!/bin/bash
# Launch WorkFlowy from a patched, user-local copy of the pacman AppImage.
#
# Patches applied to the copy:
#   1. Menu bar auto-hidden; Alt / AltGr (right Alt) toggles it. Chromium's
#      built-in Alt toggle does not fire for AltGr.
#
# The system package and /opt are never modified. The copy is rebuilt whenever
# /opt/WorkFlowy-x86_64.AppImage changes.
set -euo pipefail

SRC=/opt/WorkFlowy-x86_64.AppImage
DIR="$HOME/.local/opt/workflowy-nomenu"
STAMP="$DIR/.stamp"
APP="$DIR/squashfs-root"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/workflowy-nomenu"
LOG="$LOG_DIR/app.log"

if [[ ! -x "$APP/AppRun" ]] || [[ "$SRC" -nt "$STAMP" ]]; then
    tmp="$(mktemp -d "$DIR/extract.XXXXXX")"
    trap 'rm -rf "$tmp"' EXIT
    ( cd "$tmp" && "$SRC" --appimage-extract >/dev/null )

    res="$tmp/squashfs-root/resources"
    if [[ -f "$res/app.asar" ]]; then
        # Electron prefers app.asar over app/, so unpack and drop the archive.
        ( cd "$res" && npx --yes @electron/asar extract app.asar app >/dev/null )
        rm -f "$res/app.asar"
    fi

    python3 -I - "$res/app/main.start.ts" <<'PY'
import sys
path = sys.argv[1]
src = open(path, encoding="utf-8").read()
HANDLER = '''Electron.app.on("browser-window-created", (_event, win) => {
  win.setAutoHideMenuBar(true)
  win.setMenuBarVisibility(false)
  win.webContents.on("before-input-event", (event, input) => {
    if (input.type === "keyDown" && (input.key === "Alt" || input.key === "AltGraph") && !input.control && !input.shift && !input.meta) {
      event.preventDefault()
      win.setMenuBarVisibility(!win.isMenuBarVisible())
    }
  })
})
'''
src = src.replace(HANDLER, "")
if "browser-window-created" in src:
    old = '''Electron.app.on("browser-window-created", (_event, win) => {
  win.setAutoHideMenuBar(true)
  win.setMenuBarVisibility(false)
})
'''
    src = src.replace(old, "")
anchor = 'Electron.app.setAsDefaultProtocolClient("workflowy")\n'
if anchor not in src:
    sys.exit("workflowy-nomenu: anchor not found; upstream layout changed")
src = src.replace(anchor, HANDLER + "\n" + anchor, 1)
src = src.replace("setApplicationMenu(null)", "setApplicationMenu(menu)")
if "setApplicationMenu(menu)" not in src:
    sys.exit("workflowy-nomenu: menu call not found; upstream layout changed")
open(path, "w", encoding="utf-8").write(src)
PY

    rm -rf "$APP"
    mv "$tmp/squashfs-root" "$APP"
    touch "$STAMP"
    trap - EXIT
    rmdir "$tmp"
fi

mkdir -p "$LOG_DIR"
printf '\n===== %s =====\n' "$(date '+%F %T')" >"$LOG"
export WF_DIAG_MCP=1
exec "$APP/AppRun" --password-store=gnome-libsecret "$@" >>"$LOG" 2>&1
