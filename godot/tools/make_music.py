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

    def snare(self, bar: int, beat: float, vol: float = 0.20):
        # marching snare: bandpassed noise burst, ~0.12s
        s = int((bar * self.bar + beat * self.beat) * SR)
        n = int(0.12 * SR)
        e = min(self.n, s + n)
        if e <= s:
            return
        rng = np.random.default_rng(bar * 977 + int(beat * 31) + 7)
        nz = rng.standard_normal(e - s)
        # crude bandpass: highpass then soft lowpass via cumsum diff
        nz = np.diff(nz, prepend=0.0)
        k = np.ones(6) / 6.0
        nz = np.convolve(nz, k, mode="same")
        env = np.exp(-np.arange(e - s) / (0.03 * SR))
        self.mix[s:e] += nz * env * vol

    def boom(self, bar: int, beat: float, midi: int, vol: float = 0.5,
             dur: float = 1.4):
        # timpani: pitch-dropping sine + low thump, dur in beats
        s = int((bar * self.bar + beat * self.beat) * SR)
        n = int(min(dur * self.beat, (self.n - s) / SR) * SR)
        e = min(self.n, s + n)
        if e <= s:
            return
        t = np.arange(e - s) / SR
        f0 = freq(midi) * 1.35
        f1 = freq(midi)
        ph = 2.0 * np.pi * np.cumsum(f0 + (f1 - f0) * (t / (dur * self.beat))) / SR
        w = np.sin(ph) * np.exp(-t * 2.2)
        rng = np.random.default_rng(bar * 571 + int(beat * 13))
        th = np.convolve(rng.standard_normal(e - s),
                         np.ones(24) / 24.0, mode="same")
        th *= np.exp(-t * 5.0) * 0.5
        self.mix[s:e] += (w + th) * vol

    def arp16(self, bar: int, chord: list, vol: float = 0.16):
        # one bar of 16th-note arpeggio cycling chord tones (mechanical)
        for k in range(16):
            m = chord[k % len(chord)]
            s = int((bar * self.bar + (k * 0.25) * self.beat) * SR)
            n = int(0.22 * self.beat * SR)
            e = min(self.n, s + n)
            if e <= s:
                continue
            t = np.arange(e - s) / SR
            w = osc_square(t, freq(m)) * adsr(e - s, 0.005, 0.03, 0.6, 0.05)
            self.mix[s:e] += w * vol

    def gliss(self, bar: int, beat: float, dur: float, f0: float, f1: float,
              vol: float = 0.22):
        # eerie theremin-like sine sweep with vibrato (ghost stinger)
        s = int((bar * self.bar + beat * self.beat) * SR)
        n = int(dur * SR)
        e = min(self.n, s + n)
        if e <= s:
            return
        t = np.arange(e - s) / SR
        f = f0 + (f1 - f0) * (t / dur)
        ph = 2.0 * np.pi * np.cumsum(f) / SR
        ph += 2.5 * np.sin(2.0 * np.pi * 6.0 * t)  # vibrato
        # attack/release envelope (local: make_sfx's env_ar lives elsewhere)
        nlen = e - s
        na, nr = int(nlen * 0.4), int(nlen * 0.8)
        env = np.ones(nlen)
        if na:
            env[:na] = np.linspace(0, 1, na)
        if nr:
            env[nlen - nr:] = np.linspace(1, 0, nr)
        w = np.sin(ph) * env
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


# ============================================================ v22 theaters ==
# Nine per-theater identities. Training fields and the Verdun apocalypse do
# NOT sound the same: key, tempo, bass pattern, drum weight and melodic
# character are all composed per theater. Every track resolves to its tonic
# so the loop is seamless.
THEATERS = {
    # sortie idx -> theater key (0-based sorties 0..31)
    "by_sortie": (["training"] * 3 + ["front"] * 5 + ["industrial"] * 4
                  + ["verdun"] * 4 + ["vineyard"] * 4 + ["salient"] * 4
                  + ["meuse"] * 4 + ["argonne"] * 3 + ["armistice"]),
}


