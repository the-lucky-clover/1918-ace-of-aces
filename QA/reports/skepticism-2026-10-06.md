# Skepticism report — 2026-10-06

Automated playtesting: bot pilots of four archetypes (novice / average / expert / survivalist) flew sampled sorties through the real control path (touch steering, real fire/loop/ bomb inputs); the skeptic watched for anything that feels wrong. Evidence, not vibes. One-hit model: the SPAD XIII dies in a single hit, so every death must be telegraphed.

**SKEPTIC: 7 anomalies (0 critical, 4 high, 3 med) across 14 runs | proof 8/8 | bugs filed: 0**

## Per-sortie stats

| Sortie | Archetype | Kills | Deaths | Score | Kills/min | Dmg/min | Boss? |
|---|---|---|---|---|---|---|---|
| 1 Sortie 1 — VIMY RIDGE | average | 22 | 2 | 5270 | 26.4 | 60 | no |
| 1 Sortie 1 — VIMY RIDGE | expert | 28 | 0 | 7171 | 42.0 | 0 | no |
| 1 Sortie 1 — VIMY RIDGE | novice | 13 | 2 | 2800 | 19.5 | 75 | no |
| 1 Sortie 1 — VIMY RIDGE | survivalist | 25 | 1 | 6149 | 37.5 | 38 | no |
| 9 Sortie 9 — MOSELLE | average | 4 | 2 | 1120 | 4.8 | 34 | no |
| 17 Sortie 17 — MARNE DAWN | average | 9 | 2 | 3182 | 10.8 | 60 | no |
| 17 Sortie 17 — MARNE DAWN | expert | 34 | 1 | 13046 | 51.0 | 38 | no |
| 17 Sortie 17 — MARNE DAWN | novice | 6 | 2 | 2080 | 9.0 | 75 | no |
| 17 Sortie 17 — MARNE DAWN | survivalist | 36 | 1 | 14984 | 54.0 | 15 | no |
| 25 Sortie 25 — UDET'S GAMBIT | average | 4 | 2 | 1530 | 4.8 | 44 | no |
| 32 Sortie 32 — ARMISTICE | average | 24 | 2 | 9695 | 13.1 | 10 | no |
| 32 Sortie 32 — ARMISTICE | expert | 34 | 1 | 14425 | 51.0 | 38 | no |
| 32 Sortie 32 — ARMISTICE | novice | 6 | 2 | 2345 | 9.0 | 48 | no |
| 32 Sortie 32 — ARMISTICE | survivalist | 39 | 0 | 18070 | 58.5 | 0 | no |

## Anomalies

| t | Sortie | Archetype | Severity | Kind | Evidence |
|---|---|---|---|---|---|
| 13.1s | 1 | novice | **MED** | `spawn_camp` | e1_eindecker spawned 118px from the player etype=e1_eindecker |
| 13.1s | 1 | novice | **MED** | `spawn_camp` | e1_eindecker spawned 99px from the player etype=e1_eindecker |
| 15.0s | 32 | expert | **HIGH** | `threat_saturation` | 19 live air attackers sustained 6s — the screen is unreadable  |
| 20.0s | 32 | average | **HIGH** | `threat_saturation` | 30 live air attackers sustained 6s — the screen is unreadable  |
| 25.0s | 17 | average | **HIGH** | `threat_saturation` | 20 live air attackers sustained 6s — the screen is unreadable  |
| 25.0s | 17 | expert | **HIGH** | `threat_saturation` | 18 live air attackers sustained 6s — the screen is unreadable  |
| 35.1s | 32 | expert | **MED** | `node_leak` | node count 208 -> 332 (+59% past warmup minimum) — something isn't despawning  |

## Detector proof (seeded faults)

Every detector must catch its seeded fault every nightly — a detector that cannot prove itself is not trusted.

| Fault | Expected | Result |
|---|---|---|
| `--seedfault=stall` | `pass_stall` | **PASS** |
| `--seedfault=unfair` | `death_no_visible_cause` | **PASS** |
| `--seedfault=spawncamp` | `spawn_camp` | **PASS** |
| `--seedfault=glow` | `enemy_glow` | **PASS** |
| `--seedfault=edge` | `edge_linger` | **PASS** |
| `--seedfault=sfx` | `mixer_cap_held` | **PASS** |
| `--seedfault=rumble` | `rumble_storm` | **PASS** |
| `--seedfault=earlydeath` | `unfair_death_early` | **PASS** |

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

1. Sortie 9 (Sortie 9 — MOSELLE) [average]: kill-rate 4.8/min is 79% below the campaign median — consider a wiped-squadron bonus drop here.
2. Sortie 17 (Sortie 17 — MARNE DAWN) [average]: kill-rate 10.8/min is 52% below the campaign median — consider a wiped-squadron bonus drop here.
3. Sortie 17 (Sortie 17 — MARNE DAWN) [novice]: kill-rate 9.0/min is 60% below the campaign median — consider a wiped-squadron bonus drop here.
4. Sortie 25 (Sortie 25 — UDET'S GAMBIT) [average]: kill-rate 4.8/min is 79% below the campaign median — consider a wiped-squadron bonus drop here.
5. Sortie 32 (Sortie 32 — ARMISTICE) [average]: kill-rate 13.1/min is 42% below the campaign median — consider a wiped-squadron bonus drop here.
6. Sortie 32 (Sortie 32 — ARMISTICE) [novice]: kill-rate 9.0/min is 60% below the campaign median — consider a wiped-squadron bonus drop here.

_Thresholds: scripts/skeptic_config.gd. Bot: scripts/bot_pilot.gd. Archetypes: scripts/skeptic_archetypes.gd._
