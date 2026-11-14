#!/usr/bin/env python3
"""Re-apply the Quickshell ii customization patches after a dots update.

Every file in patches/ is checked independently:
  pristine  -> patch applies cleanly; apply it
  applied   -> reverse patch applies cleanly; nothing to do
  conflict  -> neither; end-4 changed the surrounding code, refuse

Patches are applied in filename order, so later patches may build on the
state produced by earlier ones.
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
PATCHES = sorted((ROOT / 'patches').glob('*.patch'))
BACKUP = HOME / '.local/state/ii-customizations/backups'


def run_patch(patch, *extra):
    return subprocess.run(
        ['patch', *extra, '-p1', '-d', str(TARGET), '-i', str(patch)],
        capture_output=True, text=True,
    )


def patch_files(patch):
    return [line[6:].strip() for line in patch.read_text().splitlines()
            if line.startswith('+++ b/')]


def state(patch):
    if not TARGET.is_dir():
        return 'missing'
    if run_patch(patch, '--dry-run').returncode == 0:
        return 'pristine'
    if run_patch(patch, '--dry-run', '-R').returncode == 0:
        return 'applied'
    return 'conflict'


def apply():
    if not TARGET.is_dir():
        print('target missing:', TARGET)
        return 1
    states = {patch: state(patch) for patch in PATCHES}
    conflicts = [patch for patch, value in states.items() if value == 'conflict']
    if conflicts:
        print('refusing: end-4 changed the surrounding code in:')
        for patch in conflicts:
            print(' ', patch.name)
        print('rediff needed; nothing was applied')
        return 1
    pending = [patch for patch, value in states.items() if value == 'pristine']
    if not pending:
        print('already applied')
        return 0
    stamp = datetime.now().strftime('%Y%m%d-%H%M%S')
    backup = BACKUP / stamp
    for patch in pending:
        for name in patch_files(patch):
            src = TARGET / name
            if src.exists():
                dst = backup / name
                dst.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(src, dst)
    for patch in pending:
        result = run_patch(patch, '--no-backup-if-mismatch')
        if result.returncode != 0:
            print(result.stdout + result.stderr)
            return 1
        print(patch.name, '-> applied')
    print('backup:', backup)
    shell = TARGET / 'shell.qml'
    if shell.exists():
        shell.touch()
        print('touched shell.qml to trigger a Quickshell reload')
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check', action='store_true',
                        help='exit 1 unless every patch is applied')
    args = parser.parse_args()
    states = {patch: state(patch) for patch in PATCHES}
    if args.check:
        for patch, value in states.items():
            print(f'{patch.name}: {value}')
        return 0 if all(value == 'applied' for value in states.values()) else 1
    if all(value == 'applied' for value in states.values()):
        print('already applied')
        return 0
    return apply()


if __name__ == '__main__':
    sys.exit(main())
