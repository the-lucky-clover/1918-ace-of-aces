"""Original heroic chiptune loops for 1918 — synthesized in numpy, no assets.
Square-wave lead, triangle bass, whisper-quiet noise hats. All loops are
beat-quantized and resolve to the tonic so they loop seamlessly.
Output: 22050 Hz mono 16-bit WAVs in assets/music/.
"""
import numpy as np
import wave
import os

SR = 22050
OUT = os.path.expanduser("~/workspace/1918-godot/assets/music")
os.makedirs(OUT, exist_ok=True)


def freq(midi: int) -> float:
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def osc_square(t: np.ndarray, f: float, vib: float = 0.0) -> np.ndarray:
    ph = 2.0 * np.pi * f * t
    if vib > 0.0:
        ph += vib * np.sin(2.0 * np.pi * 5.5 * t)
    return np.sign(np.sin(ph)).astype(np.float64) * 0.6


def osc_tri(t: np.ndarray, f: float) -> np.ndarray:
    c = (f * t) % 1.0
    return (2.0 * np.abs(2.0 * c - 1.0) - 1.0) * 0.8


def adsr(n: int, a: float, d: float, s: float, r: float) -> np.ndarray:
    na, nd, nr = int(n * a), int(n * d), int(n * r)
    ns = max(0, n - na - nd - nr)
    e = np.ones(n)
    if na:
        e[:na] = np.linspace(0, 1, na)
    if nd:
        e[na:na + nd] = np.linspace(1, s, nd)
    if nr:
        e[n - nr:] = np.linspace(s, 0, nr)
    return e


class Song:
    def __init__(self, bpm: float, bars: int):
        self.bpm = bpm
        self.bars = bars
        self.beat = 60.0 / bpm
        self.bar = 4 * self.beat
        self.n = int(bars * self.bar * SR)
        self.mix = np.zeros(self.n)

    def _span(self, bar: int, beat: float, dur: float):
        s = int((bar * self.bar + beat * self.beat) * SR)
        e = min(self.n, s + int(dur * self.beat * SR))
        return s, e

    def lead(self, bar: int, beat: float, dur: float, midi: int, vol: float = 0.32):
        s, e = self._span(bar, beat, dur)
        if e <= s:
            return
        t = np.arange(e - s) / SR
        w = osc_square(t, freq(midi), vib=0.15) * adsr(e - s, 0.02, 0.08, 0.75, 0.12)
        self.mix[s:e] += w * vol

    def bass(self, bar: int, beat: float, dur: float, midi: int, vol: float = 0.30):
        s, e = self._span(bar, beat, dur)
        if e <= s:
            return
        t = np.arange(e - s) / SR
        w = osc_tri(t, freq(midi)) * adsr(e - s, 0.01, 0.05, 0.85, 0.08)
        self.mix[s:e] += w * vol

    def hat(self, bar: int, beat: float, vol: float = 0.05):
        s = int((bar * self.bar + beat * self.beat) * SR)
        n = int(0.03 * SR)
        e = min(self.n, s + n)
        if e <= s:
            return
        nz = np.random.default_rng(bar * 131 + int(beat * 17)).standard_normal(e - s)
        nz = np.diff(nz, prepend=0.0)  # crude highpass -> tick
        env = np.exp(-np.arange(e - s) / (0.008 * SR))
        self.mix[s:e] += nz * env * vol

    def pad(self, bar: int, midi: int, dur_bars: float = 1.0, vol: float = 0.16):
        # soft stacked triangle chord tone
        s, e = self._span(bar, 0.0, dur_bars * 4.0)
        if e <= s:
            return
        t = np.arange(e - s) / SR
        w = (osc_tri(t, freq(midi)) + 0.5 * osc_tri(t, freq(midi + 7))) * 0.5
        w *= adsr(e - s, 0.3, 0.2, 0.7, 0.4)
        self.mix[s:e] += w * vol

    def write(self, name: str, gain: float = 0.9):
        x = self.mix * gain
        # 8 ms raised-cosine edge fades: kills clicks, loop stays seamless
        nf = int(0.008 * SR)
        if nf * 2 < len(x):
            w = 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, nf))
            x[:nf] *= w
            x[-nf:] *= w[::-1]
        x = np.clip(x, -1.0, 1.0)
        pcm = (x * 32767).astype(np.int16)
        path = os.path.join(OUT, name)
        with wave.open(path, "wb") as f:
            f.setnchannels(1)
            f.setsampwidth(2)
            f.setframerate(SR)
            f.writeframes(pcm.tobytes())
        secs = len(pcm) / SR
        print(f"WROTE {name}: {secs:.1f}s, {os.path.getsize(path)//1024} KB")


