# Skepticism report — 2026-10-05

Automated playtesting: a mid-skill bot pilot flew every sortie through the real control path (touch steering, real fire/loop/ bomb inputs); the skeptic watched for anything that feels wrong. Evidence, not vibes.

**SKEPTIC: 1 anomalies (0 critical, 0 high, 1 med) across 7 runs**

## Per-sortie stats

| Sortie | Kills | Deaths | Score | Kills/min | Dmg/min | Boss? |
|---|---|---|---|---|---|---|
| 1 Sortie 1 — Dawn Patrol | 9 | 0 | 1554 | 10.8 | 20 | no |
| 2 Sortie 2 — Moonlight Interdiction | 6 | 1 | 1144 | 7.2 | 122 | no |
| 3 Sortie 3 — The Zeppelin Sheds | 10 | 0 | 1722 | 12.0 | 30 | no |
| 4 Sortie 4 — Powder Keg | 6 | 1 | 1000 | 7.2 | 164 | no |
| 5 Sortie 5 — The Pens | 2 | 2 | 900 | 2.4 | 206 | no |
| 6 Sortie 6 — Iron Harvest | 4 | 1 | 1150 | 4.8 | 130 | no |
| 7 Sortie 7 — The Thunderhead Duel | 12 | 1 | 2020 | 6.5 | 19 | yes |

## Anomalies

| t | Sortie | Severity | Kind | Evidence |
|---|---|---|---|---|
| 12.4s | 5 | **MED** | `sfx_spam` | "explosion_small" fired 7x in one second — the mix is shouting  |

## Ideas (1942-grounded, suggestions only)

1. Sortie 5 (Sortie 5 — The Pens): kill-rate 2.4/min is 66% below the campaign median — consider a wiped-squadron bonus drop here (the POW-carrier homage queued in the v11 1942 research).

## Detector proof

WARNING: no seedfault run with a `pass_stall` flag was found — detector proof is missing this run.

_Thresholds: scripts/skeptic_config.gd. Bot: scripts/bot_pilot.gd._
