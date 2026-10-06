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
export ROOT
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
    # v22: _hull_tween retired with the hull bar (1942 one-hit model) —
    # update_integrity is a no-op, so there is nothing left to guard.
    pairs = (('hud.gd', '_score_tween'), ('main.gd', '_fade_tween'))
    for f, v in pairs:
        src = read(f)
        if (v + ' != null') not in src or '.kill()' not in src:
            sys.exit('%s: %s kill-guard missing' % (f, v))
    if '_hull_tween' in read('hud.gd'):
        sys.exit('hud.gd: _hull_tween should be retired (v22 one-hit model)')
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
    # v22: the secondary id is "truck" (singular) — matches SECONDARY_DEFS.
    if '"truck"' not in s:
        sys.exit('truck secondary missing from SECONDARY_DEFS')
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
    # v22: gas strikes are a per-sortie schedule key ("gas_strikes"), not a
    # wave etype — and main.gd must actually schedule them (they were once
    # authored but never spawned).
    if '"gas_strikes"' not in s:
        sys.exit('sortie_data.gd has no gas_strikes schedule key')
    m2 = read('main.gd')
    if '"gas_strikes"' not in m2 or '"gasstrike"' not in m2:
        sys.exit('main.gd does not schedule gas_strikes')
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
    # v22: 32 sorties each carry a brief (lore lines are optional flavor —
    # main.gd guards with s.has("lore")).
    if sd.count('"brief"') != 32:
        sys.exit('sortie_data.gd: expected 32 sortie briefs, found %d'
                 % sd.count('"brief"'))
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
elif check == 'lighting-schedule':
    # v14: every sortie has a valid takeoff; the true-north sun model
    # returns sane (non-NaN) light state for each; night sorties exist;
    # the background and atmosphere actually read the sun rig.
    import math
    sd = read('sortie_data.gd')
    takeoffs = re.findall(r'"takeoff":\s*"(\d\d:\d\d)"', sd)
    if len(takeoffs) < 7:
        sys.exit('expected >=7 sortie takeoffs, found %d' % len(takeoffs))
    def solar(mins):
        lat = math.radians(48.9); dec = math.radians(18.8)
        h = math.radians((mins / 60.0 - 12.0) * 15.0)
        sin_e = math.sin(lat) * math.sin(dec) + math.cos(lat) * math.cos(dec) * math.cos(h)
        sin_e = max(-1.0, min(1.0, sin_e))
        elev = math.degrees(math.asin(sin_e))
        cos_az = (math.sin(dec) - math.sin(lat) * sin_e) / max(0.001, math.cos(lat) * math.cos(math.asin(sin_e)))
        az = math.degrees(math.acos(max(-1.0, min(1.0, cos_az))))
        if h > 0: az = 360.0 - az
        return elev, az
    nights = 0
    for t in takeoffs:
        hh, mm = int(t[:2]), int(t[3:])
        if not (0 <= hh < 24 and 0 <= mm < 60):
            sys.exit('bad takeoff time: %s' % t)
        elev, az = solar(hh * 60 + mm)
        if math.isnan(elev) or math.isnan(az):
            sys.exit('sun model NaN for takeoff %s' % t)
        if elev < -0.5: nights += 1
    if nights < 1:
        sys.exit('no night sortie scheduled — night vs noon variety missing')
    bg = read('background.gd')
    if 'Sun.current' not in bg or 'ambient' not in bg:
        sys.exit('background.gd ignores the sun rig ambient')
    at = read('atmosphere.gd')
    if '_stars_tex' not in at or '_night' not in at:
        sys.exit('atmosphere.gd missing night mode')
    af = read('airfield.gd')
    if '_draw_bessonneau' not in af or '_draw_hat_in_ring' not in af or '_draw_flare_pots' not in af:
        sys.exit('airfield.gd missing 94th rebuild pieces')
    sn = read('sun.gd')
    if 'LAT_DEG' not in sn or 'screen-up IS North' not in sn:
        sys.exit('sun.gd missing true-north documentation')
