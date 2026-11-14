#!/usr/bin/env bash
# Show the state relevant to hibernation. No root needed.
set -u

echo "== date / uptime =="
date
uptime -p

echo
echo "== recent boots =="
journalctl --list-boots --no-pager 2>/dev/null | tail -3

echo
echo "== effective sleep config =="
systemd-analyze cat-config systemd/sleep.conf 2>/dev/null | grep -v '^#' | grep -v '^$'

echo
echo "== /sys/power/disk (current mode in brackets) =="
cat /sys/power/disk

echo
echo "== e820 ACPI region, current boot (0) =="
journalctl -b 0 --no-pager 2>/dev/null | grep 'BIOS-e820' | grep 661a || true

echo
echo "== final e820 (Registered nosave), current boot (0) =="
journalctl -b 0 --no-pager 2>/dev/null | grep 'Registered nosave memory' | grep 661a || true

echo
echo "== e820 ACPI region, previous boot (-1) =="
journalctl -b -1 --no-pager 2>/dev/null | grep 'BIOS-e820' | grep 661a || true

echo
echo "== kernel memmap view, current boot =="
for d in /sys/firmware/memmap/*; do
    s=$(cat "$d/start" 2>/dev/null || true)
    e=$(cat "$d/end" 2>/dev/null || true)
    t=$(cat "$d/type" 2>/dev/null || true)
    case "$s" in 0x000000000661*) echo "$s-$e $t" ;; esac
done
journalctl -b 0 --no-pager 2>/dev/null | grep -E 'user-defined|e820: \[mem 0x000000000661' | tail -6 || true

echo
echo "== hibernation events, current boot (0) =="
journalctl -b 0 --no-pager 2>/dev/null | grep -iE 'Image signature found|inconsistent memory map|resume from hibernation|hibernation entry|resume failed|sleep operation' | tail -12 || true

echo
echo "== hibernation events, previous boot (-1) =="
journalctl -b -1 --no-pager 2>/dev/null | grep -iE 'hibernation entry|sleep operation|suspend-then-hibernate|resume failed' | tail -12 || true

echo
if journalctl -b 0 --no-pager 2>/dev/null | grep -q 'resume from hibernation'; then
    if journalctl -b 0 --no-pager 2>/dev/null | grep -q 'inconsistent memory map'; then
        echo "RESULT: resume attempted but FAILED (memory map mismatch)"
    elif journalctl -b 0 --no-pager 2>/dev/null | grep -q 'Failed to load image'; then
        echo "RESULT: resume attempted but FAILED (image load error)"
    else
        echo "RESULT: resumed from hibernation successfully"
    fi
else
    echo "RESULT: no hibernation resume in this boot"
fi
