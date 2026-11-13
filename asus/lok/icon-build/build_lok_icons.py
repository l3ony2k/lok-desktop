"""Build "Lok Icons": Tabler Icons glyphs reachable through Material Symbols names.

ii writes icons as Material Symbols ligature names (text: "wifi"). This font adds
GSUB ligatures name -> Tabler glyph, so switching the font family is enough.
Usage: build_lok_icons.py <tabler ttf> <family name> <out ttf>
Tabler Icons: MIT, (c) Paweł Kuna. Mapping: manual-map.py + same-name matches.
"""
import json
import sys

from fontTools.feaLib.builder import addOpenTypeFeaturesFromString
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont

src, family, out = sys.argv[1:4]
exec(open("manual-map.py").read())          # defines M
tab = json.load(open("tabler-map.json"))     # tabler name -> hex codepoint
used = json.load(open("material-used.json"))

font = TTFont(src)
cmap = font.getBestCmap()
order = font.getGlyphOrder()

# Material name -> tabler glyph name
pairs = {}
for name in used:
    t = M.get(name) or name.replace("_", "-")
    cp = int(tab[t], 16)
    pairs[name] = cmap[cp]

# Wi-Fi levels: Tabler's wifi-0/1/2 sit off the full icon's grid, so cut the
# levels out of the full "wifi" glyph itself (contours: dot, arc 1, arc 2, arc 3).
# ii draws the full symbol faintly underneath, so each level reads as "n of 4".
from fontTools.pens.recordingPen import RecordingPen
_glyphset = font.getGlyphSet()
_wifi = pairs.get("signal_wifi_4_bar") or cmap[int(tab["wifi"], 16)]
_rec = RecordingPen()
_glyphset[_wifi].draw(_rec)
_contours, _cur = [], []
for op in _rec.value:
    _cur.append(op)
    if op[0] in ("closePath", "endPath"):
        _contours.append(_cur)
        _cur = []
_contours.sort(key=lambda c: min(pt[1] for o in c for pt in o[1]))  # bottom (dot) first
# Tabler's wifi is only ~563/1000 tall (most icons ~810), so it read a size smaller
# than its neighbours. Scale the whole Wi-Fi family 1.25x about the icon centre;
# every level is cut from the same scaled contours, so they stay aligned.
_S, _CY = 1.25, 400.0
_xs = [pt[0] for c in _contours for o in c for pt in o[1]]
_CX = (min(_xs) + max(_xs)) / 2
_contours = [[(op, tuple((_CX + (x - _CX) * _S, _CY + (y - _CY) * _S) for x, y in args)) for op, args in c] for c in _contours]
_full = TTGlyphPen(None)
for _c in _contours:
    for _op, _args in _c:
        getattr(_full, _op)(*_args)
_fg = _full.glyph(); _fg.recalcBounds(font["glyf"])
font["glyf"]["lokwifi_4"] = _fg
font["hmtx"]["lokwifi_4"] = (font["hmtx"][_wifi][0], _fg.xMin)
for _n in [n for n, g in pairs.items() if g == _wifi]:
    pairs[_n] = "lokwifi_4"
for _name, _keep in (("network_wifi_3_bar", 3), ("network_wifi_2_bar", 2),
                     ("network_wifi_1_bar", 1), ("signal_wifi_0_bar", 0)):
    if _name not in pairs:
        continue
    _pen = TTGlyphPen(None)
    for _c in _contours[:_keep]:
        for _op, _args in _c:
            getattr(_pen, _op)(*_args)
    _g = "lokwifi_%d" % _keep
    _glyph = _pen.glyph()
    _glyph.recalcBounds(font["glyf"])
    font["glyf"][_g] = _glyph
    # lsb must equal this glyph's own xMin or renderers shift it sideways
    _adv, _lsb = font["hmtx"][_wifi]
    font["glyf"][_wifi].recalcBounds(font["glyf"])  # stored bounds are stale (xMin 0)
    _delta = font["glyf"][_wifi].xMin - _lsb   # keep the full glyph's lsb/xMin relation
    font["hmtx"][_g] = (_adv, (_glyph.xMin - _delta) if _keep else 0)
    pairs[_name] = _g

# Drop Tabler's own private-use codepoints. Icons are reached by name only, and a
# PUA cmap entry lets fontconfig fallback pick this font for unrelated Nerd Font
# glyphs (seen while checking the cheatsheet Super keycap, U+F268).
for _t in font["cmap"].tables:
    for _cp in [c for c in _t.cmap if 0xE000 <= c <= 0xF8FF or c >= 0xF0000]:
        del _t.cmap[_cp]

# Blank zero-width glyphs for the characters names are spelled with.
chars = sorted({c for n in pairs for c in n})
glyf = font["glyf"]
hmtx = font["hmtx"]
cmap_tables = [t for t in font["cmap"].tables if t.isUnicode()]
char_glyph = {}
for c in chars:
    gname = "lokchar_%04x" % ord(c)
    pen = TTGlyphPen(None)
    glyf[gname] = pen.glyph()
    hmtx[gname] = (0, 0)
    for t in cmap_tables:
        t.cmap[ord(c)] = gname
    char_glyph[c] = gname
font.setGlyphOrder(glyf.glyphOrder)

# Longest names first so prefixes never win.
rules = []
for name in sorted(pairs, key=len, reverse=True):
    seq = " ".join(char_glyph[c] for c in name)
    rules.append(f"  sub {seq} by {pairs[name]};")
fea = "languagesystem DFLT dflt;\nlanguagesystem latn dflt;\nfeature liga {\n" + "\n".join(rules) + "\n} liga;\n"
addOpenTypeFeaturesFromString(font, fea)

# Tabler ships every glyph with lsb 0 while its outline starts further right;
# renderers place xMin at lsb, so each icon drifted left by its own xMin
# (narrow icons the most). Make lsb match the real outline for every glyph.
for _n in font.getGlyphOrder():
    _gl = font["glyf"][_n]
    if _gl.numberOfContours == 0:
        continue
    _gl.recalcBounds(font["glyf"])
    font["hmtx"][_n] = (font["hmtx"][_n][0], _gl.xMin)

# Rename the family.
for rec in font["name"].names:
    if rec.nameID in (1, 4, 16):
        rec.string = family
    elif rec.nameID == 6:
        rec.string = family.replace(" ", "")
    elif rec.nameID == 3:
        rec.string = family + " (Tabler Icons based)"
font.save(out)
json.dump(sorted(pairs), open("lok-icons-names.json", "w"))
print(f"{out}: {len(pairs)} ligatures, {len(chars)} input chars")
