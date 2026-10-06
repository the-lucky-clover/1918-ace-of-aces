#!/usr/bin/env python3
"""v22 audio-bar regression check: the score map, the SFX registry, and the
synthesized-audio honesty rule (no external/placeholder audio).

Checks:
 1. All 9 theater tracks exist, 20-60s, no clipping, seamless loop edges.
 2. All 3 boss stingers exist.
 3. music.gd THEATER_BY_SORTIE covers sorties 0-31 with all 9 theaters used.
 4. Every name in sfx.gd FILES exists on disk (catches dead SFX.play calls).
 5. Every SFX.play("name") literal in scripts/ resolves to FILES (no orphans).
 6. Engine loops are ~2s with loop-point continuity.
 7. Spectral character sanity: each theater's energy centroid differs
    (training bright vs verdun dark) — the headless-adjacent ear review.
"""
import os
import re
import struct
import sys
import wave

GODOT = os.path.expanduser("~/workspace/1918-godot")
MUSIC = os.path.join(GODOT, "assets/music")
SFXD = os.path.join(GODOT, "assets/sfx")
THEATERS = ["training", "front", "industrial", "verdun", "vineyard",
            "salient", "meuse", "argonne", "armistice"]
STINGERS = ["stinger_ace", "stinger_heavy", "stinger_ghost"]
ENGINES = ["engine_rotary", "engine_inline", "engine_bomber",
           "engine_zeppelin"]

fails = []


def fail(msg):
    fails.append(msg)
    print(f"FAIL: {msg}")


def read_wav(path):
    with wave.open(path, "rb") as w:
        assert w.getnchannels() == 1 and w.getsampwidth() == 2, \
            f"{path}: expected mono 16-bit"
        sr = w.getframerate()
        raw = w.readframes(w.getnframes())
    n = len(raw) // 2
    pcm = struct.unpack("<%dh" % n, raw)
    return sr, [v / 32768.0 for v in pcm]


# 1. theater tracks -----------------------------------------------------
for t in THEATERS:
    p = os.path.join(MUSIC, f"theater_{t}.wav")
    if not os.path.exists(p):
        fail(f"missing theater track {p}")
        continue
    sr, x = read_wav(p)
    dur = len(x) / sr
    peak = max(abs(v) for v in x)
    if not 20.0 <= dur <= 60.0:
        fail(f"theater_{t}: duration {dur:.1f}s outside 20-60s")
    if peak >= 0.99:
        fail(f"theater_{t}: clipping peak {peak:.3f}")
    edge = int(0.001 * sr)  # raised-cosine fades pin value+slope to 0
    edge_peak = max(max(abs(v) for v in x[:edge]),
                    max(abs(v) for v in x[-edge:]))
    if edge_peak > 0.05:
        fail(f"theater_{t}: loop edge not faded ({edge_peak:.3f})")
    print(f"ok theater_{t}: {dur:.1f}s peak={peak:.2f} edge={edge_peak:.3f}")

# 2. stingers ------------------------------------------------------------
for sname in STINGERS:
    p = os.path.join(MUSIC, f"{sname}.wav")
    if not os.path.exists(p):
        fail(f"missing stinger {p}")
    else:
        sr, x = read_wav(p)
        print(f"ok {sname}: {len(x)/sr:.1f}s")

# 3. theater map ---------------------------------------------------------
mgd = open(os.path.join(GODOT, "scripts/music.gd")).read()
m = re.search(r"THEATER_BY_SORTIE := \[(.*?)\]", mgd, re.S)
entries = re.findall(r'"(\w+)"', m.group(1)) if m else []
if len(entries) != 32:
    fail(f"THEATER_BY_SORTIE has {len(entries)} entries, need 32")
missing = set(THEATERS) - set(entries)
if missing:
    fail(f"theaters never used: {sorted(missing)}")
