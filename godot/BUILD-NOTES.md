# 1918 — Godot Build Notes

A real, working **Godot 4.x** project: a 2D top-down WWI shoot-em-up in the
spirit of Capcom's 194x. Portrait 720x1280, GL Compatibility renderer.

> **Working title:** the release title is still pending Steven's pick.
> It lives in exactly one place: `GAME_TITLE` in `scripts/global.gd`.
> Menus, HUD, and debrief all read from that constant.

## Art direction — the doctrine

**1918 is a juiced-up 1942.** Capcom's spirit, with the badass juice turned all
the way up: every airframe and every acre of earth rendered like it exists in
the real world.

- **Photorealistic, never photographic.** Everything is procedural and original
  — built in Blender, painted in code — but it must *read* as real: wood grain
  you could run a thumb over, doped linen with a sheen, oil staining around
  the cowling, mud with a wet shine. We never claim a procedural pixel is a
  photograph; we just make you forget to ask.
- **Skeuomorphic.** Materials behave like materials. Canvas folds, timber shows
  grain, water reflects sky, metal glints. If it doesn't feel touchable, it
  isn't done.
- **2.5D.** Strictly top-down camera, always — but the world has *depth*:
  cloud decks at real heights throwing soft shadows, altitude-true aircraft
  shadows, parallax that sells 10,000 feet. Flat is a failure mode.
- **One light, one world.** The v14 sun rig is the single source of truth.
  Every sprite, every shadow, every glint obeys the same sun. Nothing
  pasted on, nothing floating outside the light.
- **Readability is king.** Beauty never hides gameplay. A tracer, an enemy, a
  pickup must read in 1–2 seconds against any background. If the masterpiece
  gets in the way of the war, the masterpiece yields.

*Look like the real thing. Feel like a physical object. Play like 1942 on its
best day ever.*

— *enshrined per Steven, "with tact and panache," 2026-10-04*

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

## Squadron goals + flicker/shutdown hardening — 2026-10-03 (v4)

- **SQUADRON SHOOT-DOWN GOALS** (`sortie_data.gd`, `main.gd`, `hud.gd`,
  `menus.gd`, `enemy.gd`, `global.gd`): every sortie now declares its
  fighter-wave squadron strength and an attainable break-point goal
  (~55% — a decent run hits it, a great run exceeds it):
  S1 18→goal 10 (+400) · S2 19→11 (+500) · S3 22→13 (+600) ·
  S4 16→9 (+700) · S5 16→9 (+800) · S6 12→7 (+900).
  HUD shows live "SQUADRON x/y" under the score; on the break-point:
  "SQUADRON BROKEN!" callout + escalating bonus + the label turns gold.
  Morale break is real but subtle — surviving fighters fly ragged:
  weave amplitude ×1.35, scouts break off their dives earlier
  (56 px vs 8 px commitment), gunnery 20% sloppier. Debrief credits
  the squadron line ("v SQUADRON: 11/11 DOWN — BROKEN (+500)").
- **HARD RULE honored — no intro popups**: new enemies/locales debut the
  194x way, flying into frame with zero ceremony. Steven killed the
  procession outright.
- **FLICKER HARDENING**: kill-before-create on all hot modulate/alpha
  tweens — score flash (`hud.gd` `_score_tween`), hull bleed
  (`_hull_tween`), screen fades (`main.gd` `_fade_tween`), hit flashes
  (`effects.gd` `_flash_tween` via item meta). Rapid stacked hits can no
  longer make competing tweens fight over the same property mid-frame.
- **SHUTDOWN HARDENING (audit)**: player death and boss death both arm
  `debrief_timer` (verified statically — no stranded screens); cinematic
  `_finish()` already single-emits via `_emitted` guard; player `_die()`
  guarded by `alive`; state transitions guarded (`_on_menu_start` only
  from TITLE, `_on_menu_next` only from DEBRIEF); all `randi() % size()`
  sites guarded against empty arrays (added the last missing one:
  `background.gd` `generate()` pool guard); cinematic `dur`/`life`
  divisors all non-zero by data. No new crash paths found in the v3
  weather/flak code.
- **QA**: `run-nightly.sh` gains five GDScript static checks —
  squadron-reset, debrief-paths, tween-guards, pool-guard,
  squadron-goals-sane.
- Headless-validated: clean import, 30 s smoke, boss-rush full loop,
  all 6 sorties exercised — zero script errors.

## Ground war expansion — 2026-10-03 (v5)

Historically accurate (or at worst plausible), 194x-spirited: everything
just shows up, no intro popups, game stays readable at full speed.

- **TROOP TRUCKS** (`scripts/truck.gd` new): canvas-covered-bed lorries
  drive down toward the front (outpacing the scroll), STOP near the lines
  ("UNLOADING!"), and three feldgrau infantry shuffle out and MARCH
  up-screen toward the trenches, then dig in as live strafe targets
  (etype "trench" — they join the existing strafe pool + streaks).
  Bombable/strafeable (70 HP, 250 pts); empty trucks rattle off unharmed
  (no kill). New secondary **"Interdict %d reinforcement trucks"**
  (+550) on S1 and S4 (2 trucks each). Procedurally drawn (canvas ribs
  flutter, cab, wheels) — no Blender render needed; noted.
- **ENEMY AIRFIELD** (`scripts/airfield.gd` new): forward-airfield
  cluster — canvas hangar tents, runway strip, windsock, sandbag
  revetments (visual) + live targets spawned into the world: 3 parked
  aircraft in the revetments and 1 light AA gun. Parked aircraft now
  **chain-kill**: one torching sets off neighbors within 130 px (60 dmg).
  Folded into S1 (t=38.5) and S4 (t=44) as "airfield" waves. Just appears —
  194x rule honored, zero ceremony.
- **HOME AIRFIELD** (same script, "home" flavor): Allied aerodrome
  dressing scrolls past after takeoff on non-naval sorties — tents,
  windsock, parked SPADs with roundels, milling ground crew. Visual only.
- **BARBED WIRE** (`trench_segment.gd`): entanglements upgraded — posts
  every other span + concertina coil loops between them, muted palette so
  strafing readability is untouched. Minimap draws thin wire lines flanking
  each trench line.
- **BACKGROUND**: new "road" ground feature (dirt supply roads) in the
  farmland/trenches/nomansland pools — the trucks' road.
- **MINIMAP** (`minimap.gd`): ground/naval targets now draw as red
  squares (aircraft stay direction triangles — instant read); truck blips
  included; airfield icons from the "airfields" group (home = green ring,
  enemy = red square + amber dot; the old static home marker is retired);
  "trucks" wired into SEC_ETYPE objective markers.
