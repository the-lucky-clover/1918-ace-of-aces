# 1918 — Godot Build Notes

A real, working **Godot 4.x** project: a 2D top-down WWI shoot-em-up in the
spirit of Capcom's 194x. Portrait 720x1280, GL Compatibility renderer.

> **Working title:** the release title is still pending Steven's pick.
> It lives in exactly one place: `GAME_TITLE` in `scripts/global.gd`.
> Menus, HUD, and debrief all read from that constant.

## Godot version

- Built and headless-validated with **Godot 4.7.2-stable**
  (`4.7.2.stable.official.ed1daf0bf`).
- Headless editor binary lives at `~/workspace/godot/`
  (`Godot_v4.7.2-stable_linux.x86_64`) — reused for any future checks.

## How to open / run

1. Open Godot 4.x (4.7.2 recommended) → **Import** → select
   `~/workspace/1918-godot/project.godot` → **Open**.
2. Press **F5** (or the Play button). Main scene is `scenes/main.tscn`.
3. Controls: **WASD / arrows** fly · **SPACE / click** fire ·
   **X / SHIFT** bomb · **ESC** pause · **ENTER** start/continue.

Headless checks (no editor needed):

```bash
# import + script parse check
~/workspace/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path ~/workspace/1918-godot --import
# 30s gameplay smoke test, sortie 1, invincible auto-firing player
~/workspace/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path ~/workspace/1918-godot --quit-after 1800 -- --autostart
# boss-rush test: boss 0 immediately, 8x damage (validates phases → death → debrief)
~/workspace/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path ~/workspace/1918-godot --quit-after 4800 -- --autostart --autoboss
```

Both smoke tests pass with **zero script/resource errors**. Boss-rush log:
`phase 2 → phase 3 → killed (+2000) → debrief win=true primary=true`.

## What's implemented

- **Player SPAD XIII** (`scripts/player.gd`): real inertia — velocity,
  acceleration, exponential drag; banking tilt tied to lateral velocity;
  3-level weapon spread, bombs (194x panic button: wipes bullets, heavy AoE),
  airframe-integrity HP, hit flash, 1s post-hit invulnerability.
- **Enemies** (`scripts/enemy.gd`): triplane (weaves), scout (dives at you),
  fighter (balanced), bomber (slow tank), Caquot balloon (drifting HP sponge),
  AA gun (fires flak), railway gun (telegraphed 3-shell fan + "INCOMING!"),
  trench positions (destructible ground targets). Aircraft swap
  bank-left/level/bank-right sprites with turn direction.
- **AA flak** (`scripts/flak_shell.gd`): shells fly to a point near your
  position, then detonate — damage **only** in a small radius at detonation;
  afterward a lingering **black cloud** hangs for ~5s, visual-only (per spec).
- **Mission structure** (`scripts/sortie_data.gd`): 6 sorties, each with one
  **MANDATORY** primary (kill the sortie's ace) and **OPTIONAL** secondaries
  (bust balloons, strafe trenches, destroy the railway gun, down bombers)
  worth bonus points, tracked live in the HUD and itemized in the debrief.
- **6 boss aces** (`scripts/boss.gd`): fictional callsigns, 3 phases each
  (aimed bursts → spread fans + telegraphed charges → aggressive spiral
  charges), phase-change bullet clear (mercy), multi-explosion death.
- **Minimap** (`scripts/minimap.gd`): player/enemies/boss/pickups, live.
- **HUD** (`scripts/hud.gd`): hull bar (green→amber→red), score, sortie name,
  bomb count, objective checklist, boss bar, sortie brief banner.
- **Menus** (`scripts/menus.gd`): title, pause, debrief (win/fail/campaign),
  fade screen transitions (`main.gd`).
- **Backgrounds** (`scripts/background.gd`): scrolling farmland / trenches /
  cratered no-man's-land with drifting set-piece sprites.
- **Juice** (`scripts/effects.gd` + `scripts/fx/`): drawn explosions, floating
  score text, hit flashes, trauma-based screen shake, muzzle… (tracers).
- **Art**: all 42 finished Blender-rendered sprites from
  `~/workspace/1918-ace-of-aces-assets/sprites/` are imported and used.

## What's stubbed / not yet validated

- **Player art is a placeholder**: no Blender SPAD XIII render exists in the
  sprite set, so `assets/sprites/player-spad.png` is a simple PIL-drawn
  top-down biplane (roundels included). Swap in a real render when available.
- **Player-death → debrief-fail path**: code is straightforward and shares the
  validated debrief, but the headless tests used godmode — not yet exercised.
- **Bosses 2–6 and sorties 2–6**: data-driven on the same validated code
  paths, but only boss 0 / sortie 1 ran headless. Needs an editor playthrough.
- **No audio**: no music/SFX yet (the web build has a synthesized score —
  port or regenerate for Godot).
- **Touch controls**: mouse-click fire works; real touch-drag flight is not
  implemented (`emulate_touch_from_mouse` is on, but no touch flight scheme).
- **No export presets**: iOS/Android/desktop export still needs configuring
  in the editor (export templates + presets).
- **Difficulty balance**: tuned for "beatable" but not playtested by a human.
- **Debug flags** (kept intentionally): `-- --autostart` and
  `-- --autoboss` headless smoke-test hooks in `main.gd`; harmless in normal
  play.
