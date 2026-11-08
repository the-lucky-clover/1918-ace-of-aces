# Skepticism report — 2026-10-19

Automated playtesting: bot pilots of four archetypes (novice / average / expert / survivalist) flew sampled sorties through the real control path (touch steering, real fire/loop/ bomb inputs); the skeptic watched for anything that feels wrong. Evidence, not vibes. One-hit model: the SPAD XIII dies in a single hit, so every death must be telegraphed.

**SKEPTIC: 0 anomalies (0 critical, 0 high, 0 med) across 0 runs | proof 0/8 | bugs filed: 0**

## Per-sortie stats

| Sortie | Archetype | Kills | Deaths | Score | Kills/min | Dmg/min | Boss? |
|---|---|---|---|---|---|---|---|

## Anomalies

None. The sky felt right.

## Detector proof (seeded faults)

Every detector must catch its seeded fault every nightly — a detector that cannot prove itself is not trusted.

| Fault | Expected | Result |
|---|---|---|
| `--seedfault=stall` | `pass_stall` | **FAIL** — MISSING — no --seedfault=stall run found |
| `--seedfault=unfair` | `death_no_visible_cause` | **FAIL** — MISSING — no --seedfault=unfair run found |
| `--seedfault=spawncamp` | `spawn_camp` | **FAIL** — MISSING — no --seedfault=spawncamp run found |
| `--seedfault=glow` | `enemy_glow` | **FAIL** — MISSING — no --seedfault=glow run found |
| `--seedfault=edge` | `edge_linger` | **FAIL** — MISSING — no --seedfault=edge run found |
| `--seedfault=sfx` | `mixer_cap_held` | **FAIL** — MISSING — no --seedfault=sfx run found |
| `--seedfault=rumble` | `rumble_storm` | **FAIL** — MISSING — no --seedfault=rumble run found |
| `--seedfault=earlydeath` | `unfair_death_early` | **FAIL** — MISSING — no --seedfault=earlydeath run found |

## Trends (recent days, real runs)

| Sortie | Archetype | Deaths (recent) | CRITICAL runs |
|---|---|---|---|
| 1 | average | 2 → 2 → 2 | 0/3 |
| 1 | expert | 1 → 0 → 0 | 0/3 |
| 1 | novice | 2 → 2 → 2 | 0/3 |
| 1 | survivalist | 0 → 1 → 1 | 0/3 |
| 9 | average | 0 → 2 → 2 | 0/3 |
| 17 | average | 2 → 2 → 2 | 0/3 |
| 17 | expert | 0 → 1 → 1 | 0/3 |
| 17 | novice | 2 → 2 → 2 | 0/3 |
| 17 | survivalist | 1 → 1 → 1 | 0/3 |
| 25 | average | 2 → 2 → 2 | 0/3 |
| 32 | average | 2 → 2 → 2 | 0/3 |
| 32 | expert | 1 → 1 → 1 | 0/3 |
| 32 | novice | 2 → 2 → 2 | 0/3 |
| 32 | survivalist | 2 → 0 → 0 | 0/3 |

## Ideas (1942-grounded, suggestions only)

1. No strong signals this run. Kill-rating % on the debrief would give the skeptic a sharper economy signal than kills/min alone.

_Thresholds: scripts/skeptic_config.gd. Bot: scripts/bot_pilot.gd. Archetypes: scripts/skeptic_archetypes.gd._