- Sortie changes (`sortie_data.gd`): S1 + S4 each gain trucks(2) waves,
  one airfield wave, and the trucks secondary (now 3 secondaries on those
  sorties — HUD/debrief handle N objectives generically). Squadron goals
  untouched (trucks/airfields aren't squadron types).

Tuning: truck 70 HP / 250 pts · stops at y 520–860 · unload after 1.2 s ·
infantry march 34 px/s up-screen for 3.5–5 s · parked chain 130 px / 60 dmg.

## Photorealism push — 2026-10-03 (v6)

Steven's directive: "Iterate photorealism in minds eye excursions to front
lines and behind." Push the illusion with procedural craft — **never claim
it as photographic**. Everything below is honest GDScript vector work;
the game, notes, and changelog describe it as craft, not photography.

**HONESTY RULE (binding):** no text anywhere in-game or in these notes
calls the visuals photographic, archival-photo-real, or AI-generated. The
technique is layered procedural drawing; the illusion is the goal, not
the claim.

### Terrain truth (`scripts/background.gd`, `scripts/trench_segment.gd`)

- **Churned mud, layered** — mud blotches gained 6 deterministic churned
  flecks (seeded from each patch's own RNG stream) so no fill is flat; no
  per-frame noise regen anywhere.
- **Water-filled shell craters** — crater pools read `Sun.shadow_offset`
  for a sun-side rim light, plus sky sheen, and dual glints (warm
  firelight + cool sky). They catch light, not look like gray bowls.
- **Scorched earth gradient** — new `"scorch"` feature kind seeded into the
  trenches / no-man's-land pools: dark gradient wash pooling near the
  front lines.
- **Trench works with depth** (`scripts/trench_segment.gd`) — trench lip
  gets a lip-light sliver, duckboard plank treads, sandbag-parapet drop
  shadows: three stacked cues read as depth from straight above.
- **Shattered stumps** — root flare + charred tips.
- **Wreckage fields** — scorch stain under each wreck + a bent-panel arc
  so wreckage reads as torn metal, not gray boxes.

### Atmosphere rig (`scripts/atmosphere.gd` new, `scripts/sun.gd`)

New CanvasLayer **layer 4** (`_atmo` in `main.gd`, wired in `_ready` and
driven per-sortie by `_atmo.setup(takeoff, theme)` inside `start_sortie`,
after `_weather.setup` so `Global.weather_kind` is fresh):

- **Film grain** — precomputed 256×256 noise tile, ±3 px jitter every 3rd
  frame, alpha 0.05: alive but invisible unless you hunt it.
- **Vignette** — precomputed radial falloff, alpha 0.22: keeps eyes on
  the action, costs nothing.
- **Haze bands** — 3 drifting smoke-haze bands (parallax against the
  scroll) for depth behind the front.
- **Light shafts** — diagonal screen-space beams driven by
  `sun.elevation_for_takeoff()`: strong slanted gold at dawn/dusk,
  near-invisible at noon. A lens/sky effect, never a camera move.
- **Scorched-front gradient** — dark top-of-frame wash over
  trenches/no-man's-land themes: the front reads burnt before you see it.
- **Storm grade** — color-grade overlay when weather is rain/storm.
- **Deepened time-of-day grading** (`scripts/sun.gd`) — dawn gold alpha
  0.10→0.16, dusk blood 0.12→0.20, richer hues; noon stays neutral.
- **Performance** — all textures built ONCE in `_ready`; per-frame cost
  is ~10 cheap textured draws. Nightly asserts this statically
  (`atmosphere-precompute`, `atmosphere-wired`).

### Camera iron rule (non-negotiable, enforced by nightly)

Steven's standing order: the camera stays **strictly top-down at all
times** — film plane parallel to the earth. Pan and zoom only; never
rotation, tilt, or perspective shifts. Capcom 1942 congruency: the takeoff
reel is the P-38 carrier launch shot — strictly top-down aerodrome,
no wandering angles. Audit findings this pass:

- `Camera2D` (main.tscn): position only — no rotation, no zoom. Gameplay
  shake is `camera.offset` (translation = pan). Compliant.
- Cinematic sequencer (`scripts/cinematic.gd`): virtual camera is only
  ever `_cam_c` (pan) and `_cam_z` (zoom) — all six shots verified. In-plane
  aircraft banking (`_plane(rot)`) is the aircraft, not the camera, and is
  exempt (matches 1942's in-plane banking).
- One tilted-view artifact removed: `_draw_shadow` squashed shadows 0.62×
  vertically (an oblique-view leftover) — now strict circles offset
  in-plane by the sun angle.
- Takeoff reel enriched, still strictly top-down: mowing stripes, runway
  tire tracks, tent shading, crew tents, fuel bowser, AA sandbag pit,
  blast-pen revetment arcs, oil stains; farmland gained hedgerow lines and
  a country road. The diagonal light-shaft graphic is a screen-space sky
  effect, not a camera move.
- Nightly check `camera-iron-rule` fails the build if any of this ever
  regresses.

### Readability guardrails (unchanged)

Targets still pop against terrain (enemy sprites + red minimap squares
untouched); difficulty untouched; 1942 spirit intact — new detail just
shows up, no popup ceremonies.

## Roads, chateaux, mustard gas + brainstorm barrage — 2026-10-03 (v7)

### 1. Roads: proper road networks
- Farmland background pool grew two network pieces: `road_paved` (metalled
  main road — edge lines, dashed center line) and `road_cross` (crossroads
  where a paved route crosses a dirt farm track). The existing dirt supply
  road (`road`, the trucks' road) stays. Seeded placement, seamless tiling,
  zero per-frame cost.

### 2. Chateaux: three states, rear-area set-pieces
- `scripts/background.gd` now places 3 chateaux per farmland sortie in the
  farmland pool (forced count, never in the random pool — grandeur is
  curated, not scattered): **STANDING** (stone block, mansard roof lines,
  window rhythm, side wings, courtyard shadow), **BURNING** (firelight glow,
  6 flickering procedural flames on the walls), **ANCIENT RUINS** (broken
  wall stubs, rubble field of 9 seeded stones). They just exist — no targets,
  no popups, no ceremony (194x rule).

### 3. Mustard gas: a real hazard (`scripts/gas_cloud.gd`)
- Three-phase life: **warn** (2.2s grey-green pre-gas wisp + rising hiss =
  telegraph), **bloom** (1.5s expansion), **active** (11s full cloud).
- Clouds **drift with `Global.wind`** and linger; 5–7 seeded billow puffs +
  3 drifting tendrils + 2 ground-hug patches, all procedural.
- **Damage: 6.0 HP/s** inside the radius (~130px). No invulnerability frames —
  the fog just keeps burning. At 100 hull that's ~16s of exposure to kill;
  meaningful, not mean.
- Sources: `gasstrike` waves on S1 (t=20) and S4 (t=28) — three blooming
  banks in a loose diagonal, and the directive's "burst gas projectors"
  fold into the same strike visually. Minimap shows gas banks as sickly
  yellow-green hazard rings.

### 4. Gas mask power-up: the counter
- New pickup kind `gasmask` in the carrier drop pool (13-entry pool —
  drop chance identical to spread/rapid/wingman, 1/13 per roll; the pool
  only rolls when a drop happens, so the overall pickup economy is
  unchanged).
- Procedurally drawn 64×64 mask sprite (olive facepiece, dark lenses,
  filter canister) generated at runtime in `pickup.gd` — no missing-asset
  risk (verified headless: texture instantiates clean).
- Grants **25s gas immunity** (`player.gasmask_t`), HUD shows `MASK %ds` in
  the power-up line + a green ring on the player blip in the minimap.
  While masked, gas clouds are harmless. "GAS MASK!" pickup popup.

### 5. Brainstorm barrage — 12 ideas, 6 shipped
The full dozen:
1. ~~Kill-streak callouts~~ ✅ SHIPPED — air-kill chains inside a 4s window:
   DOUBLE KILL +50 / TRIPLE KILL +120 / RAMPAGE! +300 / UNSTOPPABLE! +600.
2. ~~Graze rewards~~ ✅ SHIPPED — enemy tracers threading the 20–30px
   annulus around the airframe pay +10 ("GRAZE +10"), 0.4s anti-spam
   throttle. Pilots who fly close get paid.
3. ~~Boss taunts~~ ✅ SHIPPED — each ace runs his mouth every 11–16s
   mid-duel ("You fly like a farmer!", "Is that a SPAD or a kite?" — 8
   period-flavored lines). Personality, not ceremony.
4. ~~Hedge-hopper daredevil bonus~~ ✅ SHIPPED — kills scored below
   y=1000 (down in the weeds) pay +25% ("HEDGE-HOPPER +%d"). Flying low
   is 1942; now it pays.
5. ~~Sun glare~~ ✅ SHIPPED — dawn/dusk: climbing toward the light adds
   a mild warm screen wash (max 9% alpha, smooth-lerped). Atmospheric,
   never blinding.
6. ~~"Silence the AA" secondary~~ ✅ SHIPPED — flak batteries are now a
   proper secondary objective (S1×1, S4×2, S5×2, +500 bonus), with minimap
   mapping (`flak`→`aagun`) and kill-path wiring in `main.gd`.
7. ❌ Wingman "cover me" call — cut: needs a command UI; "no buttons"
   design bar wins.
8. ❌ Dynamic trench advance (front line pushes with the campaign) —
   cut: ground-war rewrite, v8 territory.
9. ❌ Boss wingman ambush phase (the ace calls in a wingman at 50% HP) —
   cut: difficulty bar stays mild; the rage timer already does this job.
10. ❌ Power-up magnet pickup — cut: 1942 never had one; economy is
    balanced as-is.
11. ❌ Landing-gear repair pads at the home aerodrome — cut: touch-and-go
    landings are a whole flight model; the fuel/repair pickups cover it.
12. ❌ Cinematic kill-cam on ace takedowns — cut: iron rule says no
    camera cuts; the duel deserves its dignity.

### Tuning numbers (v7)
- Gas: 6.0 HP/s DoT, radius 130px (clouds spawn at 46px, bloom to full),
  active 11s, drift = wind × 0.55.
- Gas mask: 25s immunity, drop rate 1/13 of carrier drop rolls.
- Streaks: 4s window; strafe unchanged; air kills 2/3/5/8 → +50/+120/
  +300/+600. Hedge-hop: +25% of kill value below y=1000. Graze: +10,
  0.4s throttle.

### Readability guardrails (unchanged)
- Gas clouds read instantly (yellow-green, unmistakable); the warn phase
  always precedes damage. Camera iron rule untouched — no rotation, no
  tilt, pan/zoom only (nightly `camera-iron-rule` check still green).
- Chateaux and roads are countryside dressing: they never spawn on the
  flight path in a way that hides targets.

## Sound, haptics, touch, real loop animation — 2026-10-03 (v8)

### 1. Original synthesized SFX (`tools/make_sfx.py`, `scripts/sfx.gd`)
- 10 original WAVs synthesized with numpy (same wave-craft approach as
  `make_music.py`) into `assets/sfx/` — no external audio, ever:
  `explosion_small` (0.45s noise burst + sub thump), `explosion_large`
  (1.05s deeper boom + crackle), `boss_defeat` (1.8s four staggered
  blasts), `damage` (0.28s metallic thud), `pickup` (0.35s two-sine
  chime), `ui_tick` (0.06s click), `ui_confirm` (0.22s major-third blip),
  `loop` (0.75s filtered-noise whoosh, exactly LOOP_DUR), `flak`
  (0.24s sharp aerial pop), `gas` (1.2s band-passed warning hiss).
  The warning beep stays covered by `Music.fuel_warning()`.
- `scripts/sfx.gd` (new autoload, after Music in project.godot): 10-player
  round-robin pool (polyphony cap, no stacking mud), `play(name, vol_db,
  pitch, vary)` with per-call pitch wobble, `set_muted(m)` with a 0.25s
  fade, process_mode ALWAYS so UI clicks sound while paused.
- Every silence replaced: `FX.explosion` (small/large by flag), player
  damage, `try_loop`, boss `_die_spectacular`, pickup collect, flak
  `_detonate` (pop layered over the small boom — intentional), gas
  warn→bloom, every menu button (tick) + FLY/RESUME/NEXT (confirm).
- Pause menu gained a **SOUND: ON/OFF** toggle (`menus.gd`) that mutes SFX
  and music together (`Music.set_muted` tweens all tracks; warn beep
  included). The old web-only music toggle is now in-game.

### 2. Mobile haptics (`SFX.rumble` / `SFX.rumble_at`)
- `Input.vibrate_handheld()` only — hard-gated to
  `mobile`/`web_android`/`web_ios`; desktop never buzzes. 0.18s cooldown
  so dense fights don't become a jackhammer.
- The map: player damage = 70ms sharp; large explosions = proximity
  rumble (900px falloff, min 30ms); boss defeat = 280ms triumphant;
  UI selections = 15ms light tick; loop = 50ms; flak pops = 90ms
  proximity. Tasteful, not a massage chair.

### 3. Touch controls audit + complete (`main.gd`, `global.gd`)
- **Double-tap-and-hold → pause menu**: was MISSING, now implemented —
  second tap held ≥0.55s pauses (checked in `_process`, tap must stay
  inside 28px slop or it becomes a steering drag).
- **Double-tap → loop-de-loop**: existed for mouse; now a proper
  tap-vs-drag gesture path for touch (quick release of the second tap
  fires `try_loop`). Desktop keeps double-click→loop, ESC pause, Q loop.
- **NEW: relative-drag steering** — there was no touch flight at all.
  Drag on a touch device feeds `Global.touch_wish` (140px = full stick),
  blended with WASD in `player.gd`. Strictly mobile-gated so desktop
  clicks never steer.
- Emulation cross-talk fixed: with `emulate_touch_from_mouse` /
  `emulate_mouse_from_touch` both on, taps arrive twice — the touch
  path runs only on touch devices, the mouse path only on desktop.
- No on-screen gameplay buttons (standing rule). Title screen shows
  touch hints on mobile only (DRAG fly / DOUBLE-TAP loop /
  DOUBLE-TAP+HOLD pause).

### 4. Real loop-de-loop animation (12 Blender frames, `assets/sprites/loop/`)
- `blender/render_loop.py` renders the same SPAD XIII build as the player
  sprite through a true Immelmann: level → nose-up foreshorten → nose-on
  edge sliver → inverted belly-up (gear to camera) → nose-down
  foreshorten → level recovery. 12 frames, 30° pitch steps, camera
  framing locked at the level pose, strictly top-down (iron rule).
- Two gotchas found and fixed, both documented in the script header:
  (a) `aircraft()`'s joined mesh carries a baked `(pi/2,0,0)` rotation —
  that IS the level top-down pose, zeroing it aims the plane at the
  camera; (b) the roundels are separate objects and must be joined into
  the airframe or they hover while the plane pitches.
- Frame 0 is pixel-identical (0.12%) to the shipped `player-spad.png`,
  so the swap is seamless; `player.gd` swaps `sprite.texture` through
  the 12 frames over LOOP_DUR (0.75s), killing the old flat-spin cheat.
  Invulnerability window unchanged (LOOP_DUR + STAB_DUR), matched to the
  maneuver. The autotest's `try_loop()` call exercises the frame path
  headless.

### Tuning numbers (v8)
- SFX pool: 10 players, round-robin; pitch wobble ±8% default.
- Haptics: cooldown 0.18s; damage 70ms/1.0; big-explosion proximity
  900px→30ms min; boss 280ms/1.0; UI 15ms/0.3; loop 50ms/0.5.
- Touch: TAP_SLOP 28px, DOUBLE_TAP_T 0.35s, HOLD_PAUSE_T 0.55s,
  DRAG_FULL 140px.
- Loop: 12 frames / 0.75s = 16fps flip-book; frame 0 == player sprite.

### Readability guardrails (unchanged)
- Camera iron rule untouched — the loop is a sprite swap, zero camera
  movement. Nightly `camera-iron-rule` check still green.

## Ground war gets teeth — 2026-10-03 (v9)

### 1. Infantry pot-shots at the player (`trench_target.gd`)
- Live German MG nests and infantry squads now take opportunistic shots at
  the player's aircraft "just because they can": MG nests fire 3-round
  bursts (6 dmg, 420 px/s tracers, every 3.2–4.5 s, range 480 px); infantry
  squads loose single rifle rounds (3 dmg, 380 px/s, every 5–7.5 s, range
  400 px). Every shot runs the same 0.35 s telegraph blink as air enemies,
  plus a muzzle flash and a warning ring — readable, dodgeable, fair.
- New SFX: `mg_chatter` (5-round burst), `rifle_pop` (single crack).

### 2. Ground forces as two-way combatants
- MG nests, infantry, tanks, arty, sub pens, and AA all shoot back now;
  the player already strafes them. Tuning is MILD by design — spectacle
  plus light pressure, never a bullet-hell ("it ain't nothing to a boss").
- Ground fire punishes lazy loitering (short ranges, slow tracers), not flying.

### 3. Tank war (`tank_duel.gd` rewritten)
- Battles are now 1v1 (50%), lopsided 2v1 (30%), or full 2v2 (20%).
- Three factions on the field: German field-grey (dark-red square), French
  horizon-blue (tricolor roundel), British khaki (blue-grey diamond).
- Live tanks take AA pot-shots at the player: slow 400 px/s shells, 10 dmg,
  7–12 s cooldown, only when the player is genuinely overhead and in range.
- Brewing-up kills thump through the new `tank_boom` SFX plus
  `SFX.rumble_at` proximity haptics; wrecks persist as before.

### 4. Infantry-vs-infantry iteration (`ground_war.gd`)
- Volleys grew from 3 to 5 exchanges per side, dirt kicks up where rounds
  land on the lines, and single rifle "pops" mix in with the MG bursts.
- The BIG PUSH now lands a deep rolling `tank_boom` and a deck rumble.

### 5. Memoir lore (`sortie_data.gd`, `main.gd`)
- Every sortie carries a one-line `lore` flavor line under the brief,
  loosely echoing the era and spirit of Rickenbacker's "Fighting the
  Flying Circus." LOOSE and HONEST — arcade first, history as seasoning;
  no specific historical claims anywhere in-game. Tone: respect the
  fallen, celebrate the win.

### Tuning numbers (v9)
- MG nest: 6 dmg × 3, 420 px/s, 3.2–4.5 s cd, 480 px range.
- Infantry: 3 dmg, 380 px/s, 5–7.5 s cd, 400 px range.
- Tank AA: 10 dmg, 400 px/s, 7–12 s cd per tank, 520 px range, overhead only.
- Telegraph: 0.35 s blink before every ground shot.

### Readability guardrails (unchanged)
- Every new projectile is a slow readable tracer with a telegraph; camera
  iron rule untouched (nightly `camera-iron-rule` still green).

## The 1942 pass — 2026-10-03 (v10)

### 1. Pass state machine (`enemy.gd`)
- Flying aircraft now make PASSES, not residences: ENTER (top of frame) →
  ATTACK (the run, ~7/8 down, guns live) → TURN (180° bank) → EXIT (off the
  top, despawned, never seen again until a new wave).
- The run goes to TURN_Y = 1120 (~7/8 of the 1280px visible scene). Guns go
  quiet the moment the turn commits — the turn is the exit, not the fight.
- No lingering, no hovering: the scout's dive always carries downward
  (`vel.y` floored at 45% of speed) so the pass can never stall.
- Ground/naval targets (AA, railway gun, trenches, U-boats, pens, depots,
  trains, arty, parked) are exempt by nature — they ride the world scroll
  as before. Bosses are exempt (arenas, not passes). A `pass_exempt` flag
  covers boss escorts and anything else that must linger.

### 2. Wind-influenced 180° bank
- Bank direction reads physically: with |wind.x| > 12 px/s the aircraft
  banks INTO the wind (upwind side); in calm air it banks toward the
  nearest screen edge so the arc stays on-screen.
- The turn drags the sortie wind vector (×0.35) through the arc and the
  climb-out, so the wind visibly shapes the maneuver.
- Turn duration per type: 1.15 s fighters, 1.7 s bomber, 2.4 s balloon,
  2.6 s zeppelin — heavies carve wide lazy arcs.
- Readability: hard banked sprite frame through the turn + a contrail puff
  (`FX.bank_puff`, new `scripts/fx/bank_puff.gd`) + a new airy `bank_whoosh`
  SFX (synthesized in `tools/make_sfx.py`, registered in `scripts/sfx.gd`).

### 3. Per-type adaptation
- triplane/fighter (weave): personality unchanged on the way down.
- scout (dive): still dives at the player — then breaks off into the turn
  at 7/8 instead of kamikaze-chasing. Ragged squadrons break earlier.
- bomber (heavy): slow straight run, wide 1.7 s turn.
- balloon/zeppelin (drift): slow majestic drift down, lazy 2.4–2.6 s turn.
- Verified headless: scout/fighter/bomber full ENTER→ATTACK→TURN→EXIT→
  despawn cycles with zero script errors; wind (50,0) produced turn_dir -1
  (into the wind) as designed.

### Tuning numbers (v10)
- TURN_Y 1120 (7/8 of VIEW_H); turn durations 1.15 / 1.7 / 2.4 / 2.6 s.
- Wind bank threshold 12 px/s; wind drag ×0.35 through turn + exit.
- Exit despawn at y < -140; bottom despawn unchanged for scrolled targets.

### Readability guardrails (unchanged)
- The 180 reads in under a second: banked frame + puff + whoosh. Camera
  iron rule untouched — the turn is sprite + velocity, zero camera motion.

## 1942 research — what we homage, what we borrow next, what we never copy

Researched Capcom's 1942 (arcade, Nov 1984, designed by Yoshiki Okamoto —
sources: Wikipedia's 1942 article, the GameFAQs PC-88 review, Eurogamer's
retrospective, the Capcom Database wiki). Mechanics distilled:

- **Pass structure**: enemies arrive in formations, make their runs, and fly
  OFF the screen — "the cowardly enemy pilots give in surprisingly quickly,
  flying off the sides of the screen and back to base" (Eurogamer). You can
  finish levels without firing a shot.
- **Loop-the-loop**: a limited-use special roll button — brief invulnerability,
  the panic button. Refilled by power-up items.
- **POW carriers**: red fighter squadrons — wipe the WHOLE squadron and the
  last plane drops a color-coded POW icon: double firepower, Tip Tow wingmen
  (two side planes that fire with you and can take a hit), screen-clear,
  points, extra loops, rare extra plane.
- **Percentage high score**: a separate score tracking kill ratio — enemies
  shot down vs. encountered.
- **Yashichi point item**: special fighters drop a valuable point pickup.
- **Structure**: 32 stages counting down 32→1, continuous scroll with no
  breaks (like Xevious), each ending with a carrier landing + debriefing and
  briefing for the next. Stage-end "Mother Bomber" must be shot down.
- **One-hit deaths**, flat power curve ("your plane will never get much
  stronger than it was the moment you start out" — GameFAQs), Pacific theater
  P-38 "Super Ace", designed for Western accessibility.

### What 1918 already homages well
- v10's pass model IS the 1942 pass DNA: enter → attack run → 180° bank →
  exit off the top, never lingering.
- The loop-de-loop with i-frames (v8 gave it a real Blender Immelmann).
- Squadron break-points ~55% (v4) ≈ the percentage high score.
- Takeoff reel → waves → boss → landing reel → typed debrief ≈ the carrier
  landing + debriefing/briefing rhythm.
- Carrier drops/pickups ≈ POW items; the screen bomb ≈ the panic button.

### What to borrow next (as our own original implementations)
- **Debrief kill-rating %**: 1942's percentage score as a letter/percentage
  grade — we already track squad_kills/strength; surface "KILL RATING 87%".
- **Wiped-squadron bonus drop**: downing an entire squadron earns a bonus
  POW-style drop — fits the v4 squadron system like a glove.
- Keep the "NAME INBOUND" boss presentation — our answer to the Mother Bomber.

### What we deliberately NEVER copy (1918's identity)
- The 32-stage marathon — 1918 is six tight sorties plus one mythic duel.
- One-hit deaths — hull/HP + repair keeps it beatable by an average human.
- Pacific/P-38 — our war is the Western Front, 1918, SPAD XIII.
- Power creep — flat, recoverable power curve forever.

## The Ghost of the Red Baron — 2026-10-03 (v11)

### 1. Mythic boss: spectral Fokker Dr.I duel (scripts/boss.gd)
- New boss index 6, "THE RED BARON" — `spectral = true` in `configure()`.
- New sprites `assets/sprites/boss-7-baron-{level,bank-left,bank-right}.png`:
  crimson triplane with black-banded wings, rendered from the new
  `boss-7-baron` Blender model (508 tris) via `blender/render_sprites.py`
  pipeline. BONUS FIX: `boss-6-ghost-*` sprites were never rendered — S6's
  "THE GHOST" boss was loading null textures. Rendered in the same run.
- Spectral presentation: translucency breathes (alpha 0.74–0.92, applied
  AFTER the charge telegraph so the red flash keeps its color); afterimage
  echoes smear across hard maneuvers (0.07s throttle, 0.5s fade).
- Fair duel, same 3-phase framework: P1 aimed bursts, P2 aimed bursts with
  honest spread, P3 spiral at 200px/s (vs 240) so an average human threads
  it. Telegraphed charges unchanged.
- `BARON_TAUNTS`: a duelist's respect, not a villain's rant ("One last
  dance, Herr Pilot!", "The thunder keeps my score!"). Ghost wail on
  entrance ("I never left."), phase changes, and death ("THE GHOST IS LAID
  TO REST"). NO gods or deities anywhere — the thunderheads are atmosphere.
- Boss-bar fix (adjacent): `show_boss`/`update_boss` passed const MAX_HP
  while hp scaled per boss — bars for bosses 1-6 read wrong. Now a real
  `max_hp` member set in `configure()`.
- HP: 900 × 2.5 = 2250 (toughest duel, fair guns). Haptics: the standard
  280ms triumphant rumble + boss_defeat fanfare on the kill.

### 2. The Thunderhead Duel — mythic sortie 7 (scripts/sortie_data.gd)
- `SORTIES[6]`: "Sortie 7 — The Thunderhead Duel", theme "storm", boss 6,
  short storm approach (scouts/fighters/triplanes/bombers), duel at t=58.
- Lore framing is a ghost story, never a history claim.
- Placement: SECRET. After beating S6 the debrief offers "FACE THE GHOST";
  the unlock persists in `user://1918.cfg`, and the title screen gains a
  "THUNDERHEAD DUEL" button. Never reached via NEXT SORTIE
  (`CAMPAIGN_LAST = 5`, `MYTHIC_SORTIE = 6` in main.gd); mythic win →
  "LEGEND COMPLETE" → title. Debrief credits the kill (+2000) as usual.

### 3. Storm arena (scripts/weather.gd, scripts/background.gd)
- `KIND_BY_SORTIE` gains index 6 = "storm": full lightning rig, rain sheet,
  storm cells, seeded wind — the duel's arena.
- Lightning strikes now play the new `thunder` SFX (was stubbed: "no audio
  yet"). New `ghost_wail` SFX: 2.2s spectral descending cry with vibrato.
- New "storm" background theme: bruised thunderhead dark, no ground pieces —
  the arena is the sky itself. Ground war falls through to its default
  front-line battle below (fitting).

### 4. Autotest
- `--autoboss` now accepts `--autoboss=N` (was boss 0 only). Headless
  verified: boss 6 spawns, phases at the right thresholds, dies, debrief
  wins — zero script errors. Mythic sortie smoke (storm weather) clean.

### Tuning numbers (v11)
- Baron HP 2250; spiral 200px/s; wail 2.2s; thunder 2.6s at -8dB with
  ±10% pitch wobble; afterimage 0.07s cadence / 0.5s fade; translucency
  0.74 + 0.18·sin(2.6·age).

### Readability guardrails (unchanged)
- Camera iron rule untouched. The ghost reads in under a second: crimson
  triplane, translucency pulse, wail on entrance.

## Test ads + remove-ads IAP (test mode) — 2026-10-04 (v12)

### 1. Architecture: provider-agnostic facade, honest test mode
- `scripts/ads_config.gd` (preloaded consts, NOT class_name — global classes
  don't resolve in `--script` headless mode): `TEST_MODE = true` ships ON,
  Google's six OFFICIAL test IDs (verified against developers.google.com
  AdMob test-ads docs for Android + iOS), product `1918_remove_ads` $2.99,
  and the honest caps (180s cooldown, 3/session, min 1 sortie completed).
- `scripts/ads.gd` (autoload "Ads"): `show_rewarded(context, on_reward)`,
  `show_interstitial_then(on_done)`, `rewarded_available()`,
  `is_remove_ads()` (delegates to IAPs), `note_session_start()`,
  `note_sortie_completed()`, stats persisted in `user://1918.cfg` ("ads").
  Remove-ads ownership suppresses EVERY ad path — no requests, no shows.
- `scripts/ads_impl_poing.gd`: concrete Poing Studios AdMob plugin mapping
  (`MobileAds.initialize()`, `InterstitialAdLoader`/`RewardedAdLoader` +
  load callbacks, `show()`), loaded ONLY when `res://addons/admob` exists,
  so it can never break a plugin-less build. Dismiss detection probes the
  plugin's listener convention with a loudly-logged degraded fallback.
- Backend order: real plugin → TEST MODE simulation (logged timers, zero
  network) → safe no-op. Desktop/headless without the plugin = test-mode
  simulation, so the whole flow is exercisable here.

### 2. Placements (honest UX, Steven's spec)
- REWARDED (opt-in only): death debrief shows "✚ FLY AGAIN — WATCH AD
  (TEST)" → `main._on_revive_reward` → `player.revive(0.6)`: back mid-sortie
  at 60% hull, 3s invuln, wingmen stay lost. Never forced, never mid-action.
  Hidden entirely when remove-ads is owned.
- INTERSTITIAL: only in `_on_menu_next` on the victory → next-sortie path —
  never mid-sortie, never on death/retry, never before 1 sortie completed,
  max 3 per session, 180s cooldown. `on_done` continues the flow even when
  no ad shows, so the game can never hang on an ad.
- No fake close buttons, no countdowns, no accidental-tap layouts — the SDK
  renders its own chrome when the real plugin is installed.

### 3. $2.99 remove-ads IAP
- `scripts/iaps.gd` (autoload "IAPs"): `has_remove_ads()`,
  `purchase_remove_ads(on_result)`, `restore_purchases(on_result)`,
  `simulate_cancel` (test path). TEST MODE simulates the store sheet with a
  1.2s delay and clear "NOT A REAL CHARGE" logging; state persists in
  `user://1918.cfg` ("purchases"/"remove_ads").
- Real-billing hooks `_billing_*` (Android GodotGooglePlayBilling singleton)
  and `_storekit_*` (iOS) are clearly-marked integration points — method
  names vary by plugin version and are intentionally NOT guessed.
- Pause menu: "REMOVE ADS — $2.99 (TEST)" button → "ADS REMOVED ✓" when
  owned. Refreshed every time the pause menu opens.

### 4. Validation
- New `tools/test_ads.gd` headless functional test: purchase → persistence →
  full ad suppression → cancel path → rewarded grant → min-sorties gate →
  eligible interstitial show/close. PASS.
- Nightly: `gdscript-ads-test-ids` (pins the six official IDs + TEST_MODE),
  `gdscript-ads-no-real-ids` (fails on any non-test ad ID while TEST_MODE),
  `gdscript-ads-state` (gating + wiring), `godot-ads-flow` (the functional
  test, requires its [TESTADS] PASS marker).

### 5. Steven's go-live moves (see ADS-SETUP.md at repo root)
AdMob account + app/ad-unit IDs → `TEST_MODE = false` + swap IDs in
`ads_config.gd` → install Poing AdMob plugin via AssetLib → App IDs into the
Android/iOS export configs → create `1918_remove_ads` in Play Console +
App Store Connect → implement the `_billing_*`/`_storekit_*` hooks.

### Adjacent fix
- `player.heal()` never updated the HUD — repair pickups left the integrity
  bar stale. Now calls `update_integrity` like every other HP change.

## Automated playtesting + continuous skepticism — 2026-10-04 (v13)

### 1. Bot pilot (`scripts/bot_pilot.gd`, `class_name BotPilot`)
- A mid-skill bot that plays through the REAL control path: steering via
  `Global.touch_wish` (the v8 touch scheme), `Input.action_press("fire")`
  held, `Input.action_press("bomb")` on panic, `player.try_loop()` when a
  closing tracer gets inside 110px. Thinks every 0.12s with steering noise —
  competent enough to finish sorties sometimes and die sometimes.
- Dodges toward open space, detours for pickups (fuel when thirsty),
  gives active gas clouds a wide berth, keeps ~260px off gun targets.
- Deaths alternate: odd deaths take the rewarded revive (exercising the v12
  test-ads path end to end), even deaths retry (exercising death → debrief).
- Added by main.gd only under `--botpilot` (with `--autostart`): no godmode,
  no free wingmen/power-ups — the bot earns everything like a player.
- Deterministic run length: `--botquit=N` quits on GAME time (the skeptic
  calls `get_tree().quit()`); `--quit-after` is only a backstop because it
  counts render frames and headless spins ~2x the physics rate.

### 2. Skeptic (`scripts/skeptic.gd`, thresholds in `scripts/skeptic_config.gd`)
- Instruments the run and flags anything that feels wrong — every detector
  logs EVIDENCE (timestamps, positions, entities), never vibes:
  - CRITICAL (fail the nightly): `unfair_death_early` (death <3s after
    spawn/revive), `iframes_broken` (two hits <0.9s apart — the 1.0s
    immunity leaked), `softlock` (no score/kill/objective progress 25s
    while alive), `bot_zero_progress` (30s, zero kills AND zero damage).
  - HIGH: `pass_stall` / `pass_overlife` / `pass_no_turn` (v10 spec, with
    PER-ENEMY expected timings from speed/behavior — a balloon's 32s run
    is majestic, not a stall), `death_no_visible_cause`,
    `wave_stall` (next wave 40s overdue, empty sky).
  - MED: `spawn_camp`, `sfx_spam` (>6 of one sound/sec), `rumble_storm`,
    hitches, `econ_barren` / `econ_pinata` (kills/min outliers).
- Cause attribution on death: nearest tracer/flak/gas/enemy; fuel deaths
  and gas DoT are logged as designed paths, not anomalies.
- Writes `QA/reports/skepticism-<date>-s<N>.jsonl` INCREMENTALLY (flushed
  per line) — a hard `--quit-after` kill can never lose evidence.
- Seeded-fault proof: `--seedfault=stall` wedges one mid-run aircraft's
  pass machine (pinned + bullet-sponged so the fault stays observable);
  the nightly asserts `pass_stall` fired. Proven working.

### 3. Hooks (minimal, additive)
- `player.gd`: `signal damaged(amount)` emitted in `take_damage`.
- `sfx.gd`: `play_log` / `rumble_log` ring buffers (rumble logged even on
  non-mobile so headless verifies the call sites fire).
- `enemy.gd`: `debug_freeze_pass` (seeded fault only).
- `flak_shell.gd`: joins `flakshells` group (death attribution).
- `main.gd`: `total_kills` counter; `--botpilot` branch in `_debug_autostart`.

### 4. Nightly wiring (`QA/run-nightly.sh`)
- `godot-bot-sortie-1..6` (50s each), `godot-bot-mythic` (110s, reaches
  the storm), `godot-bot-seedfault` (25s, proves the detector).
- `qa-seedfault-proof`: PASS only if `pass_stall` was flagged.
- `qa-skepticism-report`: `tools/merge_skeptic.py` builds
  `QA/reports/skepticism-<date>.md` — stat table, anomaly table with
  severity, and a 1942-grounded ideas section (suggestions only, never
  auto-applied). Exits 1 — failing the nightly — on any CRITICAL.
- `gdscript-bot-skeptic-sane`: static wiring check for the whole system.

### 5. First findings (2026-10-04 shakedown)
- S1 (50s): 17 kills, 1 death → rewarded revive granted cleanly, zero
  anomalies. The sky felt right.
- S4 (50s): 8 kills, 1 death; MED `sfx_spam` — 8 explosion_small + 8 flak
  pops in one second during the t=28 gas strike. Genuinely shouty; a human
  should listen to that moment.
- Seeded fault: `pass_stall` + `pass_overlife` both fired as designed.

### Tuning numbers (v13)
- Bot: think 0.12s, steer noise ±0.15, dodge 240px, loop threat 110px +
  0.2s react, bomb panic 10 bullets/200px, pickup 420px, fuel-seek 500px/35.
- Skeptic: unfair window 3s, no-source 320px, softlock 25s, wave stall 40s,
  zero-progress 30s, stall margin 1.6x+3s, life margin 1.5x, spawn camp
  120px, sfx spam 6/s, rumble storm 4/s, hitch 100ms x8, barren 2/min,
  pinata 25/min.

## Photorealism lighting: true north, HDR-style, 94th aerodrome — 2026-10-04 (v14)

### 1. TRUE NORTH + sun position (`scripts/sun.gd` rewritten)
- **North decision: screen-up IS North.** The pilot launches from the home
  aerodrome in the south and flies the route rail north into German-held
  territory — the Western Front ran roughly east-west with the Allied rear
  to the south-west, and the v3-era model already assumed midday shadows
  point north. Documented in the script header.
- **Solar model:** latitude 48.7 N (Toul/Gengault), reference date 15 May
  1918 (declination +18.8 deg), local mean time treated as solar time
  (approximation, stated). Standard elevation/azimuth math; azimuth from
  North clockwise, mapped to screen (North = -Y, East = +X).
- **Night:** sun below -0.5 deg switches to a REPRESENTATIVE full moon
  (azimuth 140 deg, elevation 35 deg) — not an ephemeris, just honest
  moonlight. Twilight band: full day above +3 deg, full night below -8 deg
  (smoothstepped `night_factor`).
- **One light vector:** `Sun.set_takeoff(t)` (called once per sortie in
  `main.gd`) fills `Sun.current` — is_night, night_factor, light_dir,
  elevation/azimuth, shadow_len, ambient (ground multiplier), grade
  (fullscreen wash), light_color. Shadows, crater rim-light, water glints,
  hangar rims, atmosphere grades all read it. Old wrappers
  (`shadow_for_takeoff`, `elevation_for_takeoff`, `mood_tint`) kept working,
  now derived from the same model; `mood_tint` extends to deep-blue night.

### 2. HDR-STYLE lighting (honest scope)
- Renderer is `gl_compatibility`: NO real bloom/HDR output exists in this
  pipeline. "HDR-style" is simulated and documented as such: exposure
  multiplies (ambient), fullscreen grading, additive glow sprites (moon
  halo, searchlight pools, flare pots), directional sheen (water glints
  and hangar rims oriented to the light vector), per-time-of-day color
  grading. Nothing claims real HDR.

### 3. Hat-in-the-Ring aerodrome (`scripts/airfield.gd`, home flavor rebuilt)
Research (web, 2026-10-04, plus the repo's own
`godot/research/v14-hat-in-the-ring-aerodrome.md`): the 94th Aero Squadron
— formed Kelly Field Texas Aug 1917; Villeneuve-les-Vertus (Feb 1918),
Epiez (1 Apr, rained in on arrival), Gengault/Croix-de-Metz near Toul
(7 Apr–30 Jun, first combat, first US victories 14 Apr 1918 by Campbell &
Winslow in Nieuport 28s) — but the in-game home field follows the brief's
recommendation: **Rembercourt Aerodrome (1 Sep–20 Nov 1918)**, the
squadron's longest home, the full 1st Pursuit Group's field, and the
**SPAD XIII era** (the game's aircraft). The "Hat in the Ring" — Uncle
Sam's top hat tossed into a ring — became the Air Service's symbol.
Solar latitude accordingly 48.9 N. Night pursuit from this field is
period-real (185th Aero Squadron, Oct-Nov 1918).
Sources: en.wikipedia.org/wiki/Villeneuve-les-Vertus_Aerodrome,
en.wikipedia.org/wiki/94th_Aero_Squadron,
forgottenairfields.com (Toul-Croix de Metz), airandspaceforces.com
("Over There", Apr 1988 "The First Victory").
- Rebuilt home field: **Bessonneau canvas hangars** (arched profile,
  rib arcs, sun-side rim light from the light vector), **mown grass strip**
  with whitewashed edge markers (1918 fields were grass, not pavement),
  **Hat-in-the-Ring insignia** painted on the parked SPADs (ring + top-hat
  glyph), April **mud** patches, **puddles** with sky/moon glints when the
  weather is rain/storm, a fuel **tender** truck, 8 milling ground crew.
- **Night:** flare-pot path lighting — braziers lining the strip
  (period-plausible night-landing aids), flickering, compensating back up
  against the night modulate since they are light sources.
- Framed as "inspired by" throughout — never a claimed reproduction of
  any specific photograph.

### 4. Night vs noon vibes + launch-time schedule
- **Night** (`scripts/atmosphere.gd`): baked starfield, moon glow + disc,
  two sweeping searchlight pools (visual only — from top-down a vertical
  beam reads as a drifting glow; the real ones hunted Zeppelins), deep-blue
  grade; `background.gd` applies the sun rig's ambient multiplier to the
  whole landscape (aircraft live outside it, so they stay readable).
  Muzzle flashes scale up 1.6x at night (`fx/muzzle.gd`) — gunfire pops
  in the dark. Gameplay readability always wins: enemies, tracers and
  pickups are untouched by the darkening.
- **Noon:** volumetric top-light lift (blazing sun, elevation > 45 deg,
  clear skies) — crisp, luminous, full color.
- **Schedule** (sortie_data.gd): S1 05:40 dawn · S2 **03:20 night** (U-boats
  surfaced under moonlight — was 06:15) · S3 **12:00 high noon** (was 10:30)
  · S4 14:00 afternoon · S5 09:45 morning · S6 17:30 dusk · S7 18:45
  storm-dusk (storm overrides light anyway).

### 5. What was NOT re-rendered and why
- No Blender re-renders this pass: the lighting is all in the rig
  (ambient/grade/glow/sheen), which relights every existing sprite for
  free. The aerodrome is procedural `_draw` work (it was never a Blender
  asset). Re-rendering the world per time-of-day would multiply asset
  weight for zero gameplay gain.

### Tuning numbers (v14)
- Night ambient ground multiplier: (0.22, 0.27, 0.42); night grade wash:
  (0.05, 0.08, 0.24) at 0.30 alpha; moon shadow len 9px, blue-grey.
- Muzzle night boost x1.6; searchlight alpha 0.10; noon lift max 0.10.

### Adjacent fix: skeptic softlock false positive
- The nightly's first v14 run went 45/46: `qa-skepticism-report` failed on
  two CRITICAL `softlock` anomalies in S6 — "no progress for 25s". The game
  was NOT stuck: S6's waves spawn on schedule (trains t=2, arty t=16,
  first fighters t=30) and the bot was alive and flying; it just hadn't
  scored in the detector's fixed 25s window. Same family as v13's
  "Baron-duel softlock false positive".
- Fix in `scripts/skeptic.gd::_check_softlock`: stand the detector down
  while the wave schedule still has waves on the way within
  SOFTLOCK_IDLE_S + 15s — scheduled content arriving IS run progress.
  Wave-stall itself stays covered by `_check_wave_stall`, so no real spawn
  failure can hide behind this. The detector was wrong, not the game.

## Heed the Imperial Germans — Luftstreitkräfte depth pass — 2026-10-04 (v15)

### NAMING RULE (ironclad)
- WWI Imperial Germany = **Deutsches Heer** (army) / **Luftstreitkräfte**
  (air service). **"Wehrmacht" is the WWII name and must NEVER appear**
  in-game or in docs. Enforced by the nightly `gdscript-no-wehrmacht`
  check (case-insensitive sweep of scripts/, tools/, research/).

### 1. German aircraft roster (research + Blender)
Research (web, 2026-10-04): **Fokker Dr.I** — span 7.19m / length 5.77m,
stubby triplane, 320 built, spring-1918 service, twin Spandau
(migflug.com, aeropedia.com.au, avstop.com). **Fokker D.VII** — span
~8.9m / length ~6.95m, chunky, ~3,300 built from Feb 1918, lozenge camo;
the Armistice specifically required Germany to surrender all D.VIIs
(en.wikipedia.org/wiki/Fokker_D.VII, wingnutwings.com). **Albatros D.V**
— span 9.05m / length 7.33m, oval varnished-plywood shell fuselage,
900 D.V + 1662 D.Va built Apr 1917–early 1918
(en.wikipedia.org/wiki/Albatros_D.V, wingnutwings.com).
- New models in `blender/build_models.py` via the standard `aircraft()`
  builder + a new `kreuz=True` option: the **straight-armed Balkenkreuz**
  (black cross, white border — the correct spring-1918 form) on the top
  wing instead of roundels. A historical military marking used as a game
  asset; tasteful, not glorifying. Gotcha fixed in-build: the black bars
  sat only 0.005 above the white plate and z-fought invisibly — now
  raised a full 0.03.
- `enemy-fokker-dr1` (stubby triplane, feldgrau): tight aggressive weaver
  (`wfreq` 3.0, `wamp` 1.0), hp 34, speed 195. `enemy-fokker-d7` (chunky,
  lozenge tones): fast diver, hp 48, speed 245. `enemy-albatros`
  (plywood fuselage): balanced weaver, hp 40, speed 210. All rendered
  bank-left/level/bank-right through the standard pipeline (9 sprites,
  ~490 tris each) and verified visually. They relight through the v14
  sun rig like every other sprite.
- Wired into the v10 pass model (per-type weave character via new
  `wfreq`/`wamp` type keys), `SQUADRON_TYPES`, and waves across S1–S7
  (escalating German identity; Dr.I in spring-1918 sorties).

### 2. Kette doctrine (German AI personality)
- Wave dicts accept `"kette": 3` → a disciplined Vic: leader + two
  wingmen stepped back/out, sharing one weave phase and one fire rhythm.
  They fly as one body and volley together — readable, fair (same total
  firepower, just synchronized), and **never go ragged** when the
  squadron breaks; they tighten up instead. Kette waves in S1/S2/S4/S5/S6.

### 3. German ground forces
- **A7V** (`tank_duel.gd`): Germany's own tank — 20 built, 30-tonne
  armored box (warhistoryonline.com, en.wikipedia.org/wiki/A7V). Rare:
  max one per duel, ~18% of German slots. hp 150, slow 57mm (30–48 dmg,
  big boom + trauma), tall casemate hull, no turret, Balkenkreuz marking,
  bigger burning wreck.
- Infantry: the German palette entries are now documented as **feldgrau**
  (`trench_segment.gd`); MG nests gained the **MG08 gun shield**
  (`trench_target.gd`) — the German nest signature.
- The v9 two-way combat is unchanged; the Germans just look German now.

### 4. German airfield rebuild (`airfield.gd`)
- Deliberately NOT the Allied look: **dark timber hangars** (long, low,
  gabled — stained wood, not French canvas), grey-green tents, feldgrau
  ground crew, parked German machines with cross-marked wings
  (`_draw_parked_german`). The live escorts are now `parked_ger`
  (Fokker D.VII sprites) instead of generic scouts. "Inspired by" period
  Jasta field photos — never a claimed reproduction.

### Tuning numbers (v15)
- Dr.I: hp 34 / spd 195 / wfreq 3.0 / wamp 1.0 / score 120. D.VII: hp 48 /
  spd 245 / dive / score 170. Albatros: hp 40 / spd 210 / score 140.
- Kette: Vic offsets (±58, +40), shared phase + fire_cd.
- A7V: hp 150, fire cd 3.5–5.5s, 57mm 30–48 dmg, ~18% spawn, max 1/duel.

## Visual identity reinforcement — 2026-10-05 (v16)

**The directive (Steven):** every airframe and every environment must read as
REAL-WORLD, SKEUOMORPHIC (tactile, material-rich), 2.5D (layered depth),
PHOTOREALISTIC. A juiced-up 1942. The SPAD XIII is the hero — it should look
like you could reach in and touch the plywood.

### Airframe material audit

Every airframe sprite was audited against the bar: wood grain, fabric ribbing,
doped-linen sheen, metal cowling reflections, oil staining, exhaust soot,
battle wear, chipped paint. **Full roster FAILED** — the v15 renders used flat
single-color Principled materials with no grain, no ribbing, no sheen, no
grime. Visually confirmed on player-spad, enemy-fighter, wingman-spad,
zeppelin; the rest share the identical builder pipeline.

**Verdict: 0 passed, 19 models re-rendered.**

| Airframe | v15 fail | v16 material upgrades |
|---|---|---|
| player-spad (hero) | flat khaki, no grain | Painted plywood skin: stretched-noise grain ghosting through paint, clearcoat sheen, chipped-paint primer show-through, nose-ward exhaust grime gradient; doped linen wings with spanwise rib albedo bands + bump; metal cowling ring + exhaust stubs |
| wingman-spad | same as player | Same PBR stack as the hero |
| enemy-triplane/scout/fighter/bomber | flat monochrome | Linen ribbing (albedo bands), skin grain, metal mottling; cowling + soot |
| enemy-fokker-dr1/d7/albatros | flat | Same; lozenge/markings via marking PBR |
| boss-1..7 (red, checker, stripes, tiger, jester, ghost, baron) | flat livery colors | Livery markings get PBR with roughness variation; airframe materials as above |
| enemy-balloon (3 frames) | flat envelope | Ribbed envelope: wave rib albedo + bump, doped sheen |
| zeppelin | flat envelope | Same envelope PBR at scale |
| loop/loop-00..11 | flat SPAD | Re-rendered from the v16 hero with full PBR |

**Render pipeline** (`blender/render_v16.py`): rebuilds each airframe via the
canonical `build_models.py`, upgrades every material slot IN PLACE to
procedural PBR (no image textures — all procedural, all original). Key
technical fixes: (1) `normalize_pose()` bakes the join's rotation so renders
are deterministic; (2) slots replaced in place (clearing resets
material_index); (3) roundels added AFTER normalize to avoid transform
mangling; (4) **Generated texture coordinates** — Object space proved
degenerate on joined meshes (constant output); (5) **direct texture→color**
— complex Mix node chains did not survive the booth; direct links render
correctly; (6) **strong albedo variation** — the v14 sun compresses subtle
ranges, so bands use 0.70×–1.30× contrast. Lighting follows the v14 sun-rig
convention (screen-up = North, key sun due SOUTH at 60° elevation).

### 2.5D depth

- **Cloud decks** (`atmosphere.gd`): 3 drifting cirrus puffs at genuine
  altitude, each throwing a soft sun-vector shadow on the terrain below
  (`Sun.shadow_offset * 5.5`) plus a faint lit puff tinted by `light_color`.
  The puff/shadow offset is the altitude tell — 10,000 feet, not a flat map.
- **Altitude-true aircraft shadows** (`sun.gd`, `player.gd`): `Sun.draw_shadow`
  takes an altitude param — higher = larger, softer, further-thrown along the
  v14 light vector. The player's Immelmann loop drives `loop_alt` (0→1→0 via
  `sin`), so the shadow visibly detaches and rejoins through the maneuver.

### Skeuomorphic environments

- **Mud** (`background.gd`): wet sheen — a sun-oriented specular skim on the
  light side, plus per-clod top-light ticks. Churned mud catches the light.
- **Canvas** (`airfield.gd`): Bessonneau hangar gets fold shading (cloth sags
  between ribs, sun-side lift + lee hollow); tents get sag lines from the
  ridge. Cloth, not cardboard.
- **Timber** (`airfield.gd`): German hangars get long stained grain streaks
  along the planks. Timber, not a brown box.
- Water craters (sky reflection) and scorch (char gradients) from v6/v14
  already passed — untouched.

### Cohesion — one light, one world

`Sun.aircraft_tint()` grades every airframe by the sun rig (45% toward
night blue-grey at full night). Applied at the aircraft ROOT each physics
tick (absolute set, never compounds) in `player.gd`, `enemy.gd`, `boss.gd`,
`wingman.gd` — hit-flash and alpha-fade logic untouched (hierarchical
modulate multiplies cleanly).

### Nightly

New static check `QA/check_v16_sprites.py` (wired as
`gdscript-v16-sprite-sources`): parses `ROSTER` from `blender/render_v16.py`,
asserts every rostered sprite file exists, and flags any airframe-ish PNG on
disk with no render source (no orphan sprites). Legacy ground units
(`enemy-aagun`, `enemy-railwaygun`) are allowlisted — they come from the
older `render_sprites.py` pipeline.

## Sortie minimap textures + 94th mission honesty + blue-sky boss arenas — 2026-10-05 (v17)

**The directive (Steven):** every sortie's minimap renders its OWN locale
texture; the campaign honors the 94th's real mission set (trains, Drachen
balloons, Fokker hunts — no U-boats, they were an inland pursuit squadron);
the biggest baddest bosses duel in a seamless blue-sky cyclical arena; seven
chat-ready infographics, one per sortie.

### 1. Sortie-specific minimap texture maps (`minimap.gd`)

Every sortie theme now has a dedicated `_draw_*` portrait arm — no generic
fallback for any live sortie: farmland (S1, enriched with a dirt road +
farmsteads), river_interdiction (S2, moonlit winding river with silver glint),
zeppelin_sheds (S3), munitions_depot (S4), uboat_base (S5), rail_yard (S6),
storm (S7, bruised clouds + lightning vein), bluesky (boss arena, seamless sky
+ cloud wisps). The minimap reads as a tiny portrait of where you are.

### 2. 94th mission honesty (`sortie_data.gd`, `enemy.gd`, `main.gd`)

Steven's mapping, implemented:
- **Trains/troop columns:** kept (St. Mihiel / Meuse-Argonne strafing).
- **Drachen balloons:** HIGH-PRIORITY — S2 fields 3 balloons as a secondary
  objective, guarded by a flak belt (2× aagun) and Fokker screens; the brief
  names them as the artillery-directing terror they were.
- **U-boats:** reframed. The 94th flew inland pursuit (Toul, Rembercourt) —
  no naval role. S2 "Wolfpack" → **"Sortie 2 — Moonlight Interdiction"**:
  moonlit river-supply interdiction with a new `barge` enemy type (slow
  strafe target drifting downriver, PIL-rendered sprite), trains, Drachen,
  Fokker screens. The `uboat` type stays in code, unused in S2. S5's pens
  keep their boats (harbor raid, unchanged).
- **Fokker hunts + recon protection:** kept; bombers stand in for
  reconnaissance types.

The old `uboat_flotilla` theme arms remain dormant in background/ground-war/
minimap (harmless); S2's home-aerodrome dressing now shows (inland again).

### 3. Blue-sky boss arenas (`main.gd`, `background.gd`, `ground_war.gd`)

The three biggest baddest — **THE STRIPED DEVIL** (S3, the zeppelin-sheds ace),
**THE GHOST** (S6, the campaign's greatest ace), **THE RED BARON** (S7) —
duel in a seamless blue-sky cyclical arena (new `bluesky` background theme:
sky-blue + drifting cloudbanks, no terrain). On boss entry: background +
minimap switch to bluesky, ground war stands down, one shockwave beat —
no popup ceremony beyond the standing INBOUND call. (There is no "Blue Max"
boss in the roster; THE GHOST carries that slot — documented in
`sortie_data.gd`.) Boss entry convention: top-center (North), at the
sortie's `boss_at` seconds (S3 ~64s, S6 ~76s, S7 ~58s); `boss_arena` declared
per sortie, `BLUESKY_BOSSES = [2, 5, 6]`.

### 4. Infographics (`tools/make_infographics.py` → `infographics/`)

Seven 1080×1140 PNGs, one per sortie, parsed live from `sortie_data.gd`:
title + weather badge + takeoff, real-sprite strip (player, wave types,
boss), mission objectives, and a boss-entry card (boss name, minimap
thumbnail with the North spawn diamond, ~seconds to INBOUND, arena badge).
For chat delivery, one at a time.

### Nightly

- `gdscript-minimap-textures`: all 7 sortie themes have minimap arms;
  every sortie declares `boss_arena`/`boss_at`; blue-sky entry wired.
- `gdscript-s2-no-uboats`: S2 is river_interdiction, zero U-boat waves,
  barges + Drachen present; barge type/behavior exist.

## Web export preset + HTML5 export, staged for publish — 2026-10-05 (v18)

### 1. Export templates
- Official Godot **4.7.2-stable** export templates, installed to
  `~/.local/share/godot/export_templates/4.7.2.stable/` (verified via
  `version.txt`). Source: GitHub releases
  (`godotengine/godot/releases/download/4.7.2-stable/..._export_templates.tpz`,
  1.28 GB) — downloads.godotengine.org 303-redirects this version to the
  archive page, so the direct `.tpz` link there does NOT resolve.

### 2. Web preset (`export_presets.cfg`)
- Preset "Web", platform Web, runnable, `export_filter="all_resources"`.
- 720x1280 portrait, GL Compatibility (WebGL2), title "1918".
- `variant/thread_support=false` — single-threaded build, no COOP/COEP
  headers required (max hosting compatibility, incl. the artifact host).
- `html/canvas_resize_policy=2` (Adaptive), focus-canvas-on-start.
- Export path: `/home/hatch/workspace/1918-ace-of-aces/web-export/index.html`
  (absolute — resolves from both the working source and the repo mirror).

### 3. Export + verification
- Headless `--export-release "Web"`: exit 0. Output in
  `~/workspace/1918-ace-of-aces/web-export/`: `index.html` (5.4 KB, title
  "1918"), `index.js` (280 KB), `index.wasm` (39.5 MB),
  `index.pck` (2.9 MB, GDPC magic verified), audio worklets, icons. ~41 MB total.
- No export errors. PCK size sane for 7.9 MB of assets.

### 4. Staged, not published
- Publish needs Steven watching chat for the approval tap (standing pattern).
- `PUBLISH-CHECKLIST.md` (repo root): agent steps, Steven steps, honest
  web-platform limitations (haptics = Android-Chrome-only via
  `navigator.vibrate`, iOS Safari silent; ads/IAP test-mode; audio needs a
  user gesture; `user://` → IndexedDB; WebGL2 required; bot/skeptic scripts
  ship inert in the pack).

### Nightly
- `qa-web-export-ready`: `export_presets.cfg` carries a runnable Web preset
  targeting `web-export/index.html` with thread support off; 4.7.2 templates
  installed incl. a `web_*.zip`.

Desktop/mobile export presets remain future work (noted, not claimed).

## Model coverage + wingman animations + 5s post-loop invincibility — 2026-10-05 (v19)

**The directive (Steven):** no gaps in 3D model coverage; wingmen arrive and
roll like living pilots; invincibility is unmistakable; 5 full seconds of
post-loop invulnerability, by explicit order.

### 1. Coverage audit (Blender vs hand-drawn/PIL)

| Entity | Before | Verdict |
|---|---|---|
| All airframes, bosses, balloons, zeppelin, loop frames | Blender v16 PBR | covered |
| enemy-aagun, enemy-railwaygun | Blender (render_sprites.py) | covered |
| ammodepot, uboat, subpen, train, arty | Blender (build_locales.py) | covered |
| setpieces ×4, item-ammo/bomb/repair | Blender (render_sprites.py) | covered |
| tanks (3 factions) + A7V | `_draw` vector | **GAP → rendered** |
| truck | `_draw` vector | **GAP → rendered** |
| barge | PIL flat (12 colors) | **GAP → rendered** |
| MG nest | `_draw` vector | **GAP → rendered** |
| item-fuel/rapid/spread/wingman | PIL flat | **GAP → rendered** |
| infantry dots (3×4px soldiers) | `_draw` vector | intentionally vector — too small for model renders to matter |
| atmosphere gradients, gas-mask icon | runtime-generated | intentionally runtime |

**New renders** (`blender/render_v19.py`, v16 PBR pipeline, v14 sun convention):
`tank-german/french/uk` (faction hulls + turret ring, 61px), `tank-a7v`
(land-ship casemate, 91px), `tank-barrel` (separate, trained in code),
`truck` (canvas bed + ribs + cab + 6 wheels — rebuilt once: cab must face
down-screen, i.e. Blender −Y), `barge` (resized 2.4× to hold the old
~90×220px footprint), `mg-nest` (sandbag ring + MG08 + shield),
`item-fuel/rapid/spread/wingman` (1.5-unit icons, ~35px).
Wiring: `tank_duel.gd` draws hull sprites + a rotation-flipped barrel sprite
(faction markings kept as vector overlays); wrecks are the charred hull
sprite under the existing fire/smoke; `truck.gd` / `trench_target.gd` swap
to `draw_texture`; barge + pickups are drop-in PNG swaps.

### 2. Wingman arrival animation

`add_wingman()` no longer pops the wingman into formation — it spawns
off-frame below and the wingman **sweeps up with a roll** (the 8-frame
`wingman-roll` sequence, 0.9s) while the existing trail-delay steering
flies it to its slot, plus an arrival whoosh on the SFX bus.

### 3. Wingman barrel rolls — each its own

8 Blender frames: true roll about the forward axis from the v16 wingman SPAD
build (frame 0 == `wingman-spad.png`; frame 4 verified belly-up/inverted).
Triggers: (a) the player loops → each wingman rolls with 0.22s stagger,
slot 1 mirrored (`flip_h`) so they never read as synchronized clones;
(b) ambient flourish — each wingman throws a solo victory roll every
9–16s on its own timer. Steering and firing continue through the roll;
the bank-tilt is suppressed while frames own the pose.

### 4. Invincibility flashing — unmistakable

The old sine alpha blink is retired. While `invuln > 0`: hard square-wave
at ~5.4Hz — white-hot full-bright (SAFE) vs hard 0.22-alpha dip. A fresh
hit owns the sprite for 0.15s first (`flash_hold`) so damage feedback
never loses to the blink. Covers post-loop, post-revive, spawn, and
wingman-mercy windows — never ambiguous whether you're safe.

### 5. 5-second post-loop invulnerability

`POST_LOOP_INVULN := 5.0` replaces `LOOP_DUR + STAB_DUR` (`STAB_DUR`
retired from code; the loop animation itself stays 0.75s — the remaining
~4.25s is flashing flight). Steven's explicit order; the v13 skeptic may
flag difficulty impact and that's fine — the call stands.

### Nightly

New `QA/check_v19_coverage.py` wired as `gdscript-v19-coverage`:
POST_LOOP_INVULN == 5.0 and granted in `try_loop()`; hard-blink present;
v19 ROSTER sprites on disk; 8 wingman roll frames; all 44 gameplay sprite
stems traceable to a Blender pipeline (no orphans); wingman anim wiring
(`begin_arrival`/`barrel_roll`, loop trigger).

## Steven's playtest feedback: formation, entries, brains, camo — 2026-10-05 (v20)

Steven flew the build and gave four sharp notes. All four are fixed here,
plus his folded-in fifth: player tracers could be brighter.

### 1. Wingman formation slots — exactly 45° off the player's 6 (his spec)
The old slot math (`-fwd*78 + side*±58`) sat at ~37°. Now lateral EQUALS
behind (`-fwd*78.0 + side*±78.0`) — atan(78/78) = 45°, one slot each side,
slightly behind, flanking. The v19 from-below arrival sweep is untouched.
Nightly `gdscript-v20-playtest` asserts lateral == behind.

### 2. Conga lines — root cause and fix
Root cause: slow pass aircraft (balloon 32px/s, zeppelin 55, bomber 92) took
13–39 SECONDS to climb out in PASS_EXIT while the 0.35× wind drift carried
them hundreds of px off the playfield sides — and despawn was y-only, so
they lingered in wind-blown lines off the edges. (All spawns were already
top-entry; the lines were exits, not entries.)
Fix: exits now climb at min 260px/s with light wind (0.15×), and PASS_EXIT
aircraft despawn when >220px past either side edge (invisible pop —
220px off-screen). Steven's rule encoded: entries from the top 95%+,
exits straight back out the top, fast.
Skeptic: new HIGH `edge_linger` detector — a pass aircraft >160px off the
side for >3s is a regression.

### 3. Smarter enemies — no dumb wiggle
The bare `sin(age*wfreq+phase)` metronome is gone. New `_lateral()`
personalities — layered incommensurate sines with slow amplitude breathing,
so S-turns vary in period and depth:
- Dr.I "jink": aggressive direction changes, occasional darts
- scout/D.VII "slash": `_slash_run()` COMMITS to a diving line at dive
  start (faint drift correction only) — no re-homing wiggle; break-off at
  the v10 turn line, always
- Albatros "smooth": long lazy S-turns
- triplane/fighter "carve": moderate purposeful S-turns
- bomber "steady": nearly straight, faint wander
- balloon/zeppelin "drift": majestic, unchanged
Kette keeps its shared phase (one disciplined body). Magnitudes match the
old weave — dodgeability and fairness unchanged; only the pattern got
brains. `_legacy_move` (pass-exempt aircraft) flies the same personalities.

### 4. Muted tactical camo — the radioactive glow, killed
Root cause: the firing telegraph was a FULL-BODY 2.2× red strobe at 24Hz
(`sprite.modulate = Color(2.2, 1.4, 1.4)`), firing every 1.35–2.6s per
enemy — in a busy sky that's constant pulsing glow. (The v16 sprites
themselves are muted and military; the glow was runtime, not art.)
Fix: the telegraph is now a SMALL LOCAL amber glint at the nose
(`windup_glint`, drawn in `_draw`, pulsing 4–6.5px) — the airframe never
strobes. The boss charge telegraph stepped down from 2.0× red to a 1.55×
white pulse. Allowed light, per Steven: local muzzle glint, hit-flash on
damage, and the ghost baron's intentional spectral breathing (exempt).
Skeptic: new MED `enemy_glow` detector — sustained (>0.6s) full-body
overdrive >1.5× on a non-spectral pass aircraft; the 0.12s hit-flash can't
trip it. Static nightly check bans `Color(2.` strobes in enemy/wingman code.

### 5. Player tracers brighter (folded-in note)
Player streaks: 4-layer draw (30px outer glow at 0.45 alpha/11 wide →
24px mid → 16px hot core line → 4.5px pure-white tip). Player muzzle flash
gains a 1.35× size boost via a new `boost` param on `FX.muzzle`
(backwards-compatible default 1.0; enemy muzzle unchanged). Cheap _draw
only — no new nodes, no light show.

### Nightly
New `QA/check_v20_playtest.py` wired as `gdscript-v20-playtest`: 45° slot
math, all main.gd spawns off the top edge, `_lateral`/`_slash_run`/
`dive_line` present, no `Color(2.` strobes in enemy/wingman code,
`windup_glint` present, brightened player tracer + muzzle boost wiring.
Skeptic gains `edge_linger` (HIGH) and `enemy_glow` (MED) detectors.

## What's stubbed / not yet validated

- **Player art**: `assets/sprites/player-spad.png` is now a real Blender render
  (French khaki/linen biplane with tricolor roundels, top-down) generated
  from the existing procedural aircraft builder — no longer a placeholder.
- **Player-death → debrief-fail path**: code is straightforward and shares the
  validated debrief, but the headless tests used godmode — not yet exercised.
  Death-by-gas in particular (no i-frames, DoT kill) wants a live eyeball.
- **Gas mask pickup drop**: in the drop pool at 1/13 and the texture
  instantiates clean headless, but no live run has confirmed a mask drop
  appearing in play yet.
- **Bosses 2–6 and sorties 2–6**: data-driven on the same validated code
  paths, but only boss 0 / sortie 1 ran headless. Needs an editor playthrough.
- **Touch controls**: implemented and gesture-logic reviewed, but never
  exercised on a real touchscreen — the drag-steer feel (140px full
  deflection) and the 0.55s hold timing want a human thumb.
- **Haptics**: API-gated and cooldown-throttled, but `vibrate_handheld`
  never fired on real hardware from here — needs a device check.
- **Export presets**: Web preset exists and exports clean (v18). iOS/Android/
  desktop export still needs configuring in the editor (templates are
  installed; presets not yet defined).
- **Difficulty balance**: tuned for "beatable" but not playtested by a human.
- **Debug flags** (kept intentionally): `-- --autostart`, `-- --autoboss[=N]`
  (N selects the boss index; `--autoboss=6` rushes the ghost duel), and
  `-- --sortie=N` headless smoke-test hooks in `main.gd`; harmless in normal
  play.
