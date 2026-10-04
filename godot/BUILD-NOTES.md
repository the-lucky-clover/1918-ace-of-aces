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
  cratered no-man's-land with drifting set-piece sprites — now a rich grim
  war landscape: churned mud blotches, water-filled shell craters with
  flickering firelight glints, shattered tree stumps, wreckage, field
  furrows, drifting smoke banks, a burning horizon with distant artillery
  flashes, and floating embers/ash. Ground stays dark and desaturated so
  sprites and bullets stay readable.
- **Ground war** (`scripts/ground_war.gd`, `scripts/trench_segment.gd`,
  `scripts/trench_target.gd`): Allied and German trench networks scroll with
  the world — zigzag trenches, sandbag parapets, barbed wire, MG nests,
  infantry manning the lines. Factions read at a glance (khaki + blue-grey
  diamonds = Allied; field-grey + dark-red squares = German). An ambient
  battle rages between the lines independent of the player: MG tracers arc
  back and forth, muzzles blink, shells thump into the lines. German nests
  and infantry squads are live strafe targets (etype "trench") feeding the
  "strafe trenches" secondary — infantry erupt in arcade-stylized gore
  bursts (`scripts/fx/gore.gd`), nests explode.
- **Juice** (`scripts/effects.gd` + `scripts/fx/`): drawn explosions, floating
  score text, hit flashes, trauma-based screen shake, muzzle flashes on
  player and enemy guns, hot tracer streaks, thick black flak clouds with
  detonation flash, shockwave rings on bombs and big blasts, rising smoke
  columns, lingering embers.
- **Menus** (`scripts/menus.gd`): dread-soaked title (rising embers, ember
  shadow, "SIX SORTIES · SIX ACES · NO PARACHUTES"); debrief styled as a
  typed field report ("FIELD REPORT", "> " lines, MISSION COMPLETE /
  KILLED IN ACTION stamps on dried-blood dark).
- **Art**: all 42 finished Blender-rendered sprites from
  `~/workspace/1918-ace-of-aces-assets/sprites/` are imported and used.

## Feature pass — 2026-10-03: power-ups, wingman, fuel, ground war, sun, music

- **SPREAD SHOT** (`player.gd` `power_spread`): 5-way fan, 20 s. Rendered
  from the Blender item set (`render_powerups.py --kind spread`).
- **RAPID FIRE** (`player.gd` `power_rapid`): 2.5x fire-rate multiplier,
  20 s. Rendered from the Blender item set (`render_powerups.py --kind rapid`).
- **WINGMAN** (`scripts/wingman.gd`, `scenes/wingman.tscn`,
  `assets/sprites/wingman-spad.png`): escort AI in the same SPAD livery
  hue-shifted (shifted roundels/fuselage — `render_wingman.py` rotates hue
  0.5) so P1 is instantly discernible. Trails the player's flight path with
  a position-history buffer, holds rear-left / rear-right slots in a ^
  chevron pointing along the flight direction. Own HP (40), dies in an
  explosion; fights, firing at enemies within 430 px. Up to 2 at once
  (`player.gd` `add_wingman`); a dead wingman frees its slot, so a new
  pickup can replace it. Pickup icon: `item-wingman.png`.
- **LOOP-DE-LOOP** (`player.gd` `try_loop`): Q key (new `loop` input action,
  physical keycode 81) or double-tap. Full 0.75 s roll, invulnerable during
  the maneuver AND through a 2.5 s deck-stabilization window after. 10 s
  cooldown. HUD shows READY/cooldown.
- **FUEL** (`player.gd`, `hud.gd`): gauge depletes steadily — base 1.2/s +
  up to 1.8/s scaled by throttle, so pushing it drinks fuel. FUEL pickups
  (+35) from the drop table, and one drifts in every 24 s as a pressure
  valve. Low fuel (<25): flashing gauge + beep (`fuel_warn.wav`). Empty
  tank = engine dead: no thrust, heavy drag, sinking dead-stick glide;
  grabbing fuel restarts the engine; gliding into the deck = OUT OF FUEL
  crash (own debrief-fail path, wingmen die with you). Fuel can pickup
  rendered from the Blender item set (`render_fuel.py`, `item-fuel.png`).
- **Minimap** (`scripts/minimap.gd`): pickups colored by type (magenta
  spread, cyan rapid, blue wingman, orange fuel, yellow else); wingmen as
  blue dots; player blip rings — cyan (rapid), magenta (spread), gold
  (loop invuln / stabilization).
- **HUD** (`scripts/hud.gd`): fuel gauge under the hull bar
  (green->amber->red, flashes below 25%); power-up status line
  (SPREAD/RAPID timers, LOOP [Q] readiness, WINGMEN count).
