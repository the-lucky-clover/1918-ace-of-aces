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
#          in background generation, squadron goal helpers present.
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
elif check == 'airfield-spawn':
    import os
    if not os.path.exists(P + 'airfield.gd') or not os.path.exists(P + 'truck.gd'):
        sys.exit('airfield.gd or truck.gd missing')
    m = read('main.gd')
    if 'etype == "airfield"' not in m or 'etype == "truck"' not in m:
        sys.exit('main.gd missing airfield/truck wave branches')
    if 'escort_spots()' not in m:
        sys.exit('main.gd does not spawn airfield escort via escort_spots()')
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
