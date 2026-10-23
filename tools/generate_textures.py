"""Regenerates the soft-light textures used by the game (glow, shadow, grain,
vignette, scanlines). Pure zlib/struct PNG writer - no PIL required.
Run from anywhere:  python3 tools/generate_textures.py
"""
import zlib, struct, math, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "res", "textures")
os.makedirs(OUT, exist_ok=True)

def write_png(path, w, h, pixels):
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for x in range(w):
            r, g, b, a = pixels[y * w + x]
            raw += bytes((r, g, b, a))

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)
    return os.path.getsize(path)

def clamp(v, a=0.0, b=1.0):
    return a if v < a else (b if v > b else v)

def glow(size=128, power=2.2):
    px = []
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - c, y - c) / c
            a = clamp(1.0 - d) ** power
            px.append((255, 255, 255, int(a * 255)))
    return size, size, px

def shadow(size=128):
    px = []
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            dx = (x - c) / c
            dy = (y - c) / c
            d = math.sqrt(dx * dx + (dy * 2.4) ** 2)
            a = clamp(1.0 - d) ** 1.6
            px.append((0, 0, 0, int(a * 200)))
    return size, size, px

def vignette(w=320, h=180):
    px = []
    for y in range(h):
        for x in range(w):
            dx = (x - w / 2) / (w / 2)
            dy = (y - h / 2) / (h / 2)
            d = math.sqrt(dx * dx + dy * dy) / 1.4142
            a = clamp((d - 0.45) / 0.55) ** 1.4
            px.append((4, 6, 16, int(a * 235)))
    return w, h, px

def grain(size=256):
    import random
    random.seed(7)
    px = []
    for i in range(size * size):
        v = random.randint(0, 255)
        px.append((v, v, v, 26))
    return size, size, px

def scanline(w=256, h=256):
    px = []
    for y in range(h):
        a = 18 if y % 3 == 0 else 0
        for x in range(w):
            px.append((0, 0, 0, a))
    return w, h, px

for name, fn in [
    ("glow.png", lambda: glow(128, 2.0)),
    ("glow_sharp.png", lambda: glow(64, 1.2)),
    ("shadow.png", lambda: shadow(128)),
    ("vignette.png", lambda: vignette(320, 180)),
    ("grain.png", lambda: grain(256)),
    ("scanline.png", lambda: scanline(64, 64)),
]:
    w, h, px = fn()
    size = write_png(os.path.join(OUT, name), w, h, px)
    print(f"{name:16s} {w}x{h} {size/1024:.1f} KB")
