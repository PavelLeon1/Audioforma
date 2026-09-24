"""Создаёт короткий собственный WAV-фрагмент для демонстрации проекта."""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path


SAMPLE_RATE = 22_050
DURATION = 24
OUTPUT = Path(__file__).resolve().parents[1] / "assets" / "audio" / "demo.wav"


def sample_at(time: float, noise: float) -> float:
    beat_phase = time % 0.5
    kick_phase = 56 * beat_phase + 34 * (1 - math.exp(-18 * beat_phase)) / 18
    kick = math.sin(math.tau * kick_phase) * math.exp(-15 * beat_phase)

    section = min(int(time // 6), 3)
    chord = 0.0
    if section >= 1:
        chord_envelope = 0.64 + 0.36 * math.sin(math.tau * 0.5 * time) ** 2
        chord = chord_envelope * (
            math.sin(math.tau * 220 * time) * 0.17
            + math.sin(math.tau * 277.18 * time) * 0.10
            + math.sin(math.tau * 329.63 * time) * 0.08
        )

    hi_hat = 0.0
    if section >= 2:
        hat_phase = time % 0.25
        hi_hat = noise * math.exp(-65 * hat_phase) * 0.13

    bass = 0.34 * kick + 0.12 * math.sin(math.tau * 110 * time)
    if section == 3:
        bass += 0.06 * math.sin(math.tau * 82.41 * time)

    fade = min(1.0, time / 0.4, (DURATION - time) / 0.5)
    return (bass + chord + hi_hat) * max(0.0, fade)


def main() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    random_source = random.Random(20260924)
    data = bytearray()
    for index in range(SAMPLE_RATE * DURATION):
        time = index / SAMPLE_RATE
        value = sample_at(time, random_source.uniform(-1.0, 1.0))
        value = max(-1.0, min(1.0, value))
        data.extend(struct.pack("<h", round(value * 30_000)))

    with wave.open(str(OUTPUT), "wb") as result:
        result.setnchannels(1)
        result.setsampwidth(2)
        result.setframerate(SAMPLE_RATE)
        result.writeframes(data)

    print(f"Создано: {OUTPUT} ({DURATION} с, {SAMPLE_RATE} Гц)")


if __name__ == "__main__":
    main()
