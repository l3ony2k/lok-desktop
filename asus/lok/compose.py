"""Compose README demo images from raw/ shots (2560x1600 physical px)."""
from PIL import Image, ImageDraw, ImageFont
R = "raw/"; OUT = "out/"
import os; os.makedirs(OUT, exist_ok=True)
font = ImageFont.truetype("font-label.ttf", 26)
def im(n): return Image.open(R + n).convert("RGB")
def frame(img, col):
    d = ImageDraw.Draw(img); w, h = img.size; d.rectangle([0, 0, w - 1, h - 1], outline=col); return img
def save(img, name, w=None):
    if w: img = img.resize((w, round(img.height * w / img.width)), Image.LANCZOS)
    img.save(OUT + name, "WEBP", quality=90, method=6); print(name, img.size, os.path.getsize(OUT + name) // 1024, "KB")

# 1. hero: dark desktop + right sidebar
save(im("dark-sidebar.png"), "hero-dark.webp", 1920)

# 2. dark / light diagonal split of the same desktop
d, l = im("dark-desktop.png"), im("light-desktop.png")
W, H = d.size
mask = Image.new("L", (W, H), 0); md = ImageDraw.Draw(mask)
md.polygon([(W * 0.62, 0), (W, 0), (W, H), (W * 0.38, H)], fill=255)
split = Image.composite(l, d, mask)
ImageDraw.Draw(split).line([(W * 0.62, 0), (W * 0.38, H)], fill="#8c8c8c", width=2)
save(split, "dark-light.webp", 1920)

# 3. details collage on the dot wallpaper
bg = im("lok-dots-dark.png").resize((2560, 1640))
c = bg.copy(); dr = ImageDraw.Draw(c)
def label(x, y, t): dr.text((x, y), t, font=font, fill="#8f8f8f")
def paste(tile, x, y, t, col="#5e5e5e"):
    c.paste(frame(tile, col), (x, y)); label(x, y + tile.height + 12, t)
M = 80
# bar strips (dark and light), full width scaled to the canvas inner width
bw = 2560 - 2 * M
bd = im("dark-desktop.png").crop((0, 0, 2560, 54)).resize((bw, round(54 * bw / 2560)), Image.LANCZOS)
bl = im("light-desktop.png").crop((0, 0, 2560, 54)).resize((bw, round(54 * bw / 2560)), Image.LANCZOS)
paste(bd, M, M, "bar  -  workspaces | clock | monitor + net, power mode + battery, weather, status")
paste(bl, M, M + bd.height + 70, "bar  -  light", "#8c8c8c")
top = M + 2 * (bd.height + 70) + 20
launch = im("dark-launcher.png").crop((919, 66, 1641, 554))
side = im("dark-sidebar.png").crop((1960, 64, 2549, 790))
sess = im("light-session.png").crop((900, 520, 1660, 1160))
mon = im("light-monitor.png").crop((1822, 64, 2408, 214))
osd = im("dark-osd.png").crop((1093, 64, 1467, 130))
x = M; paste(launch, x, top, "launcher  -  Super tap, frecency, lok icons")
x2 = x + launch.width + 60; paste(side, x2, top, "quick toggles  -  selected = raised fill + edge + strip")
x3 = x2 + side.width + 60; paste(sess, x3, top, "session  -  light mode", "#8c8c8c")
y2 = top + launch.height + 80
paste(mon, x, y2, "resource popup  -  light", "#8c8c8c")
paste(osd, x, y2 + mon.height + 80, "OSD  -  one row, hairline frame")
c = c.crop((0, 0, 2560, max(top + side.height, y2 + mon.height + 80 + osd.height) + M + 40))
save(c, "details.webp", 1920)
