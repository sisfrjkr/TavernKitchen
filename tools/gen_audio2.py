"""Звуковая атмосфера таверны: ambience, голоса посетителей, окружение, музыкальные темы. Синтез numpy/scipy (оригинальные звуки).
Голоса — формантный синтез («гул разговоров», смех, вздохи): они задуманы как заменяемые заглушки-атмосфера, живые записи лучше."""
import os, math
import numpy as np
from scipy.signal import butter, sosfilt, lfilter
from gen_audio import SR, wav, ogg, norm, lp, hp, bp, pluck, mix, bell, sine, env, t as T_, rng

A = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
FORM = {"a": (800, 1150, 2900), "e": (420, 2000, 2800), "o": (450, 800, 2830), "i": (270, 2140, 2950), "u": (325, 700, 2700), "m": (250, 900, 2200)}

def band(x, fc, bw):
    lo, hi = max(40, fc - bw / 2), min(SR / 2 - 100, fc + bw / 2)
    return sosfilt(butter(2, [lo / (SR / 2), hi / (SR / 2)], "band", output="sos"), x)

def voice(f0, dur, vowel="a", glide=(1.0, 1.0), vib=0.02, breath=0.12, gain=1.0):
    n = int(dur * SR); t = np.arange(n) / SR
    f = f0 * np.linspace(glide[0], glide[1], n) * (1 + vib * np.sin(2 * np.pi * 5.3 * t))
    ph = np.cumsum(f) / SR
    src = (np.mod(ph, 1.0) * 2 - 1) * 0.6 + rng.normal(0, 1, n) * breath
    out = np.zeros(n)
    for fc, amp, bw in zip(FORM[vowel], (1.0, 0.6, 0.3), (110, 160, 250)):
        out += band(src, fc, bw) * amp
    a = np.minimum(1, t / 0.03) * np.minimum(1, (dur - t) / 0.06)
    return out * a * gain

def babble(dur, voices=3, level=1.0, seed=0):
    r = np.random.default_rng(seed); out = np.zeros(int(dur * SR))
    for v in range(voices):
        f0 = float(r.choice([105, 120, 135, 190, 215])); pos = float(r.uniform(0, 0.4))
        while pos < dur - 0.3:
            d = float(r.uniform(0.09, 0.26)); vw = str(r.choice(list("aeoiu")))
            g = (float(r.uniform(0.4, 1.0)))
            seg = voice(f0 * float(r.uniform(0.9, 1.15)), d, vw, (1.0, float(r.uniform(0.9, 1.12))), 0.01, 0.2, g)
            i = int(pos * SR); out[i:i + len(seg)] += seg[:len(out) - i]
            pos += d + float(r.uniform(0.02, 0.28)) + (float(r.uniform(0.4, 1.4)) if r.random() < 0.12 else 0)
    return lp(out, 3800) * level

def make_loop(x, fade=1.5):
    n = int(fade * SR); body = x[:-n].copy()
    body[:n] = body[:n] * np.linspace(0, 1, n) + x[-n:] * np.linspace(1, 0, n)
    return body

def voices():
    o = os.path.join(A, "crowd"); os.makedirs(o, exist_ok=True)
    for i in range(1, 5): wav(f"{o}/murmur_{i}.wav", norm(babble(2.4 + i * 0.3, 2 + i % 2, seed=i) * env(int((2.4 + i * 0.3) * SR), 0.25, 0.4), 0.5))
    for i, f0 in enumerate((115, 180, 140), 1):
        parts = []
        for k in range(6):
            h = voice(f0 * (1 - 0.04 * k), 0.1, "a", (1.05, 0.9), 0.0, 0.6, 1.0 - k * 0.1)
            parts.append((k * (0.15 + 0.01 * i), h, 1.0))
        wav(f"{o}/laugh_{i}.wav", norm(mix(parts, 1.3) * 1.0, 0.6))
    for i, f0 in enumerate((130, 200), 1):
        w = voice(f0, 0.45, "o", (0.85, 1.35), 0.01, 0.2) + hp(rng.normal(0, 1, int(0.45 * SR)), 1500) * 0.08 * np.linspace(1, 0, int(0.45 * SR))
        wav(f"{o}/gasp_{i}.wav", norm(w, 0.55))
    for i, f0 in enumerate((125, 175), 1):
        w = voice(f0, 0.55, "o", (1.0, 1.3), 0.02, 0.1) * 1.0
        w2 = voice(f0 * 1.2, 0.35, "a", (1.1, 0.95), 0.02, 0.1)
        wav(f"{o}/approve_{i}.wav", norm(mix([(0, w, 1), (0.5, w2, 0.9)], 1.0), 0.6))
    for i, f0 in enumerate((95, 110), 1):
        w = voice(f0, 0.7, "m", (1.1, 0.8), 0.015, 0.05)
        w2 = voice(f0 * 0.9, 0.35, "u", (1.0, 0.85), 0.01, 0.1)
        wav(f"{o}/grumble_{i}.wav", norm(mix([(0, w, 1), (0.6, w2, 0.7)], 1.1), 0.55))
    for i in range(1, 4):
        n = int(0.5 * SR); tt = np.arange(n) / SR
        x = (np.sin(2 * np.pi * (2400 + 500 * i) * tt) * np.exp(-tt * 38) + np.sin(2 * np.pi * (3500 + 300 * i) * tt) * np.exp(-tt * 55) * 0.6)
        x += lp(rng.normal(0, 1, n), 700) * np.exp(-tt * 60) * 1.4
        wav(f"{o}/mug_clink_{i}.wav", norm(x, 0.6))

