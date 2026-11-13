#!/usr/bin/env python3
"""Generate the lok window decoration for KWin (Aurorae SVG themes lok-dark / lok-light).

lok.computer windows: 2 px border, 30 px title bar with a hairline under it, hard
3 px offset shadow. Plasma-only addition: the active window is singled out with a
bright frame, a raised title bar and the shadow; inactive windows get a dim frame,
the window-colour title bar and no shadow. Rerunnable; output is generated.
"""
import os, shutil

OUT = os.path.expanduser("~/.local/share/aurorae/themes")

MODES = {
    "dark": dict(text="#ededed", text_in="#8a8a8a", title="#313131", title_in="#262626",
                 frame="#8a8a8a", frame_in="#3d3d3d", line="#3d3d3d", line_in="#313131",
                 shadow="#000000", shadow_op=0.55, hover=0.14, press=0.24),
    "light": dict(text="#161616", text_in="#6a6a6a", title="#e2e2e2", title_in="#f7f7f7",
                  frame="#3a3a3a", frame_in="#b0b0b0", line="#b0b0b0", line_in="#c4c4c4",
                  shadow="#000000", shadow_op=0.30, hover=0.10, press=0.18),
}

B = 2          # border
TOP = 30       # title area incl. top border (TitleEdgeTop + TitleHeight + TitleEdgeBottom)
SH = 3         # shadow offset = right/bottom padding
W = 8          # length of stretchable pieces

def r(x, y, w, h, color, op=1.0):
    if w <= 0 or h <= 0:
        return ""
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{color}" fill-opacity="{op}"/>'

def pieces(prefix, c, active):
    """9 pieces for one state, origin-local; returns list of (id, w, h, body)."""
    frame = c["frame"] if active else c["frame_in"]
    title = c["title"] if active else c["title_in"]
    line = c["line"] if active else c["line_in"]
    sh = (lambda x, y, w, h: r(x, y, w, h, c["shadow"], c["shadow_op"])) if active else (lambda *a: "")
    p = []
    # top row: border(B) on top, title fill, hairline at bottom (y = TOP-1)
    def top_body(w, left_border, right_border):
        s = r(0, 0, w, TOP, title) + r(0, 0, w, B, frame) + r(0, TOP - 1, w, 1, line)
        if left_border: s += r(0, 0, B, TOP, frame)
        if right_border: s += r(w - B, 0, B, TOP, frame)
        return s
    p.append(("topleft", B, TOP, top_body(B, True, False)))
    p.append(("top", W, TOP, top_body(W, False, False)))
    # topright: border column then the shadow column starting SH down
    p.append(("topright", B + SH, TOP, r(0, 0, B, TOP, frame) + sh(B, SH, SH, TOP - SH)))
    # middle row: client area is transparent
    p.append(("left", B, W, r(0, 0, B, W, frame)))
    p.append(("center", W, W, r(0, 0, W, W, "#000000", 0.0)))
    p.append(("right", B + SH, W, r(0, 0, B, W, frame) + sh(B, 0, SH, W)))
    # bottom row: border then shadow strip (starts after the left border)
    p.append(("bottomleft", B, B + SH, r(0, 0, B, B, frame)))
    p.append(("bottom", W, B + SH, r(0, 0, W, B, frame) + sh(0, B, W, SH)))
    p.append(("bottomright", B + SH, B + SH, r(0, 0, B, B, frame) + sh(B, 0, SH, B) + sh(0, B, B + SH, SH)))
    return [(f"{prefix}-{i}", w, h, body) for i, w, h, body in p]

def decoration_svg(c):
    groups, x = [], 0
    for prefix, active in (("decoration", True), ("decoration-inactive", False),
                           ("decoration-maximized", True), ("decoration-maximized-inactive", False)):
        for pid, w, h, body in pieces(prefix, c, active):
            # every piece gets an invisible box of its full size so its bounds are exact
            groups.append(f'<g id="{pid}" transform="translate({x},0)">'
                          f'<rect width="{w}" height="{h}" fill="#000" fill-opacity="0"/>{body}</g>')
            x += w + 4
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{x}" height="{TOP + 10}">'
            + "".join(groups) + "</svg>")

