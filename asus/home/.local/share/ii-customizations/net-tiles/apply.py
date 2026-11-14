#!/usr/bin/env python3
"""Re-apply the Mihomo + Tailscale quick-toggle tiles after a dots-hyprland update.

The updater rsyncs ~/.config/quickshell/ii wholesale, so every hand edit there
is lost. This script restores the component files and the five integration
edits, and merges the two toggle entries into config.json (which lives outside
the rsync tree and normally survives).

Usage:
    apply.py --check     # report what would change, touch nothing
    apply.py             # apply
"""
import argparse
import json
import shutil
import subprocess
import sys
import time
from pathlib import Path

HOME = Path.home()
QS = HOME / ".config/quickshell/ii"
BUNDLE = HOME / ".local/share/ii-customizations/net-tiles"
FILES = BUNDLE / "files"
PATCH = BUNDLE / "integration.patch"
CONFIG = HOME / ".config/illogical-impulse/config.json"
BACKUP_ROOT = HOME / ".local/state/ii-customizations/backups"

# Files the patch touches, relative to the quickshell config root.
PATCHED = [
    "modules/ii/sidebarRight/quickToggles/AbstractQuickPanel.qml",
    "modules/ii/sidebarRight/quickToggles/AndroidQuickPanel.qml",
    "modules/ii/sidebarRight/quickToggles/androidStyle/AndroidToggleDelegateChooser.qml",
    "modules/ii/sidebarRight/quickToggles/ClassicQuickPanel.qml",
    "modules/ii/sidebarRight/SidebarRightContent.qml",
]

TOGGLES = [("mihomo", "cloudflareWarp"), ("tailscale", None)]


def backup(paths):
    stamp = time.strftime("%Y%m%d-%H%M%S")
    dest = BACKUP_ROOT / stamp
    dest.mkdir(parents=True, exist_ok=True)
    for p in paths:
        if p.exists():
            rel = p.relative_to(HOME)
            target = dest / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(p, target)
    return dest


def patch_applied():
    """True when every patched file already contains its marker."""
    markers = {
        "modules/ii/sidebarRight/quickToggles/AbstractQuickPanel.qml": "openMihomoDialog",
        "modules/ii/sidebarRight/quickToggles/AndroidQuickPanel.qml": '"tailscale"',
        "modules/ii/sidebarRight/quickToggles/androidStyle/AndroidToggleDelegateChooser.qml": 'roleValue: "tailscale"',
        "modules/ii/sidebarRight/quickToggles/ClassicQuickPanel.qml": "TailscaleToggle",
        "modules/ii/sidebarRight/SidebarRightContent.qml": "showMihomoDialog",
    }
    return all((QS / rel).exists() and marker in (QS / rel).read_text(encoding="utf-8")
               for rel, marker in markers.items())


def apply_patch(check):
    if patch_applied():
        print("integration patch: already applied")
        return True
    # Dry-run first so a changed upstream file aborts before anything is written.
    dry = subprocess.run(["patch", "-p1", "--dry-run", "-d", str(QS), "-i", str(PATCH)],
                         capture_output=True, text=True)
    if dry.returncode != 0:
        print("integration patch: REFUSED — upstream files changed, rediff needed")
        print(dry.stdout + dry.stderr)
        return False
    if check:
        print("integration patch: would apply")
        return True
    real = subprocess.run(["patch", "-p1", "-d", str(QS), "-i", str(PATCH)],
                          capture_output=True, text=True)
    print("integration patch: applied" if real.returncode == 0 else "integration patch: FAILED")
    if real.returncode != 0:
        print(real.stdout + real.stderr)
    return real.returncode == 0


def install_components(check):
    changed = []
    for src in sorted(FILES.rglob("*.qml")):
        rel = src.relative_to(FILES)
        dst = QS / rel
        if dst.exists() and dst.read_bytes() == src.read_bytes():
            continue
        changed.append(rel)
        if not check:
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)
    if not changed:
        print("components: up to date")
    else:
        verb = "would install" if check else "installed"
        print(f"components: {verb} {len(changed)} file(s)")
        for rel in changed:
            print(f"  {rel}")
    return True


def merge_config(check):
    if not CONFIG.exists():
        print("config.json: missing, skipped")
        return True
    data = json.loads(CONFIG.read_text(encoding="utf-8"))
    toggles = data["sidebar"]["quickToggles"]["android"]["toggles"]
    present = {t.get("type") for t in toggles if isinstance(t, dict)}
    added = []
    for new, old in TOGGLES:
        if new in present:
            continue
        # Replace the old tile in place when it is still there, else append.
        idx = next((i for i, t in enumerate(toggles)
                    if isinstance(t, dict) and t.get("type") == old), None)
        if idx is not None:
            toggles[idx] = {"size": 1, "type": new}
        else:
            toggles.append({"size": 1, "type": new})
        added.append(new)
    if not added:
        print("config.json: toggles already present")
        return True
    if check:
        print(f"config.json: would add {added}")
        return True
    CONFIG.write_text(json.dumps(data, ensure_ascii=False, indent=4) + "\n", encoding="utf-8")
    print(f"config.json: added {added}")
    return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    if not QS.exists():
        sys.exit(f"quickshell config not found at {QS}")

    if not args.check:
        dest = backup([QS / rel for rel in PATCHED] + [CONFIG])
        print(f"backup: {dest}")

    ok = install_components(args.check)
    ok = apply_patch(args.check) and ok
    ok = merge_config(args.check) and ok
    if not ok:
        sys.exit(1)
    if not args.check:
        print("\nReload the shell:  qs -c ii ipc call panelFamily cycle  (twice)")
        print("or restart it:     qs kill -c ii && qs -c ii &")


if __name__ == "__main__":
    main()