def _drive_bass(s, bars, roots, vol=0.22, fifth=True):
    for b in range(bars):
        r = roots[b % len(roots)]
        for k in range(8):
            m = r if (not fifth or k % 4 != 2) else r + 7
            s.bass(b, k * 0.5, 0.45, m, vol=vol)


def _hats(s, bars, off_vol=0.03, back_vol=0.0):
    for b in range(bars):
        for k in range(4):
            s.hat(b, k + 0.5, vol=off_vol)
        if back_vol:
            s.hat(b, 1.0, vol=back_vol)
            s.hat(b, 3.0, vol=back_vol)


def theater_training():
    # S1-S3 Issoudun/Colombey/Toul: hopeful G-major pastoral, bugle-call
    # lead, 100 BPM, 16 bars (~38s).
    s = Song(100.0, 16)
    roots = [43, 48, 43, 50]  # G2 C3 G2 D3
    mel = [(0, 0, 1, 79), (0, 1, 1, 83), (0, 2, 2, 86),
           (1, 0, 2, 84), (1, 2, 2, 83),
           (2, 0, 1, 81), (2, 1, 1, 79), (2, 2, 1, 77), (2, 3, 1, 76),
           (3, 0, 4, 74),
           (4, 0, 1, 79), (4, 1, 1, 83), (4, 2, 2, 86),
           (5, 0, 2, 88), (5, 2, 2, 86),
           (6, 0, 1, 84), (6, 1, 1, 83), (6, 2, 1, 81), (6, 3, 1, 79),
           (7, 0, 4, 77),
           (8, 0, 1, 81), (8, 1, 1, 84), (8, 2, 2, 86),
           (9, 0, 2, 86), (9, 2, 2, 84),
           (10, 0, 1, 83), (10, 1, 1, 81), (10, 2, 1, 79), (10, 3, 1, 77),
           (11, 0, 4, 76),
           (12, 0, 1, 79), (12, 1, 1, 83), (12, 2, 2, 86),
           (13, 0, 2, 84), (13, 2, 2, 83),
           (14, 0, 1, 81), (14, 1, 1, 79), (14, 2, 2, 77),
           (15, 0, 4, 79)]  # resolve G
    _drive_bass(s, 16, roots, vol=0.22)
    _hats(s, 16, off_vol=0.028)
    for bar, beat, dur, midi in mel:
        s.lead(bar, beat, dur, midi, vol=0.27)
    s.write("theater_training.wav")


def theater_front():
    # S4-S8 approach to the front: uneasy D-minor, sparse long-note lead
    # over a low drone, rain-tick hats, 92 BPM, 16 bars (~42s).
    s = Song(92.0, 16)
    roots = [38, 38, 34, 36]  # D2 D2 Bb1 C2
    mel = [(0, 0, 4, 74), (1, 0, 4, 72), (2, 0, 4, 70), (3, 0, 2, 72),
           (3, 2, 2, 74),
           (4, 0, 4, 76), (5, 0, 4, 74), (6, 0, 4, 73), (7, 0, 4, 74),
           (8, 0, 2, 77), (8, 2, 2, 76), (9, 0, 4, 74),
           (10, 0, 2, 72), (10, 2, 2, 70), (11, 0, 4, 69),
           (12, 0, 4, 70), (13, 0, 4, 72), (14, 0, 2, 73), (14, 2, 2, 74),
           (15, 0, 4, 74)]  # resolve D
    for b in range(16):
        r = roots[b % 4]
        s.bass(b, 0, 3.8, r, vol=0.24)
        s.bass(b, 0, 3.8, r + 12, vol=0.10)
        s.pad(b, r + 12, 1.0, vol=0.10)
        for k in range(8):  # rain ticks
            s.hat(b, k * 0.5 + 0.25, vol=0.016)
    for bar, beat, dur, midi in mel:
        s.lead(bar, beat, dur, midi, vol=0.22)
    s.write("theater_front.wav")


