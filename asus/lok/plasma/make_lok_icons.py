#!/usr/bin/env python3
"""Build ~/.local/share/icons/lok: a thin user icon theme that only overrides the
places icons and inode-directory mimetype icons whose colour follows the accent (ColorScheme-Accent / -Highlight),
pinning them to a neutral grey. Everything else inherits breeze-plus-dark.

Why: lok's selection colour is a dark grey, and Breeze folders take the accent,
so folders turned dark grey on dark backgrounds. Rerunnable; output is generated.
"""
import os, re, shutil

FOLDER_GREY = "#8a8a8a"
SRC = ["/usr/share/icons/breeze-dark", "/usr/share/icons/breeze-plus-dark"]  # later wins
DST = os.path.expanduser("~/.local/share/icons/lok")
ACCENT = re.compile(r'class="ColorScheme-(Accent|Highlight)"')

if os.path.isdir(DST):
    shutil.rmtree(DST)
os.makedirs(DST)

count = 0
for src in SRC:
    for sub, wanted in (("places", lambda f: True), ("mimetypes", lambda f: f.startswith("inode-directory"))):
      for root, _, files in os.walk(os.path.join(src, sub), followlinks=True):
        for f in files:
            if not (f.endswith(".svg") and wanted(f)):
                continue
            path = os.path.join(root, f)
            try:
                svg = open(path, encoding="utf-8").read()
            except (OSError, UnicodeDecodeError):
                continue
            if not ACCENT.search(svg):
                continue
            svg = ACCENT.sub('class="LokFolder"', svg)
            # own stylesheet (not id=current-color-scheme, which KIconLoader rewrites)
            style = f'<style type="text/css" id="lok-folder">.LokFolder {{ color: {FOLDER_GREY}; }}</style>'
            svg = re.sub(r"(<svg\b[^>]*>)", r"\1" + style, svg, count=1)
            rel = os.path.relpath(path, src)
            out = os.path.join(DST, rel)
            os.makedirs(os.path.dirname(out), exist_ok=True)
            open(out, "w", encoding="utf-8").write(svg)
            count += 1

# index.theme: breeze-dark's directory table, our name and inheritance
idx = open(os.path.join(SRC[0], "index.theme"), encoding="utf-8").read()
idx = re.sub(r"(?m)^Name=.*$", "Name=Lok", idx, count=1)
idx = re.sub(r"(?m)^Comment=.*$", "Comment=breeze-plus-dark with neutral grey folders (generated)", idx, count=1)
idx = re.sub(r"(?m)^Inherits=.*$", "Inherits=breeze-plus-dark,breeze-dark,breeze,hicolor", idx, count=1)
idx = re.sub(r"(?m)^(Name|Comment)\[[^\]]+\]=.*\n", "", idx)
# directories we did not create are harmless, but breeze-plus has @2x dirs breeze-dark lacks
plus_dirs = re.search(r"(?m)^Directories=(.*)$", open(os.path.join(SRC[1], "index.theme")).read()).group(1).split(",")
have = set(re.search(r"(?m)^Directories=(.*)$", idx).group(1).split(","))
extra = [d for d in plus_dirs if d not in have and os.path.isdir(os.path.join(DST, d))]
if extra:
    idx = re.sub(r"(?m)^(Directories=.*)$", lambda m: m.group(1) + "," + ",".join(extra), idx, count=1)
    plus_idx = open(os.path.join(SRC[1], "index.theme")).read()
    for d in extra:
        m = re.search(r"(?ms)^\[" + re.escape(d) + r"\]\n.*?(?=^\[|\Z)", plus_idx)
        if m:
            idx += "\n" + m.group(0)
open(os.path.join(DST, "index.theme"), "w", encoding="utf-8").write(idx)
print(f"lok icons: {count} places/folder icons pinned to {FOLDER_GREY} in {DST}")
