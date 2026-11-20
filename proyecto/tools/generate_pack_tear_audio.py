"""Generate an original short foil/paper tearing effect, with no external samples."""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np

OUT = Path(__file__).resolve().parents[1] / 'audio'
RATE = 44100
DURATION = 0.82
SEED = 130018

def main():
    rng = np.random.default_rng(SEED)
    count = round(RATE * DURATION)
    time = np.arange(count) / RATE
    noise = rng.normal(0, 1, count)
    # A dry, mid/high-frequency rustle, pulsing irregularly like foil being torn.
    smooth = np.convolve(noise, np.ones(3) / 3, mode='same')
    body = smooth - np.convolve(smooth, np.ones(39) / 39, mode='same')
    envelope = np.zeros(count)
    for center, width, gain in [(0.055, .024, .45), (.13, .034, .8), (.24, .05, 1), (.35, .033, .75), (.46, .035, .65), (.59, .052, .38), (.70, .025, .19)]:
        envelope += gain * np.exp(-.5 * ((time - center) / width) ** 2)
    signal = body * envelope
    # Brief irregular crackles give the opening a tactile edge instead of a chord.
    for start in [.04, .10, .155, .21, .266, .31, .367, .429, .48, .55, .63]:
        index = round(start * RATE)
        length = round(rng.uniform(.003, .009) * RATE)
        tail = np.arange(length) / RATE
        burst = rng.normal(0, 1, length) * np.exp(-tail * 650)
        signal[index:index + length] += burst * .18
    signal *= np.minimum(time / .008, 1) * np.minimum((DURATION - time) / .065, 1)
    signal *= .49 / max(float(np.max(np.abs(signal))), .0001)
    pcm = np.round(signal * 32767).astype('<i2')
    path = OUT / 'sobre_rasgar.wav'
    with wave.open(str(path), 'wb') as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(pcm.tobytes())
    data = {'file': path.name, 'logical_effect': 'sobre_abrir', 'seconds': DURATION, 'sample_rate': RATE, 'channels': 1, 'peak': round(float(np.max(np.abs(signal))), 4), 'rms': round(float(np.sqrt(np.mean(signal ** 2))), 4), 'origin': 'Original AAMIX synthesized foil/paper tear; no external samples', 'generator': 'tools/generate_pack_tear_audio.py', 'seed': SEED, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
    (OUT / 'METADATOS_APERTURA_v0.13.0.json').write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf8')
    print(json.dumps(data, ensure_ascii=False))

if __name__ == '__main__':
    main()
