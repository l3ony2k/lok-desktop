#!/usr/bin/env python3
"""lok palette for ii (ASUS, 2026-11-12).

A fixed greyscale scheme after the lok skin of lok.computer: no colour is taken
from the wallpaper. Hue appears only where it carries meaning (error, success,
warning, links, terminal ANSI colours).

  lok_palette.py --mode dark|light --out DIR

writes into DIR:
  matugen.json            colours for `matugen json` (renders every ii template)
  material_colors.scss    what generate_colors_material.py would write (terminal etc.)
  Lok<Mode>.colors        KDE colour scheme (applied with plasma-apply-colorscheme)
"""
import argparse
import json
import os

# ---- M3 roles -> lok greys ---------------------------------------------------
# Layers follow ii's assumption (container levels step away from the background).
DARK = {
    "background": "#121212", "on_background": "#ededed",
    "surface": "#121212", "surface_dim": "#0c0c0c", "surface_bright": "#3a3a3a",
    "surface_container_lowest": "#0a0a0a", "surface_container_low": "#1c1c1c",
    "surface_container": "#262626", "surface_container_high": "#313131",
    "surface_container_highest": "#3c3c3c",
    "on_surface": "#ededed", "surface_variant": "#313131", "on_surface_variant": "#b4b4b4",
    "inverse_surface": "#ededed", "inverse_on_surface": "#1a1a1a",
    "outline": "#8f8f8f", "outline_variant": "#474747",
    "shadow": "#000000", "scrim": "#000000", "surface_tint": "#ededed",
    # accent = inversion: the text colour used as a fill
    "primary": "#ededed", "on_primary": "#141414",
    "primary_container": "#4d4d4d", "on_primary_container": "#ededed", "inverse_primary": "#4d4d4d",
    "secondary": "#c4c4c4", "on_secondary": "#141414",
    "secondary_container": "#3a3a3a", "on_secondary_container": "#ededed",
    "tertiary": "#9e9e9e", "on_tertiary": "#141414",
    "tertiary_container": "#313131", "on_tertiary_container": "#dcdcdc",
    "error": "#ff6e64", "on_error": "#141414", "error_container": "#4d1714", "on_error_container": "#ffd7d3",
    "primary_fixed": "#e6e6e6", "primary_fixed_dim": "#c4c4c4",
    "on_primary_fixed": "#141414", "on_primary_fixed_variant": "#3d3d3d",
    "secondary_fixed": "#dcdcdc", "secondary_fixed_dim": "#b4b4b4",
    "on_secondary_fixed": "#141414", "on_secondary_fixed_variant": "#3d3d3d",
    "tertiary_fixed": "#d2d2d2", "tertiary_fixed_dim": "#a8a8a8",
    "on_tertiary_fixed": "#141414", "on_tertiary_fixed_variant": "#3d3d3d",
    "source_color": "#808080",
    # meaning colours (not M3 roles; used for scss/kde/terminal)
    "success": "#7fc98a", "on_success": "#141414", "success_container": "#1d3b22", "on_success_container": "#c8f0cd",
    "warning": "#e3c16f", "link": "#6aaeff", "visited": "#b49bdc",
}
LIGHT = {
    "background": "#f2f2f2", "on_background": "#161616",
    "surface": "#f2f2f2", "surface_dim": "#d2d2d2", "surface_bright": "#fafafa",
    "surface_container_lowest": "#ffffff", "surface_container_low": "#e8e8e8",
    "surface_container": "#dddddd", "surface_container_high": "#d1d1d1",
    "surface_container_highest": "#c4c4c4",
    "on_surface": "#161616", "surface_variant": "#d1d1d1", "on_surface_variant": "#4a4a4a",
    "inverse_surface": "#262626", "inverse_on_surface": "#f0f0f0",
    "outline": "#5c5c5c", "outline_variant": "#b0b0b0",
    "shadow": "#000000", "scrim": "#000000", "surface_tint": "#1f1f1f",
    "primary": "#1f1f1f", "on_primary": "#f5f5f5",
    "primary_container": "#b8b8b8", "on_primary_container": "#141414", "inverse_primary": "#b8b8b8",
    "secondary": "#4a4a4a", "on_secondary": "#fafafa",
    "secondary_container": "#cccccc", "on_secondary_container": "#1a1a1a",
    "tertiary": "#6b6b6b", "on_tertiary": "#ffffff",
    "tertiary_container": "#d6d6d6", "on_tertiary_container": "#1a1a1a",
    "error": "#b42318", "on_error": "#ffffff", "error_container": "#f8d7d3", "on_error_container": "#5a0f08",
    "primary_fixed": "#e0e0e0", "primary_fixed_dim": "#c4c4c4",
    "on_primary_fixed": "#141414", "on_primary_fixed_variant": "#3d3d3d",
    "secondary_fixed": "#e4e4e4", "secondary_fixed_dim": "#c8c8c8",
    "on_secondary_fixed": "#141414", "on_secondary_fixed_variant": "#3d3d3d",
    "tertiary_fixed": "#e8e8e8", "tertiary_fixed_dim": "#cccccc",
    "on_tertiary_fixed": "#141414", "on_tertiary_fixed_variant": "#3d3d3d",
    "source_color": "#808080",
    "success": "#287a35", "on_success": "#ffffff", "success_container": "#cfe9d3", "on_success_container": "#0f3316",
    "warning": "#8a6100", "link": "#0067b3", "visited": "#6846a5",
}
# Terminal (kitty/sequences: term0 = background, term7 = foreground and cursor)
TERM = {
    "dark": ["#141414", "#e8675e", "#7fc98a", "#e3c16f", "#6aaeff", "#b49bdc", "#6bd2db", "#e6e6e6",
             "#6b6b6b", "#ff8077", "#9fe0a8", "#f2d48c", "#93c4ff", "#cbb6ea", "#93e3ea", "#f5f5f5"],
    "light": ["#f5f5f5", "#b42318", "#287a35", "#8a6100", "#0067b3", "#6846a5", "#087780", "#1f1f1f",
              "#8a8a8a", "#c9372b", "#2f8f3f", "#a37300", "#0a7ad1", "#7d58c2", "#0a8f9a", "#141414"],
}
M3_ROLES = [k for k in DARK if k not in ("success", "on_success", "success_container",
                                          "on_success_container", "warning", "link", "visited")]


