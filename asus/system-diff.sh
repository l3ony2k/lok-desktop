#!/usr/bin/env bash
# asus/system-diff.sh — compare the system-file copies in asus/system/ with the live system.
# Prints same / DIFFERS / missing / root-only per file. Read-only and never prompts:
# root-only files are read with `sudo -n` and reported as root-only if that needs a password
# (run it from a terminal after `sudo -v` to compare those too).
#   asus/system-diff.sh pull    copy the live versions of DIFFERS files into asus/system/
set -uo pipefail
S=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)/system
cd "$S"
tmp=$(mktemp); trap 'rm -f "$tmp"' EXIT
rd() { if [ -r "$1" ]; then cat "$1"; else sudo -n cat "$1" 2>/dev/null || return 2; fi; }
find . \( -type f -o -type l \) | sort | while read -r f; do
  live=/${f#./}
  if [ -L "$f" ]; then
    [ "$(readlink "$f")" = "$(readlink "$live" 2>/dev/null)" ] && st=same || st=DIFFERS
  elif [ ! -e "$live" ] && ! sudo -n test -e "$live" 2>/dev/null; then
    if [ -r "$(dirname "$live")" ] && [ -x "$(dirname "$live")" ]; then st=missing; else st=root-only; fi
  else
    rd "$live" > "$tmp"; rc=$?
    if [ $rc -eq 2 ]; then st=root-only
    elif cmp -s "$tmp" "$f"; then st=same; else st=DIFFERS; fi
    if [ "${1:-}" = pull ] && [ "$st" = DIFFERS ]; then cp "$tmp" "$f" && st=pulled; fi
  fi
  printf '%-9s %s\n' "$st" "$live"
done
