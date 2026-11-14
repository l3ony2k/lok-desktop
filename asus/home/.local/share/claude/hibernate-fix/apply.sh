#!/usr/bin/env bash
# Install the hibernation fix: use ACPI S5 (shutdown) instead of platform S4.
# This is the only step that needs root. Run with:
#   ! bash ~/.local/share/claude/hibernate-fix/apply.sh
set -euo pipefail

dir=$(cd -- "$(dirname -- "$0")" && pwd)

sudo install -Dm644 "$dir/10-hibernate-mode.conf" /etc/systemd/sleep.conf.d/10-hibernate-mode.conf

echo
echo "== effective sleep config =="
systemd-analyze cat-config systemd/sleep.conf 2>/dev/null | grep -v '^#' | grep -v '^$'

echo
echo "== current /sys/power/disk =="
cat /sys/power/disk

echo
echo "Installed. Next step: a full poweroff, then power on by hand."
