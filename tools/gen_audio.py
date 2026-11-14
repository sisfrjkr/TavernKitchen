"""Синтез оригинальных звуков: SFX (wav) и петли (ogg). Только numpy/scipy, без внешних сэмплов."""
import os, subprocess, wave
import numpy as np
from scipy.signal import lfilter, butter
SR = 22050
A = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(11)

def t(d): return np.arange(int(SR * d)) / SR
def env(n, a=0.005, r=0.1):
    e = np.ones(n); na = max(1, int(a * SR)); nr = max(1, int(r * SR))
    e[:na] = np.linspace(0, 1, na); e[-nr:] *= np.linspace(1, 0, nr); return e
def sine(f, d, amp=1.0): return np.sin(2 * np.pi * f * t(d)) * amp
def lp(x, fc, o=2): b, a = butter(o, fc / (SR / 2), "low"); return lfilter(b, a, x)
def hp(x, fc, o=2): b, a = butter(o, fc / (SR / 2), "high"); return lfilter(b, a, x)
def bp(x, lo, hi): b, a = butter(2, [lo / (SR / 2), hi / (SR / 2)], "band"); return lfilter(b, a, x)
def norm(x, peak=0.8): m = np.max(np.abs(x)) + 1e-9; return x / m * peak
def wav(path, x):
    x = np.clip(x, -1, 1); d = (x * 32767).astype("<i2")
    with wave.open(path, "wb") as w: w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(d.tobytes())
def ogg(path, x):
    tmp = path + ".tmp.wav"; wav(tmp, x)
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "3", path], check=True); os.remove(tmp)

def pluck(f, d, decay=0.996, bright=0.5):
    n = int(SR * d); N = int(SR / f); x = np.zeros(n); burst = rng.uniform(-1, 1, N) * bright + 0.0
    burst = lp(burst, 3500, 1); x[:N] = burst
    a = np.zeros(N + 2); a[0] = 1; a[N] = -0.5 * decay; a[N + 1] = -0.5 * decay
    return lfilter([1.0], a, x)

def mix(parts, total):
    out = np.zeros(int(SR * total))
    for off, x, g in parts:
        i = int(off * SR); j = min(len(out), i + len(x))
        if i < len(out): out[i:j] += x[:j - i] * g
    return out

def bell(f, d=1.2, g=1.0):
    x = sum(sine(f * m, d, a) for m, a in ((1, 1), (2.76, .5), (5.4, .25), (8.9, .1)))
    return x * np.exp(-t(d) * 4.0) * g

def sfx():
    o = os.path.join(A, "sfx"); os.makedirs(o, exist_ok=True)
    wav(f"{o}/ui_click.wav", norm(sine(520, .07) * np.exp(-t(.07) * 40) + sine(780, .07, .5) * np.exp(-t(.07) * 50), .6))
    n = t(.18); wav(f"{o}/ingredient_select.wav", norm(sine(400 + 500 * n / .18, .18) * np.exp(-n * 18), .6))
    x = rng.normal(0, 1, int(SR * .35)); x = lp(x, 900) * np.exp(-t(.35) * 9); wav(f"{o}/ingredient_drop.wav", norm(x + sine(180, .35) * np.exp(-t(.35) * 14), .8))
    x = hp(rng.normal(0, 1, int(SR * .5)), 600) * np.exp(-t(.5) * 7); wav(f"{o}/splash.wav", norm(lp(x, 5000), .7))
    x = bp(rng.normal(0, 1, int(SR * .7)), 300, 1500) * (np.sin(t(.7) * 2 * np.pi * 3.5) * .4 + .6) * env(int(SR * .7), .1, .2); wav(f"{o}/stir.wav", norm(x, .5))
    wav(f"{o}/order_issued.wav", norm(mix([(0, bell(880, 1.0), 1), (.18, bell(1175, 1.2), .8)], 1.5), .6))
    wav(f"{o}/coin.wav", norm(mix([(0, bell(1760, .5), 1), (.07, bell(2349, .6), .9)], .8), .6))
    notes = [523.25, 659.25, 783.99, 1046.5]
    wav(f"{o}/success.wav", norm(mix([(i * .11, pluck(f, 1.0, .997, .8) * 1.0, 1) for i, f in enumerate(notes)] + [(.45, bell(1568, 1.2), .3)], 1.8), .8))
    wav(f"{o}/reaction_good.wav", norm(mix([(0, pluck(587.33, .8, .996), 1), (.12, pluck(784, .9, .996), 1)], 1.2), .7))
    wav(f"{o}/fail.wav", norm(mix([(0, pluck(293.66, .8, .995), 1), (.16, pluck(246.9, 1.0, .995), 1)], 1.4), .7))
    wav(f"{o}/reaction_bad.wav", norm(mix([(0, pluck(329.6, .7, .995), 1), (.14, pluck(277.2, .9, .995), 1)], 1.2), .6))
    wav(f"{o}/serve.wav", norm(mix([(0, bell(660, .8), .7), (.1, pluck(440, 1.0), 1)], 1.3), .6))
    wav(f"{o}/buy.wav", norm(mix([(0, bell(1320, .5), 1), (.08, bell(1760, .7), 1), (.18, bell(2093, .8), .8)], 1.2), .6))
    wav(f"{o}/lid.wav", norm(lp(rng.normal(0, 1, int(SR * .25)), 1500) * np.exp(-t(.25) * 16) + sine(300, .25) * np.exp(-t(.25) * 20), .5))

