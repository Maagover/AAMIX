"""Original AAMIX menu loop and movement sounds. Requires NumPy; no samples.

Run with Python 3 from any directory. The game uses the included WAV files and
does not need Python. A fixed seed makes the source assets reproducible.
"""
from pathlib import Path
import json
import wave
import numpy as np

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / "audio"
RNG = np.random.default_rng(4017)
REPORT = {}


def write(name, data, peak=0.72):
    data = np.asarray(data, dtype=float)
    data -= data.mean(axis=0)
    data *= peak / max(float(np.max(np.abs(data))), 0.00001)
    pcm = np.rint(data * 32767).astype("<i2")
    with wave.open(str(OUT / (name + ".wav")), "wb") as file:
        file.setnchannels(1 if data.ndim == 1 else data.shape[1])
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(pcm.tobytes())
    REPORT[name] = {"seconds": round(len(data) / RATE, 3), "peak": round(float(np.max(np.abs(data))), 4), "rms": round(float(np.sqrt(np.mean(data ** 2))), 4)}


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def envelope(t, attack, decay, duration):
    return (1 - np.exp(-t / attack)) * np.exp(-t / decay) * np.clip((duration - t) / 0.04, 0, 1)


def pluck(midi, duration, mellow=1.0):
    t = np.arange(int(duration * RATE)) / RATE
    f = hz(midi)
    signal = np.sin(2 * np.pi * f * t)
    for partial, amplitude in [(2, 0.28), (3, 0.11), (4, 0.035)]:
        signal += amplitude * mellow * np.sin(2 * np.pi * f * partial * t) * np.exp(-t / (0.22 + 0.1 / partial))
    return signal * envelope(t, 0.008, duration / 3.5, duration)


def music():
    beat = 60 / 90
    length = round(64 * beat * RATE)
    mix = np.zeros((length, 2))

    def add(signal, time, volume, pan=0.0):
        index = (round(time * RATE) + np.arange(len(signal))) % length
        mix[index, 0] += signal * volume * np.sqrt((1 - pan) / 2)
        mix[index, 1] += signal * volume * np.sqrt((1 + pan) / 2)

    # Sixteen bars: Am9, Fmaj7, Cmaj7, G6, Dm9, Fmaj7, Em7, Am9.
    chords = [(45, [57, 60, 64, 71]), (41, [57, 60, 64, 65]), (48, [55, 59, 60, 64]),
              (43, [55, 59, 62, 64]), (38, [57, 60, 64, 65]), (41, [57, 60, 64, 65]),
              (40, [55, 59, 62, 64]), (45, [57, 60, 64, 71])]
    for section, (bass, chord) in enumerate(chords):
        start = section * 8 * beat
        duration = 8 * beat + 0.3
        t = np.arange(round(duration * RATE)) / RATE
        pad_env = np.sin(np.pi * np.clip(t / duration, 0, 1)) ** 1.3
        for n, note in enumerate(chord[:3]):
            f = hz(note)
            pad = (np.sin(2 * np.pi * f * t) + 0.21 * np.sin(2 * np.pi * f * 2.001 * t)) * pad_env
            add(pad, start, 0.055, (n - 1) * 0.36)
        for pulse in [0, 3.5, 4, 7]:
            add(pluck(bass, 2.2, 0.25), start + pulse * beat, 0.23, -0.06)
        pattern = [0, 2, 1, 3, 1, 2, 3, 2]
        for n in range(16):
            add(pluck(chord[pattern[n % 8]] + 12, 1.7, 0.6), start + n * 0.5 * beat, 0.075 if n % 2 else 0.095, 0.22 * (-1) ** n)
        # Original, sparse upper phrases; rests leave space around the melody.
        phrases = [[(1.5, 76), (2.5, 74), (4.0, 72), (5.5, 71)],
                   [(1.0, 69), (2.5, 72), (4.5, 76), (6.0, 72)],
                   [(0.5, 71), (2.0, 72), (3.5, 74), (5.5, 76)],
                   [(1.5, 74), (3.0, 71), (4.5, 69), (6.0, 67)],
                   [(1.0, 69), (2.5, 72), (4.0, 74), (6.0, 76)],
                   [(0.5, 76), (2.0, 72), (4.0, 69), (5.5, 72)],
                   [(1.0, 71), (2.5, 74), (4.0, 76), (6.0, 71)],
                   [(1.0, 72), (3.0, 71), (4.5, 69), (6.5, 76)]]
        for position, note in phrases[section]:
            add(pluck(note, 2.0, 0.35), start + position * beat, 0.16, 0.09)
    # A circular stereo room tail keeps the loop continuous.
    dry = mix.copy()
    for delay, gain in [(0.137, 0.14), (0.263, 0.11), (0.419, 0.075), (0.641, 0.035)]:
        mix += np.roll(dry[:, ::-1], round(delay * RATE), axis=0) * gain
    write("inicio", mix, 0.79)
    REPORT["inicio"]["bpm"] = 90
    REPORT["inicio"]["loop_boundary_jump"] = round(float(np.max(np.abs(mix[-1] - mix[0]))), 5)


