"""Regenerates every sound effect and music loop in res/audio.

Pure standard-library synthesis (no numpy, no external samples).
Run from anywhere:  python3 tools/generate_audio.py
"""
import math, random, struct, wave, os

random.seed(20240517)
SR = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "res", "audio")
os.makedirs(OUT, exist_ok=True)

def env(t, dur, a=0.01, d=0.3, s=0.0, r=0.2):
    """simple ADSR-ish envelope, t and dur in seconds"""
    if t < a:
        return t / a
    if t < a + d:
        return 1.0 - (1.0 - s) * ((t - a) / d)
    if t < dur - r:
        return s
    return max(0.0, s * (1.0 - (t - (dur - r)) / max(1e-5, r)))

def sine(f, t, phase=0.0):
    return math.sin(2 * math.pi * f * t + phase)

def saw(f, t):
    x = (f * t) % 1.0
    return 2.0 * x - 1.0

def square(f, t, duty=0.5):
    return 1.0 if (f * t) % 1.0 < duty else -1.0

def tri(f, t):
    x = (f * t) % 1.0
    return 4.0 * abs(x - 0.5) - 1.0

def noise():
    return random.uniform(-1, 1)

def render(dur, fn, sr=SR):
    n = int(dur * sr)
    out = []
    for i in range(n):
        t = i / sr
        out.append(max(-1.0, min(1.0, fn(t, i))))
    return out

def write_wav(name, samples, sr=SR):
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        frames = bytearray()
        for s in samples:
            frames += struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32000))
        w.writeframes(bytes(frames))
    return path

def tone(f0, f1, dur, shape="sine", vol=0.5, decay=3.0, delay=0.0):
    def fn(t, i):
        if t < delay:
            return 0.0
        tt = t - delay
        if tt > dur:
            return 0.0
        f = f0 * (f1 / f0) ** (tt / dur) if f1 != f0 else f0
        e = math.exp(-decay * tt) * (1 - math.exp(-80 * tt))
        if shape == "sine":
            v = sine(f, tt)
        elif shape == "saw":
            v = saw(f, tt)
        elif shape == "square":
            v = square(f, tt)
        elif shape == "tri":
            v = tri(f, tt)
        else:
            v = noise()
        return v * e * vol
    return fn

def mix(*fns):
    return lambda t, i: sum(f(t, i) for f in fns)

def noise_burst(dur, vol=0.4, damp=18.0, lowpass=0.0, delay=0.0):
    state = {"y": 0.0}
    def fn(t, i):
        if t < delay or t > delay + dur:
            return 0.0
        tt = t - delay
        n = noise()
        if lowpass > 0:
            state["y"] += (n - state["y"]) * lowpass
            n = state["y"]
        return n * math.exp(-damp * tt) * vol
    return fn

# ---------------- SFX ----------------
sfx = {}
sfx["ui.wav"] = render(0.09, mix(tone(720, 940, 0.09, "tri", 0.22, 28)))
sfx["select.wav"] = render(0.16, mix(tone(420, 760, 0.16, "tri", 0.3, 16)))
sfx["swing.wav"] = render(0.16, mix(noise_burst(0.16, 0.34, 26, 0.55), tone(340, 150, 0.14, "saw", 0.10, 22)))
sfx["hit.wav"] = render(0.17, mix(tone(170, 62, 0.17, "square", 0.30, 16), noise_burst(0.12, 0.30, 30, 0.32)))
sfx["crit.wav"] = render(0.28, mix(tone(260, 70, 0.24, "square", 0.32, 13), noise_burst(0.2, 0.32, 22, 0.3), tone(980, 320, 0.1, "tri", 0.14, 26, 0.01)))
sfx["shoot.wav"] = render(0.2, mix(tone(820, 190, 0.2, "sine", 0.30, 15), noise_burst(0.06, 0.12, 60, 0.7)))
sfx["special.wav"] = render(0.75, mix(tone(190, 940, 0.45, "saw", 0.22, 4.0), noise_burst(0.45, 0.28, 6.0, 0.25), tone(110, 44, 0.75, "sine", 0.30, 3.2)))
sfx["dash.wav"] = render(0.25, mix(noise_burst(0.22, 0.26, 12, 0.35), tone(520, 1550, 0.18, "sine", 0.14, 12)))
sfx["jump.wav"] = render(0.18, mix(tone(300, 640, 0.18, "sine", 0.22, 18)))
sfx["hurt.wav"] = render(0.34, mix(tone(220, 74, 0.3, "saw", 0.32, 9.0), noise_burst(0.24, 0.22, 12, 0.25)))
sfx["pickup.wav"] = render(0.2, mix(tone(880, 1320, 0.09, "sine", 0.24, 20), tone(1320, 1780, 0.12, "sine", 0.16, 18, 0.06)))
sfx["core.wav"] = render(0.3, mix(tone(520, 800, 0.14, "tri", 0.26, 14), tone(790, 1080, 0.2, "tri", 0.2, 12, 0.08)))
sfx["awaken.wav"] = render(1.5, mix(*[
    tone(f, f * 1.5, 1.1, "sine", 0.12, 2.0, i * 0.085) for i, f in enumerate([262, 330, 392, 523, 659, 784])
] + [tone(66, 130, 1.4, "saw", 0.18, 1.6), noise_burst(0.9, 0.10, 3.0, 0.2)]))
sfx["boss.wav"] = render(1.7, mix(tone(58, 40, 1.6, "saw", 0.30, 1.4), tone(88, 55, 1.2, "sine", 0.22, 1.6, 0.1), noise_burst(1.2, 0.10, 2.4, 0.18)))
sfx["boss_hit.wav"] = render(0.24, mix(tone(112, 48, 0.24, "square", 0.26, 13), noise_burst(0.2, 0.26, 17, 0.35)))
sfx["phase.wav"] = render(1.2, mix(tone(70, 180, 1.05, "saw", 0.30, 2.2), tone(430, 90, 0.8, "sine", 0.16, 2.6, 0.15), noise_burst(0.7, 0.18, 3.4, 0.2)))
sfx["gameover.wav"] = render(1.8, mix(*[tone(f, f * 0.9, 0.6, "tri", 0.18, 3.0, i * 0.18) for i, f in enumerate([392, 330, 262, 196])] + [tone(98, 60, 1.5, "sine", 0.22, 2.0, 0.2)]))
sfx["victory.wav"] = render(2.1, mix(*[tone(f, f, 0.85, "sine", 0.14, 2.2, i * 0.115) for i, f in enumerate([262, 330, 392, 523, 659, 784, 1046])] + [tone(131, 262, 2.0, "tri", 0.18, 1.4)]))
sfx["stage.wav"] = render(0.8, mix(tone(196, 392, 0.6, "sine", 0.22, 3.0), tone(392, 587, 0.5, "tri", 0.12, 3.2, 0.12)))
sfx["warning.wav"] = render(0.3, mix(tone(880, 660, 0.12, "square", 0.16, 14), tone(660, 440, 0.14, "square", 0.14, 12, 0.14)))
sfx["explode.wav"] = render(0.5, mix(noise_burst(0.45, 0.34, 7.0, 0.2), tone(92, 38, 0.4, "saw", 0.22, 6.0)))
sfx["orb.wav"] = render(0.22, mix(tone(300, 620, 0.2, "sine", 0.2, 12)))