def camel(name):
    head, *rest = name.split("_")
    return head + "".join(w.capitalize() for w in rest)


def matugen_json(mode):
    pal = DARK if mode == "dark" else LIGHT
    colors = {k: {"dark": {"color": DARK[k]}, "light": {"color": LIGHT[k]}, "default": {"color": pal[k]}}
              for k in M3_ROLES}
    return {"colors": colors, "mode": mode, "is_dark_mode": mode == "dark", "image": ""}


def scss(mode):
    pal = DARK if mode == "dark" else LIGHT
    lines = [f"$darkmode: {'True' if mode == 'dark' else 'False'};", "$transparent: False;"]
    for key in ("primary", "secondary", "tertiary", "neutral", "neutral_variant"):
        lines.append(f"${key}_paletteKeyColor: #808080;")
    for k in M3_ROLES:
        if k == "source_color":
            continue
        lines.append(f"${camel(k)}: {pal[k]};")
    for k in ("success", "on_success", "success_container", "on_success_container"):
        lines.append(f"${camel(k)}: {pal[k]};")
    for i, c in enumerate(TERM[mode]):
        lines.append(f"$term{i}: {c};")
    return "\n".join(lines) + "\n"


def rgb(h):
    h = h.lstrip("#")
    return ",".join(str(int(h[i:i + 2], 16)) for i in (0, 2, 4))