elif check == 'german-roster':
    # v15: the Luftstreitkräfte roster — German aircraft with real
    # identities, Balkenkreuz sprites, squadron membership, Kette doctrine,
    # A7V armor, German airfield flavor, German parked aircraft.
    # v22: the universal E1-E10 roster carries the identities now.
    import os
    e = read('enemy.gd')
    for t in ('e1_eindecker', 'e2_albatros_d3', 'e3_albatros_d5',
              'e4_fokker_dr1', 'parked_ger'):
        if '"%s"' % t not in e:
            sys.exit('enemy.gd missing Luftstreitkräfte type: %s' % t)
    for pat in ('wfreq', 'wamp', 'kette', 'p_kette_phase'):
        if pat not in e:
            sys.exit('enemy.gd missing v15 piece: %s' % pat)
    A = '/home/hatch/workspace/1918-godot/assets/sprites/'
    for t in ('enemy-fokker-dr1', 'enemy-eindecker', 'enemy-albatros-d3'):
        for fr in ('bank-left', 'level', 'bank-right'):
            p = A + '%s-%s.png' % (t, fr)
            if not os.path.exists(p) or os.path.getsize(p) < 1000:
                sys.exit('missing/small German sprite: %s' % p)
    sd = read('sortie_data.gd')
    for t in ('e1_eindecker', 'e2_albatros_d3', 'e3_albatros_d5',
              'e4_fokker_dr1'):
        if t not in sd:
            sys.exit('sortie_data.gd never fields %s' % t)
    if '"kette": 3' not in sd:
        sys.exit('sortie_data.gd has no Kette formation waves')
    m = read('main.gd')
    if '_spawn_enemy' not in m or 'kette_n' not in m or '"kette"' not in m:
        sys.exit('main.gd missing Kette spawn path')
    td = read('tank_duel.gd')
    if 'a7v' not in td or '"a7v": preload' not in td or 'heavy' not in td:
        sys.exit('tank_duel.gd missing the A7V')
    af = read('airfield.gd')
    if '_draw_timber_hangar' not in af or '_draw_parked_german' not in af \
            or 'parked_ger' not in af:
        sys.exit('airfield.gd missing German field rebuild')
elif check == 'no-wehrmacht':
    # v15 naming rule: WWI Imperial Germany = Deutsches Heer /
    # Luftstreitkräfte. "Wehrmacht" is the WWII name — it must never appear
    # in-game or in docs.
    import os
    roots = ['/home/hatch/workspace/1918-godot/scripts',
             '/home/hatch/workspace/1918-godot/tools',
             '/home/hatch/workspace/1918-godot/research']
    hits = []
    for r in roots:
        if not os.path.isdir(r):
            continue
        for dp, dn, fn in os.walk(r):
            for f in fn:
                if f.endswith(('.gd', '.md', '.txt', '.cfg')):
                    p = os.path.join(dp, f)
                    with open(p, encoding='utf-8', errors='ignore') as fh:
                        if 'wehrmacht' in fh.read().lower():
                            hits.append(p)
    if hits:
        sys.exit('FORBIDDEN term "Wehrmacht" found in: %s' % ', '.join(hits))
    e = read('enemy.gd')
    if 'Luftstreitkr' not in e:
        sys.exit('enemy.gd missing period-correct Luftstreitkräfte naming')
