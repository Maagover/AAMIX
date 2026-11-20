"""Original upbeat AAMIX battle music and UI cues; no recordings or borrowed melody."""
from pathlib import Path
import hashlib
import json
import wave
import numpy as np

RATE = 22050
BPM = 148
BEAT = 60 / BPM
OUT = Path(__file__).resolve().parents[1] / 'audio'
RNG = np.random.default_rng(140018)
REPORT = {}

def write(name, data, peak):
    data = np.asarray(data, dtype=float)
    data -= data.mean(axis=0)
    data *= peak / max(float(np.max(np.abs(data))), .00001)
    pcm = np.rint(data * 32767).astype('<i2')
    path = OUT / (name + '.wav')
    with wave.open(str(path), 'wb') as handle:
        handle.setnchannels(1 if data.ndim == 1 else data.shape[1])
        handle.setsampwidth(2)
        handle.setframerate(RATE)
        handle.writeframes(pcm.tobytes())
    REPORT[name] = {'seconds': round(len(data)/RATE, 4), 'peak': round(float(np.max(np.abs(data))), 4), 'rms': round(float(np.sqrt(np.mean(data**2))), 4), 'channels': 1 if data.ndim == 1 else data.shape[1], 'sample_rate': RATE, 'sha256': hashlib.sha256(path.read_bytes()).hexdigest(), 'origin': 'Original AAMIX synthesis; no external samples or existing melodies'}

def hz(midi):
    return 440 * 2 ** ((midi - 69) / 12)

def voice(midi, duration, kind='lead'):
    t = np.arange(round(duration * RATE)) / RATE
    f = hz(midi)
    phase = 2*np.pi*f*t + .025*np.sin(2*np.pi*5*t)
    if kind == 'bass':
        wave_data = np.sin(phase) + .25*np.sin(phase*2) + .13*np.sin(phase*3)
        decay = 4.5
    elif kind == 'arp':
        wave_data = np.sin(phase) + .22*np.sin(phase*2)
        decay = 7
    else:
        wave_data = np.sin(phase) + .32*np.sin(phase*3) + .14*np.sin(phase*5) + .045*np.sin(phase*7)
        decay = 2.5
    env = np.minimum(t/.008, 1)*np.minimum((duration-t)/.035, 1)*np.exp(-t*decay)
    return wave_data * env

def drums(kind):
    duration = {'kick':.22, 'snare':.18, 'hat':.06}[kind]
    t = np.arange(round(duration*RATE))/RATE
    noise = RNG.normal(0,1,len(t))
    if kind == 'kick':
        f = 52 + 105*np.exp(-t*36)
        data = np.sin(2*np.pi*np.cumsum(f)/RATE)*np.exp(-t*22) + noise*.025*np.exp(-t*130)
    elif kind == 'snare':
        high = noise - np.convolve(noise,np.ones(17)/17,mode='same')
        data = high*.32*np.exp(-t*26) + np.sin(2*np.pi*175*t)*.20*np.exp(-t*35)
    else:
        high = noise - np.convolve(noise,np.ones(7)/7,mode='same')
        data = high*.25*np.exp(-t*80)
    return data * np.minimum(t/.001,1)*np.minimum((duration-t)/.012,1)

def battle():
    length = round(128*BEAT*RATE)
    mix = np.zeros((length,2))
    def add(signal, beat, gain, pan=0):
        index = (round(beat*BEAT*RATE)+np.arange(len(signal))) % length
        mix[index,0] += signal*gain*np.sqrt((1-pan)/2)
        mix[index,1] += signal*gain*np.sqrt((1+pan)/2)
    # D minor progression. Every phrase below is newly composed for this project.
    chords = [(38,[62,65,69]),(34,[62,65,70]),(36,[60,64,67]),(33,[60,64,69]),(31,[62,67,70]),(38,[62,65,69]),(33,[61,64,69]),(33,[61,67,69])]
    phrases = [[(0,74,.5),(.75,77,.25),(1.5,76,.5),(2.25,81,.5),(3.25,77,.5)],[(.25,77,.5),(1,74,.5),(1.75,82,.25),(2.5,81,.5),(3.25,77,.5)],[(0,79,.5),(.75,76,.25),(1.5,84,.5),(2.25,79,.5),(3,76,.75)],[(.25,76,.5),(1,72,.5),(1.75,81,.25),(2.5,79,.5),(3.25,76,.5)],[(0,79,.5),(.75,82,.25),(1.5,81,.5),(2.25,86,.5),(3.25,82,.5)],[(.25,81,.5),(1,77,.5),(1.75,74,.25),(2.5,77,.5),(3.25,81,.5)],[(0,85,.5),(.75,81,.25),(1.5,79,.5),(2.25,76,.5),(3.25,73,.5)],[(.25,76,.5),(1,79,.5),(1.75,81,.25),(2.5,85,.5),(3.25,81,.5)]]
    for bar in range(32):
        start = bar*4
        root, chord = chords[bar%8]
        for beat in [0,.75,1.5,2,2.75,3.5]:
            add(voice(root+(12 if beat in [.75,2.75] else 0),BEAT*.45,'bass'),start+beat,.28,-.06)
        for step in range(16):
            note = chord[[0,2,1,2][step%4]] + (12 if bar>=16 else 0)
            add(voice(note,BEAT*.28,'arp'),start+step/4,.055,.24*(-1)**step)
        for offset,note,duration in phrases[bar%8]:
            shift = 12 if bar in [15,23,31] else 0
            add(voice(note+shift,duration*BEAT+.08),start+offset,.15,.08)
        for b in [0,2,2.75]: add(drums('kick'),start+b,.31)
        for b in [1,3]: add(drums('snare'),start+b,.23)
        for n in range(8): add(drums('hat'),start+n*.5,.11 if n%2 else .15,-.24)
    dry=mix.copy()
    for delay,gain in [(BEAT*.75,.11),(BEAT*1.5,.055)]: mix += np.roll(dry[:,::-1],round(delay*RATE),axis=0)*gain
    write('batalla',mix,.74)
    REPORT['batalla'].update({'bpm':BPM,'bars':32,'loop_boundary_jump':round(float(np.max(np.abs((mix[-1]-mix[0])*.74/np.max(np.abs(mix))))),6)})

def cues():
    t=np.arange(round(.23*RATE))/RATE
    phase=2*np.pi*np.cumsum(560+820*np.exp(-t*17))/RATE
    popup=np.sin(phase)*np.sin(np.pi*np.clip(t/.23,0,1))**1.7*np.exp(-t*12)
    write('popup',popup,.34)
    duration=1.05
    data=np.zeros(round(duration*RATE))
    for start,note in [(0,74),(.09,81),(.18,86),(.29,89),(.41,93)]:
        signal=voice(note,.6,'arp')*.19
        index=round(start*RATE)
        data[index:index+len(signal)] += signal[:len(data)-index]
    write('singular',data,.45)

def main():
    OUT.mkdir(exist_ok=True)
    battle();cues()
    (OUT/'METADATOS_COMBATE_v0.14.0.json').write_text(json.dumps(REPORT,ensure_ascii=False,indent=2)+'\n',encoding='utf8')
    print(json.dumps(REPORT,ensure_ascii=False))

if __name__=='__main__': main()
