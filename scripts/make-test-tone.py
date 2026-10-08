"""Create a low-amplitude, 50-second stereo test tone without third-party packages.

Usage: python3 scripts/make-test-tone.py work/test-tone.wav
Creates an explicit test fixture; does not play audio.
"""
import math
from pathlib import Path
import struct
import sys
import wave

if len(sys.argv) != 2:
    raise SystemExit(__doc__)
output = Path(sys.argv[1])
output.parent.mkdir(parents=True, exist_ok=True)
rate = 48000
second = bytearray()
for frame in range(rate):
    sample = round(0.02 * 32767 * math.sin(math.tau * 440 * frame / rate))
    second.extend(struct.pack("<hh", sample, sample))
with wave.open(str(output), "wb") as writer:
    writer.setnchannels(2)
    writer.setsampwidth(2)
    writer.setframerate(rate)
    for _ in range(50):
        writer.writeframesraw(second)
print(output)
