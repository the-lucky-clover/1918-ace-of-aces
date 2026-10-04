# Skepticism report — 2026-10-04

Automated playtesting: a mid-skill bot pilot flew every sortie through the real control path (touch steering, real fire/loop/ bomb inputs); the skeptic watched for anything that feels wrong. Evidence, not vibes.

**SKEPTIC: 3 anomalies (0 critical, 0 high, 3 med) across 7 runs**

## Per-sortie stats

| Sortie | Kills | Deaths | Score | Kills/min | Dmg/min | Boss? |
|---|---|---|---|---|---|---|
| 1 Sortie 1 — Dawn Patrol | 16 | 1 | 3620 | 19.2 | 136 | no |
| 2 Sortie 2 — Wolfpack | 12 | 0 | 2210 | 14.4 | 12 | no |
| 3 Sortie 3 — The Zeppelin Sheds | 8 | 0 | 1666 | 9.6 | 22 | no |
| 4 Sortie 4 — Powder Keg | 18 | 0 | 5566 | 21.6 | 54 | no |
| 5 Sortie 5 — The Pens | 6 | 0 | 1647 | 7.2 | 80 | no |
| 6 Sortie 6 — Iron Harvest | 4 | 1 | 1104 | 4.8 | 121 | no |
| 7 Sortie 7 — The Thunderhead Duel | 8 | 2 | 1619 | 4.4 | 95 | yes |

## Anomalies

| t | Sortie | Severity | Kind | Evidence |
|---|---|---|---|---|
| 15.0s | 5 | **MED** | `sfx_spam` | "explosion_small" fired 7x in one second — the mix is shouting  |
| 22.2s | 4 | **MED** | `sfx_spam` | "explosion_small" fired 7x in one second — the mix is shouting  |
| 42.4s | 1 | **MED** | `sfx_spam` | "explosion_small" fired 7x in one second — the mix is shouting  |

## Ideas (1942-grounded, suggestions only)

1. Sortie 6 (Sortie 6 — Iron Harvest): kill-rate 4.8/min is 50% below the campaign median — consider a wiped-squadron bonus drop here (the POW-carrier homage queued in the v11 1942 research).

## Detector proof

WARNING: no seedfault run with a `pass_stall` flag was found — detector proof is missing this run.

_Thresholds: scripts/skeptic_config.gd. Bot: scripts/bot_pilot.gd._