GLYPHS = {  # 20x20 button, 1.5 px strokes, drawn as rects/polylines
    "close": '<path d="M6 6 L14 14 M14 6 L6 14" stroke="{fg}" stroke-width="1.5" fill="none"/>',
    "maximize": '<rect x="5.75" y="5.75" width="8.5" height="8.5" stroke="{fg}" stroke-width="1.5" fill="none"/>',
    "restore": '<rect x="5.75" y="7.75" width="6.5" height="6.5" stroke="{fg}" stroke-width="1.5" fill="none"/>'
               '<path d="M8 7.75 V5.75 H14.25 V12 H12.25" stroke="{fg}" stroke-width="1.5" fill="none"/>',
    "minimize": '<rect x="5" y="13" width="10" height="1.5" fill="{fg}"/>',
    "alldesktops": '<rect x="8" y="8" width="4" height="4" fill="{fg}"/>',
}

def button_svg(glyph, c):
    states = {
        "active": ("", c["text"]),
        "hover": (r(0, 0, 20, 20, c["text"], c["hover"]), c["text"]),
        "pressed": (r(0, 0, 20, 20, c["text"], c["press"]), c["text"]),
        "inactive": ("", c["text_in"]),
        "deactivated": ("", c["text_in"]),
        "pressed-inactive": (r(0, 0, 20, 20, c["text"], c["press"]), c["text_in"]),
        "hover-inactive": (r(0, 0, 20, 20, c["text"], c["hover"]), c["text_in"]),
    }
    out, x = [], 0
    for st, (bg, fg) in states.items():
        out.append(f'<g id="{st}-center" transform="translate({x},0)"><rect width="20" height="20" '
                   f'fill="#000" fill-opacity="0"/>{bg}{GLYPHS[glyph].format(fg=fg)}</g>')
        x += 24
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{x}" height="20">' + "".join(out) + "</svg>"

for mode, c in MODES.items():
    name = f"lok-{mode}"
    d = os.path.join(OUT, name)
    if os.path.isdir(d):
        shutil.rmtree(d)
    os.makedirs(d)
    open(os.path.join(d, "decoration.svg"), "w").write(decoration_svg(c))
    for g in GLYPHS:
        open(os.path.join(d, f"{g}.svg"), "w").write(button_svg(g, c))
    open(os.path.join(d, "metadata.desktop"), "w").write(
        f"[Desktop Entry]\nName=Lok {mode.capitalize()}\nComment=lok.computer windows (generated)\n"
        f"X-KDE-PluginInfo-Name={name}\nX-KDE-PluginInfo-Author=leon\nX-KDE-PluginInfo-Version=1\n"
        "X-KDE-PluginInfo-License=GPL\nX-KDE-ServiceTypes=KWin/Decoration\n")
    open(os.path.join(d, f"{name}rc"), "w").write(
        "[General]\n"
        f"ActiveTextColor={c['text']}\nInactiveTextColor={c['text_in']}\n"
        "TitleAlignment=Left\nTitleVerticalAlignment=Center\nAnimation=0\nShadow=false\n"
        "Blur=false\n\n"
        "[Layout]\n"
        f"BorderLeft={B}\nBorderRight={B}\nBorderBottom={B}\n"
        f"TitleEdgeTop={B + 3}\nTitleEdgeBottom=4\nTitleEdgeLeft={B + 6}\nTitleEdgeRight={B + 4}\n"
        f"TitleHeight={TOP - (B + 3) - 4}\nTitleBorderLeft=8\nTitleBorderRight=8\n"
        "ButtonWidth=20\nButtonHeight=20\nButtonSpacing=2\nButtonMarginTop=0\nExplicitButtonSpacer=8\n"
        f"PaddingTop=0\nPaddingLeft=0\nPaddingRight={SH}\nPaddingBottom={SH}\n"
        "TitleEdgeTopMaximized=3\nTitleEdgeBottomMaximized=4\nTitleEdgeLeftMaximized=6\nTitleEdgeRightMaximized=4\n")
    print(f"aurorae theme {name} -> {d}")