def paper(duration, strokes=1):
    t = np.arange(round(duration * RATE)) / RATE
    noise = RNG.standard_normal(len(t))
    # Band-limited friction, with a gentle short tap at the end of each stroke.
    low = np.convolve(noise, np.ones(5) / 5, mode="same")
    noise = low - np.convolve(low, np.ones(61) / 61, mode="same")
    gate = np.zeros(len(t))
    for n in range(strokes):
        start = n * duration / strokes
        local = np.maximum(t - start, 0)
        stroke = (t >= start) * (1 - np.exp(-local / 0.006)) * np.exp(-local / (duration / strokes / 3.2))
        gate += stroke
    result = noise * gate
    return result * np.clip((duration - t) / 0.025, 0, 1)


def effect(name, duration, kind):
    t = np.arange(round(duration * RATE)) / RATE
    if kind == "paper":
        data = paper(duration) + 0.025 * np.sin(2 * np.pi * 160 * t) * envelope(t, 0.002, 0.025, duration)
    elif kind == "shuffle":
        data = paper(duration, 7)
    elif kind == "attack":
        f = 1000 - 800 * np.minimum(t / 0.22, 1)
        phase = np.cumsum(f) * 2 * np.pi / RATE
        data = paper(duration) * 0.65 + np.sin(phase) * envelope(t, 0.008, 0.055, duration) * 0.13
        hit = np.maximum(t - 0.16, 0)
        data += (t > 0.16) * np.sin(2 * np.pi * 83 * hit) * np.exp(-hit / 0.045) * 0.14
    elif kind == "block":
        data = paper(duration) * 0.12
        for f, gain, decay in [(190, 0.42, 0.055), (580, 0.13, 0.045), (1160, 0.045, 0.025)]:
            data += np.sin(2 * np.pi * f * t) * envelope(t, 0.0015, decay, duration) * gain
    elif kind == "damage":
        data = paper(duration) * 0.25 + np.sin(2 * np.pi * (96 * t - 18 * t * t)) * envelope(t, 0.004, 0.05, duration) * 0.16
    else:
        f = 660 if kind == "pay" else 480
        data = (np.sin(2 * np.pi * f * t) + 0.18 * np.sin(2 * np.pi * f * 1.5 * t)) * envelope(t, 0.004, 0.035, duration)
    write(name, data, 0.44 if kind == "ui" else 0.62)


def main():
    OUT.mkdir(exist_ok=True)
    music()
    for name, duration, kind in [("robo", 0.18, "paper"), ("carta", 0.22, "paper"),
                                 ("pago", 0.19, "pay"), ("ataque", 0.34, "attack"),
                                 ("bloqueo", 0.31, "block"), ("descarte", 0.27, "paper"),
                                 ("barajar", 0.46, "shuffle"), ("dano", 0.26, "damage"),
                                 ("interfaz", 0.12, "ui")]:
        effect(name, duration, kind)
    (OUT / "METADATOS.json").write_text(json.dumps(REPORT, indent=2) + "\n")
    print(json.dumps(REPORT))


if __name__ == "__main__":
    main()
