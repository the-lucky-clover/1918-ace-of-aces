"""Original combat/UI sound effects for 1918 — synthesized in numpy, no assets.
22050 Hz mono 16-bit WAVs in assets/sfx/. Every sound is generated from
first principles (oscillators + filtered noise + envelopes); nothing is
sampled, copied, or downloaded.
"""
import numpy as np
import wave
import os

SR = 22050
OUT = os.path.expanduser("~/workspace/1918-godot/assets/sfx")
os.makedirs(OUT, exist_ok=True)


def write_wav(name: str, x: np.ndarray) -> None:
    x = np.clip(x, -1.0, 1.0)
    pcm = (x * 32767).astype(np.int16)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    print(f"SFX {name} ({len(pcm)/SR:.2f}s)")


def noise(n: int, seed: int) -> np.ndarray:
    return np.random.default_rng(seed).standard_normal(n)


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    # one-pole lowpass; cutoff in Hz
    a = 1.0 - np.exp(-2.0 * np.pi * cutoff / SR)
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += a * (v - acc)
        y[i] = acc
    return y


def highpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    return x - lowpass(x, cutoff)


def env_exp(n: int, decay: float) -> np.ndarray:
    t = np.arange(n) / SR
    return np.exp(-t * decay)


def env_ar(n: int, attack: float, release: float) -> np.ndarray:
    t = np.arange(n) / SR
    dur = n / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    r = np.clip((dur - t) / max(release, 1e-4), 0, 1)
    return np.minimum(a, r)


def sine_sweep(n: int, f0: float, f1: float) -> np.ndarray:
    t = np.arange(n) / SR
    dur = n / SR
    f = f0 + (f1 - f0) * (t / dur)
    ph = 2.0 * np.pi * np.cumsum(f) / SR
    return np.sin(ph)


def blip(freq: float, dur: float, vol: float = 0.5, seed: int = 0) -> np.ndarray:
    n = int(dur * SR)
    t = np.arange(n) / SR
    return np.sin(2.0 * np.pi * freq * t) * env_exp(n, 14.0) * vol


def blast(dur: float, seed: int, sub_f0: float = 70.0, sub_f1: float = 32.0,
          noise_vol: float = 0.55, sub_vol: float = 0.6) -> np.ndarray:
    """One explosion: sub thump sweeping down + decaying filtered noise."""
    n = int(dur * SR)
    nz = lowpass(noise(n, seed), 900.0) * env_exp(n, 6.0) * noise_vol
    # initial crack: bright noise, very fast decay
    crack = highpass(noise(n, seed + 1), 2500.0) * env_exp(n, 40.0) * 0.35
    sub = sine_sweep(n, sub_f0, sub_f1) * env_exp(n, 5.0) * sub_vol
    return nz + crack + sub


# --- the set ---

# small explosion: quick dirty pop (fighters, trucks, AA guns)
write_wav("explosion_small.wav", blast(0.45, 11))

# large explosion: deep rolling boom (bombers, balloons, depots, screen bomb)
write_wav("explosion_large.wav", blast(1.05, 23, sub_f0=55.0, sub_f1=26.0,
                                      noise_vol=0.65, sub_vol=0.75))

# boss defeat: four staggered blasts, descending — a multi-kill fanfare
n = int(1.8 * SR)
mix = np.zeros(n)
for i, (off, dur, seed) in enumerate([(0.0, 0.7, 31), (0.28, 0.8, 37),
                                      (0.62, 0.9, 43), (1.0, 0.75, 53)]):
    b = blast(dur, seed, sub_f0=65.0 - i * 8.0, sub_f1=28.0)
    s = int(off * SR)
    e = min(n, s + len(b))
    mix[s:e] += b[:e - s] * (1.0 - i * 0.12)
write_wav("boss_defeat.wav", mix * 0.9)