elif check == 'ghost-baron-duel':
    # v22: the mythic-unlock flow is retired — the Baron is the S32 finale
    # (4 phases, Ghost Blue Max joins in P4). Assert the finale pieces.
    import os
    A = '/home/hatch/workspace/1918-godot/assets'
    sd = read('sortie_data.gd')
    for pat in ('"GHOST OF THE RED BARON"', '"BLUE MAX GHOST"',
                '"spectral": true', '31'):
        if pat not in sd:
            sys.exit('sortie_data.gd missing S32 finale piece: %s' % pat)
    bo = read('boss.gd')
    for pat in ('spectral', 'BARON_TAUNTS', '_spawn_afterimage', 'ghost_wail',
                'bluemax_spawned'):
        if pat not in bo:
            sys.exit('boss.gd missing ghost-baron piece: %s' % pat)
    for suffix in ('level', 'bank-left', 'bank-right'):
        p = A + '/sprites/boss-7-baron-%s.png' % suffix
        if not os.path.exists(p):
            sys.exit('missing sprite asset: %s' % p)
    w = read('weather.gd')
    if 'KIND_BY_SORTIE' not in w or w.count('"storm"') < 3:
        sys.exit('weather.gd KIND_BY_SORTIE missing storm entries')
    if 'SFX.play("thunder"' not in w:
        sys.exit('weather.gd lightning missing thunder SFX')
    bg = read('background.gd')
    if '"storm"' not in bg:
        sys.exit('background.gd missing storm theme')
    # v22: the 32-sortie campaign flow replaced the mythic unlock — assert
    # the campaign markers instead of the retired duel-request pieces.
    m = read('main.gd')
    for pat in ('CAMPAIGN_LAST', 'play_theater', 'start_engine',
                'sortie_index == CAMPAIGN_LAST'):
        if pat not in m:
            sys.exit('main.gd missing v22 campaign flow piece: %s' % pat)
    if 'FACE THE GHOST' in read('menus.gd'):
        sys.exit('menus.gd still carries the retired mythic duel button')
    s = read('sfx.gd')
    for pat in ('ghost_wail', 'thunder', 'stinger_ghost', 'engine_rotary',
                'railgun_boom', 'searchlight_sweep'):
        if pat not in s:
            sys.exit('sfx.gd missing v22 sound: %s' % pat)
    for wav in ('ghost_wail.wav', 'thunder.wav', 'alarm.wav',
                'railgun_boom.wav', 'searchlight_sweep.wav',
                'engine_rotary.wav'):
        if not os.path.exists(A + '/sfx/' + wav):
            sys.exit('assets/sfx/%s missing' % wav)
elif check == 'ads-test-ids':
    # v12: config must carry Google's OFFICIAL test IDs (verified against
    # https://developers.google.com/admob/android/test-ads and the iOS page)
    c = read('ads_config.gd')
    official = {
        'ca-app-pub-3940256099942544~3347511713': 'android app id',
        'ca-app-pub-3940256099942544~1458002511': 'ios app id',
        'ca-app-pub-3940256099942544/1033173712': 'android interstitial',
        'ca-app-pub-3940256099942544/5224354917': 'android rewarded',
        'ca-app-pub-3940256099942544/4411468910': 'ios interstitial',
        'ca-app-pub-3940256099942544/1712485313': 'ios rewarded',
    }
    for unit, label in official.items():
        if unit not in c:
            sys.exit('ads_config.gd missing official test id (%s): %s' % (label, unit))
    if 'const TEST_MODE := true' not in c:
        sys.exit('ads_config.gd TEST_MODE is not true — test IDs must not ship as live config')
elif check == 'ads-no-real-ids':
    # v12: no real-looking ad unit/app IDs may be committed while TEST_MODE is on
    import glob
    c = read('ads_config.gd')
    test_mode = 'const TEST_MODE := true' in c
    bad = []
    for f in glob.glob(P + '*.gd'):
        src = open(f).read()
        for m in re.finditer(r'ca-app-pub-(\d{16})([~/])(\d+)', src):
            if m.group(1) != '3940256099942544':
                bad.append('%s: %s' % (f.split('/')[-1], m.group(0)))
    if test_mode and bad:
        sys.exit('real-looking ad IDs committed while TEST_MODE is on: %s' % '; '.join(bad))
    if not test_mode and not bad:
        sys.exit('TEST_MODE off but no real ad IDs found — config looks half-swapped')
