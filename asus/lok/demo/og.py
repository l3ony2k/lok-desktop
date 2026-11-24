"""GitHub social preview (1280x640) for lok-desktop, from shoot.sh's raw dark-right.png."""
from PIL import Image, ImageDraw, ImageFont
import sys
# usage: og.py <raw shots dir> <font dir with IoskeleyMonoTermNerdFont-{Medium,Regular}.ttf> <out.png>
RAW, FONTS, OUT = sys.argv[1].rstrip("/") + "/", sys.argv[2].rstrip("/") + "/", sys.argv[3]
W, H = 1280, 640
BG, FRAME, TEXT, SUB, DIM = "#121212", "#3d3d3d", "#ededed", "#8f8f8f", "#5e5e5e"
fM = lambda s: ImageFont.truetype(FONTS + "IoskeleyMonoTermNerdFont-Medium.ttf", s)
fR = lambda s: ImageFont.truetype(FONTS + "IoskeleyMonoTermNerdFont-Regular.ttf", s)
c = Image.new("RGB", (W, H), BG); d = ImageDraw.Draw(c)
# right: the desktop, cropped to the top-left two thirds so the bar and windows stay readable
hw, hh = 640, 524
hero = Image.open(RAW + "dark-right.png").convert("RGB").crop((1160, 0, 2560, 1146)).resize((hw, hh), Image.LANCZOS)
x0, y0 = W - hw - 56, (H - hh) // 2
c.paste(hero, (x0, y0)); d.rectangle([x0 - 1, y0 - 1, x0 + hw, y0 + hh], outline=FRAME)
# left: title block
L = 64
d.text((L, 150), "lok-desktop", font=fM(58), fill=TEXT)
# privacy dots as the only colour: 2x2 squares
for i, col in enumerate(["#ff9f0a", "#30d158", "#0a84ff", "#bf5af2"]):
    x, y = L + (i % 2) * 18, 238 + (i // 2) * 18
    d.rectangle([x, y, x + 11, y + 11], fill=col)
d.text((L + 48, 237), "greyscale · square · 1 px", font=fR(20), fill=SUB)
lines = ["A rice of end-4's", "illogical-impulse:", "Hyprland + Quickshell", "on Arch, on an ASUS", "Chromebook."]
for i, t in enumerate(lines): d.text((L, 296 + i * 30), t, font=fR(20), fill=SUB)
d.line([(L, 460), (L + 420, 460)], fill=FRAME, width=1)
d.text((L, 478), "github.com/l3ony2k/lok-desktop", font=fR(18), fill=DIM)
c.save(OUT, optimize=True); print("ok")
