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
