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

def music_loop():
    # All oscillators fit the 32-second cycle; crossfade chord gates at each boundary.
    rate, duration = 22050, 32
    chords = [(110, 130.8128, 164.8138), (87.3071, 110, 130.8128),
              (97.9989, 123.4708, 146.8324), (82.4069, 97.9989, 123.4708)]
    samples = []
    def oscillator(hz, t):
        return math.sin(2 * math.pi * round(hz * duration) / duration * t)
    for i in range(rate * duration):
        t = i / rate
        value = 0.0
        for j, chord in enumerate(chords):
            distance = ((t - (j * 8 + 4) + 16) % 32) - 16
            gate = max(0, min(1, (5 - abs(distance))))
            value += gate * sum(oscillator(hz, t) + .2 * oscillator(hz * 2, t) for hz in chord) * .035
        phase = t % 2
        chord = chords[int(t // 8)]
        value += .065 * oscillator(chord[0] / 2, t) * math.sin(math.pi * phase / 2) ** 2
        blip_phase = t % 1
        value += .028 * oscillator(chord[int(t) % 3] * 4, t) * math.exp(-blip_phase * 12) * min(1, blip_phase * 100)
        samples.append(int(max(-1, min(1, value)) * 32767))
    with wave.open('assets/sounds/music_loop.wav', 'wb') as output:
        output.setparams((1, 2, rate, 0, 'NONE', 'not compressed'))
        output.writeframes(struct.pack('<%dh' % len(samples), *samples))
    import shutil, subprocess, os
    if shutil.which('ffmpeg'):
        subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', 'assets/sounds/music_loop.wav', '-c:a', 'libvorbis', '-b:a', '64k', 'assets/sounds/music_loop.ogg'], check=True)
        os.remove('assets/sounds/music_loop.wav')
    elif shutil.which('oggenc'):
        subprocess.run(['oggenc', '-b', '64', '-o', 'assets/sounds/music_loop.ogg', 'assets/sounds/music_loop.wav'], check=True)
        os.remove('assets/sounds/music_loop.wav')

if __name__ == '__main__':
    main()
    music_loop()