def theater_industrial():
    # S9-S12 Pont-a-Mousson: mechanical E-minor, 16th arps, driving 8ths,
    # snare backbeat, 124 BPM, 16 bars (~31s).
    s = Song(124.0, 16)
    roots = [40, 36, 43, 38]  # E2 C2 G2 D2
    chords = [[64, 67, 71], [60, 64, 67], [67, 71, 74], [62, 66, 69]]
    mel = [(0, 0, 0.5, 76), (0, 0.5, 0.5, 79), (0, 1, 1, 81),
           (0, 2, 0.5, 79), (0, 2.5, 0.5, 76),
           (1, 0, 2, 74), (1, 2, 2, 76),
           (2, 0, 0.5, 72), (2, 0.5, 0.5, 76), (2, 1, 1, 79),
           (2, 2, 0.5, 76), (2, 2.5, 0.5, 72),
           (3, 0, 2, 74), (3, 2, 2, 71),
           (4, 0, 0.5, 76), (4, 0.5, 0.5, 79), (4, 1, 1, 83),
           (4, 2, 0.5, 81), (4, 2.5, 0.5, 79),
           (5, 0, 2, 81), (5, 2, 2, 79),
           (6, 0, 0.5, 76), (6, 0.5, 0.5, 79), (6, 1, 1, 81),
           (6, 2, 2, 83),
           (7, 0, 4, 81),
           (8, 0, 0.5, 83), (8, 0.5, 0.5, 86), (8, 1, 1, 88),
           (8, 2, 0.5, 86), (8, 2.5, 0.5, 83),
           (9, 0, 2, 81), (9, 2, 2, 79),
           (10, 0, 1, 81), (10, 1, 1, 79), (10, 2, 2, 76),
           (11, 0, 4, 74),
           (12, 0, 0.5, 76), (12, 0.5, 0.5, 79), (12, 1, 1, 81),
           (12, 2, 0.5, 79), (12, 2.5, 0.5, 76),
           (13, 0, 2, 74), (13, 2, 2, 76),
           (14, 0, 1, 74), (14, 1, 1, 72), (14, 2, 2, 74),
           (15, 0, 4, 76)]  # resolve E
    for b in range(16):
        s.arp16(b, chords[b % 4], vol=0.13)
        r = roots[b % 4]
        for k in range(8):
            s.bass(b, k * 0.5, 0.4, r, vol=0.20)
        s.snare(b, 1.0, vol=0.16)
        s.snare(b, 3.0, vol=0.16)
    for bar, beat, dur, midi in mel:
        s.lead(bar, beat, dur, midi, vol=0.24)
    s.write("theater_industrial.wav")


def theater_verdun():
    # S13-S16 Verdun: funereal C-minor dirge, tolling long tones, deep
    # whole-note bass, timpani, no hats, 72 BPM, 12 bars (~40s).
    s = Song(72.0, 12)
    roots = [36, 32, 34, 31]  # C2 Ab1 Bb1 G1
    mel = [(0, 0, 4, 72), (1, 0, 4, 70), (2, 0, 4, 68), (3, 0, 4, 67),
           (4, 0, 2, 68), (4, 2, 2, 70), (5, 0, 4, 72),
           (6, 0, 2, 70), (6, 2, 2, 68), (7, 0, 4, 67),
           (8, 0, 4, 68), (9, 0, 4, 70), (10, 0, 4, 72),
           (11, 0, 4, 72)]  # resolve C
    for b in range(12):
        r = roots[b % 4]
        s.bass(b, 0, 3.9, r, vol=0.26)
        s.pad(b, r, 1.0, vol=0.09)
        s.pad(b, r + 7, 1.0, vol=0.06)
        if b % 4 == 0:
            s.boom(b, 0, r - 12, vol=0.4, dur=2.0)
    for bar, beat, dur, midi in mel:
        s.lead(bar, beat, dur, midi, vol=0.24)
    s.write("theater_verdun.wav")


