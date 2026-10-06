# 1918 Automated Playtesting (v23)

The skeptic bot flies the game for real and argues with the build every
night. This document is the operator's manual. (Versioning: holistic —
v23's number is assigned by completion order; this file documents the
framework, not the version.)

## Architecture

```
--botpilot --botarchetype=<n> --botquit=<s> --sortie=<i> [--seedfault=<f>]
   │  Godot headless, real control path (touch steering, fire/bomb,
   │  try_loop) — no godmode, no freebies
   ▼
bot_pilot.gd ──► flies (4 archetype brains, SkepticArchetypes)
skeptic.gd ────► watches (anomaly detectors, JSONL evidence)
   │  QA/reports/skepticism-<date>-s<N>[-<archetype>][-seed-<fault>].jsonl
   ▼
tools/merge_skeptic.py ──► skepticism-<date>.md
   │  per-sortie × archetype stats · anomaly table · per-fault proof table
   │  difficulty-curve verdicts · trends · auto-filed QA/bugs/
   ▼
QA/skeptic/check_terrain.py ──► terrain prompt hygiene (iron rule, static)
```

The nightly (`QA/run-nightly.sh`) runs: base average sample (sorties 1, 9,
17, 25, 32 at 50s), the archetype matrix (novice/expert/survivalist on
sorties 1, 17, 32 at 40s), the seeded-fault library (8 faults on sortie 1
at 25s), then merges. Fragments are keyed `(sortie, archetype, fault)` — non-average archetypes
carry their name in the fragment (`s0-novice.jsonl`) and seeded runs carry
the fault (`s0-seed-stall.jsonl`), so parallel runs can never overwrite or
collide with each other (the v21 lesson).

## Archetypes (`scripts/skeptic_archetypes.gd`)

Calibrated for the 1942 one-hit model (the SPAD XIII dies in ONE hit), so
survival skill must be legible in deaths-per-run. Expected ordering:
**expert ≤ survivalist < average < novice**.

| Archetype | Brain | Dies |
|---|---|---|
| `novice` | 0.30s reactions, sloppy steering, 130px dodge radius, panics late | a lot |
| `average` | v13 mid-skill tuning exactly — the human mean | sometimes |
| `expert` | 0.05s reactions, 360px dodge radius, loops on a hair trigger | rarely |
| `survivalist` | dodges first/kills second: 460px dodge radius, danger weight 3.2×, stations low (home_y 0.74) for reaction time | the cautious player's proxy |

Select with `--botarchetype=<name>` (default `average`). The bot still
flies the real control path — archetypes change only the brain's
parameters, never the physics.

**Calibration (measured 2026-10-06, 40s runs, headless):**

| Archetype | S1 kills/deaths | S17 kills/deaths | S32 kills/deaths |
|---|---|---|---|
| novice | 5/2 | 5/2 | 26/1 |
| average | 12/2 | — | — |
| expert | 30/1 | 6/2 | 36/1 |
| survivalist | 32/1 | 33/0 | 28/1 |

The ordering holds: survivalist is the hardest to kill (0–1 deaths),
expert kills the most (aggression pays), novice kills little and dies
most. Survival skill is legible — the one-hit model is playable by
cautious hands, which is the fairness baseline the detectors defend.

## Detectors (`scripts/skeptic.gd`, thresholds in `skeptic_config.gd`)

CRITICAL fails the nightly. HIGH/MED are warnings. Every detector logs
evidence (timestamps, positions, entities), not vibes.

**Pass model (v10):** `pass_stall`, `pass_overlife`, `pass_no_turn`,
`edge_linger` (v20 conga-line regression), `enemy_glow` (v20 radioactive
telegraph regression) — HIGH/MED.

**Deaths:** `unfair_death_early` (CRITICAL, <3s after spawn),
`death_no_visible_cause` (HIGH, nothing near the corpse),
`iframes_broken` (legacy: meaningless under one-hit death, kept as a
tripwire).

**One-hit fairness (v23, CRITICAL `unfair_kill`):** every death must be
telegraphed. Three gates: (1) the killing blow came from off-screen;
(2) a tracer/flak round with no on-screen shooter in range
(unattributable fire); (3) rammed by an aircraft still in ENTER or on
the field <1.5s (no telegraph yet). Ground targets are exempt from gate
3 — flying into a trench is the pilot's own fault.

**Wave pacing (v23):** `dead_air` (MED — 20s with nothing to shoot and
nothing shooting while the next wave is 25s+ out; boss arenas exempt),
`threat_saturation` (HIGH — 14+ live air attackers sustained 6s).

**Formation integrity (v23):** `kette_broken` (MED — a Kette member
>420px from its Vic centroid for 4s mid-pass; turns/exits may reform).

**Perf proxy (v23, headless):** `perf_sag` (MED — physics fps <50 for
10s), `node_leak` (MED — node count +25% with no sortie change),
plus the v13 `hitch`/`hitch_storm` wall-clock detectors.

**Feel:** `sfx_spam` (MED, >6 same-name plays/s — unreachable through
`SFX.play` since the v21 mixer cap; kept as defense-in-depth),
`rumble_storm` (MED), `spawn_camp` (MED), `softlock`/`wave_stall`/
`bot_zero_progress` (CRITICAL/HIGH).

**Difficulty curve (v23, merge-time):** `difficulty_curve` (HIGH —
average dies >8× in a 40s run), `expert_early_heat` (MED — expert dies
>2× on sorties 1–8), `survivalist_paradox` (MED — survivalist dies 4+
more than average on the same sortie: damage is unavoidable, not
dodgeable).

