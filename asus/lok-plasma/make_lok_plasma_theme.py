#!/usr/bin/env python3
"""Generate the "lok" Plasma desktop theme (~/.local/share/plasma/desktoptheme/lok).

Reads the 9-slice frame structure (prefixes + hint elements) of selected Breeze
SVGs and re-emits them as square, shadowless frames whose colours come from the
active KDE colour scheme (LokDark / LokLight), so the theme follows light/dark.
Files not generated here fall back to Breeze. Rerunnable; output is generated.
"""
import gzip, json, os, re, shutil
import xml.etree.ElementTree as ET

SRC = "/usr/share/plasma/desktoptheme/default"
DST = os.path.expanduser("~/.local/share/plasma/desktoptheme/lok")
POS = ["topleft", "top", "topright", "left", "center", "right", "bottomleft", "bottom", "bottomright"]
S = 4  # piece size in svg units

T, B, H = "ColorScheme-Text", "ColorScheme-Background", "ColorScheme-Highlight"
V, BB, CB = "ColorScheme-ViewBackground", "ColorScheme-ButtonBackground", "ColorScheme-ComplementaryBackground"
NEG, POSV = "ColorScheme-NegativeText", "ColorScheme-PositiveText"

def F(fill=None, border=None, bw=(1, 1, 1, 1)):
    """fill/border = (class, opacity) or None; bw = (top, right, bottom, left)."""
    return {"fill": fill, "border": border, "bw": bw}

FLOAT = F((B, 1), (T, 0.30))
NOTHING = F()
HOVER = F((T, 0.07), None)
SELECTED = F((H, 1), (T, 0.30))
SELECTED_HOVER = F((H, 1), (T, 0.45))

def strip(side):  # selected + 2 px status strip on one side (t, r, b, l index)
    bw = [1, 1, 1, 1]; bw[side] = 2
    return F((H, 1), (T, 0.55), tuple(bw))

SPEC = {
    "dialogs/background": {"": FLOAT},
    "widgets/tooltip": {"": FLOAT},
    "widgets/background": {"": FLOAT, "toolbutton-pressed": F((H, 1), None)},
    "widgets/panel-background": {"": F((CB, 1), (T, 0.20)), "thick": F((CB, 1), (T, 0.20))},
    "widgets/viewitem": {"normal": NOTHING, "hover": HOVER, "selected": SELECTED, "selected+hover": SELECTED_HOVER},
    "widgets/plasmoidheading": {"header": F(None, (T, 0.15), (0, 0, 1, 0)), "footer": F(None, (T, 0.15), (1, 0, 0, 0))},
    "widgets/frame": {"plain": NOTHING, "raised": F((B, 1), (T, 0.20)), "sunken": F((V, 1), (T, 0.20)),
                      "border": F(None, (T, 0.20))},
    "widgets/lineedit": {"base": F((V, 1), (T, 0.30)), "hover": F(None, (T, 0.45)), "focus": F(None, (T, 0.65)),
                         "focusframe": F(None, (T, 0.65))},
    "widgets/button": {"normal": F((BB, 1), (T, 0.25)), "pressed": F((H, 1), (T, 0.45)),
                       "hover": F(None, (T, 0.45)), "focus": F(None, (T, 0.65)),
                       "toolbutton-hover": HOVER, "toolbutton-pressed": F((H, 1), None),
                       "toolbutton-focus": F(None, (T, 0.50)), "mask-normal": F((B, 1), None)},
    "widgets/scrollbar": {"background-horizontal": NOTHING, "background-vertical": NOTHING,
                          "slider": F((T, 0.25), None), "mouseover-slider": F((T, 0.40), None)},
    "widgets/bar_meter_horizontal": {"bar-inactive": F((T, 0.12), None), "bar-active": F((T, 0.60), None)},
    "widgets/tabbar": {p + "-active-tab": F((H, 1), None) for p in ("north", "south", "east", "west")},
}
# taskbar: south is unprefixed; strip on the screen-edge side
TASKS = {}
for orient, side in (("", 2), ("north-", 0), ("east-", 1), ("west-", 3)):
    TASKS[orient + "normal"] = NOTHING
    TASKS[orient + "minimized"] = NOTHING
    TASKS[orient + "hover"] = HOVER
    TASKS[orient + "focus"] = strip(side)
    TASKS[orient + "attention"] = F((NEG, 0.25), None)
    TASKS[orient + "progress"] = F((POSV, 0.25), None)
TASKS["group-expander"] = NOTHING
SPEC["widgets/tasks"] = TASKS