def theater_vineyard():
    # S17-S20 Chateau-Thierry: bittersweet A-major lyrical line over warm
    # pads, gentle half-note bass, 88 BPM, 16 bars (~44s).
    s = Song(88.0, 16)
    roots = [45, 42, 38, 40]  # A2 F#2 D2 E2
    mel = [(0, 0, 2, 76), (0, 2, 2, 81),
           (1, 0, 3, 83), (1, 3, 1, 81),
           (2, 0, 2, 79), (2, 2, 2, 76),
           (3, 0, 4, 74),
           (4, 0, 2, 76), (4, 2, 2, 79),
           (5, 0, 3, 81), (5, 3, 1, 79),
           (6, 0, 2, 77), (6, 2, 2, 76),
           (7, 0, 4, 74),
           (8, 0, 2, 81), (8, 2, 2, 83),
           (9, 0, 3, 86), (9, 3, 1, 84),
           (10, 0, 2, 83), (10, 2, 2, 81),
           (11, 0, 4, 79),
           (12, 0, 2, 81), (12, 2, 2, 79),
           (13, 0, 3, 77), (13, 3, 1, 76),
           (14, 0, 2, 74), (14, 2, 2, 71),
           (15, 0, 4, 69)]  # resolve A
    for b in range(16):
        r = roots[b % 4]
        s.bass(b, 0, 1.9, r, vol=0.22)
        s.bass(b, 2, 1.9, r + 7, vol=0.16)
        s.pad(b, r + 12, 1.0, vol=0.12)
        s.hat(b, 2.5, vol=0.02)
    for bar, beat, dur, midi in mel:
        s.lead(bar, beat, dur, midi, vol=0.25)
    s.write("theater_vineyard.wav")


def theater_salient():
    # S21-S24 Marne salient: escalating F#-minor ostinato, driving 8th
    # hats, snare backbeat, climb to a peak then resolve, 112 BPM, 16 bars.
    s = Song(112.0, 16)
    roots = [42, 38, 45, 40]  # F#2 D2 A2 E2
    for b in range(16):
        r = roots[b % 4]
        for k in range(8):  # ostinato bass
            m = [r, r, r + 7, r, r, r, r + 10, r + 7][k]
            s.bass(b, k * 0.5, 0.42, m, vol=0.21)
        for k in range(8):
            s.hat(b, k * 0.5, vol=0.028)
        s.snare(b, 1.0, vol=0.14)
        s.snare(b, 3.0, vol=0.14)
    mel = []
    for b in range(8):  # A: grinding motif
        tail = [64, 62, 61, 62, 64, 62, 61, 59][b]
        mel += [(b, 0, 0.5, 66), (b, 0.5, 0.5, 69), (b, 1, 0.5, 71),
                (b, 1.5, 0.5, 69), (b, 2, 1, 66), (b, 3, 1, tail)]
    mel += [(8, 0, 1, 69), (8, 1, 1, 71), (8, 2, 2, 73),
            (9, 0, 1, 74), (9, 1, 1, 76), (9, 2, 2, 78),
            (10, 0, 1, 79), (10, 1, 1, 81), (10, 2, 2, 83),
            (11, 0, 4, 84),
            (12, 0, 1, 83), (12, 1, 1, 81), (12, 2, 2, 79),
            (13, 0, 1, 78), (13, 1, 1, 76), (13, 2, 2, 74),
            (14, 0, 1, 73), (14, 1, 1, 71), (14, 2, 2, 69),
            (15, 0, 4, 66)]  # resolve F#
    for bar, beat, dur, midi in mel:
        s.lead(bar, beat, dur, midi, vol=0.25)
    s.write("theater_salient.wav")


def theater_meuse():
    # S25-S28 return to Verdun: grim Bb-minor march, snare 2&4, anthem
    # lead, 104 BPM, 16 bars (~37s).
    s = Song(104.0, 16)
    roots = [34, 42, 37, 44]  # Bb1 F#2 Db2 Ab2
    mel = [(0, 0, 1, 70), (0, 1, 1, 72), (0, 2, 2, 73),
           (1, 0, 2, 74), (1, 2, 2, 73),
           (2, 0, 1, 72), (2, 1, 1, 70), (2, 2, 2, 68),
           (3, 0, 4, 70),
           (4, 0, 1, 73), (4, 1, 1, 74), (4, 2, 2, 77),
           (5, 0, 2, 76), (5, 2, 2, 74),
           (6, 0, 1, 73), (6, 1, 1, 72), (6, 2, 1, 70), (6, 3, 1, 68),
           (7, 0, 4, 70),
           (8, 0, 1, 74), (8, 1, 1, 75), (8, 2, 2, 77),
           (9, 0, 2, 79), (9, 2, 2, 77),
           (10, 0, 1, 75), (10, 1, 1, 74), (10, 2, 2, 73),
           (11, 0, 4, 74),
           (12, 0, 1, 73), (12, 1, 1, 72), (12, 2, 2, 70),
           (13, 0, 2, 72), (13, 2, 2, 70),
           (14, 0, 1, 68), (14, 1, 1, 70), (14, 2, 2, 72),
           (15, 0, 4, 70)]  # resolve Bb
    for b in range(16):
        r = roots[b % 4]
        s.bass(b, 0, 1.8, r, vol=0.24)
        s.bass(b, 2, 1.8, r, vol=0.20)
        s.snare(b, 1.0, vol=0.18)
        s.snare(b, 3.0, vol=0.18)
        for k in range(4):
            s.hat(b, k, vol=0.03)
    for bar, beat, dur, midi in mel:
        s.lead(bar, beat, dur, midi, vol=0.26)
    s.write("theater_meuse.wav")


