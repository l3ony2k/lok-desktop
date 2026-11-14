#!/usr/bin/env python3
"""Re-apply the lock-screen temp-workspace recovery after a dots-hyprland update.

The updater overwrites ~/.config/quickshell/ii wholesale, so the Lock.qml fix
is lost. The lock screen parks each monitor on workspace 2147483647 - realId;
if Quickshell restarts while locked, the in-memory saved map is gone and the
monitor stays on the temp workspace (SUPER+1..0 then cannot leave the INT_MAX
group). The patch makes restore reversible from the temp id itself and heals
at startup.

2026-11-12: the patch also adds `lock.parkWorkspaces` (Config.qml, default
true = upstream). When false the lock does not park monitors at all. Toggle
with `ii-lock-park on|off|status` (~/.local/bin); live, no restart needed.

Kept separate from fonts-and-icons/apply.py because that script refuses to
apply anything when any patch conflicts (its overview-search-only patch is
currently stale), which would silently block this fix.

States for the patch, relative to ~/.config/quickshell/ii:
  pristine  -> applies cleanly; apply it
  applied   -> reverse applies cleanly; nothing to do
  conflict  -> neither; end-4 changed the surrounding code, refuse

Usage:
    apply.py --check     # report state, touch nothing
    apply.py             # apply if pristine
"""
import argparse
import shutil
import subprocess
import sys
from datetime import datetime
from pathlib import Path

HOME = Path.home()
TARGET = HOME / '.config/quickshell/ii'
ROOT = Path(__file__).resolve().parent
PATCH = ROOT / 'patches/lock-temp-workspace.patch'
BACKUP = HOME / '.local/state/ii-customizations/backups'
FILES = ['modules/ii/lock/Lock.qml', 'modules/common/Config.qml']


def run_patch(*extra):
    return subprocess.run(
        ['patch', *extra, '-p1', '-d', str(TARGET), '-i', str(PATCH)],
        capture_output=True, text=True,
    )


def state():
    if not TARGET.is_dir():
        return 'missing'
    if run_patch('--dry-run').returncode == 0:
        return 'pristine'
    if run_patch('--dry-run', '-R').returncode == 0:
        return 'applied'
    return 'conflict'


def apply():
    current = state()
    if current == 'applied':
        print('already applied')
        return 0
    if current != 'pristine':
        print(f'{PATCH.name}: {current} — upstream changed Lock.qml/Config.qml, rediff needed')
        return 1
    stamp = datetime.now().strftime('%Y%m%d-%H%M%S')
    for f in FILES:
        src = TARGET / f
        if src.exists():
            dst = BACKUP / stamp / f
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
            print('backup:', dst)
    result = run_patch('--no-backup-if-mismatch')
    if result.returncode != 0:
        print(result.stdout + result.stderr)
        return 1
    print(PATCH.name, '-> applied')
    shell = TARGET / 'shell.qml'
    if shell.exists():
        shell.touch()
    # touching shell.qml does NOT reliably reload quickshell (2026-11-12)
    print('restart quickshell to load it: Ctrl+Super+R')
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true',
                        help='exit 0 only if the patch is applied')
    args = parser.parse_args()
    current = state()
    if args.check:
        print(f'{PATCH.name}: {current}')
        return 0 if current == 'applied' else 1
    return apply()


if __name__ == '__main__':
    sys.exit(main())