elif check == 'bot-skeptic-sane':
    # v13: the bot pilot + skepticism engine are wired end to end
    import os
    G = '/home/hatch/workspace/1918-godot/'
    for f in ('scripts/bot_pilot.gd', 'scripts/skeptic.gd',
              'scripts/skeptic_config.gd', 'tools/merge_skeptic.py'):
        if not os.path.exists(G + f):
            sys.exit('%s missing' % f)
    bp = read('bot_pilot.gd')
    for pat in ('Global.touch_wish', 'try_loop', '_on_revive_requested',
                '_on_menu_next', 'ST_PLAYING', 'ST_DEBRIEF'):
        if pat not in bp:
            sys.exit('bot_pilot.gd missing: %s' % pat)
    sk = read('skeptic.gd')
    for pat in ('pass_stall', 'pass_overlife', 'pass_no_turn', 'softlock',
                'unfair_death_early', 'iframes_broken', 'sfx_spam',
                'rumble_storm', 'spawn_camp', 'bot_zero_progress',
                'wave_stall', 'debug_freeze_pass', 'skepticism-',
                # v23: new detectors + fault library + archetypes
                'dead_air', 'threat_saturation', 'kette_broken',
                'unfair_kill', 'perf_sag', 'node_leak', 'mixer_cap_held',
                'botarchetype', 'seedfault'):
        if pat not in sk:
            sys.exit('skeptic.gd missing detector/hook: %s' % pat)
    sa = read('skeptic_archetypes.gd')  # v23: four bot brains
    for pat in ('novice', 'expert', 'survivalist', 'params_for'):
        if pat not in sa:
            sys.exit('skeptic_archetypes.gd missing: %s' % pat)
    p = read('player.gd')
    if 'signal damaged' not in p or 'damaged.emit' not in p:
        sys.exit('player.gd missing damaged signal')
    s = read('sfx.gd')
    if 'play_log' not in s or 'rumble_log' not in s:
        sys.exit('sfx.gd missing play/rumble logs')
    e = read('enemy.gd')
    if 'debug_freeze_pass' not in e:
        sys.exit('enemy.gd missing debug_freeze_pass')
    m = read('main.gd')
    for pat in ('--botpilot', 'total_kills', 'BotPilot.new()', 'Skeptic.new()'):
        if pat not in m:
            sys.exit('main.gd missing bot wiring: %s' % pat)
    # v22: read the nightly script we are actually running (the repo may be
    # checked out on a branch/worktree elsewhere — never hardcode the path).
    import os as _os
    sh = open(_os.path.join(_os.environ.get('ROOT', _os.getcwd()),
                            'QA/run-nightly.sh')).read()
    for pat in ('godot-bot-sortie-', 'godot-bot-finale', 'godot-bot-seedfault',
                'qa-seedfault-proof', 'qa-skepticism-report',
                'merge_skeptic.py',
                # v23: archetype matrix, fault library, terrain hygiene
                'godot-bot-novice', 'godot-bot-seedfault-stall',
                '--botarchetype=', 'check_terrain.py', 'qa-terrain-hygiene'):
        if pat not in sh:
            sys.exit('run-nightly.sh missing bot stage: %s' % pat)
elif check == 'minimap-textures':
    # v17: every sortie theme gets its own minimap portrait (never generic).
    # v22: 32 sorties / 32 themes; boss arenas moved to the BOSS_ROSTER
    # ("arena" flag, 6 blue-sky bosses); blue-sky bosses agree.
    import re
    sd = read('sortie_data.gd')
    themes = re.findall(r'"theme": "([^"]+)"', sd)
    if len(themes) != 32 or len(set(themes)) != 32:
        sys.exit('sortie_data.gd: expected 32 unique themes, got %d/%d'
                 % (len(themes), len(set(themes))))
    arenas = re.findall(r'"arena": (true|false)', sd)
    if len(arenas) != 32:
        sys.exit('BOSS_ROSTER: expected 32 arena flags, got %d' % len(arenas))
    mm = read('minimap.gd')
    for t in set(themes):
        if '"%s":' % t not in mm:
            sys.exit('minimap.gd _draw_terrain missing arm for theme "%s"' % t)
    if '"bluesky":' not in mm:
        sys.exit('minimap.gd missing bluesky arena portrait')
    mn = read('main.gd')
    if '"bluesky"' not in mn:
        sys.exit('main.gd missing blue-sky boss arena entry')
    if arenas.count('true') < 1:
        sys.exit('no blue-sky arena bosses in the roster')
