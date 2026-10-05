# Skepticism report — 2026-10-05

Automated playtesting: a mid-skill bot pilot flew every sortie through the real control path (touch steering, real fire/loop/ bomb inputs); the skeptic watched for anything that feels wrong. Evidence, not vibes.

**SKEPTIC: 5 anomalies (0 critical, 0 high, 5 med) across 7 runs**

## Per-sortie stats

| Sortie | Kills | Deaths | Score | Kills/min | Dmg/min | Boss? |
|---|---|---|---|---|---|---|
| 1 Sortie 1 — Dawn Patrol | 10 | 0 | 2207 | 12.0 | 65 | no |
| 2 Sortie 2 — Moonlight Interdiction | 17 | 0 | 4384 | 20.4 | 12 | no |
| 3 Sortie 3 — The Zeppelin Sheds | 7 | 1 | 1524 | 8.4 | 53 | no |
| 4 Sortie 4 — Powder Keg | 12 | 1 | 3736 | 14.4 | 140 | no |
| 5 Sortie 5 — The Pens | 6 | 1 | 1060 | 7.2 | 175 | no |
| 6 Sortie 6 — Iron Harvest | 3 | 0 | 1330 | 3.6 | 43 | no |
| 7 Sortie 7 — The Thunderhead Duel | 15 | 1 | 4314 | 8.2 | 29 | yes |

## Anomalies

| t | Sortie | Severity | Kind | Evidence |
|---|---|---|---|---|
| 12.4s | 5 | **MED** | `sfx_spam` | "explosion_small" fired 7x in one second — the mix is shouting  |
| 15.5s | 5 | **MED** | `sfx_spam` | "flak" fired 7x in one second — the mix is shouting  |
| 23.3s | 4 | **MED** | `sfx_spam` | "explosion_small" fired 7x in one second — the mix is shouting  |
| 43.4s | 2 | **MED** | `sfx_spam` | "explosion_small" fired 7x in one second — the mix is shouting  |
| 47.0s | 1 | **MED** | `sfx_spam` | "explosion_small" fired 8x in one second — the mix is shouting  |

## Ideas (1942-grounded, suggestions only)

1. Sortie 4 (Sortie 4 — Powder Keg): damage pressure 140/min is 2.7x the median — check telegraph fairness on its waves (1942 was built for accessibility, not punishment).
2. Sortie 5 (Sortie 5 — The Pens): damage pressure 175/min is 3.3x the median — check telegraph fairness on its waves (1942 was built for accessibility, not punishment).
3. Sortie 6 (Sortie 6 — Iron Harvest): kill-rate 3.6/min is 57% below the campaign median — consider a wiped-squadron bonus drop here (the POW-carrier homage queued in the v11 1942 research).

## Detector proof

WARNING: no seedfault run with a `pass_stall` flag was found — detector proof is missing this run.

_Thresholds: scripts/skeptic_config.gd. Bot: scripts/bot_pilot.gd._
