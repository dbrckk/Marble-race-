#!/usr/bin/env python3
"""Synthesize the three seamless, original bridge rolling loops."""
import subprocess
from pathlib import Path

import numpy as np


SAMPLE_RATE = 32000
DURATION = 2.0
FRAMES = int(SAMPLE_RATE * DURATION)
TIME = np.arange(FRAMES) / SAMPLE_RATE
OUTPUT = Path(__file__).resolve().parents[1] / "assets/audio/sfx"


def band(rng, low, high):
    frequencies = np.fft.rfftfreq(FRAMES, 1 / SAMPLE_RATE)
    spectrum = np.fft.rfft(rng.standard_normal(FRAMES))
    response = 1 / ((1 + (low / np.maximum(1, frequencies))**6)
                    * (1 + (frequencies / high)**6))
    signal = np.fft.irfft(spectrum * response)
    return signal / signal.std()


def joints(rate, decay, resonances):
    age = np.mod(TIME * rate, 1.0) / rate
    envelope = np.minimum(1.0, age * 850) * np.exp(-age * decay)
    return envelope * sum(weight * np.sin(2 * np.pi * hz * age)
                          for hz, weight in resonances)


def encode(name, signal):
    signal *= 0.028 / np.sqrt(np.mean(signal**2))
    pcm = np.clip(signal * 32767, -32767, 32767).astype("<i2")
    subprocess.run(
        ["ffmpeg", "-loglevel", "error", "-y", "-f", "s16le",
         "-ar", str(SAMPLE_RATE), "-ac", "1", "-i", "pipe:0",
         "-c:a", "libvorbis", "-q:a", "3", str(OUTPUT / name)],
        input=pcm.tobytes(), check=True,
    )


def main():
    rng = np.random.default_rng(1252026)
    wood = band(rng, 140, 520) * 0.65 + band(rng, 750, 1850) * 0.12
    wood += joints(8, 76, [(232, 1.50), (589, 0.32)])
    ice = band(rng, 1350, 5200) * 0.67 + band(rng, 290, 1100) * 0.23
    ice *= 0.85 + 0.15 * np.sin(2 * np.pi * 3 * TIME)
    ice += joints(5.5, 115, [(1430, 0.36), (2587, 0.22)])
    steel = band(rng, 180, 900) * 0.60 + band(rng, 1300, 3600) * 0.15
    steel += joints(12, 66, [(387, 0.95), (911, 0.75), (1967, 0.38)])
    encode("bridge_timber_roll.ogg", wood)
    encode("bridge_ice_roll.ogg", ice)
    encode("bridge_steel_roll.ogg", steel)


if __name__ == "__main__":
    main()
