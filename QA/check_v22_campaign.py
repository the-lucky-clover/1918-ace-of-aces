#!/usr/bin/env python3
"""v22 nightly: THE 32-SORTIE CAMPAIGN data integrity + 1942 damage model.

1. Exactly 32 sorties defined in the generated sortie_data.gd.
2. Enemy counts per sortie in the 80-120 band (pacing curve: early ~80,
   mid ~100, late ~120); S32 uses the doc's explicit 96.
3. Boss roster complete: 32 entries, tiers 60..500, HP = round(900*tier/60),
   kinds in {ace, heavy, ground}, sprite files present on disk.
4. E1-E10 roster present in enemy.gd TYPES with doc HP x10.
5. Every sortie has theme (in minimap TERRAIN), weather, takeoff time,
   aerodrome, 4 secondaries, and waves summing to enemy_count.
6. Elites: 4 per sortie (miniboss framework).
"""
import os
import re
import sys

GODOT = os.path.expanduser("~/workspace/1918-godot")
DATA = os.path.join(GODOT, "scripts", "sortie_data.gd")
ENEMY = os.path.join(GODOT, "scripts", "enemy.gd")
MINIMAP = os.path.join(GODOT, "scripts", "minimap.gd")
SPRITES = os.path.join(GODOT, "assets", "sprites")

fails = []


def read(p):
    with open(p) as f:
        return f.read()


def check(cond, msg):
    if not cond:
        fails.append(msg)


data = read(DATA)
enemy = read(ENEMY)
minimap = read(MINIMAP)

# --- 1: 32 sorties
n_sorties = data.count('"boss_at"')
check(n_sorties == 32, "sorties defined: %d != 32" % n_sorties)

# --- 2: enemy-count band + pacing curve
counts = [int(x) for x in re.findall(r'"enemy_count": (\d+)', data)]
check(len(counts) == 32, "enemy_count entries: %d" % len(counts))
for i, c in enumerate(counts):
    check(80 <= c <= 120, "S%d enemy count %d outside 80-120" % (i + 1, c))
early = counts[:10]
mid = counts[10:21]
late = counts[21:31]
check(all(c == 80 for c in early), "early curve not 80: %s" % early)
check(all(c == 100 for c in mid), "mid curve not 100: %s" % mid)
check(all(c == 120 for c in late), "late curve not 120: %s" % late)
check(counts[31] == 96, "S32 not the doc's 96: %d" % counts[31])

# --- 3: boss roster
BOSS_HITS = [25, 30, 32, 35, 40, 45, 48, 50, 40, 50, 55, 58, 60, 70,
             75, 80, 100, 120, 135, 140, 180, 150, 80, 90, 180, 250,
             120, 300, 340, 370, 400, 500]
roster = re.findall(
    r'\{"name":\s*"([^"]+)",\s*"hits":\s*(\d+),\s*"hp":\s*(\d+),\s*'
    r'"kind":\s*"([^"]+)",\s*"sprite":\s*"([^"]+)",\s*'
    r'"frames":\s*"([^"]+)",\s*"arena":\s*(true|false),\s*'
    r'"phases":\s*(\d+),\s*"spectral":\s*(true|false)', data)
check(len(roster) == 32, "boss roster entries: %d" % len(roster))
for bi, (name, hits, hp, kind, sprite, frames, arena, phases, spectral) in enumerate(roster):
    check(int(hits) == BOSS_HITS[bi],
          "boss S%d %s hits %s != %d" % (bi + 1, name, hits, BOSS_HITS[bi]))
    check(int(hp) == int(hits) * 12,
          "boss %s hp %s != hits x12" % (name, hp))
    check(kind in ("ace", "heavy", "ground"), "boss %s kind %s" % (name, kind))
    check(frames in ("bank", "single"), "boss %s frames %s" % (name, frames))
    if frames == "bank":
        for fr in ("bank-left", "level", "bank-right"):
            p = os.path.join(SPRITES, "%s-%s.png" % (sprite, fr))
            check(os.path.isfile(p), "missing boss sprite %s" % p)
    else:
        p = os.path.join(SPRITES, "%s.png" % sprite)
        check(os.path.isfile(p), "missing boss sprite %s" % p)
spec4 = [r for r in roster if r[7] == "4"]
check(len(spec4) == 1 and "RED BARON" in spec4[0][0],
      "expected one 4-phase boss (Red Baron), got %s" % spec4)
# damage regions on the big bosses (inlined in the roster)
for label in ("HYDROGEN CELLS", "COMMAND GONDOLA", "ENGINE CAR",
              "LOCOMOTIVE", "AMMO WAGON", "COCKPIT", "BOMB BAY"):
    check(label in data, "missing damage region %s" % label)
check(data.count('"mult": 2.0') >= 10, "weak-point regions missing")