STYLE = ('<style type="text/css" id="current-color-scheme">'
         ".ColorScheme-Text{color:#ededed}.ColorScheme-Background{color:#262626}"
         ".ColorScheme-Highlight{color:#4a4a4a}.ColorScheme-ViewBackground{color:#1c1c1c}"
         ".ColorScheme-ButtonBackground{color:#313131}.ColorScheme-ComplementaryBackground{color:#121212}"
         ".ColorScheme-NegativeText{color:#ff6e64}.ColorScheme-PositiveText{color:#7fc98a}</style>")

def rect(x, y, w, h, paint, extra=""):
    cls, op = paint
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" class="{cls}" '
            f'style="fill:currentColor;fill-opacity:{op};stroke:none"{extra}/>')

def frame(prefix, spec, ox, oy):
    """Emit the 9 pieces of one frame at origin (ox, oy) laid out on a 3x3 grid."""
    out = []
    t, r, b, l = spec["bw"]
    for i, pos in enumerate(POS):
        col, row = i % 3, i // 3
        x, y = ox + col * (S + 2), oy + row * (S + 2)
        pid = f"{prefix}-{pos}" if prefix else pos
        parts = []
        # invisible full-size rect keeps every piece S x S
        parts.append(f'<rect x="{x}" y="{y}" width="{S}" height="{S}" style="fill:#000;fill-opacity:0"/>')
        if spec["fill"]:
            parts.append(rect(x, y, S, S, spec["fill"]))
        if spec["border"]:
            if row == 0 and t: parts.append(rect(x, y, S, t, spec["border"]))
            if row == 2 and b: parts.append(rect(x, y + S - b, S, b, spec["border"]))
            if col == 0 and l: parts.append(rect(x, y, l, S, spec["border"]))
            if col == 2 and r: parts.append(rect(x + S - r, y, r, S, spec["border"]))
        out.append(f'<g id="{pid}">' + "".join(parts) + "</g>")
    return out

# content padding overrides (svg units, scaled by the display scale): Breeze's
# 4 px dialog margins relied on rounded corners + shadow to look padded
MARGINS = {"dialogs/background": 12, "widgets/tooltip": 8, "widgets/background": 12}

def hints(src_svg, prefixes, margin=None):
    """Copy hint-* elements (sizes matter, positions do not); drop shadow hints."""
    root = ET.fromstring(src_svg)
    out, x = [], 5000
    for el in root.iter():
        i = el.get("id") or ""
        if "hint" not in i or i.startswith("shadow-"):
            continue
        pre = i.split("hint")[0].rstrip("-")
        if pre and pre not in prefixes:
            continue
        try:
            w = float(el.get("width", "1")); h = float(el.get("height", "1"))
        except ValueError:
            w = h = 1.0
        if margin is not None and re.fullmatch(r"hint-(top|bottom|left|right)-margin", i):
            w = h = margin
        out.append(f'<rect id="{i}" x="{x}" y="0" width="{w}" height="{h}" style="fill:none"/>')
        x += max(w, 1) + 4
    return out

