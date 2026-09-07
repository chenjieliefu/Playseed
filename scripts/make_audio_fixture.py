"""Original deterministic test signals; no external recordings, model or samples."""
import argparse
import io
import math
from pathlib import Path
import random
import struct
import wave

RATE = 22050


def encode(samples):
    out = io.BytesIO()
    with wave.open(out, 'wb') as writer:
        writer.setnchannels(1); writer.setsampwidth(2); writer.setframerate(RATE)
        writer.writeframes(b''.join(struct.pack('<h', round(max(-1, min(1, x)) * 32767)) for x in samples))
    return out.getvalue()


def signals():
    randomizer = random.Random(831)
    result = {}
    for name, seconds, start, end in [('开火', .12, 420, 130), ('命中', .18, 180, 70), ('升级', .45, 440, 880), ('胜利', .8, 523, 1046), ('失败', .65, 350, 100)]:
        values = []
        for i in range(int(RATE * seconds)):
            t = i / RATE
            envelope = min(1, t / .01) * (1 - t / seconds) ** 2
            phase = 2 * math.pi * (start * t + (end - start) * t * t / (2 * seconds))
            value = math.sin(phase)
            if name == '命中': value = .4 * value + .6 * randomizer.uniform(-1, 1)
            values.append(.23 * envelope * value)
        result[name] = encode(values)
    notes = [60, 64, 67, 64, 62, 65, 69, 65, 59, 62, 67, 62, 60, 64, 67, 72]
    beat = .46875
    melody = []
    for i in range(int(RATE * beat * len(notes))):
        t = i / RATE
        index = min(int(t / beat), len(notes) - 1)
        local = t - index * beat
        frequency = 440 * 2 ** ((notes[index] - 69) / 12)
        env = min(1, local / .02) * max(0, 1 - local / beat) ** 2
        melody.append(.13 * env * (math.sin(2 * math.pi * frequency * local) + .25 * math.sin(4 * math.pi * frequency * local)))
    result['海岛节拍'] = encode(melody)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=True)
    for name, data in signals().items():
        with (args.output / (name + '.wav')).open('xb') as f: f.write(data)
