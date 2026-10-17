#!/usr/bin/env python3
"""Synthesises the app's sounds from scratch, so they are original to this
project. Writes 16-bit mono WAV files to App/Resources/Sounds.

Run from the repository root: python3 scripts/make_sounds.py
The output is deterministic, so re-running gives byte-identical files.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "App", "Resources", "Sounds")


def write(name, samples):
    peak = max(abs(s) for s in samples) or 1.0
    scale = 0.7 * 32767 / peak
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(s * scale)) for s in samples))
    print("wrote", os.path.normpath(path))


def chime(partials, seconds, decay):
    """A soft bell: a few sine partials with an exponential decay and a
    short fade in so it never clicks."""
    n = int(RATE * seconds)
    out = []
    for i in range(n):
        t = i / RATE
        env = math.exp(-t * decay) * min(1.0, t / 0.008)
        out.append(env * sum(a * math.sin(2 * math.pi * f * t) for f, a in partials))
    return out


def creak(seconds):
    """A dry pod creak: a train of short filtered noise clicks whose rate
    slows, like a stiff hinge giving way."""
    rng = random.Random(27)
    n = int(RATE * seconds)
    out = [0.0] * n
    t = 0.0
    while t < seconds - 0.02:
        start = int(t * RATE)
        amp = 0.6 + 0.4 * rng.random()
        prev = 0.0
        for j in range(int(0.006 * RATE)):
            if start + j >= n:
                break
            prev = 0.55 * prev + 0.45 * rng.uniform(-1, 1)  # low pass the noise
            out[start + j] += amp * prev * math.exp(-j / (0.0015 * RATE))
        t += 0.012 + 0.03 * (t / seconds) + 0.004 * rng.random()
    fade = int(0.03 * RATE)
    for i in range(fade):
        out[n - 1 - i] *= i / fade
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    # Yes: bright, rising major third.
    write("chime-yes.wav", [a + b for a, b in zip(
        chime([(880, 1.0), (1760, 0.25), (2640, 0.08)], 0.7, 6.0),
        [0.0] * int(0.09 * RATE) + chime([(1108.7, 0.8), (2217.5, 0.2)], 0.61, 6.0))])
    # Maybe and playful: a single soft, round tone.
    write("chime-maybe.wav", chime([(659.3, 1.0), (1318.5, 0.18)], 0.6, 7.0))
    # No: lower and shorter, with a falling second note.
    write("chime-no.wav", [a + b for a, b in zip(
        chime([(523.3, 1.0), (1046.5, 0.15)], 0.55, 8.0),
        [0.0] * int(0.1 * RATE) + chime([(392.0, 0.9), (784.0, 0.12)], 0.45, 8.0))])
    write("pod-creak.wav", creak(0.35))


if __name__ == "__main__":
    main()