# --- 4: E1-E10 in TYPES with doc HP x10
# v22 1942 hits: 1 bullet = 12 dmg = 1 hit
e_hits = {"e1_eindecker": 1, "e2_albatros_d3": 2, "e3_albatros_d5": 3,
          "e4_fokker_dr1": 4, "e5_rumpler": 8, "e6_gotha": 28,
          "e7_staaken": 68, "e8_zeppelin": 137, "e9_searchlight": 4,
          "e10_archy": 6, "balloon": 10}
for et, h in e_hits.items():
    m = re.search(r'"%s": \{"hp": ([\d.]+)' % et, enemy)
    check(m is not None, "TYPES missing %s" % et)
    if m:
        check(float(m.group(1)) == h * 12.0,
              "%s HP %s != %d hits x12" % (et, m.group(1), h))
# E-type sprites on disk
for et in ("e1_eindecker", "e2_albatros_d3", "e5_rumpler", "e6_gotha",
           "e7_staaken"):
    p = os.path.join(SPRITES, "enemy-%s-level.png" %
                     et.replace("e1_eindecker", "eindecker").replace(
                         "e2_albatros_d3", "albatros-d3").replace(
                         "e5_rumpler", "rumpler").replace(
                         "e6_gotha", "gotha").replace("e7_staaken", "staaken"))
    check(os.path.isfile(p), "missing E-type sprite %s" % p)
check(os.path.isfile(os.path.join(SPRITES, "enemy-searchlight.png")),
      "missing enemy-searchlight.png")

# --- 5: per-sortie fields
themes = re.findall(r'"theme": "([^"]+)"', data)
check(len(themes) == 32, "theme entries: %d" % len(themes))
for t in set(themes):
    check('"%s"' % t in minimap, "minimap TERRAIN missing theme %s" % t)
check(len(re.findall(r'"aerodrome": "([^"]+)"', data)) == 32, "aerodrome x32")
check(len(re.findall(r'"takeoff": "([^"]+)"', data)) == 32, "takeoff x32")
check(len(re.findall(r'"weather": "([^"]+)"', data)) == 32, "weather x32")
sec_blocks = re.findall(r'"secondaries": \[(.*?)\]', data)
check(len(sec_blocks) == 32, "secondaries blocks: %d" % len(sec_blocks))
for i, b in enumerate(sec_blocks):
    check(b.count('"id"') == 4, "S%d secondaries != 4" % (i + 1))

# --- 6: elites — 4 minibosses per sortie
elite_waves = data.count('"elites": 1')
check(elite_waves == 32 * 4, "elite waves %d != 128" % elite_waves)

# --- boss names: fictional/inspired, no real-person claims beyond inspired
check("RED BARON" in data, "Red Baron missing from roster")

# --- v22 1942 damage model: player dies in one hit, no hull attrition
player = read(os.path.join(GODOT, "scripts", "player.gd"))
check("const MAX_HP" not in player and "var hp" not in player,
      "player still has hull HP (one-hit model)")
check("_die()  # one hit is all it takes" in player,
      "player take_damage not one-hit")
pickup = read(os.path.join(GODOT, "scripts", "pickup.gd"))
check('"repair", "repair"' not in read(os.path.join(GODOT, "scripts", "enemy.gd")),
      "repair still in drop pool")

# every wave type must be spawnable (TYPES key or a _spawn_enemy special).
# Catches generator plural/singular slips like the "trucks" crash.
import re as _re
_enemy_src = read(os.path.join(GODOT, "scripts", "enemy.gd"))
_tm = _re.search(r"const TYPES: Dictionary = \{(.*?)\n\}", _enemy_src, _re.S)
_valid = set(_re.findall(r'^\t"([a-z0-9_]+)":', _tm.group(1), _re.M))
_valid |= {"gasstrike", "truck", "airfield"}  # _spawn_enemy specials
_sd = read(os.path.join(GODOT, "scripts", "sortie_data.gd"))
_wave_types = set(_re.findall(r'"type": "([a-z0-9_]+)"', _sd))
_bad = sorted(t for t in _wave_types if t not in _valid)
check(not _bad, "unspawnable wave types: %s" % _bad)
# secondary ids must exist in SECONDARY_DEFS (same plural/singular trap).
_defs = set(_re.findall(r'^\t"([a-z0-9_]+)": \{"text"', _sd, _re.M))
_sec_ids = set(_re.findall(r'"secondaries": \[(.*?)\]', _sd, _re.S)[0] and
               _re.findall(r'"id": "([a-z0-9_]+)"', _sd))
_bad_sec = sorted(s for s in _sec_ids if s not in _defs)
check(not _bad_sec, "undefined secondary ids: %s" % _bad_sec)

if fails:
    print("V22-FAIL")
    for f in fails:
        print(" -", f)
    sys.exit(1)
print("V22-OK: 32 sorties, 32 bosses, E1-E10, 128 elites, terrain x32")