for name, samples in sfx.items():
    write_wav(name, samples)

# ---------------- MUSIC LOOPS ----------------
def pad_loop(root, scale, bpm, bars, brightness=0.5, drone=True):
    sr = 16000
    beat = 60.0 / bpm
    dur = beat * 4 * bars
    n = int(dur * sr)
    out = [0.0] * n
    step = beat / 2.0
    idx = 0
    t = 0.0
    while t < dur - 0.05:
        deg = scale[idx % len(scale)]
        octv = 12 if (idx // len(scale)) % 2 == 1 else 0
        freq = 440.0 * 2 ** ((root + deg + octv - 69) / 12.0)
        length = step * (2.6 if idx % 4 == 0 else 1.9)
        start = int(t * sr)
        ln = int(length * sr)
        for k in range(min(ln, n - start)):
            tt = k / sr
            e = math.exp(-2.2 * tt / length) * (1 - math.exp(-90 * tt))
            v = sine(freq, tt) * 0.16 + sine(freq * 2, tt) * 0.05 * brightness
            out[start + k] += v * e * 0.5
        idx += 1
        t += step
    if drone:
        bass = 440.0 * 2 ** ((root - 24 - 69) / 12.0)
        for i in range(n):
            tt = i / sr
            swell = 0.5 + 0.5 * math.sin(2 * math.pi * tt / dur - math.pi / 2)
            out[i] += sine(bass, tt) * 0.10 * (0.5 + 0.5 * swell)
    # loop-safe fade at both ends
    fade = int(0.06 * sr)
    for i in range(fade):
        g = i / fade
        out[i] *= g
        out[n - 1 - i] *= g
    return out, sr

music_specs = {
    "music_title.wav": (57, [0, 3, 5, 7, 10, 12, 7, 3], 62, 4, 0.7),
    "music_campus.wav": (55, [0, 2, 3, 7, 9, 12, 9, 7], 70, 4, 0.5),
    "music_rift.wav": (53, [0, 3, 5, 6, 10, 12, 6, 5], 66, 4, 0.4),
    "music_boss.wav": (50, [0, 1, 5, 6, 8, 12, 8, 6], 84, 4, 0.35),
    "music_victory.wav": (60, [0, 2, 4, 7, 9, 12, 9, 7], 72, 4, 0.8),
}
for name, (root, scale, bpm, bars, bright) in music_specs.items():
    samples, sr = pad_loop(root, scale, bpm, bars, bright)
    write_wav(name, samples, sr)

print(f"wrote {len(os.listdir(OUT))} files to {OUT}")
total = 0
for f in sorted(os.listdir(OUT)):
    sz = os.path.getsize(os.path.join(OUT, f))
    total += sz
    print(f"{f:22s} {sz/1024:8.1f} KB")
print("TOTAL", round(total / 1024 / 1024, 2), "MB")