def theater_argonne():
    # S29-S31 St Mihiel to Argonne: relentless G-minor push, fast 8th
    # bass, urgent lead, 132 BPM, 16 bars (~29s).
    s = Song(132.0, 16)
    roots = [43, 39, 46, 41]  # G2 Eb2 Bb2 F2
    mel = [(0, 0, 0.5, 74), (0, 0.5, 0.5, 77), (0, 1, 0.5, 79),
           (0, 1.5, 0.5, 77), (0, 2, 1, 74), (0, 3, 1, 72),
           (1, 0, 2, 74), (1, 2, 2, 70),
           (2, 0, 0.5, 72), (2, 0.5, 0.5, 75), (2, 1, 0.5, 77),
           (2, 1.5, 0.5, 75), (2, 2, 1, 72), (2, 3, 1, 70),
           (3, 0, 2, 72), (3, 2, 2, 67),
           (4, 0, 0.5, 74), (4, 0.5, 0.5, 77), (4, 1, 0.5, 79),
           (4, 1.5, 0.5, 81), (4, 2, 1, 79), (4, 3, 1, 77),
           (5, 0, 2, 76), (5, 2, 2, 74),
           (6, 0, 0.5, 72), (6, 0.5, 0.5, 74), (6, 1, 1, 76),
           (6, 2, 1, 74), (6, 3, 1, 72),
           (7, 0, 4, 70),
           (8, 0, 0.5, 79), (8, 0.5, 0.5, 81), (8, 1, 0.5, 83),
           (8, 1.5, 0.5, 81), (8, 2, 1, 79), (8, 3, 1, 77),
           (9, 0, 2, 79), (9, 2, 2, 76),
           (10, 0, 0.5, 74), (10, 0.5, 0.5, 76), (10, 1, 1, 79),
           (10, 2, 1, 81), (10, 3, 1, 79),
           (11, 0, 4, 81),
           (12, 0, 1, 79), (12, 1, 1, 77), (12, 2, 2, 76),
           (13, 0, 1, 74), (13, 1, 1, 72), (13, 2, 2, 70),
           (14, 0, 1, 72), (14, 1, 1, 70), (14, 2, 2, 69),
           (15, 0, 4, 67)]  # resolve G
    _drive_bass(s, 16, roots, vol=0.22)
    for b in range(16):
        for k in range(8):
            s.hat(b, k * 0.5, vol=0.032)
        s.snare(b, 1.0, vol=0.15)
        s.snare(b, 3.0, vol=0.15)
    for bar, beat, dur, midi in mel:
        s.lead(bar, beat, dur, midi, vol=0.25)
    s.write("theater_argonne.wav")