elif check == 's2-no-uboats':
    # v17 94th mission honesty is superseded: v22 S2 is Colombey-les-Belles,
    # a training sortie — forward field, balloon storage, Eindeckers only.
    # The check now guards S2's v22 identity (no front-line hardware).
    import re
    sd = read('sortie_data.gd')
    takeoffs = [m.start() for m in re.finditer(r'"takeoff"', sd)]
    s2 = sd[takeoffs[1]:takeoffs[1] + 4000]
    if '"theme": "colombey"' not in s2:
        sys.exit('S2 theme is not colombey')
    for pat in ('"type": "uboat"', '"type": "e8_zeppelin"',
                '"type": "e6_gotha"', '"type": "e7_staaken"'):
        if pat in s2:
            sys.exit('S2 training sortie fields front-line hardware: %s' % pat)
    if '"type": "e1_eindecker"' not in s2:
        sys.exit('S2 missing its Eindecker training flights')
    e = read('enemy.gd')
    if '"barge"' not in e:
        sys.exit('enemy.gd missing barge type/behavior')
elif check == 'ads-state':    # v12: remove-ads must suppress every ad path; placements + caps wired
    a = read('ads.gd')
    for pat in ('func is_remove_ads', 'func show_rewarded', 'func show_interstitial_then',
                'func rewarded_available', 'INTERSTITIAL_COOLDOWN_S',
                'INTERSTITIAL_MAX_PER_SESSION', 'INTERSTITIAL_MIN_SORTIES_COMPLETED'):
        if pat not in a:
            sys.exit('ads.gd missing ads piece: %s' % pat)
    # both show paths must bail when remove-ads is owned
    for fn in ('func show_rewarded', 'func show_interstitial_then'):
        i = a.find(fn)
        body = a[i:i + 900]
        if 'is_remove_ads()' not in body:
            sys.exit('ads.gd %s does not gate on is_remove_ads()' % fn)
    ip = read('iaps.gd')
    for pat in ('func has_remove_ads', 'func purchase_remove_ads',
                'func restore_purchases', '"purchases"', '"remove_ads"',
                '1918_remove_ads'):
        if pat not in ip:
            sys.exit('iaps.gd missing IAP piece: %s' % pat)
    if 'AdsConfig.TEST_MODE' not in ip:
        sys.exit('iaps.gd does not honor TEST_MODE')
    me = read('menus.gd')
    for pat in ('REMOVE ADS', 'revive_requested', 'FLY AGAIN'):
        if pat not in me:
            sys.exit('menus.gd missing ads UI piece: %s' % pat)
    mn = read('main.gd')
    for pat in ('revive_requested', '_on_revive_reward', 'player.revive(',
                'show_interstitial_then', 'note_session_start', 'note_sortie_completed'):
        if pat not in mn:
            sys.exit('main.gd missing ads wiring piece: %s' % pat)
    pl = read('player.gd')
    if 'func revive(' not in pl:
        sys.exit('player.gd missing revive()')
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
# v22: the 32-sortie campaign — sorties, pacing curve, boss roster, E1-E10,
# 128 elites, 32 terrain identities
if python3 "$ROOT/QA/check_v22_campaign.py" >"$OUT" 2>&1; then
    record "qa-v22-campaign" "PASS — $(tail -1 "$OUT")"
else
    record "qa-v22-campaign" "FAIL — $(cat "$OUT" | head -8 | tr '\n' ';')"
