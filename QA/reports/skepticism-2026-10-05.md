# Skepticism report — 2026-10-05

Automated playtesting: a mid-skill bot pilot flew every sortie through the real control path (touch steering, real fire/loop/ bomb inputs); the skeptic watched for anything that feels wrong. Evidence, not vibes.

**SKEPTIC: 0 anomalies (0 critical, 0 high, 0 med) across 7 runs**

## Per-sortie stats

| Sortie | Kills | Deaths | Score | Kills/min | Dmg/min | Boss? |
|---|---|---|---|---|---|---|
| 1 Sortie 1 — Dawn Patrol | 7 | 1 | 1107 | 8.4 | 112 | no |
| 2 Sortie 2 — Moonlight Interdiction | 8 | 0 | 1280 | 9.6 | 30 | no |
| 3 Sortie 3 — The Zeppelin Sheds | 20 | 0 | 5150 | 24.0 | 60 | no |
| 4 Sortie 4 — Powder Keg | 24 | 0 | 6280 | 28.8 | 42 | no |
| 5 Sortie 5 — The Pens | 3 | 0 | 480 | 3.6 | 82 | no |
| 6 Sortie 6 — Iron Harvest | 11 | 0 | 4215 | 13.2 | 60 | no |
| 7 Sortie 7 — The Thunderhead Duel | 8 | 1 | 1350 | 4.4 | 57 | yes |

## Anomalies

None. The sky felt right.

## Ideas (1942-grounded, suggestions only)

1. Sortie 4 (Sortie 4 — Powder Keg): 28.8 kills/min is a pinata — check it doesn't trivialize the squadron break-point.
2. Sortie 5 (Sortie 5 — The Pens): kill-rate 3.6/min is 62% below the campaign median — consider a wiped-squadron bonus drop here (the POW-carrier homage queued in the v11 1942 research).

## Detector proof

The `--seedfault=stall` run wedged a pass aircraft and the skeptic flagged `pass_stall` as designed — the detector fires on real faults, not just theory.

_Thresholds: scripts/skeptic_config.gd. Bot: scripts/bot_pilot.gd._