def theater_armistice():
    # S32 Armistice front: D-minor storm, timpani thunder, a D-major
    # triumph lift, then resolve to Dm for the loop, 100 BPM, 20 bars.
    s = Song(100.0, 20)
    roots = [38, 38, 34, 33, 38, 43, 38, 33,   # Dm Dm Bb A / Dm Gm Dm A
             38, 38, 43, 45, 38, 47, 43, 45,   # D D G A / D Bm G A
             38, 38, 34, 33]                    # Dm Dm Bb A
    mel = [(0, 0, 4, 62), (1, 0, 4, 64), (2, 0, 4, 65), (3, 0, 4, 64),
           (4, 0, 2, 62), (4, 2, 2, 60), (5, 0, 4, 62),
           (6, 0, 2, 64), (6, 2, 2, 65), (7, 0, 4, 64),
           (8, 0, 1, 74), (8, 1, 1, 76), (8, 2, 2, 77),
           (9, 0, 2, 79), (9, 2, 2, 77),
           (10, 0, 1, 76), (10, 1, 1, 74), (10, 2, 2, 72),
           (11, 0, 4, 74),
           (12, 0, 1, 78), (12, 1, 1, 81), (12, 2, 2, 83),  # D major lift
           (13, 0, 4, 86),
           (14, 0, 1, 84), (14, 1, 1, 83), (14, 2, 1, 81), (14, 3, 1, 78),
           (15, 0, 4, 81),
           (16, 0, 2, 79), (16, 2, 2, 77),  # back to Dm
           (17, 0, 2, 76), (17, 2, 2, 74),
           (18, 0, 2, 72), (18, 2, 2, 74),
           (19, 0, 4, 74)]  # resolve D
    for b in range(20):
        r = roots[b]
        s.bass(b, 0, 3.6, r, vol=0.24)
        s.bass(b, 0, 3.6, r + 12, vol=0.10)
        s.pad(b, r + 12, 1.0, vol=0.08)
        if b % 2 == 0:
            s.boom(b, 0, max(24, r - 12), vol=0.34, dur=1.6)
        if b >= 12:  # triumph: drums enter
            s.snare(b, 1.0, vol=0.16)
            s.snare(b, 3.0, vol=0.16)
            for k in range(8):
                s.hat(b, k * 0.5, vol=0.03)
    for bar, beat, dur, midi in mel:
        s.lead(bar, beat, dur, midi, vol=0.26)
    s.write("theater_armistice.wav")


# ------------------------------------------------------- boss stingers ----
def stingers():
    # short dramatic hits on boss spawn: ace (heroic rise), heavy
    # (massive dissonant slam), ghost (eerie wail).
    a = Song(120.0, 2)
    a.boom(0, 0, 26, vol=0.55, dur=1.6)
    for i, m in enumerate([74, 76, 77, 79, 81, 86]):
        a.lead(0, i * 0.5, 0.45, m, vol=0.34)
    a.snare(0, 2.0, vol=0.22)
    a.snare(1, 0.0, vol=0.26)
    a.bass(1, 0, 3.5, 38, vol=0.3)
    a.write("stinger_ace.wav")

    h = Song(100.0, 2)
    h.boom(0, 0, 24, vol=0.65, dur=2.2)
    h.boom(0, 1.0, 24, vol=0.5, dur=2.0)
    for m in (48, 49, 50):  # dissonant cluster slam
        h.lead(0, 0, 3.5, m, vol=0.22)
    h.pad(0, 36, 2.0, vol=0.16)
    h.snare(1, 2.0, vol=0.24)
    h.write("stinger_heavy.wav")

    g = Song(90.0, 2)
    g.gliss(0, 0, 3.2, 380.0, 1150.0, vol=0.20)
    g.pad(0, 40, 2.0, vol=0.14)  # E minor dread
    g.pad(0, 47, 2.0, vol=0.10)
    g.boom(1, 2.0, 28, vol=0.4, dur=1.4)
    g.lead(1, 0, 3.0, 76, vol=0.16)
    g.lead(1, 0, 3.0, 79, vol=0.12)
    g.write("stinger_ghost.wav")


if __name__ == "__main__":
    splash()
    pause()
    theater_training()
    theater_front()
    theater_industrial()
    theater_verdun()
    theater_vineyard()
    theater_salient()
    theater_meuse()
    theater_argonne()
    theater_armistice()
    stingers()
    # fuel warning: urgent two-tone beep, 0.7s, replayed by the game
    w = Song(120.0, 1)
    for i, m in enumerate([88, 88, 84, 84]):
        w.lead(0, i * 0.25, 0.22, m, vol=0.4)
    w.write("fuel_warn.wav")
    print("ALL TRACKS DONE")