# player damage: low heavy thud + metallic click
n = int(0.28 * SR)
t = np.arange(n) / SR
thud = (np.sin(2.0 * np.pi * 95.0 * t) * env_exp(n, 22.0) * 0.7
        + highpass(noise(n, 61), 3000.0) * env_exp(n, 60.0) * 0.25)
write_wav("damage_thud.wav", thud)

# pickup collect: bright two-tone chime, up a fifth
n = int(0.35 * SR)
chime = np.zeros(n)
b1, b2 = blip(659.25, 0.35, 0.45), blip(987.77, 0.35, 0.45)
chime[:len(b1)] += b1
s2 = int(0.09 * SR)
chime[s2:s2 + len(b2)] += b2[:len(chime) - s2]
write_wav("pickup_chime.wav", chime)

# UI tick: tiny tactile click
n = int(0.06 * SR)
tick = (np.sign(np.sin(2.0 * np.pi * 1400.0 * np.arange(n) / SR))
        * env_exp(n, 90.0) * 0.28)
write_wav("ui_tick.wav", tick)

# UI confirm: confident two-tone up
n = int(0.22 * SR)
conf = np.zeros(n)
c1, c2 = blip(440.0, 0.22, 0.4), blip(587.33, 0.22, 0.4)
conf[:len(c1)] += c1
s2 = int(0.08 * SR)
conf[s2:s2 + len(c2)] += c2[:len(conf) - s2]
write_wav("ui_confirm.wav", conf)

# loop-de-loop whoosh: air rushing past, swelling then releasing (0.75s = LOOP_DUR)
n = int(0.75 * SR)
t = np.arange(n) / SR
swell = env_ar(n, 0.30, 0.30)
# sweep the lowpass cutoff upward through the maneuver
raw = noise(n, 71)
cut = 400.0 + 2600.0 * np.sin(np.pi * np.clip(t / 0.75, 0, 1))
y = np.zeros(n)
acc = 0.0
for i in range(n):
    a = 1.0 - np.exp(-2.0 * np.pi * cut[i] / SR)
    acc += a * (raw[i] - acc)
    y[i] = acc
write_wav("loop_whoosh.wav", y * swell * 0.8)

# flak burst pop: sharp aerial pop + brief ring
n = int(0.24 * SR)
pop = (highpass(noise(n, 83), 1200.0) * env_exp(n, 28.0) * 0.5
       + np.sin(2.0 * np.pi * 720.0 * np.arange(n) / SR) * env_exp(n, 30.0) * 0.25)
write_wav("flak_pop.wav", pop)

# mustard gas bloom: slow toxic exhale, swells in and out
n = int(1.2 * SR)
hiss = highpass(noise(n, 97), 1800.0) * env_ar(n, 0.45, 0.55) * 0.42
write_wav("gas_hiss.wav", hiss)

# tank gun: long-barreled boom — deeper sub, longer rolling tail
write_wav("tank_boom.wav", blast(0.7, 113, sub_f0=48.0, sub_f1=22.0,
                                 noise_vol=0.6, sub_vol=0.8))

# MG chatter: short 5-round burst of pops, for nest fire
n = int(0.55 * SR)
chatter = np.zeros(n)
for i in range(5):
    s = int(i * 0.1 * SR)
    p = (highpass(noise(int(0.12 * SR), 200 + i), 900.0)
         * env_exp(int(0.12 * SR), 26.0) * 0.4)
    e = min(n, s + len(p))
    chatter[s:e] += p[:e - s]
write_wav("mg_chatter.wav", chatter)

# rifle pop: single sharp crack — infantry pot-shots
n = int(0.22 * SR)
rp = (highpass(noise(n, 311), 1400.0) * env_exp(n, 30.0) * 0.5
      + np.sin(2.0 * np.pi * 480.0 * np.arange(n) / SR) * env_exp(n, 32.0) * 0.2)
write_wav("rifle_pop.wav", rp)

print("ALL SFX DONE")