- **Ground war expansion** (`scripts/ground_war.gd`,
  `scripts/tank_duel.gd`): burning buildings (small at this altitude)
  scattered along the front with flickering fire and rising smoke columns;
  tank duels — Allied khaki (blue-grey diamond) vs German field-grey
  (dark-red square) tanks trading arcing shells, 75% hit chance, burning
  wrecks persist as they scroll. Pure ground theater, cannot hurt the
  player.
- **Dynamic lighting** (`scripts/sun.gd`): each sortie declares a takeoff
  time (`sortie_data.gd` "takeoff"); `Sun.shadow_for_takeoff()` maps it to
  a shadow vector — long shadows east/west at dawn/dusk, short at noon.
  Player, enemies, bosses, wingmen draw soft top-down elliptical shadows
  via `Sun.draw_shadow()`.
- **HDR-ish bloom**: `main.tscn` `WorldEnvironment` + Environment
  `background_mode=BG_CANVAS`, subtle glow (intensity 0.35, bloom 0.05) —
  cheap, only brightens explosions/firelight/popups.
- **Music** (`scripts/music.gd` autoload, `tools/make_music.py`):
  three ORIGINAL synthesized chiptune loops (numpy -> WAV, square/triangle
  waves, no external assets) — `splash_theme.wav` (heroic 32 s),
  `pause_theme.wav` (restrained 32 s), `gameplay_theme.wav` (heroic 1m52
  seamless loop), plus `fuel_warn.wav` beep. Crossfades (1.4 s) on
  title/splash, sortie/gameplay, pause. All validated as seamless loops
  (boundary continuity checked in the synth script).
