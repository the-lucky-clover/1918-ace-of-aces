# Skepticism report — 2026-10-05

Automated playtesting: a mid-skill bot pilot flew every sortie through the real control path (touch steering, real fire/loop/ bomb inputs); the skeptic watched for anything that feels wrong. Evidence, not vibes.

**SKEPTIC: 6 anomalies (0 critical, 0 high, 6 med) across 7 runs**

## Per-sortie stats

| Sortie | Kills | Deaths | Score | Kills/min | Dmg/min | Boss? |
|---|---|---|---|---|---|---|
| 1 Sortie 1 — Dawn Patrol | 30 | 0 | 7684 | 36.0 | 0 | no |
| 2 Sortie 2 — Wolfpack | 13 | 0 | 3160 | 15.6 | 82 | no |
| 3 Sortie 3 — The Zeppelin Sheds | 12 | 1 | 2490 | 14.4 | 43 | no |
| 4 Sortie 4 — Powder Keg | 13 | 0 | 3094 | 15.6 | 104 | no |
| 5 Sortie 5 — The Pens | 3 | 0 | 660 | 3.6 | 77 | no |
| 6 Sortie 6 — Iron Harvest | 13 | 0 | 4132 | 15.6 | 49 | no |
| 7 Sortie 7 — The Thunderhead Duel | 10 | 2 | 2510 | 5.5 | 88 | yes |

## Anomalies

| t | Sortie | Severity | Kind | Evidence |
|---|---|---|---|---|
| 11.4s | 5 | **MED** | `sfx_spam` | "explosion_small" fired 9x in one second — the mix is shouting  |
| 11.4s | 5 | **MED** | `sfx_spam` | "flak" fired 8x in one second — the mix is shouting  |
| 34.0s | 4 | **MED** | `spawn_camp` | fokker_dr1 spawned 91px from the player etype=fokker_dr1 |
| 39.2s | 4 | **MED** | `spawn_camp` | trench spawned 118px from the player etype=trench |
| 39.2s | 4 | **MED** | `spawn_camp` | trench spawned 107px from the player etype=trench |
| 43.9s | 7 | **MED** | `sfx_spam` | "explosion_small" fired 7x in one second — the mix is shouting  |

## Ideas (1942-grounded, suggestions only)

1. Sortie 1 (Sortie 1 — Dawn Patrol): 36.0 kills/min is a pinata — check it doesn't trivialize the squadron break-point.
2. Sortie 5 (Sortie 5 — The Pens): kill-rate 3.6/min is 76% below the campaign median — consider a wiped-squadron bonus drop here (the POW-carrier homage queued in the v11 1942 research).

## Detector proof

WARNING: no seedfault run with a `pass_stall` flag was found — detector proof is missing this run.

_Thresholds: scripts/skeptic_config.gd. Bot: scripts/bot_pilot.gd._