def environment():
    o = os.path.join(A, "env"); os.makedirs(o, exist_ok=True)
    for i in range(1, 4):
        n = int(0.7 * SR); tt = np.arange(n) / SR
        x = lp(rng.normal(0, 1, n), 1200 + 300 * i) * np.exp(-tt * 18) * 1.5 + sine(150 + 20 * i, 0.7) * np.exp(-tt * 22) * 0.5
        wav(f"{o}/dish_{i}.wav", norm(hp(x, 300) + 0.0, 0.6))
    for i in range(1, 3):
        n = int((0.7 + 0.15 * i) * SR); tt = np.arange(n) / SR
        stick = (np.sin(2 * np.pi * 14 * tt) > 0.2).astype(float) * 0.6 + 0.4
        x = bp(rng.normal(0, 1, n), 180 + 90 * i, 900) * stick * np.minimum(1, tt / 0.05) * np.minimum(1, (tt[-1] - tt) / 0.1)
        wav(f"{o}/chair_{i}.wav", norm(x, 0.5))
    for i in range(1, 4):
        parts = []
        for k in range(4):
            n = int(0.12 * SR); tt = np.arange(n) / SR
            step = lp(rng.normal(0, 1, n), 420 + 60 * i) * np.exp(-tt * 45) + sine(80 + 10 * (k % 2), 0.12) * np.exp(-tt * 40) * 0.5
            parts.append((k * (0.42 + 0.03 * i), step, 1.0))
        wav(f"{o}/steps_{i}.wav", norm(mix(parts, 1.9), 0.6))
    for i in range(1, 3):
        d = 1.0 + 0.4 * i; n = int(d * SR); tt = np.arange(n) / SR
        f = 210 + 90 * np.sin(np.pi * tt / d) * (1 if i == 1 else -0.5) + 30 * i
        ph = np.cumsum(f) / SR
        x = (np.mod(ph, 1) * 2 - 1) * 0.5
        x = band(x, 520, 300) * 1.2 + band(rng.normal(0, 1, n), 700, 500) * 0.15
        x *= np.minimum(1, tt / 0.1) * np.minimum(1, (d - tt) / 0.25) * (0.7 + 0.3 * np.sin(2 * np.pi * 7 * tt))
        wav(f"{o}/door_creak_{i}.wav", norm(x, 0.5))
    n = int(1.3 * SR); tt = np.arange(n) / SR
    cr = band((np.mod(np.cumsum(180 + 120 * tt) / SR, 1) * 2 - 1) * 0.5, 480, 300) * np.minimum(1, tt / 0.1) * np.exp(-tt * 1.2)
    th = lp(rng.normal(0, 1, n), 300) * np.exp(-np.maximum(0, tt - 0.9) * 0) * ((tt > 0.95) & (tt < 1.1)) * 1.5
    wav(f"{o}/chest_open.wav", norm(cr + th, 0.55))
    for i in range(1, 4):
        n = int(0.09 * SR); tt = np.arange(n) / SR
        wav(f"{o}/bubble_pop_{i}.wav", norm(np.sin(2 * np.pi * np.cumsum(520 - 3800 * tt * (0.8 + 0.2 * i)) / SR) * np.exp(-tt * 55), 0.5))
    # ветер и гул зала — петли
    x = bp(rng.normal(0, 1, int(14 * SR)), 140, 900); tt = np.arange(len(x)) / SR
    x *= 0.55 + 0.45 * np.sin(2 * np.pi * tt / 7.0 + 1.0) * np.sin(2 * np.pi * tt / 3.1)
    ogg(f"{o}/wind_loop.ogg", norm(make_loop(x, 2.0), 0.4))
    L = 30.0; n = int(L * SR)
    bed = np.zeros(n)
    for s in range(4): bed += babble(L, 2, 1.0, seed=100 + s)[:n] * 0.45
    bed += lp(rng.normal(0, 1, n), 220) * 0.12 + lp(rng.normal(0, 1, n), 90) * 0.15
    for _ in range(14):
        k = int(rng.uniform(0, L - 1) * SR); cl = np.sin(2 * np.pi * rng.uniform(2200, 3800) * np.arange(int(0.25 * SR)) / SR) * np.exp(-np.arange(int(0.25 * SR)) / SR * 40) * rng.uniform(0.04, 0.12)
        bed[k:k + len(cl)] += cl
    for _ in range(8):
        k = int(rng.uniform(0, L - 1) * SR); th = lp(rng.normal(0, 1, int(0.15 * SR)), 600) * np.exp(-np.arange(int(0.15 * SR)) / SR * 30) * 0.2
        bed[k:k + len(th)] += th
    bed = lp(bed, 3500)
    ogg(f"{o}/tavern_room.ogg", norm(make_loop(np.concatenate([bed, bed[:int(2 * SR)]]), 2.0)[:int(28 * SR)], 0.5))

