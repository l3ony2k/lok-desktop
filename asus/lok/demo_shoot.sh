#!/bin/bash
# Demo screenshots for the README. Runs on the ASUS in the Hyprland session; uses workspace 9 and
# its own kitty windows (class lokdemo), closes them afterwards and returns to the previous workspace.
set -u
pgrep -x hyprlock >/dev/null && { echo LOCKED; exit 3; }
export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/1000/hypr | head -1)
export XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 YDOTOOL_SOCKET=/run/user/1000/.ydotool_socket
O=/tmp/lokdemo; rm -rf "$O"; mkdir -p "$O"
mode=$1
g()    { hyprctl -q eval "hl.dispatch(hl.dsp.global(\"quickshell:$1\"))"; }
run()  { hyprctl -q eval "hl.exec_cmd(\"$1\")"; }
shot() { sleep "${2:-0.8}"; grim -o eDP-1 "$O/$mode-$1.png"; }
cursor() { for i in 1 2 3 4 5 6 7 8; do read cx cy < <(hyprctl cursorpos | tr -d ","); dx=$(( ($1 - cx) / 2 )); dy=$(( ($2 - cy) / 2 )); [ "$dx" -eq 0 ] && [ "$dy" -eq 0 ] && break; ydotool mousemove -x $dx -y $dy >/dev/null; sleep 0.08; done; }
prev=$(hyprctl activeworkspace -j | python3 -c 'import json,sys;print(json.load(sys.stdin)["id"])')
hyprctl -q eval 'hl.dispatch(hl.dsp.focus({workspace=9}))'; sleep 0.5
pkill -f "[k]itty --class lokdemo"; sleep 0.8   # fresh windows pick up the current light/dark terminal colours
if true; then
  run "kitty --class lokdemo sh -c 'fastfetch; exec sleep infinity'"; sleep 1.5
  run "kitty --class lokdemo btop"; sleep 1.5
  run "kitty --class lokdemo sh -c 'cd ~/.config/quickshell/ii && bat --paging=never --theme=ansi --style=numbers,header,grid -r 129:145 modules/common/Appearance.qml; exec sleep infinity'"; sleep 3
fi
cursor 960 1150                                    # bottom of the screen, over a window, out of the way
shot desktop 1.5
g sidebarRightOpen; shot sidebar 1.0; g sidebarRightClose; sleep 0.4
ydotool key 125:1 125:0 >/dev/null; sleep 0.8; ydotool key 37:1 37:0 23:1 23:0 >/dev/null; shot launcher 0.8
ydotool key 1:1 1:0 >/dev/null; sleep 0.4
cursor 1552 18; shot monitor 1.2; cursor 960 960
g osdVolumeTrigger; shot osd 0.3; g osdVolumeHide; sleep 0.3
g sessionOpen; shot session 0.8; g sessionClose; sleep 0.4
if [ "${2:-}" = cleanup ]; then
  pkill -f "[k]itty --class lokdemo"; sleep 0.5
  hyprctl -q eval "hl.dispatch(hl.dsp.focus({workspace=$prev}))"
fi
ls "$O"