## Seeded-fault library (v23)

One fault per detector, via `--seedfault=<name>` on sortie 1 (35s —
the stall fault needs ~25s of pinned time before `pass_stall`'s margin
expires). Every detector must catch its fault every nightly — an unproven
detector is not trusted. Proof is gated by the merge (exit 1 on any
missing proof).

| Fault | What it does | Proves |
|---|---|---|
| `stall` | freezes + pins a pass aircraft | `pass_stall` |
| `unfair` | teleports the bot to clear sky, then kills it (after spawn protection ages out) | `death_no_visible_cause` |
| `spawncamp` | teleports an enemy onto the bot as a "fresh" spawn | `spawn_camp` |
| `glow` | forces a 2.3× full-body overdrive for 1.5s | `enemy_glow` |
| `edge` | pins an enemy off the playfield side | `edge_linger` |
| `sfx` | 10 same-name plays in one frame — **verifies the v21 mixer cap**: must log ≤4 (`mixer_cap_held` event); `sfx_cap_broken` CRITICAL if the cap regresses | v21 cap holds |
| `rumble` | 6 haptic pulses in one frame | `rumble_storm` |
| `earlydeath` | kills the bot 1.0s after spawn | `unfair_death_early` |

Note: `sfx_spam` can no longer be proven through `SFX.play` (the v21
cap sits at 4, the detector at 6 — by design). The `sfx` fault guards
the cap instead; if the cap is ever removed, `sfx_spam` becomes
provable again.

## Reporting

`merge_skeptic.py` writes `QA/reports/skepticism-<date>.md`:
per-sortie × archetype stats, the anomaly table, the per-fault proof
table, auto-filed bugs, trends, and 1942-grounded ideas (suggestions
only — never auto-applied).

**Trends:** every merge appends to `QA/reports/skepticism-trends.jsonl`
(date, sortie, archetype, kills, deaths, kpm, anomaly counts). The
report shows recent deaths-per-archetype and CRITICAL-run rates per
sortie — regressions across nights are visible at a glance.

**Auto-filed bugs:** HIGH/CRITICAL hits are filed to `QA/bugs/NNN-
<detector>-s<N>.md` from `QA/BUG-REPORT-TEMPLATE.md`, deduplicated by a
`<!-- skeptic-sig: … -->` marker (re-runs never double-file). Filed
bugs are triage-required: severity blocker (CRITICAL) / major (HIGH),
suspected cause pre-filled from the detector map, status open.

## Terrain hygiene (`QA/skeptic/check_terrain.py`)

Static, structural (headless Godot cannot see pixels — true pixel
verification stays a human review step): 32 TERRAIN identities, every
sortie theme resolves, every painter exists, no
perspective/horizon/rotation tokens in the painters (the camera iron
rule applied to the map), the aerodrome strip in the bottom ~14%
(first/last section doctrine), landing damage states 0–3 all used.

## Nightly runtime (measured 2026-10-06, headless ≈1× realtime)

| Stage | Runs | Wall |
|---|---|---|
| base average sample (5 sorties × 50s) | 5 | ~4.5 min |
| archetype matrix (3 × 3 sorties × 40s) | 9 | ~6.5 min |
| seeded-fault library (8 × 35s) | 8 | ~5 min |
| merge + terrain check | — | <10s |
| **bot section total** | **22** | **~16 min** |

Godot startup is ~2s per run (warm `.godot` cache). The full nightly
is longer (sortie sweep, import, web checks); the bot section above is
the v23 addition.

## Validation status (2026-10-06, against v22's in-flight 32-sortie code)

- [x] GDScript parses clean (headless --import, zero errors)
- [x] archetype death ordering: expert ≤ survivalist < average < novice
      (S1: 1/1/2/2 · S17: 2/0/–/2 · S32: 1/1/–/1 deaths)
- [x] all 8 seeded faults prove their detectors (8/8 PASS)
- [x] merge: proof table 8/8, trends append, bug autofile dedupe
- [x] terrain hygiene PASS on the 32 identities
- [x] unfair_kill gate precision: refined against 3 false-positive classes
      found in calibration (trench/balloon rams, ground-MG tracers);
      re-verified silent on fair deaths, still fires on the real S32
      spawn-ram case
- [x] node_leak baseline fixed (t=0 → warmup-minimum); verified silent
- [ ] full nightly pass on the branch — the nightly tests
      ~/workspace/1918-godot, which receives this framework at merge;
      the v23 stages were validated individually against /tmp/1918-v23
      (project copy + framework overlaid)

## After v22 merges

Re-run the whole matrix: the archetype calibration and the
difficulty-curve limits were tuned against v22's in-flight 32-sortie
data and one-hit model. If v22 retunes waves, damage, or spawn tables,
re-calibrate `CURVE_AVG_DEATH_LIMIT` / `CURVE_EXPERT_EARLY_LIMIT` and
the archetype death ordering before trusting a green nightly.

## Coordination

v22 owns `main` and the game source. This framework lives on
`agent/v23-playtesting`; v23 touches only
`scripts/skeptic*.gd`, `scripts/bot_pilot.gd` (additive archetype
params), `tools/merge_skeptic.py`, `QA/run-nightly.sh` (additive
stages), and new files under `QA/skeptic/`. Never merge to main from
here — the merge (and the re-validation above) is the parent's call.
