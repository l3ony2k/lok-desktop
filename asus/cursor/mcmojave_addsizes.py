#!/usr/bin/env python3
"""Add larger nominal sizes to the installed McMojave xcursor theme (lok task, 2026-11-15).

McMojave ships nominal 24/30/36/48 (images N*4/3 px: 32/40/48/64). At 1.333 scale any
XCURSOR_SIZE from 32 to 40 lands on the 48 frames, so the cursor cannot grow. This renders
extra nominal sizes from the upstream SVGs (github.com/vinceliuice/McMojave-cursors, src/) with
rsvg-convert and appends them to each installed cursor file; existing frames are kept as is.
  mcmojave_addsizes.py <upstream src dir> <installed cursors dir> <out dir> 54 60
Hotspots scale from the nominal-48 entries of src/config/<name>.cursor.
"""
import os, struct, subprocess, sys

SRC, INST, OUT = sys.argv[1], sys.argv[2], sys.argv[3]
SIZES = [int(s) for s in sys.argv[4:]]
IMG = 0xfffd0002

def read_chunks(path):
    d = open(path, 'rb').read()
    assert d[:4] == b'Xcur', path
    ntoc = struct.unpack('<I', d[12:16])[0]
    chunks = []
    for i in range(ntoc):
        t, sub, pos = struct.unpack('<III', d[16 + 12 * i:28 + 12 * i])
        hsize = struct.unpack('<I', d[pos:pos + 4])[0]
        if t == IMG:
            w, h = struct.unpack('<II', d[pos + 16:pos + 24])
            end = pos + hsize + w * h * 4
        else:  # comment chunk: header 20 + length
            ln = struct.unpack('<I', d[pos + 16:pos + 20])[0]
            end = pos + hsize + ln
        chunks.append((t, sub, d[pos:end]))
    return chunks

def render(svg, px):
    png = subprocess.run(['rsvg-convert', '-w', str(px), '-h', str(px), svg], check=True, capture_output=True).stdout
    raw = subprocess.run(['magick', 'png:-', '-depth', '8', 'RGBA:-'], input=png, check=True, capture_output=True).stdout
    assert len(raw) == px * px * 4, (svg, len(raw))
    out = bytearray(len(raw))
    for i in range(0, len(raw), 4):  # RGBA -> premultiplied ARGB, little endian (B,G,R,A)
        r, g, b, a = raw[i], raw[i + 1], raw[i + 2], raw[i + 3]
        out[i] = b * a // 255; out[i + 1] = g * a // 255; out[i + 2] = r * a // 255; out[i + 3] = a
    return bytes(out)

def image_chunk(nominal, px, xhot, yhot, delay, pixels):
    return struct.pack('<IIIIIIIII', 36, IMG, nominal, 1, px, px, xhot, yhot, delay) + pixels

def write(path, chunks):
    ntoc = len(chunks)
    pos = 16 + 12 * ntoc
    toc, body = b'', b''
    for t, sub, data in chunks:
        toc += struct.pack('<III', t, sub, pos + len(body))
        body += data
    open(path, 'wb').write(struct.pack('<4sIII', b'Xcur', 16, 0x10000, ntoc) + toc + body)

os.makedirs(OUT, exist_ok=True)
done = 0
for cfg in sorted(os.listdir(os.path.join(SRC, 'config'))):
    name = cfg[:-len('.cursor')]
    inst = os.path.join(INST, name)
    if not os.path.isfile(inst) or os.path.islink(inst):
        print('skip (not an installed file):', name); continue
    frames = []
    for line in open(os.path.join(SRC, 'config', cfg)):
        f = line.split()
        if len(f) >= 4 and f[0] == '48':
            frames.append((int(f[1]), int(f[2]), os.path.basename(f[3])[:-4], int(f[4]) if len(f) > 4 else 0))
    assert frames, name
    chunks = [c for c in read_chunks(inst) if not (c[0] == IMG and c[1] in SIZES)]
    for n in SIZES:
        px = n * 4 // 3
        for xh, yh, base, delay in frames:
            pixels = render(os.path.join(SRC, 'svg', base + '.svg'), px)
            chunks.append((IMG, n, image_chunk(n, px, round(xh * n / 48), round(yh * n / 48), delay, pixels)))
    write(os.path.join(OUT, name), chunks)
    done += 1
print(f'{done} cursors written to {OUT} with sizes', SIZES)