def loops():
    # кипение: пузырьки как случайные короткие «бульки»
    d = 6.0; x = np.zeros(int(SR * d))
    for _ in range(90):
        f = rng.uniform(180, 520); n = t(.09); b = sine(f * (1 + n * 6), .09) * np.exp(-n * 45); i = rng.integers(0, len(x) - len(b)); x[i:i + len(b)] += b * rng.uniform(.3, 1)
    x += lp(rng.normal(0, 1, len(x)), 700) * .12
    ogg(f"{A}/sfx/boil_loop.ogg", norm(x, .5))
    # огонь: шум + щелчки
    d = 8.0; n = len(t(d)); x = lp(rng.normal(0, 1, n), 500) * .35 + lp(rng.normal(0, 1, n), 2500) * .08
    for _ in range(60):
        i = rng.integers(0, n - 800); c = hp(rng.normal(0, 1, 600), 1500) * np.exp(-np.arange(600) / 70.0); x[i:i + 600] += c * rng.uniform(.2, .8)
    ogg(f"{A}/sfx/fire_loop.ogg", norm(x, .5))
    # дождь
    x = hp(lp(rng.normal(0, 1, int(SR * 8)), 7000), 900) * .5; ogg(f"{A}/sfx/rain_loop.ogg", norm(x, .35))

def music():
    bpm = 72; beat = 60 / bpm; bars = 16; total = bars * 4 * beat
    prog = [(220.0, [261.63, 329.63, 440.0]), (174.61, [261.63, 349.23, 440.0]), (130.81, [261.63, 329.63, 392.0]), (196.0, [246.94, 293.66, 392.0])]
    parts = []
    for bar in range(bars):
        root, chord = prog[bar % 4]; t0 = bar * 4 * beat
        pat = [0, 1, 2, 1, 2, 1, 0, 1]
        for k, idx in enumerate(pat):
            f = chord[idx] * (2 if k % 4 == 3 else 1)
            parts.append((t0 + k * beat / 2, pluck(f, 1.6, .9965, .7), .55 if k % 2 == 0 else .38))
        parts.append((t0, pluck(root / 2, 3.0, .9985, .5), .8))
        if bar % 4 == 2:
            mel = [chord[2] * 2, chord[1] * 2, chord[0] * 2]
            for j, f in enumerate(mel): parts.append((t0 + (1 + j) * beat * 1.0, pluck(f, 1.8, .997, .6), .45))
    x = mix(parts, total + 3.0)
    pad = np.zeros_like(x)
    for bar in range(bars):
        root, chord = prog[bar % 4]; i = int(bar * 4 * beat * SR); d = 4 * beat + 0.5; n = int(d * SR)
        seg = sum(np.sin(2 * np.pi * f * t(d)) for f in (root, chord[0] * .5)) * np.minimum(1, np.minimum(np.arange(n) / (SR * .8), (n - np.arange(n)) / (SR * .8)))
        j = min(len(pad), i + n); pad[i:j] += seg[:j - i] * .05
    x += pad
    L = int(total * SR); head = x[:L].copy(); tail = x[L:L + int(3 * SR)]
    head[:len(tail)] += tail  # хвост «закольцовываем» для бесшовной петли
    ogg(f"{A}/music_tavern.ogg", norm(lp(head, 5500, 1), .7))

if __name__ == "__main__":
    os.makedirs(A, exist_ok=True); sfx(); loops(); music()
    for r, _, fs in os.walk(A):
        for f in fs: print(os.path.join(r, f).split("audio")[1], os.path.getsize(os.path.join(r, f)) // 1024, "KB")