def compose(name, bpm, bars, prog, style):
    beat = 60 / bpm; total = bars * 4 * beat; parts = []
    for bar in range(bars):
        root, chord = prog[bar % len(prog)]; t0 = bar * 4 * beat
        if style == "menu":
            for k, idx in enumerate([0, 2, 1, 2, 0, 1, 2, 1]):
                f = chord[idx] * (2 if k % 4 == 3 else 1)
                parts.append((t0 + k * beat / 2, bell(f * 2, 1.4, 0.35) if k % 2 == 0 else pluck(f, 1.6, 0.9965, 0.7), 0.5 if k % 2 == 0 else 0.4))
            parts.append((t0, pluck(root / 2, 3.2, 0.9985, 0.5), 0.8))
        elif style == "event":
            for k in range(8):
                f = chord[[0, 1, 2, 1, 0, 2, 1, 2][k]] * (2 if k % 4 == 2 else 1)
                parts.append((t0 + k * beat / 2, pluck(f, 0.9, 0.994, 0.9), 0.55 if k % 2 == 0 else 0.4))
            parts.append((t0, pluck(root / 2, 1.6, 0.997, 0.5), 0.8)); parts.append((t0 + 2 * beat, pluck(root / 2 * 1.5, 1.2, 0.996, 0.5), 0.6))
            for b in range(4):  # мягкий «барабан»
                th = lp(rng.normal(0, 1, int(0.12 * SR)), 260) * np.exp(-np.arange(int(0.12 * SR)) / SR * 28)
                parts.append((t0 + b * beat, th, 0.5 if b % 2 == 0 else 0.3))
            if bar % 2 == 1: parts.append((t0 + 3 * beat, bell(chord[2] * 4, 0.8, 0.3), 0.5))
        else:  # evening
            if bar % 2 == 0:
                for j, idx in enumerate([0, 1, 2]): parts.append((t0 + j * beat * 1.3, pluck(chord[idx], 3.0, 0.998, 0.5), 0.5))
            parts.append((t0, pluck(root / 2, 4.5, 0.9988, 0.4), 0.7))
    x = mix(parts, total + 4.0)
    pad = np.zeros_like(x)
    for bar in range(bars):
        root, chord = prog[bar % len(prog)]; i = int(bar * 4 * beat * SR); d = 4 * beat + 0.8; n = int(d * SR)
        seg = sum(np.sin(2 * np.pi * f * np.arange(n) / SR) for f in (root, chord[0] * .5, chord[1] * .5)) * np.minimum(1, np.minimum(np.arange(n) / (SR * 1.0), (n - np.arange(n)) / (SR * 1.0)))
        j = min(len(pad), i + n); pad[i:j] += seg[:j - i] * (0.07 if style == "evening" else 0.04)
    x += pad
    L = int(total * SR); head = x[:L].copy(); tail = x[L:L + int(4 * SR)]; head[:len(tail)] += tail
    ogg(os.path.join(A, "music", name + ".ogg"), norm(lp(head, 3800 if style == "evening" else 5500, 1), 0.7))

def music():
    os.makedirs(os.path.join(A, "music"), exist_ok=True)
    compose("menu_theme", 66, 16, [(146.83, [293.66, 349.23, 440.0]), (116.54, [233.08, 293.66, 349.23]), (174.61, [261.63, 349.23, 440.0]), (130.81, [261.63, 329.63, 392.0])], "menu")
    compose("event_lively", 112, 16, [(130.81, [261.63, 329.63, 392.0]), (196.0, [293.66, 392.0, 493.88]), (220.0, [261.63, 329.63, 440.0]), (174.61, [261.63, 349.23, 440.0])], "event")
    compose("evening", 54, 12, [(110.0, [220.0, 261.63, 329.63]), (146.83, [220.0, 293.66, 349.23]), (87.31, [174.61, 220.0, 261.63]), (98.0, [196.0, 246.94, 293.66])], "evening")

if __name__ == "__main__":
    voices(); environment(); music()
    for r, _, fs in os.walk(A):
        for f in sorted(fs): pass
    tot = sum(os.path.getsize(os.path.join(r, f)) for r, _, fs in os.walk(A) for f in fs)
    print("аудио всего:", tot // 1024, "КБ")
