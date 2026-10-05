# Skepticism report — 2026-10-05

Automated playtesting: a mid-skill bot pilot flew every sortie through the real control path (touch steering, real fire/loop/ bomb inputs); the skeptic watched for anything that feels wrong. Evidence, not vibes.

**SKEPTIC: 5 anomalies (0 critical, 0 high, 5 med) across 7 runs**

## Per-sortie stats

| Sortie | Kills | Deaths | Score | Kills/min | Dmg/min | Boss? |
|---|---|---|---|---|---|---|
| 1 Sortie 1 — Dawn Patrol | 8 | 1 | 1307 | 9.6 | 122 | no |
| 2 Sortie 2 — Moonlight Interdiction | 18 | 0 | 4754 | 21.6 | 67 | no |
| 3 Sortie 3 — The Zeppelin Sheds | 14 | 0 | 3470 | 16.8 | 103 | no |
| 4 Sortie 4 — Powder Keg | 14 | 1 | 4070 | 16.8 | 144 | no |
| 5 Sortie 5 — The Pens | 9 | 1 | 2090 | 10.8 | 152 | no |
| 6 Sortie 6 — Iron Harvest | 3 | 0 | 1095 | 3.6 | 118 | no |
| 7 Sortie 7 — The Thunderhead Duel | 7 | 1 | 1307 | 3.8 | 41 | yes |

## Anomalies

| t | Sortie | Severity | Kind | Evidence |
|---|---|---|---|---|
| 12.4s | 5 | **MED** | `sfx_spam` | "explosion_small" fired 7x in one second — the mix is shouting  |
| 15.5s | 2 | **MED** | `sfx_spam` | "explosion_small" fired 7x in one second — the mix is shouting  |
| 21.2s | 4 | **MED** | `sfx_spam` | "explosion_small" fired 8x in one second — the mix is shouting  |
| 21.2s | 4 | **MED** | `sfx_spam` | "flak" fired 7x in one second — the mix is shouting  |
| 40.3s | 7 | **MED** | `sfx_spam` | "explosion_small" fired 8x in one second — the mix is shouting  |

## Ideas (1942-grounded, suggestions only)

1. Sortie 6 (Sortie 6 — Iron Harvest): kill-rate 3.6/min is 66% below the campaign median — consider a wiped-squadron bonus drop here (the POW-carrier homage queued in the v11 1942 research).

## Detector proof

WARNING: no seedfault run with a `pass_stall` flag was found — detector proof is missing this run.

_Thresholds: scripts/skeptic_config.gd. Bot: scripts/bot_pilot.gd._
