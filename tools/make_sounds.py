"""Regenerate the game's deterministic, quiet retro sound effects (stdlib only)."""
import wave
import struct
import math
import random

RATE = 44100
SOUNDS = {
    'card_play': [900, 400], 'card_draw': [700], 'buy': [880, 1175, 1760],
    'reserve': [660, 880], 'damage': [140, 85], 'life_gain': [523, 659, 784],
    'hack': [1400, 2100], 'turn_start': [350, 440, 697, 1209],
    'your_turn': [440, 660, 880, 660], 'eliminated': [330, 220, 110],
    'warning': [660, 440, 660],
    'button': [1000], 'win': [523, 659, 784, 1046],
    'lose': [523, 440, 349, 262], 'shuffle': [280, 380, 260], 'ice': [1760, 2349],
}

def main():
    rng = random.Random(47)
    for name, notes in SOUNDS.items():
        step = .14 if name in ('win', 'lose') else .065
        samples = []
        for frequency in notes:
            for i in range(int(RATE * step)):
                t = i / RATE
                envelope = min(1, t / .004) * (1 - t / step) ** 2
                tone = math.sin(2 * math.pi * frequency * t)
                tone += .22 * math.sin(2 * math.pi * frequency * 2 * t)
                if name in ('shuffle', 'card_play', 'damage'):
                    tone = .55 * tone + .45 * rng.uniform(-1, 1)
                samples.append(tone * envelope)
        peak = max(abs(x) for x in samples)
        with wave.open('assets/sounds/' + name + '.wav', 'wb') as output:
            output.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
            output.writeframes(b''.join(struct.pack('<h', int(x / peak * 8000)) for x in samples))

if __name__ == '__main__':
    main()
