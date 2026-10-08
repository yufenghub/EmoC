"""Generate quiet, short PCM fixtures for emulator playback checks."""
import math
import struct
import wave
from pathlib import Path

output = Path(__file__).resolve().parents[1] / "build" / "playback-fixtures"
output.mkdir(parents=True, exist_ok=True)
rate = 22050
for name, frequency in [("EmoC-QA-A", 220), ("EmoC-QA-B", 330)]:
    with wave.open(str(output / f"{name}.wav"), "wb") as stream:
        stream.setparams((1, 2, rate, 0, "NONE", "not compressed"))
        samples = [int(1000 * math.sin(2 * math.pi * frequency * i / rate))
                   for i in range(rate * 12)]
        stream.writeframes(struct.pack(f"<{len(samples)}h", *samples))
print(output)
