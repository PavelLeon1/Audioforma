"""Создаёт локальные WAV-файлы для проверки частотных диапазонов."""

from __future__ import annotations

import math
import struct
import wave
from pathlib import Path


OUTPUT = Path(__file__).resolve().parents[1] / "tests" / "fixtures"
SAMPLE_RATE = 44_100
DURATION_SECONDS = 2
FREQUENCIES = (80, 800, 5_000)


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for frequency in FREQUENCIES:
        data = bytearray()
        for index in range(SAMPLE_RATE * DURATION_SECONDS):
            time = index / SAMPLE_RATE
            fade = min(1.0, time / 0.05, (DURATION_SECONDS - time) / 0.05)
            sample = math.sin(math.tau * frequency * time) * 0.5 * max(fade, 0.0)
            data.extend(struct.pack("<h", round(sample * 32_767)))

        path = OUTPUT / f"{frequency}.wav"
        with wave.open(str(path), "wb") as result:
            result.setnchannels(1)
            result.setsampwidth(2)
            result.setframerate(SAMPLE_RATE)
            result.writeframes(data)
        print(path)


if __name__ == "__main__":
    main()