fi
# v22 audio bar: 9 theater tracks, stingers, engine loops, sfx registry
if python3 "$ROOT/QA/check_v22_audio.py" >"$OUT" 2>&1; then
    record "qa-v22-audio" "PASS — $(tail -1 "$OUT")"
else
    record "qa-v22-audio" "FAIL — $(cat "$OUT" | head -8 | tr '\n' ';')"
fi
# v22 photorealism: sprite->.blend traceability, flat-shade heuristic,
# placeholder-color scan, fx particle set
if python3 "$ROOT/QA/check_v22_visual.py" >"$OUT" 2>&1; then
    record "qa-v22-visual" "PASS — $(tail -1 "$OUT")"
else
    record "qa-v22-visual" "FAIL — $(cat "$OUT" | head -8 | tr '\n' ';')"
fi
godot_check "godot-ads-flow"    "$GODOT" --headless --path "$PROJECT" --script res://tools/test_ads.gd
if ! grep -q '\[TESTADS\] PASS' "$OUT"; then
    # godot_check already recorded; downgrade if the PASS marker is missing
    for i in "${!names[@]}"; do
        if [[ "${names[$i]}" == "godot-ads-flow" && "${results[$i]}" == PASS* ]]; then
            results[$i]="FAIL — [TESTADS] PASS marker missing"
        fi
    done
fi
# sortie sweep: every sortie's weather, waves, and flak paths must run clean
# v22: all 32 sorties boot and run (each ~25s game time, fast headless)
for s in $(seq 0 31); do
    godot_check "godot-sortie-$((s+1))" "$GODOT" --headless --path "$PROJECT" --quit-after 1500 -- --autostart --sortie="$s"
done
# --- v13: bot playtest + continuous skepticism ---
# The bot flies each sortie through the real control path (50s each; the
# S32 finale gets 110s so the run can reach the Ghost's storm). --botquit
# drives run length by GAME time (--quit-after counts render frames and
# spins ~2x the physics rate, so it is only a backstop). Fragments land in
# QA/reports/ as skepticism-<date>-s<N>.jsonl; merge_skeptic.py builds the
# report and fails on CRITICAL anomalies. Bot failures fail loudly.
SKEP_DIR="$REPORT_DIR"
rm -f "$SKEP_DIR/skepticism-$DATE-s"*.jsonl
# v22: sample the 32-sortie campaign — early / mid / late / finale
for s in 0 8 16 24 31; do
    godot_check "godot-bot-sortie-$((s+1))" "$GODOT" --headless --path "$PROJECT" --quit-after 9000 -- --autostart --botpilot --botquit=50 --sortie="$s" --skepdir="$SKEP_DIR"
done
# v22: the mythic duel is retired (the Baron is S32 now) — the long run goes
# to the Armistice finale instead, so the bot can reach the 4-phase Ghost.
godot_check "godot-bot-finale" "$GODOT" --headless --path "$PROJECT" --quit-after 16000 -- --autostart --botpilot --botquit=110 --sortie=31 --skepdir="$SKEP_DIR"
# --- v23: archetype matrix — novice / expert / survivalist on early / mid /
# finale (average is covered by the base sample above). 40s game time each.
for a in novice expert survivalist; do
    for s in 0 16 31; do
        godot_check "godot-bot-$a-s$((s+1))" "$GODOT" --headless --path "$PROJECT" --quit-after 8000 -- --autostart --botpilot --botquit=40 --botarchetype="$a" --sortie="$s" --skepdir="$SKEP_DIR"
    done
done
# --- v23: seeded-fault library — every detector must catch its fault.
# Proof is gated by merge_skeptic.py's per-fault table (exit 1 when any
# detector fails to fire); no separate grep needed. 35s runs: the stall
# fault needs ~25s of pinned time before pass_stall's margin expires.
for f in stall unfair spawncamp glow edge sfx rumble earlydeath; do
    godot_check "godot-bot-seedfault-$f" "$GODOT" --headless --path "$PROJECT" --quit-after 7000 -- --autostart --botpilot --botquit=35 --sortie=0 --seedfault="$f" --skepdir="$SKEP_DIR"
