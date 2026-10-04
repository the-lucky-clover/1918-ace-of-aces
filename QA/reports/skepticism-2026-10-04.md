# Skepticism report — 2026-10-04

Automated playtesting: a mid-skill bot pilot flew every sortie through the real control path (touch steering, real fire/loop/ bomb inputs); the skeptic watched for anything that feels wrong. Evidence, not vibes.

**SKEPTIC: 3 anomalies (0 critical, 0 high, 3 med) across 7 runs**

## Per-sortie stats

| Sortie | Kills | Deaths | Score | Kills/min | Dmg/min | Boss? |
|---|---|---|---|---|---|---|
| 1 Sortie 1 — Dawn Patrol | 9 | 1 | 1289 | 10.8 | 120 | no |
| 2 Sortie 2 — Wolfpack | 11 | 0 | 1779 | 13.2 | 30 | no |
| 3 Sortie 3 — The Zeppelin Sheds | 16 | 0 | 3644 | 19.2 | 22 | no |
| 4 Sortie 4 — Powder Keg | 6 | 1 | 910 | 7.2 | 121 | no |
| 5 Sortie 5 — The Pens | 13 | 0 | 3599 | 15.6 | 74 | no |
| 6 Sortie 6 — Iron Harvest | 6 | 0 | 1999 | 7.2 | 42 | no |
| 7 Sortie 7 — The Thunderhead Duel | 5 | 1 | 800 | 2.7 | 63 | yes |

## Anomalies

| t | Sortie | Severity | Kind | Evidence |
|---|---|---|---|---|
| 11.9s | 5 | **MED** | `sfx_spam` | "explosion_small" fired 7x in one second — the mix is shouting  |
| 15.0s | 5 | **MED** | `sfx_spam` | "flak" fired 9x in one second — the mix is shouting  |
| 31.0s | 4 | **MED** | `sfx_spam` | "explosion_small" fired 8x in one second — the mix is shouting  |

## Ideas (1942-grounded, suggestions only)

1. No strong signals this run. The v11 borrow queue still stands: debrief kill-rating % would give the skeptic a sharper economy signal than kills/min alone.

## Detector proof

WARNING: no seedfault run with a `pass_stall` flag was found — detector proof is missing this run.

_Thresholds: scripts/skeptic_config.gd. Bot: scripts/bot_pilot.gd._
