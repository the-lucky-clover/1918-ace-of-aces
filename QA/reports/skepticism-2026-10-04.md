# Skepticism report — 2026-10-04

Automated playtesting: a mid-skill bot pilot flew every sortie through the real control path (touch steering, real fire/loop/ bomb inputs); the skeptic watched for anything that feels wrong. Evidence, not vibes.

**SKEPTIC: 4 anomalies (0 critical, 0 high, 4 med) across 7 runs**

## Per-sortie stats

| Sortie | Kills | Deaths | Score | Kills/min | Dmg/min | Boss? |
|---|---|---|---|---|---|---|
| 1 Sortie 1 — Dawn Patrol | 7 | 0 | 1320 | 8.4 | 80 | no |
| 2 Sortie 2 — Wolfpack | 17 | 0 | 3856 | 20.4 | 64 | no |
| 3 Sortie 3 — The Zeppelin Sheds | 10 | 1 | 1680 | 12.0 | 41 | no |
| 4 Sortie 4 — Powder Keg | 8 | 0 | 1770 | 9.6 | 26 | no |
| 5 Sortie 5 — The Pens | 5 | 1 | 1554 | 6.0 | 203 | no |
| 6 Sortie 6 — Iron Harvest | 4 | 0 | 847 | 4.8 | 118 | no |
| 7 Sortie 7 — The Thunderhead Duel | 10 | 1 | 1925 | 5.5 | 61 | yes |

## Anomalies

| t | Sortie | Severity | Kind | Evidence |
|---|---|---|---|---|
| 14.0s | 5 | **MED** | `sfx_spam` | "explosion_small" fired 8x in one second — the mix is shouting  |
| 14.0s | 5 | **MED** | `sfx_spam` | "flak" fired 8x in one second — the mix is shouting  |
| 44.7s | 4 | **MED** | `spawn_camp` | trench spawned 81px from the player etype=trench |
| 44.7s | 4 | **MED** | `spawn_camp` | trench spawned 105px from the player etype=trench |

## Ideas (1942-grounded, suggestions only)

1. Sortie 5 (Sortie 5 — The Pens): damage pressure 203/min is 3.2x the median — check telegraph fairness on its waves (1942 was built for accessibility, not punishment).
2. Sortie 6 (Sortie 6 — Iron Harvest): kill-rate 4.8/min is 42% below the campaign median — consider a wiped-squadron bonus drop here (the POW-carrier homage queued in the v11 1942 research).

## Detector proof

WARNING: no seedfault run with a `pass_stall` flag was found — detector proof is missing this run.

_Thresholds: scripts/skeptic_config.gd. Bot: scripts/bot_pilot.gd._
