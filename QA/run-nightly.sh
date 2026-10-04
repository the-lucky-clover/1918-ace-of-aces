#!/usr/bin/env bash
# QA/run-nightly.sh — nightly verification for 1918 (web + Godot builds).
#
# Checks:
#   Godot: headless --import, 30s autostart smoke, boss-rush loop —
#          all asserting ZERO script errors.
#   Web:   static regression checks on 1918-ace-of-aces.html, including the
#          bug-001 photo-frame guards (artifactFlyIn keyframes must not force
#          transform:none in the `to` state; intro-play removal >= 1000ms).
#   GDScript: static hardening checks — squadron state resets per sortie,
#          both death paths arm the debrief timer (no stranded screens),
#          tween kill-guards present (no flicker stacking), empty-pool guard
#          in background generation, squadron goal helpers present,
#          the v10 1942 enemy pass model (states, wind-bank, exit despawn).
#   Sync:  VERSION file, splash ver-badge, and both global.gd copies agree.
#
# Writes QA/reports/YYYY-MM-DD.md with pass/fail per check.
# Exit 0 when every check passes, 1 otherwise.
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GODOT="$HOME/workspace/godot/Godot_v4.7.2-stable_linux.x86_64"
PROJECT="$HOME/workspace/1918-godot"
REPORT_DIR="$ROOT/QA/reports"
mkdir -p "$REPORT_DIR"
DATE="$(date +%Y-%m-%d)"
REPORT="$REPORT_DIR/$DATE.md"
OUT="$(mktemp)"

names=()
results=()
record() { names+=("$1"); results+=("$2"); }

# Run a godot command, fail on non-zero exit or script errors in output.
# (The "resources still in use at exit" / ObjectDB leak lines are benign.)
godot_check() {
    local name="$1"; shift
    : > "$OUT"
    if "$@" >"$OUT" 2>&1; then
        if grep -qiE 'script error|parse error|failed to (load|open|instance)' "$OUT"; then
            record "$name" "FAIL — script errors in godot output"
        else
            record "$name" "PASS"
        fi
    else
        record "$name" "FAIL — godot exited non-zero"
    fi
}

# Static regression checks on the web HTML.
web_check() {
    local name="$1"; shift
    if python3 - "$@" <<'PYEOF' >"$OUT" 2>&1; then
import re, sys

src = open('1918-ace-of-aces.html').read()

def keyframes_block():
    i = src.find('@keyframes artifactFlyIn')
    if i < 0:
        return None
    j = src.find('{', i)
    depth = 0
    for k in range(j, len(src)):
        if src[k] == '{':
            depth += 1
        elif src[k] == '}':
            depth -= 1
            if depth == 0:
                return src[j:k + 1]
    return None

check = sys.argv[1]
if check == 'photo-keyframes':
    blk = keyframes_block()
    if blk is None:
        sys.exit('artifactFlyIn keyframes not found')
    m = re.search(r'to\s*\{([^}]*)\}', blk)
    if m is None:
        sys.exit('no `to` state in artifactFlyIn')
    if 'transform:none' in m.group(1).replace(' ', ''):
        sys.exit('`to` state forces transform:none (bug 001 regression)')
elif check == 'intro-timeout':
    m = re.search(r"remove\('intro-play'\)\},\s*(\d+)", src)
    if m is None:
        sys.exit('intro-play removal timeout not found')
    if int(m.group(1)) < 1000:
        sys.exit('intro-play removal timeout %sms < 1000ms' % m.group(1))
elif check == 'version-sync':
    ver = open('VERSION').read().strip()
    b = re.search(r'class="ver-badge">v(\d+)</span>', src)
    if b is None or b.group(1) != ver:
        sys.exit('splash badge v%s != VERSION %s' % (b.group(1) if b else '?', ver))
    for gd in ('/home/hatch/workspace/1918-godot/scripts/global.gd',
               'godot/scripts/global.gd'):
        g = open(gd).read()
        gm = re.search(r'const VERSION: String = "(\d+)"', g)
        if gm is None or gm.group(1) != ver:
            sys.exit('const VERSION in %s != %s' % (gd, ver))
PYEOF
        record "$name" "PASS"
    else
        record "$name" "FAIL — $(cat "$OUT" | head -1)"
    fi
}

