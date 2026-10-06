# Skepticism report — 2026-10-06

Automated playtesting: a mid-skill bot pilot flew every sortie through the real control path (touch steering, real fire/loop/ bomb inputs); the skeptic watched for anything that feels wrong. Evidence, not vibes.

**SKEPTIC: 2 anomalies (0 critical, 0 high, 2 med) across 5 runs**

## Per-sortie stats

| Sortie | Kills | Deaths | Score | Kills/min | Dmg/min | Boss? |
|---|---|---|---|---|---|---|
| 1 Sortie 1 — VIMY RIDGE | 33 | 2 | 8448 | 39.6 | 60 | no |
| 9 Sortie 9 — MOSELLE | 14 | 1 | 4300 | 16.8 | 30 | no |
| 17 Sortie 17 — MARNE DAWN | 16 | 2 | 5948 | 19.2 | 42 | no |
| 25 Sortie 25 — UDET'S GAMBIT | 10 | 2 | 3925 | 12.0 | 44 | no |
| 32 Sortie 32 — ARMISTICE | 4 | 2 | 1450 | 2.2 | 20 | no |

## Anomalies

| t | Sortie | Severity | Kind | Evidence |
|---|---|---|---|---|
| 15.3s | 32 | **MED** | `spawn_camp` | e4_fokker_dr1 spawned 90px from the player etype=e4_fokker_dr1 |
| 16.2s | 32 | **MED** | `spawn_camp` | e4_fokker_dr1 spawned 91px from the player etype=e4_fokker_dr1 |

## Ideas (1942-grounded, suggestions only)

1. Sortie 1 (Sortie 1 — VIMY RIDGE): 39.6 kills/min is a pinata — check it doesn't trivialize the squadron break-point.
2. Sortie 32 (Sortie 32 — ARMISTICE): kill-rate 2.2/min is 87% below the campaign median — consider a wiped-squadron bonus drop here (the POW-carrier homage queued in the v11 1942 research).

## Detector proof

The `--seedfault=stall` run wedged a pass aircraft and the skeptic flagged `pass_stall` as designed — the detector fires on real faults, not just theory.

_Thresholds: scripts/skeptic_config.gd. Bot: scripts/bot_pilot.gd._
