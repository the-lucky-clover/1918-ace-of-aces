# Skepticism report — 2026-10-05

Automated playtesting: a mid-skill bot pilot flew every sortie through the real control path (touch steering, real fire/loop/ bomb inputs); the skeptic watched for anything that feels wrong. Evidence, not vibes.

**SKEPTIC: 2 anomalies (0 critical, 0 high, 2 med) across 7 runs**

## Per-sortie stats

| Sortie | Kills | Deaths | Score | Kills/min | Dmg/min | Boss? |
|---|---|---|---|---|---|---|
| 1 Sortie 1 — Dawn Patrol | 7 | 1 | 1107 | 8.4 | 112 | no |
| 2 Sortie 2 — Moonlight Interdiction | 8 | 0 | 1280 | 9.6 | 30 | no |
| 3 Sortie 3 — The Zeppelin Sheds | 20 | 0 | 5150 | 24.0 | 60 | no |
| 4 Sortie 4 — Powder Keg | 24 | 0 | 6280 | 28.8 | 42 | no |
| 5 Sortie 5 — The Pens | 7 | 1 | 1879 | 8.4 | 54 | no |
| 6 Sortie 6 — Iron Harvest | 11 | 0 | 4215 | 13.2 | 60 | no |
| 7 Sortie 7 — The Thunderhead Duel | 8 | 1 | 1350 | 4.4 | 57 | yes |

## Anomalies

| t | Sortie | Severity | Kind | Evidence |
|---|---|---|---|---|
| 9.8s | 5 | **MED** | `sfx_spam` | "explosion_small" fired 7x in one second — the mix is shouting  |
| 9.8s | 5 | **MED** | `sfx_spam` | "flak" fired 7x in one second — the mix is shouting  |

## Ideas (1942-grounded, suggestions only)

1. Sortie 4 (Sortie 4 — Powder Keg): 28.8 kills/min is a pinata — check it doesn't trivialize the squadron break-point.

## Detector proof

WARNING: no seedfault run with a `pass_stall` flag was found — detector proof is missing this run.

_Thresholds: scripts/skeptic_config.gd. Bot: scripts/bot_pilot.gd._
