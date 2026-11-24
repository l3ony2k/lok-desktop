#!/bin/sh
sleep 5; clear; cd ~/.config/quickshell/ii || exit
c=$(tput cols); l=$(tput lines)
bat --color=always --paging=never --theme=ansi --style=numbers,header,grid -r 28:74 modules/ii/bar/PrivacyDots.qml | python3 "$(dirname "$0")/chop.py" "$c" | head -n $((l-1))
exec sleep infinity
