"""Generate original short AAMIX musical cues with Python's standard library.

No samples or recordings are used. Existing audio is never replaced.
"""
from pathlib import Path
import array
import json
import math
import wave

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "audio"


def tone_track(seconds, notes):
    samples = [0.0] * round(seconds * RATE)
    for start, length, midi, level in notes:
        frequency = 440.0 * 2.0 ** ((midi - 69) / 12.0)
        for i in range(round(length * RATE)):
            index = round(start * RATE) + i
            if index >= len(samples):
                break
            t = i / RATE
            # Soft plucked bell; smooth attack/release avoid boundary clicks.
            attack = min(1.0, t / 0.012)
            release = min(1.0, max(0.0, length - t) / 0.08)
            envelope = attack * release * math.exp(-t * 3.8 / length)
            partials = (
                math.sin(math.tau * frequency * t)
                + 0.24 * math.sin(math.tau * frequency * 2.0 * t) * math.exp(-t * 3.0)
                + 0.10 * math.sin(math.tau * frequency * 3.0 * t) * math.exp(-t * 7.0)
            )
            samples[index] += partials * envelope * level
    peak = max(abs(v) for v in samples) or 1.0
    scale = min(1.0, 0.66 / peak)
    samples = [v * scale for v in samples]
    return samples


CUES = {
    "regalo": (1.35, [(0, .55, 72, .28), (.14, .6, 76, .28), (.28, .65, 79, .28), (.48, .8, 84, .26)]),
    "regalo_recibido": (1.7, [(0, .6, 67, .24), (.13, .6, 72, .24), (.26, .6, 76, .24), (.42, 1.1, 79, .28), (.46, 1.1, 84, .23), (.46, 1.1, 72, .18)]),
    "victoria": (2.25, [(0, .4, 67, .25), (.2, .4, 72, .25), (.4, .4, 76, .25), (.6, .5, 79, .27), (.9, 1.2, 84, .26), (.9, 1.2, 76, .20), (.9, 1.2, 72, .20), (.9, 1.2, 60, .20)]),
    "derrota": (1.9, [(0, .65, 72, .26), (.32, .65, 68, .25), (.64, 1.1, 63, .26), (.64, 1.1, 60, .17), (.64, 1.1, 56, .17)]),
    "turno": (.5, [(0, .25, 72, .18), (.12, .35, 79, .20)]),
    "sobre_abrir": (.95, [(0, .35, 55, .14), (.08, .35, 62, .16), (.16, .4, 67, .18), (.26, .55, 74, .21), (.35, .55, 86, .18)]),
    "sobre_carta": (.42, [(0, .22, 79, .17), (.08, .3, 84, .15)]),
}


def main():
    OUT.mkdir(exist_ok=True)
    metadata = {}
    for name, (duration, notes) in CUES.items():
        samples = tone_track(duration, notes)
        pcm = array.array("h", (round(v * 32767) for v in samples))
        with wave.open(str(OUT / f"{name}.wav"), "wb") as target:
            target.setnchannels(1)
            target.setsampwidth(2)
            target.setframerate(RATE)
            target.writeframes(pcm.tobytes())
        metadata[name] = {
            "seconds": duration,
            "peak": round(max(abs(v) for v in samples), 4),
            "rms": round(math.sqrt(sum(v * v for v in samples) / len(samples)), 4),
            "origin": "Original AAMIX synthesized tones; no external samples",
        }
    (OUT / "METADATOS_MOMENTOS.json").write_text(json.dumps(metadata, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {len(metadata)} original musical cues.")


if __name__ == "__main__":
    main()
