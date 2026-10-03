#!/usr/bin/env bash
# bin/bump-version.sh — bump the holistic 1918 version by +1.
#
# Updates, all in one stroke:
#   1. VERSION file at the repo root
#   2. the splash-screen version badge in 1918-ace-of-aces.html
#   3. the VERSION constant in scripts/global.gd (working copy AND repo mirror)
#   4. CHANGELOG.md — a new entry is PREPENDED (newest first), in pirate speak
#
# Usage: bin/bump-version.sh "<changelog entry, in pirate speak>"
#
# Idempotent-safe: every replacement targets one unique, anchored pattern.
# Re-running with a new entry bumps exactly once more; no duplicates,
# no half-applied state (set -euo pipefail aborts on the first failure).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ENTRY="${1:-}"
if [ -z "$ENTRY" ]; then
    echo "Usage: $0 \"<changelog entry, in pirate speak>\"" >&2
    exit 1
fi
if [ ! -f VERSION ]; then
    echo "ERROR: VERSION file missing at repo root" >&2
    exit 1
fi
if [ ! -f CHANGELOG.md ]; then
    echo "ERROR: CHANGELOG.md missing at repo root" >&2
    exit 1
fi

CUR="$(tr -d '[:space:]' < VERSION)"
NEXT=$((CUR + 1))

# 1. VERSION file
printf '%s\n' "$NEXT" > VERSION

# 2. Web splash badge — exactly one <span class="ver-badge">vN</span>
HTML="1918-ace-of-aces.html"
if [ "$(grep -o 'class="ver-badge">v[0-9]*</span>' "$HTML" | wc -l)" -ne 1 ]; then
    echo "ERROR: expected exactly one ver-badge span in $HTML" >&2
    exit 1
fi
sed -i -E 's/(class="ver-badge">v)[0-9]+(<\/span>)/\1'"$NEXT"'\2/' "$HTML"

# 3. Godot VERSION constant — working copy and repo mirror, kept identical
for GD in "$HOME/workspace/1918-godot/scripts/global.gd" "godot/scripts/global.gd"; do
    if [ "$(grep -c 'const VERSION: String = "[0-9]*"' "$GD")" -ne 1 ]; then
        echo "ERROR: expected exactly one const VERSION in $GD" >&2
        exit 1
    fi
    sed -i -E 's/(const VERSION: String = ")[0-9]+(")/\1'"$NEXT"'\2/' "$GD"
done

# 4. CHANGELOG.md — new entry goes right below the marker (newest first)
DATE="$(date +%Y-%m-%d)"
python3 - "$NEXT" "$DATE" "$ENTRY" <<'PYEOF'
import sys
nxt, date, entry = sys.argv[1], sys.argv[2], sys.argv[3]
p = 'CHANGELOG.md'
src = open(p).read()
marker = '<!-- NEW ENTRIES GO BELOW THIS LINE (newest first) -->\n'
assert src.count(marker) == 1, 'changelog marker missing or duplicated'
block = '## v%s — %s\n\n%s\n\n' % (nxt, date, entry)
open(p, 'w').write(src.replace(marker, marker + '\n' + block, 1))
print('changelog entry added for v%s' % nxt)
PYEOF

echo "v$CUR -> v$NEXT"
