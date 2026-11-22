#!/usr/bin/env python3
"""Synthesize Catch's sounds (numpy -> wav -> ogg via oggenc). Re-run to regenerate Catch/Sounds/*.ogg.

Cozy and ambient (user, 2026-11-21: "really cozy and ambient fishing vibes … fishing before rest"): quiet, warm,
low-passed, soft attacks, long tails. Three cues per slot (bobber lands, waiting, bite window) and two ambience
loops that play while you fish. 2026-11-21 second pass: louder over WoW's own ambience, and the bite cue from
natural models (plucked string, kalimba, water drop) instead of sine bells ("too artificial").
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "Catch", "Sounds")
rng = np.random.default_rng(11)


def t(seconds):
    return np.arange(int(SR * seconds)) / SR


def lowpass(x, cutoff):
    """one-pole low-pass, run twice (12 dB/oct) — warm, no ringing"""
    a = np.exp(-2 * np.pi * cutoff / SR)
    for _ in range(2):
        y = np.empty_like(x)
        acc = 0.0
        for i, v in enumerate(x):
            acc = (1 - a) * v + a * acc
            y[i] = acc
        x = y
    return x


def env(n, attack, decay):
    e = np.exp(-np.arange(n) / (SR * decay))
    a = int(SR * attack)
    if a:
        e[:a] *= np.sin(np.linspace(0, np.pi / 2, a)) ** 2      # soft, no click
    return e


def place(total, parts):
    out = np.zeros(int(SR * total))
    for start, sig in parts:
        i = int(SR * start)
        j = min(len(out), i + len(sig))
        out[i:j] += sig[: j - i]
    return out


def sweep(f0, f1, length, tau):
    tt = t(length)
    freq = f1 + (f0 - f1) * np.exp(-tt / tau)
    return np.sin(2 * np.pi * np.cumsum(freq) / SR)


def plop(level=1.0, f0=420, f1=140):
    s = sweep(f0, f1, 0.5, 0.04) * env(int(SR * 0.5), 0.008, 0.09)
    s += lowpass(rng.standard_normal(len(s)), 400) * env(len(s), 0.01, 0.06) * 0.6
    return s * level


def bubble(f0=200, f1=520, length=0.14, level=1.0):
    tt = t(length)
    freq = f0 + (f1 - f0) * (tt / length) ** 1.6
    return np.sin(2 * np.pi * np.cumsum(freq) / SR) * env(len(tt), 0.012, 0.05) * level


def soft_click(level=1.0):
    n = int(SR * 0.06)
    s = lowpass(rng.standard_normal(n), 900) * env(n, 0.003, 0.012)
    s += np.sin(2 * np.pi * 520 * np.arange(n) / SR) * env(n, 0.003, 0.015) * 0.5
    return s * level


def bell(freq, length=2.4, level=1.0, attack=0.025):
    tt = t(length)
    partials = [(1.0, 1.0, 1.1), (2.0, 0.22, 0.6), (2.76, 0.08, 0.35)]
    return sum(a * np.sin(2 * np.pi * freq * r * tt) * env(len(tt), attack, d) for r, a, d in partials) * level


def hum(freq=110, length=2.6, level=1.0):
    """a warm fel hum: root + fifth + octave, slow swell, slight beating"""
    tt = t(length)
    s = (np.sin(2 * np.pi * freq * tt) + 0.5 * np.sin(2 * np.pi * freq * 1.5 * tt + 0.3)
         + 0.25 * np.sin(2 * np.pi * (freq * 2 + 0.7) * tt))
    shape = np.sin(np.pi * np.linspace(0, 1, len(tt))) ** 1.5
    return s * shape * level


def pluck(freq, length=2.6, damping=0.996, brightness=900, level=1.0):
    """Karplus-Strong plucked string: a burst of soft noise circulating in a delay line — a natural, warm pluck"""
    n = int(SR * length)
    period = int(SR / freq)
    buf = lowpass(rng.standard_normal(period), brightness)
    out = np.zeros(n)
    prev = 0.0
    for i in range(n):
        j = i % period
        v = buf[j]
        out[i] = v
        buf[j] = damping * 0.5 * (v + prev)
        prev = v
    out *= env(n, 0.004, length * 0.45)
    return lowpass(out, 2200) * level


def kalimba(freq, length=2.2, level=1.0):
    """a thumb-piano tine: soft attack, fundamental + a quickly dying inharmonic partial, a little wood knock"""
    tt = t(length)
    detune = 1 + 0.002 * rng.standard_normal()
    s = np.sin(2 * np.pi * freq * detune * tt) * env(len(tt), 0.006, 0.7)
    s += 0.25 * np.sin(2 * np.pi * freq * 5.4 * tt) * env(len(tt), 0.004, 0.06)
    s += lowpass(rng.standard_normal(len(tt)), 600) * env(len(tt), 0.002, 0.01) * 0.3
    return lowpass(s, 2600) * level


def drop(level=1.0, f0=700, f1=1400):
    """a single water drop: a short rising resonance and a tiny splash"""
    tt = t(0.6)
    freq = f0 + (f1 - f0) * (1 - np.exp(-tt / 0.02))
    s = np.sin(2 * np.pi * np.cumsum(freq) / SR) * env(len(tt), 0.002, 0.045)
    s += lowpass(rng.standard_normal(len(tt)), 1200) * env(len(tt), 0.001, 0.02) * 0.25
    return lowpass(s, 2400) * level


def water(length, cutoff=260, wave_every=(3.5, 6.0), depth=0.8):
    n = int(SR * length)
    s = lowpass(rng.standard_normal(n), cutoff)
    # slow swells: small waves against the jetty
    swell = np.zeros(n)
    pos = 0.0
    while pos < length:
        w = rng.uniform(*wave_every)
        i, j = int(SR * pos), min(n, int(SR * (pos + w)))
        swell[i:j] = np.sin(np.pi * np.linspace(0, 1, j - i)) ** 2 * rng.uniform(0.6, 1.0)
        pos += w * rng.uniform(0.55, 0.8)
    return s * (1 - depth + depth * swell)


def loop(signal, fade=1.5):
    """make a seamless loop: crossfade the tail into the head"""
    f = int(SR * fade)
    head, tail = signal[:f], signal[-f:]
    ramp = np.linspace(0, 1, f)
    signal = signal[:-f].copy()
    signal[:f] = tail * (1 - ramp) + head * ramp
    return signal


def write(name, signal, peak_db, fade_out=0.05):
    signal = signal / (np.max(np.abs(signal)) or 1) * (10 ** (peak_db / 20))
    fo = int(SR * fade_out)
    if fo:
        signal[-fo:] *= np.linspace(1, 0, fo)
    pcm = (np.clip(signal, -1, 1) * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as d:
        wav = os.path.join(d, name + ".wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        subprocess.run(["oggenc", "-Q", "-q", "4", "-o", os.path.join(OUT, name + ".ogg"), wav], check=True)
    print(f"{name}.ogg  {len(pcm) / SR:.1f}s  peak {peak_db} dB")


os.makedirs(OUT, exist_ok=True)

# --- bobber lands: a soft sign the line is in the water (audible over WoW's own ambience) ---
write("lands_plop", place(1.0, [(0, plop()), (0.35, bubble(level=0.3)), (0.55, bubble(240, 480, 0.12, 0.18))]), -13, 0.3)
gaps = np.cumsum(np.linspace(0.06, 0.12, 7))
write("lands_reel", place(1.1, [(s, soft_click(1.0 - 0.1 * k)) for k, s in enumerate(gaps - gaps[0])]), -16, 0.2)
write("lands_drop", place(1.4, [(0, plop(0.8, 300, 110)), (0.5, bubble(170, 380, 0.2, 0.25))]), -13, 0.3)

# --- while waiting: quiet, but there ------------------------------------------------------
write("wait_lap", water(2.2, 220, (1.6, 2.0), 0.9), -22, 0.4)
write("wait_bubbles", place(0.9, [(0, bubble(160, 400, 0.18)), (0.32, bubble(210, 460, 0.15, 0.6))]), -22, 0.2)
write("wait_breath", lowpass(rng.standard_normal(int(SR * 2.0)), 160) * np.sin(np.pi * np.linspace(0, 1, int(SR * 2.0))) ** 3, -24, 0.3)

# --- bite window: natural, gentle "get ready" ---------------------------------------------
write("window_pluck", place(3.0, [(0, pluck(196.0)), (0.28, pluck(293.7, level=0.7))]), -17, 0.6)   # G3 then D4
write("window_kalimba", place(2.6, [(0, kalimba(392.0)), (0.22, kalimba(523.3, level=0.6))]), -18, 0.5)
write("window_drop", place(1.2, [(0, drop()), (0.42, drop(0.45, 620, 1150))]), -18, 0.3)
write("window_fel", hum(110, 2.6), -18, 0.4)

# --- ambience loops while you fish -----------------------------------------------------------
L = 24.0
lake = water(L + 1.5, 300, (3.5, 6.0), 0.75)
for start in rng.uniform(0, L, 6):                                   # a few distant bubbles
    lake += place(L + 1.5, [(start, bubble(150, 360, 0.2, 0.08))])
write("ambience_lake", loop(lake), -16, 0)
tt = t(L + 1.5)
drone = (np.sin(2 * np.pi * 55 * tt) + 0.6 * np.sin(2 * np.pi * 82.4 * tt + 1) + 0.3 * np.sin(2 * np.pi * 110.4 * tt))
drone *= 0.75 + 0.25 * np.sin(2 * np.pi * tt / 8.0)                 # slow breathing
dusk = lowpass(drone, 300) * 0.5 + water(L + 1.5, 260, (4.0, 7.0), 0.7)
write("ambience_dusk", loop(dusk), -16, 0)

# --- a catch: a small splash and a warm note; a rare or valuable catch: a gentle rising kalimba ----------
write("catch_soft", place(1.8, [(0, drop(0.5, 520, 980)), (0.12, kalimba(523.3, 1.6, 0.55))]), -19, 0.4)   # C5
write("catch_rare", place(3.2, [(0, drop(0.45, 520, 980)), (0.10, kalimba(392.0, 2.2, 0.7)),
                                (0.26, kalimba(493.9, 2.2, 0.6)), (0.42, kalimba(587.3, 2.4, 0.55)),
                                (0.62, kalimba(784.0, 2.6, 0.45))]), -17, 0.6)                           # G4 B4 D5 G5