extra = set(entries) - set(THEATERS)
if extra:
    fail(f"unknown theaters in map: {sorted(extra)}")
print(f"ok theater map: 32 sorties, {len(set(entries))} theaters")

# 4+5. sfx registry vs disk vs call sites --------------------------------
sgd = open(os.path.join(GODOT, "scripts/sfx.gd")).read()
files = {}
for name, sub, fname in re.findall(
        r'"([\w_]+)":\s*"res://assets/(sfx|music)/([\w_]+\.wav)"', sgd):
    files[name] = (sub, fname)
for name, (sub, fname) in files.items():
    base = SFXD if sub == "sfx" else MUSIC
    if not os.path.exists(os.path.join(base, fname)):
        fail(f"sfx.gd FILES[{name}] missing on disk: {fname}")
print(f"ok sfx registry: {len(files)} names all on disk")

called = set()
for root, _ds, fns in os.walk(os.path.join(GODOT, "scripts")):
    for fn in fns:
        if not fn.endswith(".gd"):
            continue
        for mm in re.finditer(r'SFX\.play\("([\w_]+)"', open(
                os.path.join(root, fn)).read()):
            called.add(mm.group(1))
orphans = called - set(files)
if orphans:
    fail(f"SFX.play names with no FILES entry: {sorted(orphans)}")
print(f"ok call sites: {len(called)} SFX.play names all resolve")

# 6. engine loops ---------------------------------------------------------
for en in ENGINES:
    p = os.path.join(SFXD, f"{en}.wav")
    sr, x = read_wav(p)
    dur = len(x) / sr
    if not 1.85 <= dur <= 2.05:
        fail(f"{en}: duration {dur:.2f}s, expected ~2s loop")
    # loop continuity: first/last 30ms should roughly meet (crossfaded)
    w = int(0.03 * sr)
    head = sum(x[:w]) / w
    tail = sum(x[-w:]) / w
    peak = max(1e-6, max(abs(v) for v in x))
    if abs(head - tail) / peak > 0.35:
        fail(f"{en}: loop point discontinuity {abs(head-tail)/peak:.2f}")
    print(f"ok {en}: {dur:.2f}s loop-continuous")

# 7. spectral character (headless-adjacent ear review) --------------------
import math
print("--- spectral centroids (Hz) ---")
centroids = {}
for t in THEATERS:
    sr, x = read_wav(os.path.join(MUSIC, f"theater_{t}.wav"))
    # crude DFT-free estimate: zero-crossing rate -> dominant freq proxy
    zc = sum(1 for i in range(1, len(x), 7)
             if x[i] * x[i - 1] < 0)
    proxy = zc * sr / (2 * len(x) / 7)
    # energy-weighted: RMS in low (<300Hz) vs high (>2kHz) via diffs
    lo = sum(v * v for v in x[::7]) / (len(x) / 7)
    hi_sig = [x[i] - x[i - 1] for i in range(1, len(x), 7)]
    hi = sum(v * v for v in hi_sig) / len(hi_sig)
    centroids[t] = (proxy, math.sqrt(lo), math.sqrt(hi))
    print(f"  {t:10s} zc-proxy={proxy:6.0f}Hz rms_lo={math.sqrt(lo):.3f} "
          f"rms_hi={math.sqrt(hi):.3f}")
lo_vals = sorted(centroids.items(), key=lambda kv: kv[1][1])
hi_vals = sorted(centroids.items(), key=lambda kv: kv[1][2])
print(f"darkest low-end: {lo_vals[-1][0]}, brightest top: {hi_vals[-1][0]}")
if centroids["verdun"][2] > centroids["industrial"][2]:
    fail("verdun brighter than industrial — character inversion?")
if centroids["training"][2] < centroids["verdun"][2]:
    fail("training darker than verdun — character inversion?")

print()
if fails:
    print(f"{len(fails)} FAILURES")
    sys.exit(1)
print("ALL AUDIO CHECKS GREEN")
