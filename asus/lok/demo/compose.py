"""Compose the README images from shoot.sh's raw 2560x1600 shots.
Usage: python3 compose.py <raw dir> <out dir> [label font .ttf]  (needs Pillow)."""
import os
from PIL import Image, ImageChops, ImageDraw, ImageFont
import sys
S = sys.argv[1].rstrip("/") + "/"   # raw shots (shoot.sh writes ~/.cache/lokdemo/out)
OUT = sys.argv[2].rstrip("/") + "/"; os.makedirs(OUT, exist_ok=True)
FONT = sys.argv[3] if len(sys.argv) > 3 else "/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf"
def im(n): return Image.open(S + n + ".png").convert("RGB")
def save(img, name, w=None, q=88):
    if w and img.width > w: img = img.resize((w, round(img.height * w / img.width)), Image.LANCZOS)
    img.save(OUT + name, "WEBP", quality=q, method=6); print(f"{name:28s} {img.size} {os.path.getsize(OUT+name)//1024} KB")
def popup_bbox(shot, base="t-desktop6", pad=28):
    a, b = im(shot), im(base)
    d = ImageChops.difference(a, b).convert("L").point(lambda v: 255 if v > 40 else 0)
    dr = ImageDraw.Draw(d)
    dr.rectangle([0, 0, 2560, 56], fill=0)          # bar numbers / clock
    dr.rectangle([0, 820, 2560, 1600], fill=0)      # btop
    dr.rectangle([0, 470, 1050, 600], fill=0)       # fastfetch uptime / date
    x0, y0, x1, y1 = d.getbbox()
    return a.crop((max(0, x0 - pad), 0, min(2560, x1 + pad), min(1600, y1 + pad)))
def frame(img, col="#4a4a4a"):
    ImageDraw.Draw(img).rectangle([0, 0, img.width - 1, img.height - 1], outline=col); return img
def collage(tiles, cols, bg="#0d0d0d", gap=36, label_col="#8f8f8f", h=None):
    font = ImageFont.truetype(FONT, 22)
    rows = [tiles[i:i + cols] for i in range(0, len(tiles), cols)]
    rh = [max(t[0].height for t in r) + 44 for r in rows]
    W = gap + max(sum(t[0].width + gap for t in r) for r in rows); H = gap + sum(r + gap for r in rh)
    c = Image.new("RGB", (W, H), bg); dr = ImageDraw.Draw(c); y = gap
    for r, hh in zip(rows, rh):
        x = gap
        for t, lab in r:
            c.paste(frame(t.copy()), (x, y)); dr.text((x, y + t.height + 12), lab, font=font, fill=label_col); x += t.width + gap
        y += hh + gap
    return c

# 1 hero
save(im("dark-desktop"), "hero-dark.webp", 1920)
# 2 dark / light diagonal split
d, l = im("dark-desktop2"), im("light-desktop"); W, H = d.size
m = Image.new("L", (W, H), 0); ImageDraw.Draw(m).polygon([(W*.62, 0), (W, 0), (W, H), (W*.38, H)], fill=255)
sp = Image.composite(l, d, m); ImageDraw.Draw(sp).line([(W*.62, 0), (W*.38, H)], fill="#8c8c8c", width=2)
save(sp, "dark-light.webp", 1920)
# 3 sidebars: dark + light, left + right
L = lambda n: im(n).crop((0, 54, 606, 1600)); R = lambda n: im(n).crop((1962, 54, 2560, 1600))
save(collage([(L("dark-left"), "left · dashboard"), (L("light-left"), "left · light"),
              (R("dark-right"), "right · toggles, notifications, calendar"), (R("light-right"), "right · light")], 4), "sidebars.webp", 1920)
# 4 detail modal + caffeine dialog
save(collage([(L("dark-left-detail"), "dashboard card → detail dialog"), (R("dark-caffeine"), "right-click a tile → its dialog (Caffeine)")], 2), "dialogs.webp", 1600)
# 5 bar popups
pops = [("dark-pop-privacy", "privacy dots"), ("dark-pop-monitor", "resources"),
        ("dark-pop-battery", "battery & power mode"), ("dark-pop-weather", "weather"), ("dark-pop-clock", "clock"),
        ("dark-pop-media", "media"), ("light-pop-privacy", "privacy · light"), ("light-pop-monitor", "resources · light")]
tiles = []
for n, lab in pops:
    t = popup_bbox(n, "t-desktop6" if n.startswith("dark") else "light-desktop"); tiles.append((t, lab))
save(collage(tiles, 4), "bar-popups.webp", 1920)
# 6 colour pick
save(im("dark-colorpick").crop((1500, 0, 2560, 900)), "color-pick.webp", 1400)
# 7 search, notification, OSD, session
s = im("dark-search").crop((760, 40, 1760, 560)); nt = im("dark-notif").crop((2020, 54, 2560, 200))
o = im("dark-osd").crop((1040, 50, 1520, 150)); se = im("dark-session").crop((640, 300, 1920, 1300))
save(collage([(s, "search · Super+Space"), (se, "session"), (nt, "notification"), (o, "volume OSD")], 2), "launcher-osd-session.webp", 1920)
# 8 vertical bar
save(im("dark-vertical"), "vertical-bar.webp", 1920)
# 9 window gaps
g = [im(f"dark-gaps-{m}").resize((853, 533), Image.LANCZOS) for m in ("none", "small", "large")]
save(collage([(g[0], "gaps: none (single shared border)"), (g[1], "small"), (g[2], "large")], 3), "window-gaps.webp", 1920)
