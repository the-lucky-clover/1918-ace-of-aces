# 1918: Ace of Aces — Astra Handoff Brief

Written 2026-10-07 for Steven, so a second AI (Astra) lands running when his rate limit hits. Corrected 2026-10-14 (the Godot-on-GitHub fix below).

## Where things live (verified 2026-10-07, Godot location corrected 2026-10-14)

- **GitHub `the-lucky-clover/1918-ace-of-aces`** = the WHOLE project. v23, commit `0ea3d6e`, pushed clean, local main == origin/main, working tree clean. The web build lives at the repo root; the Godot 4.7.2 project lives in the repo's `godot/` folder (project.godot, scenes/, scripts/, assets/, blender/, export_presets.cfg), tracked since 2026-10-03 and current through v23. A fresh clone pulls everything Astra needs. (The live public link still serves an older build — republish is staged on Steven's approval-card tap.)
- **Godot 4.7.2 project is ON GITHUB** — `godot/` folder in `the-lucky-clover/1918-ace-of-aces`, pushed through v23. *Correction 2026-10-14: an earlier version of this brief said the Godot project was local-only. That was wrong — the wrong claim came from `~/workspace/1918-godot/`, a standalone working copy that is not a git repo and is not the canonical location. Ignore that folder; the repo's `godot/` is the source of truth.* Godot binary: `~/workspace/godot/Godot_v4.7.2-stable_linux.x86_64`.
- **His original 3D models:** `blender/models/player-spad.blend` + `player-spad.glb` ARE in the GitHub repo — pushed. Note: there is no wingman .blend; the wingman is sprite-based in the Godot project (`assets/sprites/wingman-spad.png`, `wingman/` roll frames, `scripts/wingman.gd`).
- **Local-only, never pushed:** `~/workspace/1918-ace-of-aces-assets/` (~65MB: reference photos, Blender backup files). Not needed by the build; share if Astra wants raw working files.

## The game (web build, v23)

- 32-sortie campaign, 3,196 enemies, 32 bosses, 128 elites, 128 secondaries; 1942 one-hit damage doctrine (player dies in one hit; enemies/bosses in fixed hits-to-destroy; HP hidden).
- Versioning: holistic from 0, +1 per work action. `VERSION` file + `bin/bump-version.sh` update both displays. **Every CHANGELOG.md entry in pirate speak** — house rule, no exceptions.
- Nightly: `QA/run-nightly.sh` (headless checks incl. photo-frame keyframe assertion); reports in `QA/reports/`.
- Automated skeptic QA: seeded-fault-proven detectors, four bot pilots (novice/average/expert/survivalist). **Known issues awaiting the next refit (v24):** threat_saturation in sorties 17, 25, 32 (18–32 concurrent attackers). Bots survive them — not ship-blockers. v24 refit is staged, waiting on Steven's word.

## Open decisions only Steven can make

1. **Title:** "Ace of Aces" killed (NOVA trademark), "Bloody April" killed, "Over the Trenches" crowded. Finalists: **"Canvas & Wire"** (screened clean) or **just "1918"** (clean). No final call yet.
2. **1917 vs 1918 date label:** S1's "9 Apr 1917" is an orphan from the superseded British arc; the campaign arc is coherent 1918 American (Issoudun → Armistice, matches 93rd Aero Squadron). Recommendation on file: S1 → "Mar 1918", Voss boss → ghost/legacy framing (he died Sep 1917) or swap to Udet (Blue Max 1918). Steven's call.
3. **Human verdicts owed:** photoreal sprite legibility, one-hit combat feel in human hands, web build playtest round two, two-device Wingman Link shakedown.
4. **Store path:** Play Console $25 account + identity verification (name must match government ID word-for-word); new accounts need **14 days of 12+ testers continuously opted in on the closed track** before production access. AdMob accounts + $2.99 remove-ads IAP are his moves; ad code can be wired on test units first.

## Suggested first tasks for Astra (no Steven input needed)

1. ~~Push `~/workspace/1918-godot/` to a repo (new repo or subdirectory) so it's shareable.~~ — ALREADY DONE: the Godot project is in the repo at `godot/`, pushed through v23. Nothing to push.
2. Build the Android export preset / native wrapper groundwork for the closed-track test.
3. Triage and fix the S17/S25/S32 saturation bugs when Steven green-lights the v24 refit.
4. Keep the skeptic nightly green; every fix lands with a seeded-fault proof.

## Standing rules (do not bend)

- No demos, no simulations, no placeholders — real functionality or honestly labeled gaps.
- No fake auth, fake testimonials, fake countdowns, dark patterns. Honest UX is the ethic.
- Never mention the shoe brand by name in the OG Box Scanner context (unrelated project, but same ethic).
- Harsh playtest language from Steven is specification, not attitude. Root-cause everything the same session.