- **Build order**: run `tools/make_music.py` BEFORE exporting/importing, so
  the four WAVs exist in `assets/music/`; the music autoload loads them at
  runtime. (They're committed with the project too.)
- Headless-validated 2026-10-03: clean import + autostart + autoboss
  smoke tests, zero errors.

## Polish pass — 2026-10-03: full modular tune-up ("tally-ho" standard)

Every module improved, nothing regressed. Headless-validated: clean
import, 30 s smoke test, boss-rush full loop — zero script errors.

- **PLAYER** (`player.gd`): banking tilt now lerps (smooth roll-in/out,
  no snapping); tiny recoil kick per shot for weapon punch; loop-de-loop
  punches forward out of the maneuver (classic 194x exit dash); "LOOP
  READY" callout when the cooldown completes; one-time "LOW FUEL!" popup
  when crossing 25% fuel.
- **ENEMIES** (`enemy.gd`): per-spawn speed variance (±8%); 0.35 s
  telegraph flash before every shot; 0.4 s fade-in on entry; heavy kills
  (bomber/balloon/railway gun) punctuated with a brief hit-stop.
- **BOSSES** (`boss.gd`): phase changes now land a slow-mo beat
  (hit-stop 0.35 s); last-stand ENRAGE under 15% HP (faster guns +
  callout); boss death gets a final slow-mo beat.
- **POWER-UPS** (`pickup.gd`, `enemy.gd`, `global.gd`): pickups magnetize
  toward the player within 130 px; every collect fires a colored sparkle
  burst; pity timer guarantees a drop after 22 dry kills
  (`Global.kills_since_drop`).
- **WINGMAN** (`wingman.gd`, `player.gd`): follow steering is now
  velocity-smoothed (no jitter); a wingman going down grants the player
  1 s mercy invulnerability.
- **FUEL**: one-time LOW FUEL callout at 25% (in addition to the flashing
  gauge + beep); drain balance unchanged (arcade-fair).
- **GROUND WAR** (`ground_war.gd`, `tank_duel.gd`): new "BIG PUSH"
  event every 45–75 s — synchronized volleys, walking shell bursts, and
  a cry from the front; tanks now flash muzzles when firing.
- **SUN/LIGHTING** (`sun.gd`, `main.gd`): shadow darkness follows sun
  elevation (deep at dawn/dusk, faint at noon); new per-sortie time-of-day
  mood tint overlay (warm dawn, neutral midday, blood-red dusk, low alpha).
- **MUSIC/AUDIO** (`music.gd`, `main.gd`): game track ducks during boss
  duels and restores after; SFX still stubbed (noted, not built).
- **HUD/MENUS** (`hud.gd`, `menus.gd`, `main.gd`): score label flashes on
  every gain; hull bar bleeds red for a beat on damage; pause menu now
  lists live mandatory + optional objectives; sorties open with a
  "TALLY-HO!" cry.
- **EFFECTS** (`effects.gd`, `fx/shockwave.gd`, `bullet.gd`, `main.gd`):
  new `FX.hitstop()` (nesting-safe time-scale dip); collect bursts reuse
  the shockwave ring with per-pickup tint; player tracers can now shoot
  down incoming enemy fire (both die in a spark); enemy bullets capped at
  240 live for readability; trench strafe streaks (3+ kills in 4 s) pay
  escalating bonus points with callouts.

## Cinematic minimap + takeoff/landing pass — 2026-10-03

- **Modular cinematic sequencer** (`scripts/cinematic.gd`): one reusable
  player runs both reels, parameterized per sortie (theme, takeoff time via
  `sun.gd` for shadow vectors + mood tint, sortie name). Skippable with tap /
  ENTER ("TAP TO SKIP" hint). Emits `finished` once per reel.
- **Takeoff reel** (~6.6 s): Allied aerodrome from directly overhead (runway
  strip, hangar tents, windsock, parked SPADs, slow push-in) → takeoff roll
  (acceleration, dust puffs, smooth tracking) → climb-out (ground falls away,
  shadow separates and fades with altitude, farmland scrolls fast, trench
  band slides in at the front). Captioned with sortie name + takeoff time.
- **Landing reel** (~6.4 s, victory only): return cruise over farmland →
  final approach (aerodrome centered, shadow converges as altitude bleeds
  off) → touchdown (dust burst, rollout decel, "MISSION COMPLETE" stamp).
- **IRON RULE honored**: the virtual camera never leaves top-down —
  perpendicular to the playfield through every shot. Pan + zoom only; never
  rotation, never tilt. (Aircraft bank in-plane; that is the plane moving.)
- **Flow** (`main.gd`): new `State.CINEMATIC`. `start_sortie` now plays the
  takeoff reel, then `_begin_play()` (brief banner, TALLY-HO, game music —
  moved here so the brief no longer expires behind the reel). Boss kill on
  victory plays the landing reel, then the debrief; defeat skips straight to
  debrief. Both reels auto-skip in headless autotest.
- **Minimap upgrade** (`scripts/minimap.gd`, `hud.gd`): theme-aware terrain
  backdrop (farmland patchwork / trench lines with cratered band / crater
  speckle, plus home-aerodrome marker); animated unit icons (triangles
  oriented by travel direction, pulsing; boss = pulsing diamond with
  expanding threat ring); pulsing gold markers on live secondary-objective
  targets (balloons/trench/railgun/bombers); smoothed icon motion plus an
  eased camera-follow reticle around the player; existing power-up rings
  kept. Still readable at a glance.
- Headless-validated 2026-10-03: clean import, 30 s autostart smoke test,
  boss-rush full loop (`phase 2 → phase 3 → killed (+2000) → debrief
  win=true`) — zero script errors. Both cinematic reels exercised
  headless (takeoff skip path + landing natural finish) — zero errors.

## Minimap locales pass — 2026-10-03: five new locales, every sortie distinct

Eight themes in the system (`minimap.gd` `_draw_terrain`, `background.gd`
`THEMES` + theme-pooled `GroundFeatures`, `ground_war.gd` density). Sortie
roster — no two sorties share a locale:

- **S1 Dawn Patrol — farmland** (unchanged): gentle intro, balloons + trenches.
- **S2 Wolfpack — uboat_flotilla** (NEW): open coastal water, sandy
  coastline, wave speckle. U-boats ride surfaced — sink 4 before they
  crash-dive (proximity dive, 2 s submerge, escapes with no kill). Secondaries:
  uboats(4), bombers(3). Ground war stands down at sea (`naval` flag: no
  trench segments, no tank duels).
- **S3 The Zeppelin Sheds — zeppelin_sheds** (NEW): giant hangar sheds +
  mooring mast on the ground and minimap. Zeppelins (420 HP drifting
  gasbags, big score) + parked aircraft to strafe. Secondaries: zeppelins(2),
  parked(4).
- **S4 Powder Keg — munitions_depot** (NEW): ammo-dump grid + rail spur.
  Depots **chain-detonate** — killing one sets off every depot within
  210 px (`CHAIN DETONATION!`). Secondaries: depots(4), trenches(5).
- **S5 The Pens — uboat_base** (NEW): harbor with concrete moles, pen
  blocks, cranes. Concrete sub pens (320 HP, roof AA) under heavy flak.
  Secondaries: pens(3), uboats(2).
- **S6 Iron Harvest — rail_yard** (NEW): marshaling yard, rail fan, boxcars.
  The railway gun's home turf — trains to wreck, artillery batteries
  defending. Secondaries: railgun(1), arty(4).

New enemy types (`enemy.gd` TYPES): uboat (dive mechanic), subpen,
zeppelin, ammodepot (chain), train (sways along rails), arty
(counter-battery), parked (reuses scout sprite). New Blender renders
(`blender/build_locales.py`, `render_locales.py`): uboat, subpen, zeppelin,
ammodepot, train, arty — all <400 tris, original. Ground/naval targets don't
drop pickups; zeppelin/subpen/train get heavy-kill FX. Considered but cut:
artillery park, enemy forward airfield, balloon park (staged candidates).

## Flak / weather / orchestration pass — 2026-10-03 (v3)

All tuned MILD by design — fun and replayable beats punishing. Headless-validated:
clean import, 30 s smoke, boss-rush full loop, plus all 6 sorties exercised
headless (new `--sortie=N` autotest hook) — zero script errors. The sweep caught
two pre-existing bugs (fixed): `_spawn_piece` modulo-by-zero on empty `pieces`
arrays (naval/rear-area locales) and `secondary_text` formatting the railgun's
`%d`-less text with a target arg.

- **FLAK / ARCHIE REWORK** (`flak_shell.gd`, `enemy.gd`, `main.gd`):
  - AA batteries fire TIMED shells fused to burst near the player with a
    slight lead on velocity (lead 0.45, shell speed 560 px/s).
  - CONGA LINES: each firing opens a volley of 4–6 shells ~0.4 s apart
    marching along the trajectory toward the player's area.
  - Every burst leaves the persistent small black puff (~5.5 s, visual-only).
  - Damage: splash within 40 px = LIGHT (6.5 hull); DIRECT hit within 12 px
    of the plane = devastating (70 hull, can destroy the airframe — "DIRECT
    HIT!" callout + hit-stop beat).
  - CAMPING PUNISHMENT: stillness (speed < 70 px/s) feeds `Global.aa_heat`
    0→1 over 2.5 s; movement bleeds it off. Hot guns: tighter lead (up to
    0.9), error radius shrinks 46→16 px, volleys grow 4→6 shells. One fair
    warning — "ARCHIE'S GOT YOUR RANGE!" — when the guns find you. The 0.35 s
    muzzle windup flash telegraphs every volley.
- **ORCHESTRATION** (`sortie_data.gd`, `minimap.gd`): all 6 wave timelines
  rebuilt on a build-tension-release rhythm — light intro, escalating fighter
  waves, the secondary target at ~75% of the route, the ace at 100% (end).
  Minimap telegraphs it: a route rail with a gold tick at 75% and a pulsing
  red boss diamond at 100%, plus a live progress pip.
- **DYNAMIC WEATHER** (`scripts/weather.gd` new, `player.gd`, `bullet.gd`,
  `background.gd`, `minimap.gd`): per-sortie seeded conditions — S1 clear,
  S2 windy, S3 rain, S4 storm, S5 windy, S6 clear. Wind vector (34–72 px/s)
  drifts the player (0.55×), pushes crosswind laterally (0.35×) and makes
  turns slightly sluggish (grip −10% × intensity); tracers bend lightly
  (0.25×). Turbulence: gentle periodic airframe nudges, scaled by intensity.
  NO weather damage, ever. Storm: jagged lightning bolts + restrained white
  screen flash (SFX still stubbed). Rain: slanted particle sheet streaks
  angled by wind, density by intensity. Minimap: wind arrow (dir + strength)
  and pulsing storm-cell icons where lightning is active.
- **SKY** (`background.gd`): palette shifted blue-sky-friendly through
  altitude haze (still dark enough for readability); high cloud-wisp features
  added to every locale pool; feature wrapping verified seamless.

Tuning numbers: splash 6.5/40px · direct 70/12px · conga 4–6 @ 0.4s ·
camping threshold 70 px/s, 2.5 s to full heat · wind 34–72 px/s ·
turbulence 26–80 px/s nudges every 0.45–0.9 s · lightning every 3.5–8 s.

## What's stubbed / not yet validated

- **Player art**: `assets/sprites/player-spad.png` is now a real Blender render
  (French khaki/linen biplane with tricolor roundels, top-down) generated
  from the existing procedural aircraft builder — no longer a placeholder.
- **Player-death → debrief-fail path**: code is straightforward and shares the
  validated debrief, but the headless tests used godmode — not yet exercised.
- **Bosses 2–6 and sorties 2–6**: data-driven on the same validated code
  paths, but only boss 0 / sortie 1 ran headless. Needs an editor playthrough.
- **No audio**: SFX (explosions, gunfire, pickups) not yet built — music
  tracks only (the web build has a synthesized score — port or regenerate
  SFX for Godot).
- **Touch controls**: mouse-click fire works; real touch-drag flight is not
  implemented (`emulate_touch_from_mouse` is on, but no touch flight scheme).
- **No export presets**: iOS/Android/desktop export still needs configuring
  in the editor (export templates + presets).
- **Difficulty balance**: tuned for "beatable" but not playtested by a human.
- **Debug flags** (kept intentionally): `-- --autostart` and
  `-- --autoboss` headless smoke-test hooks in `main.gd`; harmless in normal
  play.