def kde_scheme(mode):
    p = DARK if mode == "dark" else LIGHT
    name = "LokDark" if mode == "dark" else "LokLight"
    view_bg = p["surface_container_lowest"] if mode == "light" else p["surface_container_low"]
    # light windows/popups float just above the #f2f2f2 base (ii bar) instead of the
    # recessed #dddddd container grey; dark keeps surface_container
    win_bg = "#f7f7f7" if mode == "light" else p["surface_container"]
    common = {
        "ForegroundNormal": p["on_surface"], "ForegroundInactive": p["on_surface_variant"],
        "ForegroundActive": p["on_surface"], "ForegroundLink": p["link"], "ForegroundVisited": p["visited"],
        "ForegroundNegative": p["error"], "ForegroundNeutral": p["warning"], "ForegroundPositive": p["success"],
        "DecorationFocus": p["outline"], "DecorationHover": p["outline"],
    }
    sets = {
        "Window": {"BackgroundNormal": win_bg, "BackgroundAlternate": p["surface_container_high"]},
        "View": {"BackgroundNormal": view_bg, "BackgroundAlternate": "#f4f4f4" if mode == "light" else "#212121"},  # alternating rows: a hint, not stripes
        "Button": {"BackgroundNormal": p["surface_container_high"], "BackgroundAlternate": p["surface_container_highest"]},
        "Header": {"BackgroundNormal": win_bg, "BackgroundAlternate": p["surface_container_high"]},
        "Header][Inactive": {"BackgroundNormal": p["surface_container"], "BackgroundAlternate": p["surface_container_high"]},
        "Tooltip": {"BackgroundNormal": p["surface_container_highest"], "BackgroundAlternate": p["surface_container_high"]},
        "Complementary": {"BackgroundNormal": p["background"], "BackgroundAlternate": p["surface_container_low"]},
        # selection = one step from the surface toward the text colour (same rule as
        # ii's colPrimary); text keeps the normal text colour. Inversion made apps
        # that draw selected text with the normal text colour unreadable.
        "Selection": {"BackgroundNormal": "#4a4a4a" if mode == "dark" else "#c8c8c8",
                      "BackgroundAlternate": "#3c3c3c" if mode == "dark" else "#d4d4d4",
                      "ForegroundNormal": p["on_surface"], "ForegroundActive": p["on_surface"],
                      "ForegroundInactive": p["on_surface_variant"]},
    }
    out = [f"[General]\nColorScheme={name}\nName=Lok {mode.capitalize()}\nshadeSortColumn=true\n",
           "[KDE]\ncontrast=4\n",
           "[ColorEffects:Disabled]\nColor=" + rgb(p["surface_container"]) +
           "\nColorAmount=0.5\nColorEffect=3\nContrastAmount=0.5\nContrastEffect=0\nIntensityAmount=0\nIntensityEffect=0\n",
           "[ColorEffects:Inactive]\nChangeSelectionColor=false\nEnable=false\n"]
    for section, vals in sets.items():
        merged = dict(common)
        merged.update(vals)
        out.append(f"[Colors:{section}]\n" + "".join(f"{k}={rgb(v)}\n" for k, v in sorted(merged.items())))
    out.append("[WM]\nactiveBackground=" + rgb(p["surface_container"]) + "\nactiveForeground=" + rgb(p["on_surface"]) +
               "\ninactiveBackground=" + rgb(p["surface_container_low"]) + "\ninactiveForeground=" + rgb(p["on_surface_variant"]) + "\n")
    return name, "\n".join(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", choices=["dark", "light"], required=True)
    ap.add_argument("--out", required=True)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    json.dump(matugen_json(a.mode), open(os.path.join(a.out, "matugen.json"), "w"), indent=1)
    open(os.path.join(a.out, "material_colors.scss"), "w").write(scss(a.mode))
    name, text = kde_scheme(a.mode)
    open(os.path.join(a.out, f"{name}.colors"), "w").write(text)
    print(name)


if __name__ == "__main__":
    main()