# Static checks on the Godot GDScript sources (flicker/shutdown hardening).
gdscript_check() {
    local name="$1"; shift
    if python3 - "$@" <<'PYEOF' >"$OUT" 2>&1; then
import re, sys

P = '/home/hatch/workspace/1918-godot/scripts/'
def read(f):
    return open(P + f).read()

check = sys.argv[1]
if check == 'squadron-reset':
    m = read('main.gd')
    for pat in ('squad_kills = 0', 'Global.squadron_broken = false',
                'squad_broken = false'):
        if pat not in m:
            sys.exit('start_sortie missing reset: %s' % pat)
elif check == 'debrief-paths':
    m = read('main.gd')
    # both death paths must arm the debrief timer — no stranded screens
    for fn in ('_on_player_died', '_on_boss_killed'):
        i = m.find('func ' + fn)
        if i < 0:
            sys.exit(fn + ' not found')
        if 'debrief_timer' not in m[i:i + 400]:
            sys.exit(fn + ' does not arm debrief_timer')
elif check == 'tween-guards':
    # flicker guards: kill-before-create on hot modulate/alpha tweens
    pairs = (('hud.gd', '_score_tween'), ('hud.gd', '_hull_tween'),
             ('main.gd', '_fade_tween'))
    for f, v in pairs:
        src = read(f)
        if (v + ' != null') not in src or '.kill()' not in src:
            sys.exit('%s: %s kill-guard missing' % (f, v))
    # effects.gd stores its guard in item meta rather than a member var
    fx = read('effects.gd')
    if 'has_meta("_flash_tween")' not in fx or '.kill()' not in fx:
        sys.exit('effects.gd: _flash_tween kill-guard missing')
elif check == 'pool-guard':
    b = read('background.gd')
    i = b.find('func generate(')
    blk = b[i:i + 600]
    if 'pool.is_empty()' not in blk:
        sys.exit('generate() missing empty-pool guard (modulo-by-zero risk)')
elif check == 'squadron-goals-sane':
    s = read('sortie_data.gd')
    if 'SQUADRON_TYPES' not in s or 'squadron_goal' not in s:
        sys.exit('squadron goal helpers missing from sortie_data.gd')
elif check == 'truck-secondary-sane':
    s = read('sortie_data.gd')
    if '"trucks"' not in s:
        sys.exit('trucks secondary missing from SECONDARY_DEFS')
    mm = read('minimap.gd')
    if '"trucks": "truck"' not in mm:
        sys.exit('minimap SEC_ETYPE missing trucks->truck')
    m = read('main.gd')
    i = m.find('sec_id = "trucks"')
    if i < 0 or '"truck":' not in m[max(0, i - 200):i]:
        sys.exit('main.gd kill-match missing "truck" -> "trucks"')
elif check == 'atmosphere-wired':
    import os
    if not os.path.exists(P + 'atmosphere.gd'):
        sys.exit('atmosphere.gd missing')
    m = read('main.gd')
    for pat in ('AtmosphereScript', '_atmo', '_atmo.setup'):
        if pat not in m:
            sys.exit('main.gd missing atmosphere wiring: %s' % pat)
    if 'layer = 4' not in m:
        sys.exit('main.gd: atmosphere CanvasLayer not on layer 4')
elif check == 'atmosphere-precompute':
    a = read('atmosphere.gd')
    i = a.find('func _ready()')
    if i < 0:
        sys.exit('atmosphere.gd has no _ready()')
    ready = a[i:a.find('func ', i + 12) if a.find('func ', i + 12) > 0 else len(a)]
    for tex in ('_grain_tex', '_vign_tex', '_haze_tex', '_shaft_tex', '_scorch_tex'):
        if tex not in ready:
            sys.exit('texture not precomputed in _ready(): %s' % tex)
    i = a.find('func _draw()')
    nxt = a.find('\nfunc ', i)
    drawblk = a[i:nxt] if nxt > 0 else a[i:i + 4000]
    if 'ImageTexture.create_from_image' in drawblk or 'Image.create(' in drawblk:
        sys.exit('_draw() regenerates textures per-frame (must be precomputed)')
elif check == 'camera-iron-rule':
    # camera stays strictly top-down: pan and zoom only, never rotation/tilt
    m = read('main.gd')
    if 'camera.rotation' in m:
        sys.exit('main.gd touches camera rotation')
    tscn = open('/home/hatch/workspace/1918-godot/scenes/main.tscn').read()
    camblk = tscn.split('type="Camera2D"')[1][:300]
    if 'rotation' in camblk or 'zoom' in camblk:
        sys.exit('Camera2D has rotation/zoom set in main.tscn')
    c = read('cinematic.gd')
    # the virtual camera may only ever change _cam_c (pan) and _cam_z (zoom);
    # in-plane aircraft banking via _plane() is exempt (it is not the camera)
    for line in c.splitlines():
        s = line.strip()
        if s.startswith('_cam_') and '=' in s and '==' not in s:
            var = s.split('=')[0].strip()
            if var not in ('_cam_c', '_cam_z'):
                sys.exit('cinematic writes unexpected camera var: %s' % var)
elif check == 'airfield-spawn':
    m = read('main.gd')
    if 'AirfieldScript' not in m or 'etype == "airfield"' not in m:
        sys.exit('main.gd missing airfield spawn path')
    a = read('airfield.gd')
    # the airfield is a visual cluster on its own group; its parked
    # aircraft register as individual "enemies" targets
    if 'add_to_group("airfields")' not in a:
        sys.exit('airfield.gd not in airfields group')
elif check == 'gas-system-sane':
    import os
    if not os.path.exists(P + 'gas_cloud.gd'):
        sys.exit('gas_cloud.gd missing')
    g = read('gas_cloud.gd')
    for pat in ('add_to_group("gasclouds")', 'take_gas_damage', 'Global.wind'):
        if pat not in g:
            sys.exit('gas_cloud.gd missing: %s' % pat)
    m = read('main.gd')
    if 'GasCloudScript' not in m or 'etype == "gasstrike"' not in m:
        sys.exit('main.gd missing gasstrike spawn path')
    p = read('player.gd')
    for pat in ('gasmask_t', 'take_gas_damage', 'power_gasmask'):
        if pat not in p:
            sys.exit('player.gd missing gas wiring: %s' % pat)
    pk = read('pickup.gd')
    if '"gasmask"' not in pk or '_make_gasmask_texture' not in pk:
        sys.exit('pickup.gd missing gasmask pickup path')
    e = read('enemy.gd')
    if '"gasmask"' not in e:
        sys.exit('enemy.gd drop pool missing gasmask')
    s = read('sortie_data.gd')
    if '"gasstrike"' not in s:
        sys.exit('sortie_data.gd has no gasstrike waves')
    mm = read('minimap.gd')
    if '"gasclouds"' not in mm:
        sys.exit('minimap.gd does not render gas clouds')
elif check == 'chateau-roads-sane':
    b = read('background.gd')
    for pat in ('"chateau":', '"road_paved":', '"road_cross":'):
        if pat not in b:
            sys.exit('background.gd missing draw case: %s' % pat)
    # the farmland pool lives in the POOLS const near the top of the file
    i = b.find('"farmland": [')
    blk = b[i:i + 700]
    for pat in ('"road_paved"', '"road_cross"'):
        if pat not in blk:
            sys.exit('farmland pool missing: %s' % pat)
    if '"kind": "chateau"' not in b:
        sys.exit('background.gd missing chateau placement block')
elif check == 'flak-secondary-sane':
    s = read('sortie_data.gd')
    if '"flak"' not in s:
        sys.exit('flak secondary missing from SECONDARY_DEFS')
    mm = read('minimap.gd')
    if '"flak": "aagun"' not in mm:
        sys.exit('minimap SEC_ETYPE missing flak->aagun')
    m = read('main.gd')
    i = m.find('sec_id = "flak"')
    if i < 0 or '"aagun":' not in m[max(0, i - 200):i]:
        sys.exit('main.gd kill-match missing "aagun" -> "flak"')
elif check == 'graze-streak-sane':
    bl = read('bullet.gd')
    if 'award_graze' not in bl:
        sys.exit('bullet.gd missing graze call')
    m = read('main.gd')
    for pat in ('func award_graze', 'air_streak = 0', '"RAMPAGE!"', 'HEDGE-HOPPER'):
        if pat not in m:
            sys.exit('main.gd missing streak/graze wiring: %s' % pat)
    bo = read('boss.gd')
    if 'TAUNTS' not in bo:
        sys.exit('boss.gd missing taunt table')
elif check == 'ground-war-two-way':
    tt = read('trench_target.gd')
    for pat in ('_open_fire', 'BulletScene', 'mg_chatter', 'rifle_pop',
                'windup = 0.35', 'bool(player.get("alive"))'):
        if pat not in tt:
            sys.exit('trench_target.gd missing pot-shot wiring: %s' % pat)
    td = read('tank_duel.gd')
    for pat in ('_aa_potshot', 'rumble_at', 'tank_boom', '"french"', '"uk"',
                'n_allied = 2', 'n_german = 2'):
        if pat not in td:
            sys.exit('tank_duel.gd missing v9 tank-war wiring: %s' % pat)
    gw = read('ground_war.gd')
    if '_dirt_kick' not in gw or 'rifle pops' not in gw:
        sys.exit('ground_war.gd missing infantry-battle iteration')
    s = read('sfx.gd')
    for pat in ('tank_boom', 'mg_chatter', 'rifle_pop'):
        if pat not in s:
            sys.exit('sfx.gd missing v9 sound: %s' % pat)
    sd = read('sortie_data.gd')
    if sd.count('"lore"') != 6:
        sys.exit('sortie_data.gd: expected 6 lore lines, found %d' % sd.count('"lore"'))
elif check == 'enemy-pass-model':
    # v10: the 1942 pass — ENTER → ATTACK (guns live) → TURN (180° bank into
    # the wind) → EXIT (off the top, despawned). Ground/naval targets exempt.
    import os
    e = read('enemy.gd')
    for pat in ('PASS_ENTER', 'PASS_ATTACK', 'PASS_TURN', 'PASS_EXIT',
                'TURN_Y', '_begin_turn', '_attack_run', '_legacy_move',
                'pass_exempt', 'Global.wind', 'bank_puff', 'bank_whoosh'):
        if pat not in e:
            sys.exit('enemy.gd missing 1942 pass-model piece: %s' % pat)
    fx = read('effects.gd')
    if 'BankPuffScript' not in fx or 'func bank_puff' not in fx:
        sys.exit('effects.gd missing bank_puff contrail')
    if not os.path.exists(P + 'fx/bank_puff.gd'):
        sys.exit('scripts/fx/bank_puff.gd missing')
    s = read('sfx.gd')
    if '"bank_whoosh"' not in s:
        sys.exit('sfx.gd missing bank_whoosh registration')
    if not os.path.exists('/home/hatch/workspace/1918-godot/assets/sfx/bank_whoosh.wav'):
        sys.exit('assets/sfx/bank_whoosh.wav missing')
    m = read('main.gd')
    if 'brief_txt' not in m or 's.has("lore")' not in m:
        sys.exit('main.gd missing lore brief wiring')
PYEOF
        record "$name" "PASS"
    else
        record "$name" "FAIL — $(cat "$OUT" | head -1)"
    fi
}