done
# merge fragments into QA/reports/skepticism-<date>.md
# (v23: archetype-aware stats, per-fault proof table, trends, bug autofile;
#  exits 1 on CRITICAL anomalies or missing detector proof)
if python3 "$PROJECT/tools/merge_skeptic.py" "$SKEP_DIR" "$DATE" >"$OUT" 2>&1; then
    record "qa-skepticism-report" "PASS — $(grep -o 'SKEPTIC:.*' "$OUT" | head -1)"
else
    record "qa-skepticism-report" "FAIL — $(grep -o 'SKEPTIC:.*' "$OUT" | head -1)"
fi
# v23: the merge gates detector proof — record its tally here so the
# long-standing qa-seedfault-proof stage keeps its name and meaning.
if grep -q 'proof 8/8' "$OUT" 2>/dev/null; then
    record "qa-seedfault-proof" "PASS — 8/8 detectors proved"
else
    record "qa-seedfault-proof" "FAIL — $(grep -o 'proof [0-9]*/8' "$OUT" | head -1)"
fi
# --- v23: terrain hygiene — the 32 minimap identities under the iron rule ---
if python3 "$ROOT/QA/skeptic/check_terrain.py" "$PROJECT/scripts" >"$OUT" 2>&1; then
    record "qa-terrain-hygiene" "PASS — $(tail -1 "$OUT")"
else
    record "qa-terrain-hygiene" "FAIL — $(cat "$OUT" | head -8 | tr '\n' ';')"
fi
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
gdscript_check "gdscript-ghost-baron-duel" ghost-baron-duel
gdscript_check "gdscript-ads-test-ids" ads-test-ids
gdscript_check "gdscript-ads-no-real-ids" ads-no-real-ids
gdscript_check "gdscript-ads-state" ads-state
gdscript_check "gdscript-bot-skeptic-sane" bot-skeptic-sane
gdscript_check "gdscript-lighting-schedule" lighting-schedule
gdscript_check "gdscript-german-roster" german-roster
gdscript_check "gdscript-no-wehrmacht" no-wehrmacht
gdscript_check "gdscript-minimap-textures" minimap-textures
gdscript_check "gdscript-s2-no-uboats" s2-no-uboats
# v16: every airframe sprite must have a Blender render source (no orphans)
if python3 "$ROOT/QA/check_v16_sprites.py" >"$OUT" 2>&1; then
    record "gdscript-v16-sprite-sources" "PASS — $(tail -1 "$OUT")"
else
    record "gdscript-v16-sprite-sources" "FAIL — $(cat "$OUT" | head -5 | tr '\n' ';')"
fi

# v19: model coverage + 5s post-loop invuln + wingman animation wiring
if python3 "$ROOT/QA/check_v19_coverage.py" >"$OUT" 2>&1; then
    record "gdscript-v19-coverage" "PASS — $(tail -1 "$OUT")"
else
    record "gdscript-v19-coverage" "FAIL — $(cat "$OUT" | head -5 | tr '\n' ';')"
fi

# v18: web export preset + installed export templates (static readiness check)
if python3 "$ROOT/QA/check_web_export.py" >"$OUT" 2>&1; then
    record "qa-web-export-ready" "PASS — $(tail -1 "$OUT")"
else
    record "qa-web-export-ready" "FAIL — $(cat "$OUT" | head -5 | tr '\n' ';')"
fi

# v20: Steven's playtest feedback — 45° wingman slots, top entry, movement
# personalities, muted camo (no full-body strobes), brighter player tracers
if python3 "$ROOT/QA/check_v20_playtest.py" >"$OUT" 2>&1; then
    record "gdscript-v20-playtest" "PASS — $(tail -1 "$OUT")"
else
    record "gdscript-v20-playtest" "FAIL — $(cat "$OUT" | head -5 | tr '\n' ';')"
fi

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
