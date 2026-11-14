#!/usr/bin/env python3
"""Regenerate Herdr's "end-4" theme from dots-hyprland's Material You colors.

Source of truth: ~/.local/state/quickshell/user/generated/material_colors.scss
Written by quickshell's switchwall.sh on every wallpaper / accent / light-dark
change. Both the quickshell UI and the generated kitty theme derive from it,
so Herdr stays in step with the rest of the desktop.

Output: ~/.config/herdr-app/themes/end-4.json (Herdr hot-reloads it).

Triggered by the systemd user path unit herdr-end4-theme.path, and safe to run
by hand. Writes nothing when the palette is unchanged or incomplete.
"""

import json
import os
import re
import sys
import tempfile

HOME = os.path.expanduser("~")
SRC = os.environ.get(
    "END4_SCSS",
    os.path.join(HOME, ".local/state/quickshell/user/generated/material_colors.scss"),
)
OUT = os.environ.get(
    "HERDR_THEME_OUT",
    os.path.join(HOME, ".config/herdr-app/themes/end-4.json"),
)

LINE = re.compile(r"^\s*\$([A-Za-z0-9_]+)\s*:\s*#([0-9A-Fa-f]{6})\s*;")

# Material role -> Herdr theme color name.
UI_MAP = {
    "canvas": "background",
    "chrome": "background",
    "surface": "surfaceContainer",
    "popover": "surfaceContainerHigh",
    "raised": "surfaceContainerHigh",
    "hover": "surfaceContainerHighest",
    "selected": "primaryContainer",
    "border": "outlineVariant",
    "input": "outline",
    "foreground": "onSurface",
    "muted": "onSurfaceVariant",
    "dim": "outline",
    "accent": "primary",
    "accent_foreground": "onPrimary",
    "solid": "primary",
    "solid_foreground": "onPrimary",
    "selection": "secondaryContainer",
    "working": "term2",
    "blocked": "error",
    "done": "success",
    "idle": "term8",
    "unknown": "tertiaryContainer",
    # Diff/inbox semantics for the Changes and Files panels. Kept separate from
    # working/blocked so a mod can tell an agent state from a file state.
    "add": "success",
    "del": "error",
}


def parse_scss(path):
    values = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            match = LINE.match(line)
            if match:
                values[match.group(1)] = "#" + match.group(2).upper()
    return values


def build(values):
    required = set(UI_MAP.values()) | {f"term{i}" for i in range(16)} | {
        "onSecondaryContainer"
    }
    missing = sorted(required - values.keys())
    if missing:
        raise KeyError("missing roles: " + ", ".join(missing))

    return {
        # Terminals. kitty gets background/foreground/cursor/selection from the
        # same generated palette; term0 and term7 match its bg/fg.
        "background": values["term0"],
        "foreground": values["term7"],
        "selection": values["onSecondaryContainer"],
        "cursor": values["term7"],
        "ansi": [values[f"term{i}"] for i in range(16)],
        "colors": {name: values[role] for name, role in UI_MAP.items()},
    }


def write_if_changed(path, text):
    try:
        with open(path, encoding="utf-8") as fh:
            if fh.read() == text:
                return False
    except FileNotFoundError:
        pass

    directory = os.path.dirname(path)
    os.makedirs(directory, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".end-4.", suffix=".json")
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            fh.write(text)
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except FileNotFoundError:
            pass
        raise
    return True


def main():
    try:
        values = parse_scss(SRC)
    except FileNotFoundError:
        print(f"no palette at {SRC}; nothing to do", file=sys.stderr)
        return 0

    try:
        theme = build(values)
    except KeyError as exc:
        print(f"palette incomplete ({exc}); keeping the last good theme", file=sys.stderr)
        return 0

    text = json.dumps(theme, indent=2) + "\n"
    changed = write_if_changed(OUT, text)
    print(f"{'wrote' if changed else 'unchanged'}: {OUT}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
