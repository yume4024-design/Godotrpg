"""Deterministic original Project Crystal music and effects. No sampled material."""
from pathlib import Path
import math
import random
import struct
import wave

OUT = Path(__file__).resolve().parents[1] / 'assets/audio/original'
RATE = 22050
OUT.mkdir(parents=True, exist_ok=True)


def write(name, seconds, voices):
    samples = [0.0] * int(seconds * RATE)
    rng = random.Random(619)
    for start, length, frequency, gain, kind in voices:
        for i in range(min(int(length * RATE), len(samples) - int(start * RATE))):
            t = i / RATE
            envelope = min(1.0, t / .012) * min(1.0, (length - t) / .06)
            if kind == 'pluck':
                signal = (math.sin(math.tau * frequency * t) + .22 * math.sin(math.tau * frequency * 2 * t)) * math.exp(-4 * t / length)
            elif kind == 'noise':
                signal = rng.uniform(-1, 1) * math.exp(-10 * t / length)
            else:
                signal = math.sin(math.tau * (frequency * t + 100 * t * t)) * math.exp(-2 * t / length)
            samples[int(start * RATE) + i] += signal * gain * envelope
    peak = max(abs(v) for v in samples)
    scale = min(1.0, .8 / max(peak, .001))
    with wave.open(str(OUT / (name + '.wav')), 'wb') as wav:
        wav.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        wav.writeframes(struct.pack('<' + 'h' * len(samples), *(int(v * scale * 32767) for v in samples)))
    print(f'{name}: {seconds:.2f}s peak={peak * scale:.3f}')


def note(midi):
    return 440 * 2 ** ((midi - 69) / 12)


for name, root, melody in [
    ('village', 60, [0, 4, 7, 12, 9, 7, 4, 2, 5, 9, 7, 4, 2, 4, 7, 2]),
    ('forest', 57, [0, 7, 10, 14, 12, 7, 3, 5, 10, 7, 5, 3, 2, 5, 7, 2]),
    ('mine', 50, [12, 19, 15, 14, 12, 10, 7, 14, 15, 19, 17, 14, 10, 7, 14, 10]),
    ('battle', 57, [0, 7, 12, 10, 7, 3, 5, 7, 12, 15, 14, 10, 7, 5, 3, 7]),
]:
    beat = .375 if name == 'battle' else .75
    duration = 16 * beat
    voices = [(i * beat, beat * .92, note(root + pitch), .22, 'pluck') for i, pitch in enumerate(melody)]
    for i in range(16):
        voices.append((i * beat, beat * .85, note(root - 12 + [0, 7, 3, 7][i % 4]), .12, 'pluck'))
    write(name, duration, voices)

write('confirm', .2, [(0, .18, 740, .32, 'pluck')])
write('hit', .24, [(0, .2, 130, .5, 'noise'), (0, .22, 100, .22, 'sweep')])
write('heal', .65, [(i * .12, .28, note(72 + pitch), .26, 'pluck') for i, pitch in enumerate([0, 4, 7, 12])])
write('guard', .28, [(0, .26, 280, .3, 'pluck'), (.035, .22, 560, .2, 'pluck')])
write('victory', 1.3, [(i * .2, .45, note(67 + pitch), .3, 'pluck') for i, pitch in enumerate([0, 4, 7, 12, 7])])
write('defeat', 1.2, [(i * .25, .4, note(60 - pitch), .26, 'pluck') for i, pitch in enumerate([0, 2, 5, 12])])
write('crystal', 2.7, [(i * .3, .55, note(72 + [0, 7, 12][i % 3]), .24, 'pluck') for i in range(8)])
