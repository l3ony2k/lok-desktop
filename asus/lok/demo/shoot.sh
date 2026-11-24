#!/usr/bin/env bash
# lok README screenshots. Run on the ASUS inside the Hyprland session, workspace 1 empty, nobody
# using the machine (it moves the cursor, opens sidebars, switches light/dark).
#   shoot.sh prepare   back up notes / notifications / ii config.json, put the demo content in,
#                      weather city -> Hong Kong, gaps large, Caffeine on (no lock while shooting)
#   shoot.sh dark      demo windows on workspace 1 + every dark shot   -> ~/.cache/lokdemo/out/
#   shoot.sh light     light mode with the light wallpaper + light shots
#   shoot.sh restore   dark mode + original wallpaper, put the backups back (sha256 checked), stop the demo
# Then on any machine with Pillow: python3 compose.py <raw dir> <out dir> [font.ttf] -> asus/lok/screenshots/
# Coordinates are logical px for the 2560x1600 panel at scale 1.333 (1920x1200 logical).
set -u
H=$(cd "$(dirname "$(readlink -f "$0")")" && pwd); D=~/.cache/lokdemo; mkdir -p "$D/out" "$D/bak"
export XDG_RUNTIME_DIR=/run/user/$(id -u) WAYLAND_DISPLAY=wayland-1 LANG=C.UTF-8 YDOTOOL_SOCKET=/run/user/$(id -u)/.ydotool_socket
export HYPRLAND_INSTANCE_SIGNATURE=$(ls -t "$XDG_RUNTIME_DIR/hypr" | head -1)
O=$D/out; C=~/.config/illogical-impulse/config.json; NOTES=~/.local/state/quickshell/user/notes.txt
NOTIF=~/.cache/quickshell/notifications/notifications.json; WALL=~/Pictures/Wallpapers
ipc()  { qs -c ii ipc call "$@" >/dev/null 2>&1; }
run()  { hyprctl -q eval "hl.exec_cmd(\"$1\")"; }
shot() { sleep "${2:-0.8}"; grim -o eDP-1 "$O/$1.png"; echo "shot $1"; }
cursor() { for _ in $(seq 12); do read -r cx cy < <(hyprctl cursorpos | tr -d ","); dx=$(( ($1-cx)*3/4 )); dy=$(( ($2-cy)*3/4 ))
  [ "${dx#-}" -le 1 ] && [ "${dy#-}" -le 1 ] && break; ydotool mousemove -x $dx -y $dy >/dev/null; sleep 0.06; done; }
wiggle() { ydotool mousemove -x 2 -y 0 >/dev/null; sleep 0.1; ydotool mousemove -x -2 -y 0 >/dev/null; }
key() { ydotool key "$@" >/dev/null; }
cfg() { t=$(mktemp); jq "$1" "$C" > "$t" && cat "$t" > "$C"; rm -f "$t"; }
layer() { hyprctl layers -j | jq -r '..|objects|select(.namespace?)|.namespace' | grep -qiE "$1"; }
windows() { # $1 = btop script
  pkill -f "[k]itty --class lokdemo"; sleep 1
  run "kitty --class lokdemo -o font_size=11 $H/w-ff.sh"; sleep 0.8
  run "kitty --class lokdemo -o font_size=10.5 $H/w-code.sh"; sleep 0.8
  run "kitty --class lokdemo -o font_size=10 $H/$1"; sleep 7; cursor 1250 1150; }
pops() { # $1 = dark|light
  for p in "privacy 1488" "monitor 1550" "battery 1674" "weather 1752" "clock 960" "media 330"; do set -- "$1" $p
    cursor "$3" 20; sleep 0.4; wiggle; shot "$1-pop-$2" 1.6; cursor 1250 1150; sleep 0.6; done; }