# --- run the checks ---
godot_check "godot-import"      "$GODOT" --headless --path "$PROJECT" --import
godot_check "godot-smoke-30s"   "$GODOT" --headless --path "$PROJECT" --quit-after 1800 -- --autostart
godot_check "godot-boss-rush"   "$GODOT" --headless --path "$PROJECT" --quit-after 3600 -- --autostart --autoboss
# sortie sweep: every sortie's weather, waves, and flak paths must run clean
for s in 0 1 2 3 4 5; do
    godot_check "godot-sortie-$((s+1))" "$GODOT" --headless --path "$PROJECT" --quit-after 1500 -- --autostart --sortie="$s"
done
web_check   "web-photo-keyframes" photo-keyframes
web_check   "web-intro-timeout"   intro-timeout
web_check   "web-version-sync"    version-sync
gdscript_check "gdscript-squadron-reset"  squadron-reset
gdscript_check "gdscript-debrief-paths"  debrief-paths
gdscript_check "gdscript-tween-guards"   tween-guards
gdscript_check "gdscript-pool-guard"     pool-guard
gdscript_check "gdscript-squadron-goals" squadron-goals-sane
gdscript_check "gdscript-truck-secondary" truck-secondary-sane
gdscript_check "gdscript-airfield-spawn"  airfield-spawn
gdscript_check "gdscript-atmosphere-wired" atmosphere-wired
gdscript_check "gdscript-atmosphere-precompute" atmosphere-precompute
gdscript_check "gdscript-camera-iron-rule" camera-iron-rule
gdscript_check "gdscript-gas-system" gas-system-sane
gdscript_check "gdscript-chateau-roads" chateau-roads-sane
gdscript_check "gdscript-flak-secondary" flak-secondary-sane
gdscript_check "gdscript-graze-streak" graze-streak-sane
gdscript_check "gdscript-ground-war-two-way" ground-war-two-way
gdscript_check "gdscript-enemy-pass-model" enemy-pass-model

# --- write the report ---
VER="$(tr -d '[:space:]' < VERSION)"
pass=0; fail=0
{
    echo "# Nightly QA report — $DATE"
    echo ""
    echo "Version under test: **v$VER**"
    echo "Godot binary: \`$GODOT\` (4.7.2)"
    echo ""
    for i in "${!names[@]}"; do
        if [[ "${results[$i]}" == PASS* ]]; then
            echo "- [x] ${names[$i]} — ${results[$i]}"
            pass=$((pass + 1))
        else
            echo "- [ ] ${names[$i]} — ${results[$i]}"
            fail=$((fail + 1))
        fi
    done
    echo ""
    echo "**$pass passed, $fail failed**"
} > "$REPORT"

rm -f "$OUT"
echo "Report: QA/reports/$DATE.md — $pass passed, $fail failed"
[ "$fail" -eq 0 ]