def build(path, spec):
    src = gzip.open(os.path.join(SRC, path + ".svgz")).read().decode()
    body = []
    for n, (prefix, fs) in enumerate(spec.items()):
        body += frame(prefix, fs, (n % 8) * 40, (n // 8) * 40)
    body += hints(src, set(spec), MARGINS.get(path))
    write_svg(path, body)

def write_svg(path, body):
    svg = ('<svg xmlns="http://www.w3.org/2000/svg" width="6000" height="400">' + STYLE
           + "".join(body) + "</svg>")
    for sub in ("", "translucent/", "opaque/"):
        out = os.path.join(DST, sub + path + ".svgz")
        os.makedirs(os.path.dirname(out), exist_ok=True)
        with gzip.open(out, "wb") as f:
            f.write(svg.encode())

def build_switch():
    """widgets/switch: 3-slice bar (left/center/right) per state + square handle.
    Off = hollow frame, on = selected fill + bright frame; the handle is an inset
    10 px square inside a 16 px box (same reading as ii's lok switch)."""
    BAR_H, P = 16, 4
    body, x = [], 0
    states = {"inactive": (None, (T, 0.35)), "active": ((H, 1), (T, 0.60))}
    for st, (fill, border) in states.items():
        for piece in ("left", "center", "right"):
            parts = [f'<rect x="{x}" y="0" width="{P}" height="{BAR_H}" style="fill:#000;fill-opacity:0"/>']
            if fill:
                parts.append(rect(x, 0, P, BAR_H, fill))
            parts.append(rect(x, 0, P, 1, border))
            parts.append(rect(x, BAR_H - 1, P, 1, border))
            if piece == "left":
                parts.append(rect(x, 0, 1, BAR_H, border))
            if piece == "right":
                parts.append(rect(x + P - 1, 0, 1, BAR_H, border))
            body.append(f'<g id="{st}-{piece}">' + "".join(parts) + "</g>")
            x += P + 4
    def handle(eid, knob_op, ring=None):
        nonlocal x
        parts = [f'<rect x="{x}" y="0" width="16" height="16" style="fill:#000;fill-opacity:0"/>']
        if ring:
            parts.append(rect(x, 0, 16, 1, ring) + rect(x, 15, 16, 1, ring)
                         + rect(x, 0, 1, 16, ring) + rect(x + 15, 0, 1, 16, ring))
        if knob_op:
            parts.append(rect(x + 3, 3, 10, 10, (T, knob_op)))
        body.append(f'<g id="{eid}">' + "".join(parts) + "</g>")
        x += 20
    handle("handle", 0.80)
    handle("handle-hover", 0.95)
    handle("handle-pressed", 1.0)
    handle("handle-focus", None, (T, 0.65))
    handle("handle-shadow", None)
    body.append(f'<rect id="hint-bar-size" x="{x}" y="0" width="38" height="{BAR_H}" style="fill:none"/>')
    write_svg("widgets/switch", body)

def box(eid, x, size, parts):
    return (f'<g id="{eid}"><rect x="{x}" y="0" width="{size}" height="{size}" '
            f'style="fill:#000;fill-opacity:0"/>' + "".join(parts) + "</g>")

def ring(x, size, paint):
    return [rect(x, 0, size, 1, paint), rect(x, size - 1, size, 1, paint),
            rect(x, 0, 1, size, paint), rect(x + size - 1, 0, 1, size, paint)]

def build_slider():
    """widgets/slider: flat groove + mid-grey filled part; handle = 3 px bright bar
    (ii's lok slider handle), focus = 1 px ring."""
    body = frame("groove", F((T, 0.18), None), 0, 0) + frame("groove-highlight", F((T, 0.60), None), 40, 0)
    x, HS = 100, 20
    for orient in ("horizontal", "vertical"):
        def bar(op):
            if orient == "horizontal":
                return [rect(x + (HS - 3) / 2, 0, 3, HS, (T, op))]
            return [rect(x, (HS - 3) / 2, HS, 3, (T, op))]
        body.append(box(f"{orient}-slider-handle", x, HS, bar(0.90))); x += HS + 4
        body.append(box(f"{orient}-slider-hover", x, HS, bar(1.0))); x += HS + 4
        body.append(box(f"{orient}-slider-focus", x, HS, ring(x, HS, (T, 0.55)))); x += HS + 4
        body.append(box(f"{orient}-slider-shadow", x, HS, [])); x += HS + 4
    body.append(f'<rect id="hint-handle-size" x="{x}" y="0" width="{HS}" height="{HS}" style="fill:none"/>')
    body.append(f'<rect id="hint-tile-center" x="{x + 30}" y="0" width="2" height="2" style="fill:none"/>')
    write_svg("widgets/slider", body)

def build_radiobutton():
    """widgets/radiobutton: square like everything in lok; checked = inset square."""
    S16, x, body = 16, 0, []
    for eid, parts in (("normal", [rect(0, 0, S16, S16, (V, 1))] + ring(0, S16, (T, 0.45))),
                       ("hover", ring(0, S16, (T, 0.75))),
                       ("focus", ring(0, S16, (T, 0.85))),
                       ("checked", [rect(4, 4, 8, 8, (T, 0.95))]),
                       ("symbol", [rect(4, 4, 8, 8, (T, 0.95))]),
                       ("shadow", [])):
        g =[s.replace('<rect x="', f'<rect transform="translate({x},0)" x="', 1) for s in parts]
        body.append(box(eid, x, S16, g)); x += S16 + 4
    body.append(f'<rect id="hint-size" x="{x}" y="0" width="{S16}" height="{S16}" style="fill:none"/>')
    write_svg("widgets/radiobutton", body)

if os.path.isdir(DST):
    shutil.rmtree(DST)
os.makedirs(DST)
for path, spec in SPEC.items():
    build(path, spec)
build_switch()
build_slider()
build_radiobutton()
json.dump({"KPlugin": {"Id": "lok", "Name": "Lok", "Version": "1",
                        "Description": "Square, shadowless, greyscale (lok.computer). Generated; colours follow the KDE colour scheme.",
                        "License": "LGPL-2.1+", "Authors": [{"Name": "leon"}]},
           "X-Plasma-API-Minimum-Version": "6.0"},
          open(os.path.join(DST, "metadata.json"), "w"), indent=1)
# no blur/contrast behind panels and popups: lok surfaces are opaque
open(os.path.join(DST, "plasmarc"), "w").write(
    "[ContrastEffect]\nenabled=false\n\n[BlurBehindEffect]\nenabled=false\n\n[AdaptiveTransparency]\nenabled=false\n")
print(f"lok plasma theme: {len(SPEC)} svgs in {DST}")