# ---------------------------------------------------------------- splash ---
# Heroic D-minor theme, 112 BPM, 8 bars (~17s). i-VI-III-VII, resolves to Dm.
def splash():
    s = Song(112.0, 8)
    roots = [38, 34, 41, 36, 38, 34, 41, 36]  # D2 Bb1 F2 C2 ...
    mel = [  # (bar, beat, dur, midi)
        (0, 0, 1, 74), (0, 1, 1, 77), (0, 2, 2, 81),
        (1, 0, 1.5, 82), (1, 1.5, 0.5, 81), (1, 2, 2, 79),
        (2, 0, 1, 81), (2, 1, 1, 84), (2, 2, 2, 86),
        (3, 0, 3, 84), (3, 3, 1, 81),
        (4, 0, 1, 86), (4, 1, 1, 84), (4, 2, 1, 82), (4, 3, 1, 81),
        (5, 0, 2, 79), (5, 2, 2, 77),
        (6, 0, 1, 76), (6, 1, 1, 77), (6, 2, 2, 79),
        (7, 0, 4, 81),
    ]
    for b in range(8):
        r = roots[b]
        for k in range(8):  # driving 8th-note bass: root root fifth root...
            m = r if k % 4 != 2 else r + 7
            s.bass(b, k * 0.5, 0.45, m, vol=0.26)
        for k in range(4):
            s.hat(b, k + 0.5, vol=0.035)
    for bar, beat, dur, midi in mel:
        s.lead(bar, beat, dur, midi, vol=0.30)
    # final bar: soft timpani-ish hits under the resolve
    for k in range(4):
        s.bass(7, k, 0.9, 38, vol=0.30)
    s.write("splash_theme.wav")


# ----------------------------------------------------------------- pause ---
# Restrained A-minor meditation, 80 BPM, 4 bars (12s). Barely-there.
def pause():
    s = Song(80.0, 4)
    roots = [45, 41, 48, 43]  # A2 F2 C3 G2
    line = [(0, 0, 2, 76), (0, 2, 2, 74), (1, 0, 2, 72), (1, 2, 2, 71),
            (2, 0, 4, 72), (3, 0, 2, 71), (3, 2, 2, 69)]
    for b in range(4):
        s.pad(b, roots[b], 1.0, vol=0.14)
        s.pad(b, roots[b] + 12, 1.0, vol=0.07)
    for bar, beat, dur, midi in line:
        s.lead(bar, beat, dur, midi, vol=0.13)
    s.write("pause_theme.wav", gain=0.8)


# -------------------------------------------------------------- gameplay ---
# Long heroic loop, 104 BPM, 24 bars (~55s). A: Dm Bb F C x4, B: lift.
def gameplay():
    s = Song(104.0, 24)
    progA = [38, 34, 41, 36] * 4
    progB = [34, 41, 36, 43] * 2
    roots = progA + progB
    # A-section melody: bold 2-bar call, answer, variation
    call = [(0, 0, 1, 74), (0, 1, 1, 77), (0, 2, 1, 81), (0, 3, 1, 79),
            (1, 0, 2, 77), (1, 2, 1, 76), (1, 3, 1, 74)]
    ans = [(2, 0, 1, 77), (2, 1, 1, 81), (2, 2, 1, 84), (2, 3, 1, 82),
           (3, 0, 3, 81), (3, 3, 1, 79)]
    var = [(4, 0, 0.5, 81), (4, 0.5, 0.5, 84), (4, 1, 1, 86), (4, 2, 2, 84),
           (5, 0, 1, 82), (5, 1, 1, 81), (5, 2, 2, 79),
           (6, 0, 1, 77), (6, 1, 1, 79), (6, 2, 1, 81), (6, 3, 1, 79),
           (7, 0, 4, 77)]
    mel = []
    for rep in (0, 8):  # A twice
        mel += [(b + rep, bt, d, m) for (b, bt, d, m) in call + ans]
    mel += [(b + 16, bt, d, m) for (b, bt, d, m) in var]  # B: 16-23
    # B-section lift: climb then resolve
    mel += [(16, 0, 1, 82), (16, 1, 1, 84), (16, 2, 2, 86),
            (17, 0, 2, 87), (17, 2, 2, 86),
            (18, 0, 1, 84), (18, 1, 1, 82), (18, 2, 2, 81),
            (19, 0, 4, 79),
            (20, 0, 1, 81), (20, 1, 1, 84), (20, 2, 1, 86), (20, 3, 1, 84),
            (21, 0, 2, 82), (21, 2, 2, 81),
            (22, 0, 1, 79), (22, 1, 1, 77), (22, 2, 2, 76),
            (23, 0, 4, 74)]  # resolve to D -> loops to bar 0 Dm
    for b in range(24):
        r = roots[b]
        for k in range(8):
            m = r if k % 4 != 2 else r + 7
            s.bass(b, k * 0.5, 0.45, m, vol=0.22)
        for k in range(4):  # hats offbeat, snare-ish tick on 2 & 4
            s.hat(b, k + 0.5, vol=0.03)
        s.hat(b, 1.0, vol=0.06)
        s.hat(b, 3.0, vol=0.06)
    for bar, beat, dur, midi in mel:
        s.lead(bar, beat, dur, midi, vol=0.26)
    s.write("gameplay_theme.wav")


if __name__ == "__main__":
    splash()
    pause()
    gameplay()
    # fuel warning: urgent two-tone beep, 0.7s, replayed by the game
    w = Song(120.0, 1)
    for i, m in enumerate([88, 88, 84, 84]):
        w.lead(0, i * 0.25, 0.22, m, vol=0.4)
    w.write("fuel_warn.wav")
    print("ALL TRACKS DONE")