case "${1:-}" in
prepare)
  pgrep -x hyprlock >/dev/null && { echo "unlock the screen first"; exit 1; }
  cp -p "$NOTES" "$NOTIF" "$C" "$D/bak/"; sha256sum "$NOTES" "$NOTIF" "$C" > "$D/bak/SHA256SUMS"
  cp "$H/notes.txt" "$NOTES"; python3 "$H/notifications.py" > "$NOTIF"
  cfg '.bar.weather.city="hong kong" | .windowGaps.mode="large"'
  sed -e 's#^color_theme = .*#color_theme = "/usr/share/btop/themes/paper.theme"#' -e 's#^theme_background = .*#theme_background = False#' \
    ~/.config/btop/btop.conf > "$D/btop-light.conf"
  ii-restart >/dev/null 2>&1; sleep 6; ipc coffee keepScreen true; ipc coffee start 2
  (nohup python3 "$H/player.py" 1800 >/dev/null 2>&1 &)
  hyprctl -q eval 'hl.dispatch(hl.dsp.focus({workspace=1}))' ;;
dark)
  windows w-top.sh; shot dark-desktop 1.0
  ipc sidebarLeft open; shot dark-left 1.5; cursor 120 408; sleep 0.3; ydotool click 0xC0 >/dev/null
  shot dark-left-detail 1.8; key 1:1 1:0; sleep 0.5; ipc sidebarLeft close; sleep 0.5
  ipc sidebarRight open; shot dark-right 1.5; cursor 1853 278; sleep 0.3; ydotool click 0xC1 >/dev/null
  shot dark-caffeine 1.2; key 1:1 1:0; sleep 0.5; ipc sidebarRight close; sleep 0.5
  ipc privacy simulate mic active; ipc privacy simulate camera active; pops dark
  ipc search toggle; sleep 1; ydotool type kitty >/dev/null; shot dark-search 1.2; layer "overview|search" && key 1:1 1:0; sleep 0.5
  notify-send -a Builds -i utilities-terminal "Screenshots ready" "lok-desktop · 14 images · lok"; shot dark-notif 1.0
  ipc osdVolume trigger; shot dark-osd 0.4; ipc osdVolume hide; sleep 0.4
  ipc session open; shot dark-session 1.0; ipc session close; sleep 0.5
  for m in none small large; do cfg ".windowGaps.mode=\"$m\""; sleep 2.5; shot "dark-gaps-$m" 0.5; done
  cfg '.bar.vertical=true'; sleep 3; windows w-top.sh; shot dark-vertical 0.5; cfg '.bar.vertical=false'; sleep 3
  # colour pick: fastfetch + palette only; loupe on the corner of the orange swatch
  pkill -f "[k]itty --class lokdemo"; sleep 1; run "kitty --class lokdemo -o font_size=11 $H/w-ff.sh"; sleep 0.8
  run "kitty --class lokdemo -o font_size=12 $H/w-pal.sh"; sleep 6
  ipc region screenshot; sleep 1.8; cursor 1239 302; sleep 0.3; wiggle; shot dark-colorpick 1.2; layer region && key 1:1 1:0
  windows w-top.sh; shot dark-desktop2 0.5 ;;
light)
  timeout 120 ~/.config/quickshell/ii/scripts/colors/switchwall.sh --mode light "$WALL/wallhaven-7jmgey-lok-light.png" >/dev/null 2>&1; sleep 5
  windows w-top-light.sh; shot light-desktop 0.5
  ipc sidebarLeft open; shot light-left 1.5; ipc sidebarLeft close; sleep 0.6
  ipc sidebarRight open; shot light-right 1.5; ipc sidebarRight close; sleep 0.5
  ipc privacy simulate mic active; ipc privacy simulate camera active; pops light ;;
restore)
  timeout 120 ~/.config/quickshell/ii/scripts/colors/switchwall.sh --mode dark "$WALL/wallhaven-7jmgey-lok.png" >/dev/null 2>&1; sleep 3
  pkill -f "lok/demo/player.py"; pkill -f "[k]itty --class lokdemo"
  cp -p "$D/bak/notes.txt" "$NOTES"; cp -p "$D/bak/notifications.json" "$NOTIF"; cp -p "$D/bak/config.json" "$C"
  ii-restart >/dev/null 2>&1; sleep 7; ipc coffee stop
  (cd / && sha256sum -c "$D/bak/SHA256SUMS") ;;
*) sed -n 2,10p "$0"; exit 1 ;;
esac
