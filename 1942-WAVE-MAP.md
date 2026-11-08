# 1942 Wave Map — full-playthrough analysis for the 1918 mirror

**Source video:** "1942 (Arcade) Playthrough" — Longplay Center, https://www.youtube.com/watch?v=jl5WWgmvIQA
uploaded 2026-05-06, 92 views, 5 likes. **Duration 1:07:23 (4,043 s).** No captions, no
chapters. Description confirms: Capcom 1984 arcade, P-38 "Super Ace", 32 stages, loop
maneuver, Pacific Theater, goal Tokyo.

**Method:** downloaded the video (360p, 360×412, 151 MB) with yt-dlp (Android player
client — the default web client was bot-blocked). Sampled **one frame every 15 s**
(270 frames) across the entire run, then re-sampled **every 2 s** around all four boss
fights, one full stage transition, and one POW sequence (171 frames), plus a **0.5 s**
burst around a loop maneuver (13 frames). Every claim below carries a video timestamp
so it can be re-checked against a frame. Research frames kept in `1942-research/`
(`frames/`, `dense/`, `loop/`, contact sheets in `sheets/`, `dense_sheets/`).

**Cross-checks:** Capcom 1940 Series Wiki (nineteenforty.fandom.com/wiki/1942),
GameFAQs 1942 FAQ (Harring, 2000), NamuWiki 1942, MobyGames. Where the video and the
docs disagree, the video wins and the disagreement is flagged.

**Scope rule:** flow/structure inspiration only. No Capcom sprites, music, or code are
copied here; all 1918 art and lore is 1918's own.

---

## 1. Headline findings — the ten things that matter

1. **32 stages, counted DOWN 32 → 1, ~120 s each.** Non-boss stage ≈ 120 s
   (carrier card to carrier card); boss stages ≈ 150 s; the final-boss stage ≈ 165 s.
   Whole run: first carrier card 00:15 → last tally 1:06:15 = 66:00 of play.
   4,043 s ÷ 32 ≈ 126 s/stage including title and ending.
2. **The stage is the unit, and the carrier is the punctuation.** Every stage begins
   AND ends on the same full-screen aircraft-carrier image: land → tally → next-stage
   card → takeoff. There is no separate menu, loading screen, or briefing wall.
   The whole transition beat is ~20 s (see §6).
3. **Bosses are rare and fast.** Only **4 bosses in 32 stages** (stages 26, 18, 10, 02
   by the countdown number — i.e. the 7th, 15th, 23rd, 31st stages played). Each boss
   fight lasts **~7–14 s** against a max-firepower player: the boss enters, climbs,
   hovers, and dies in one sustained burst. The boss is a *punctuation mark*, not a
   gauntlet.
4. **Boss intros come from the BOTTOM.** Three of the four bosses (stages 18, 10, 02)
   rise out of the bottom edge, nose-up, directly at the player — a huge 4-engine
   bomber filling ~50–85% of screen width. Stage 26's boss enters from the top
   instead. After entry the boss climbs to the top third, stops, strafes side to side,
   and fires aimed shots plus small fans.
5. **This is NOT a bullet hell.** Peak enemy bullet count on screen is **~10–20**:
   aimed singles plus 5–7-shot fans from large planes. The threat is the *aim* and the
   *collision*, not the volume. Player fire is 2 main streams + 1 per side fighter.
6. **Waves are formations, not streams.** 3–6 planes in V shapes, columns, and
   diagonals; red 5-plane and 10-plane formations with a clear-bonus (500 / 1,000);
   a new formation roughly every **8–10 s**; **~10–13 waves per stage**; 1–2 large
   bombers (Daihiryu) per stage.
7. **A pre-boss lull, then a post-boss calm.** ~10 s before each boss the spawns
   nearly stop and the score barely moves; after the boss dies there are ~6–10 s of
   empty ocean before the carrier arrives. The game breathes around the boss.
8. **Bonus stages every 4th stage.** Stages remaining 29, 25, 21, 17, 13, 09, 05, 01
   are labeled `( % AND POINT UP STAGE )`: small planes **do not shoot**; only large
   aircraft spray bullets. The final stage (01) is a bonus stage.
9. **The tally is the score game.** Each stage ends with `SHOOTING DOWN NN%` →
   `BONUS` by percentage bracket (100% = 50,000 special; 95–99% = 20,000; 90–94% =
   10,000; 85–89% = 5,000; 80–84% = 4,000; 70–79% = 3,000; 60–69% = 2,000;
   50–59% = 1,000; <50% = 0) → `R x1000` for each unused loop (1,000 each).
   Clearing the game pays **10,000,000**.
10. **The score does NOT overflow at 999,999 in this playthrough.** The score passes
    1,000,000 at ~32:45 (1,000,720) and climbs to the final 12,250,140. The
    overflow claim in some docs does not apply to this revision/run — flagged, not
    assumed.

---

## 2. How 1942 counts — read this first

The arcade counts stages **remaining**, 32 down to 1. The first stage you play is
"LAST 32 STAGE"; the last is "LAST STAGE". All stage numbers in this document use
the **countdown number as shown on screen**, with the play order in parentheses.
Areas come in blocks of 4: 32–29 Midway, 28–25 Marshall, 24–21 Attu, 20–17 Rabaul,
16–13 Leyte, 12–09 Saipan, 08–05 Iwo Jima, 04–01 Okinawa.

1918 counts UP (Sortie 1 → Sortie 32). The mirror mapping in §7 is by **play order**:
1942's 1st-played stage (32) ↔ 1918 Sortie 1; 1942's 7th-played (26, boss 1) ↔
Sortie 7; 15th-played (18, boss 2) ↔ Sortie 15; 23rd-played (10, boss 3) ↔
Sortie 23; 31st-played (02, final boss) ↔ Sortie 31; 32nd-played (01, last) ↔
Sortie 32.

---

## 3. Stage-by-stage breakdown (all 32, in play order)

Times are carrier-card to carrier-card, ±15 s (the 15 s sampling grid). "Tally" is
shown only where the ~4 s tally text was legible in the sampled frames; most tallies
were not captured and are marked as such — the tally *format* is documented in §6/§7.
Wave character is what the sampled frames show (snapshot counts, not a full census).

| Played | Stage | Area | Length | Terrain / notes | Bonus / Boss | Tally (if captured) |
|---:|---:|---|---|---|---|---|
| 1 | 32 | Midway | ~105 s | Ocean, green islands; sparse pairs/trios; 1 Daihiryu seen 01:00 | — | not captured |
| 2 | 31 | Midway | ~120 s | Ocean/islands; red POW ball seen 01:15; small groups of 2–4 | — | not captured |
| 3 | 30 | Midway | ~120 s | Ocean/islands; 3–5 planes on screen; first red fans | — | not captured |
| 4 | 29 | Midway | ~120 s | Ocean/islands; **10-plane red formation** at 07:00 (vertical column) | **BONUS** | **93% · 10,000 · R×1000=3,000** (08:00) |
| 5 | 28 | Marshall | ~120 s | Ocean → jungle forest, rivers, lakes | — | **93% · 10,000 · R×1000=3,000** (10:00) |
| 6 | 27 | Marshall | ~120 s | Jungle/lakes; V and column formations of 4–5; "1000" popup 11:30 | — | **88% · 5,000 · R×1000=3,000** (12:00) |
| 7 | 26 | Marshall | **~150 s** | Jungle/lakes → ocean; Daihiryu pass 13:40–13:48; **boss 14:12–14:20** | **BOSS 1** | **95% · 20,000 · R×1000=3,000** (14:34) |
| 8 | 25 | Marshall | ~120 s | Ocean; red fans (large-aircraft sprays only — bonus rules); side fighters visible | **BONUS** | not captured |
| 9 | 24 | Attu | ~120 s | Forest/rivers/lakes; 3–6 planes per snapshot | — | not captured |
| 10 | 23 | Attu | ~120 s | Forest/river; "5000" Yashichi popup 20:15 | — | not captured |
| 11 | 22 | Attu | ~120 s | Forest/river; Daihiryu top-left 21:15; big explosions 21:45–22:00 | — | not captured |
| 12 | 21 | Attu | ~120 s | Ocean; red fans; player + side fighters; "POW" letter seen 24:00 | **BONUS** | not captured |
| 13 | 20 | Rabaul | ~120 s | Ocean, green islands; Daihiryu top-center 25:15; red POW balls | — | not captured |
| 14 | 19 | Rabaul | ~120 s | Ocean/islands; Daihiryu mid-right 27:15; player + side fighters throughout | — | not captured |
| 15 | 18 | Rabaul | **~150 s** | Ocean/islands; Daihiryu passes 30:12–30:18; **boss 30:38–30:45 (bottom entry)** | **BOSS 2** | **92% · 10,000 · R×1000=3,000** (31:02) |
| 16 | 17 | Rabaul | ~120 s | Ocean; red 5- and 8-plane columns (32:00, 32:15); score passes 1,000,000 at 32:45 | **BONUS** | not captured |
| 17 | 16 | Leyte | ~120 s | Brown/green land, forests, lakes; diagonal 10-plane line 33:30; Daihiryu 33:45 | — | not captured |
| 18 | 15 | Leyte | ~120 s | Brown fields, forest patches, lakes; Daihiryu top-center 35:45 | — | not captured |
| 19 | 14 | Leyte | ~120 s | Forest/lakes; red formation row 38:15; Daihiryu 37:45 | — | not captured |
| 20 | 13 | Leyte | ~120 s | Ocean → forest; red 5-plane row 39:45 | **BONUS** | not captured |
| 21 | 12 | Saipan | ~120 s | Green forest + rivers; Daihiryu mid-left 41:45 | — | not captured |
| 22 | 11 | Saipan | ~120 s | Forest/ocean; red 5-plane diagonal 43:15; red POW ball 44:15 | — | not captured |
| 23 | 10 | Saipan | **~150 s** | Fields → coast → ocean; Daihiryu pass 46:46–46:52; pre-boss lull 46:58–47:06; **boss 47:08–47:20 (bottom entry)** | **BOSS 3** | **92%** (47:30; bonus line not legible) |
| 24 | 09 | Saipan | ~120 s | Ocean; red 5-plane vertical column 48:30; "5000" popup 49:15 | **BONUS** | not captured |
| 25 | 08 | Iwo Jima | ~120 s | Green land with **spiral crater hills** + river; red fans | — | not captured |
| 26 | 07 | Iwo Jima | ~120 s | Crater hills/river; Daihiryu mid-screen 53:15 | — | not captured |
| 27 | 06 | Iwo Jima | ~120 s | Crater hills/river/coast; Daihiryu top-center 55:15 | — | not captured |
| 28 | 05 | Iwo Jima | ~120 s | Ocean; red 5-plane row 56:00; "1500" popup 56:15; Daihiryu 57:15 | **BONUS** | not captured |
| 29 | 04 | Okinawa | ~120 s | **Dense gray city** (buildings, river, green parks) → green fields | — | not captured |
| 30 | 03 | Okinawa | ~120 s | City → fields; vertical 6-plane column 60:45; Daihiryu 61:15 | — | not captured |
| 31 | 02 | Okinawa | **~165 s** | City → forest → ocean; Daihiryu 63:20–63:22; **final boss 63:46–64:00 (bottom entry, tan→green)**; CONGRATULATION 64:02–64:08 | **FINAL BOSS** | **+11,000 total** (64:16; %/split not legible) |
| 32 | 01 | Okinawa | ~120 s | Ocean; red 5-plane row 64:45; Daihiryu 65:45; red fans | **BONUS · LAST STAGE** | **93%** (66:15; figure "6863" also shown, see §6) |

**Ending (after stage 01):** 66:30 `WE GIVE UP!` + `SPECIAL BONUS 10,000,000 PTS` +
`GAME OVER` → 66:45 `PRESENTED BY CAPCOM` + `PS. HOPE OUR NEXT GAME:` → 67:00
top-5 ranking entry (`TOP 12250140 ANDERS 33`) → 67:15 title screen
(`1942 / INSERT COIN / © 1984 CAPCOM`). **Final score 12,250,140**
(2,250,140 + 10,000,000). Video ends 67:23.

**Pacing totals:** 32 stages ≈ 66:00 of play. Non-boss ≈ 120 s, boss ≈ 150 s,
final-boss ≈ 165 s. Combat portion of a non-boss stage ≈ 100 s; transition ≈ 20 s.

---

## 4. Wave anatomy — the building blocks

Every stage is built from the same small kit, repeated with slowly rising fire
frequency. Nothing new is introduced after the first minutes; later stages are
denser and shoot more often, not different.

### 4.1 Enemy roster (as seen + documented)

| 1942 enemy | Look / behavior (observed) | Entry vector | Fire | Hits to kill (docs) | Points |
|---|---|---|---|---|---|
| Gray fodder (Kuro-den) | Small gray/green single-seat fighter; flies at the player, then half-loops and comes back the other way | Top, top-left, top-right | Aimed single shots; frequency rises with stage | 1 | 30–200 |
| Green circler (Kuro-den Kai) | Small green fighter; wide circles, can leave and re-enter the screen | Top / sides | Aimed singles | 1 | 30–200 |
| Red formation (Akamizu) | Small red fighters in **formations of 5 or 10**; fly straight in V / column / diagonal lines | Top | Usually none (formation bonus is the point) | 1 each | 100 each; **500 bonus for clearing a 5-formation, 1,000 for a 10-formation**; clearing a formation drops a power-up marker worth 1,000 |
| Mid-size (Shoryu / Fukusuke / BVD) | Medium twin-engine; faster than fodder | Top; some swing in from the sides | Aimed singles | ~6 | 1,000 or 1,500 |
| Large bomber (Daihiryu, G4M) | Big tan 4-engine bomber; **enters from the top flying down**, crosses the screen, sometimes stops near the top and strafes side to side firing | Top (flying down) — see note | **5–7-shot spread fans** + aimed singles | ~12 | 2,000 base; **+500 per consecutive bomber destroyed without dying**, max 9,000; resets to 2,000 on player death |
| Yashichi plane | Small plane that drifts slowly **up from the lower-left or lower-right**, toward the top | **Bottom-left / bottom-right** | None | 1 | Hit it and it becomes a Yashichi worth **5,000** when collected |
| Boss (Ayako, G8N-based) | Huge green (final: tan→green) 4-engine bomber, ~50–85% of screen width | **Bottom (3 of 4) / top (stage 26)** | Aimed shots + small fans (§5) | ~30 | 20,000 / 30,000 / 40,000 / 50,000 (§5) |

**Bottom-entry note:** the large planes are the ones the player has to watch *behind*
them for. The FAQ's "approaches from the bottom" describes the Daihiryu/boss class:
they rise from the bottom edge, climb to near the top, stop, and strafe side to side
while firing. In the sampled frames, Daihiryu passes were also seen entering from the
top flying down (13:40–13:48, 25:15, 30:12–30:18, 46:46–46:52) — both entries exist;
the bottom-entry climb-and-hover is the dangerous one because it comes up behind the
player's firing line.

### 4.2 Formation shapes (observed in frames)

- **Pair / trio:** 2–3 fodder planes in a loose horizontal row or short diagonal,
  entering from the top edge (most common; every stage, e.g. 00:30, 01:30, 20:00).
- **V of 4–5:** small planes in a V, top entry (e.g. 23:57, 46:30).
- **Column of 5:** red formation flying straight down in a single file (e.g. 07:00
  ten-plane column, 32:00 eight-plane column, 48:30 five-plane column, 60:45 six-plane
  column).
- **Diagonal line of 5–10:** red or gray planes on a diagonal (e.g. 33:30, 39:45).
- **Row of 4–5:** horizontal row across the top (e.g. 23:53, 56:00).
- **Daihiryu + escort:** a large bomber crossing with 2–4 small planes around it
  (e.g. 13:40–13:48, 27:15, 46:46–46:52).
- **Kamikaze dive:** individual fodder planes break from formation and dive at the
  player's position (seen as planes angled steeply down toward the player, e.g.
  01:30, 21:15).

### 4.3 Wave cadence (measured)

- **New formation every ~8–10 s** in the early stages, tightening to ~5–8 s late
  (POW window 23:45–24:19: a new element every ~5–8 s; boss-3 pre-boss window
  46:30–47:08: waves at 46:30, 46:40, 46:46, 46:54, then the lull).
- **~10–13 waves per 100 s of combat**, 3–6 planes per wave → roughly **35–60
  enemy planes per stage** plus 1–2 Daihiryu. (Snapshot counts only; a full census
  from stills is not possible — see §10.)
- **1–2 Daihiryu per stage**, usually in the middle third or just before the boss
  (the "last wave" before the boss is often a Daihiryu pass: 13:40–13:48 before boss
  1; 46:46–46:52 before boss 3).
- **Yashichi plane roughly once per stage**, drifting up from a bottom corner;
  "5000" popups were captured at 20:15, 13:52, 49:15, 64:45.
- **Difficulty curve is shallow:** later stages mean more frequent bullets and more
  simultaneous planes, not new mechanics. Bullet frequency per plane rises with the
  stage number; the roster never changes.

### 4.4 Terrain (the scrolling map)

The ground scrolls continuously under the fight; each area has a fixed look, and
each stage scrolls ocean → land → ocean (the carrier sits on ocean at both ends):

- **Midway (32–29):** open ocean, green islands with brown beaches, small rocks.
- **Marshall (28–25):** ocean, then dense jungle forest with rivers and blue lakes.
- **Attu (24–21):** jungle forest, winding rivers, lakes, brown coastline.
- **Rabaul (20–17):** ocean with green islands (volcanic-looking brown/green islets).
- **Leyte (16–13):** brown and green farmland, forest patches, lakes, rivers.
- **Saipan (12–09):** green forest, rivers, coastline.
- **Iwo Jima (08–05):** green land with distinctive **spiral/concentric-circle crater
  hills** and a river.
- **Okinawa (04–01):** dense **gray city** (building blocks, a river, green parks),
  then green fields and coast.

The terrain is decoration — no ground targets exist in 1942; every enemy is an
aircraft.

---

## 5. Boss encounters — all four, frame by frame

All four bosses are the same aircraft (Ayako, based on the Nakajima G8N): a huge
4-engine bomber. No health bar, no name card, no intro cutscene — the boss simply
flies in and the fight starts. The player in this run had maximum firepower plus
two side fighters for all four fights, so each one died in **~7–14 s**. (A weaker
player's fight would last longer; the documented ~30 hits is the un-upgraded
reference.)

### 5.1 Boss 1 — end of stage 26 (Marshall), 20,000 pts

- **12:00** stage 26 begins. Daihiryu pass 13:40–13:48 (top entry, flying down).
- **13:49.5–13:50.5** the player performs a **loop** (0.5 s sampling): the P-38
  somersaults end-over-end for ~1 s, invulnerable, side fighters vanish during the
  loop and return after; a Yashichi "5000" is collected right after (13:50.5).
- **13:58–14:10** pre-boss lull: ocean, almost no enemies, score barely moves
  (277,970 → 278,300 over 12 s).
- **14:12** boss enters from the **TOP**, nose-down, diving at the player — huge
  green bomber, ~55% of screen width. Player + side fighters at the bottom.
- **14:14–14:18** boss turns, climbs to the top third nose-up, strafes slightly,
  fires aimed red dots and two small fans (~12 bullets visible at 14:14).
- **14:20** boss dies in a multi-fireball explosion (orange blasts across the
  wings/fuselage); score jumps 282,100 → 302,200 (**+20,100 = 20,000 boss +
  100**). Fight duration ≈ **8 s**.
- **14:22–14:28** post-boss calm: empty ocean, player alone (~6 s).
- **14:30–14:34** carrier scrolls in, player lands, tally: 95% / 20,000 / R×1000=3,000.

### 5.2 Boss 2 — end of stage 18 (Rabaul), 30,000 pts

- **28:30** stage 18 begins. Daihiryu passes 30:12–30:18 (top entry).
- **30:18** a green bomber flashes at the top-right (boss's first pass or a
  Daihiryu — not resolvable in the frame; see §10).
- **30:20–30:36** pre-boss lull: empty ocean, player + side fighters, score nearly
  frozen (877,270 → 887,370 over 16 s, mostly the "5000" Yashichi at 30:22).
- **30:38** boss enters from the **BOTTOM** — huge green 4-engine bomber rising
  out of the bottom edge, nose-up, tail cut off by the screen edge, ~40% of width
  visible and growing. This is the dramatic bottom-entry intro.
- **30:40–30:44** boss climbs to the top-center, hovers nose-up, strafes, fires
  aimed red dots and small fans (~6–10 bullets on screen).
- **30:45–30:46** boss dies in a 4+ fireball explosion across the airframe; score
  jumps 891,270 → 921,770 (**+30,500 ≈ 30,000 boss + 500**). A "30000" score popup
  appears at the top-right at 30:48. Fight duration ≈ **7 s**.
- **30:48–30:56** post-boss calm: empty ocean (~8 s).
- **30:56–31:02** carrier in, landing, tally: 92% / 10,000 / R×1000=3,000.
- **31:04** next card: `( % AND POINT UP STAGE ) / RABAUL / LAST 17 STAGE`.

### 5.3 Boss 3 — end of stage 10 (Saipan), 40,000 pts

- **45:00** stage 10 begins. Daihiryu pass 46:46–46:52.
- **46:58–47:06** pre-boss lull: empty ocean, player + side fighters, score frozen
  at 1,487,780 for ~8 s.
- **47:08** boss enters from the **BOTTOM** — huge green bomber, nose-up, tail at
  the bottom edge, ~85% of screen width (the largest boss entry in the run).
  A red 7-shot fan and 3 aimed dots are already in the air below it.
- **47:10–47:16** boss climbs to the top-center, hovers, strafes, fires aimed dots
  and fans (peak ~10–12 bullets visible). Player pours fire into it from below;
  hit flashes on the wings at 47:12.
- **47:18–47:20** boss dies: score jumps 1,491,880 → 1,532,680 (**+40,800 ≈ 40,000
  boss + 800**); the death frame shows 3 orange fireballs on the wings/fuselage.
  Fight duration ≈ **10–12 s**.
- **47:22–47:28** post-boss calm: empty ocean (~6 s).
- **47:30–47:34** carrier in, landing, tally: 92% (bonus line not legible).

### 5.4 Boss 4 — end of stage 02 (Okinawa), FINAL BOSS, 50,000 pts

- **61:30** stage 02 begins. Daihiryu passes 63:20–63:22.
- **63:40–63:44** pre-boss lull: empty ocean, player alone, score frozen at
  2,117,640.
- **63:46** final boss enters from the **BOTTOM** — huge **TAN/khaki** 4-engine
  bomber, nose-up, tail at the bottom edge, ~85% of screen width. (Color differs
  from the green bosses 1–3 — see note below.)
- **63:48–63:56** boss climbs to the top-center, hovers, strafes, fires red fans
  (6-shot) and aimed dots (peak ~10 bullets). Player hits register as red X
  flashes on the tail/fuselage (63:50). Score creeps 2,117,640 → 2,122,940
  (hit points at 100 per hit on a multi-hit plane).
- **63:58** the boss now renders **GREEN** at the top-center (palette shift after
  ~12 s of sustained fire — see note).
- **64:00** boss dies: **4 orange fireballs erupt on the wings** (2 per wing);
  score jumps 2,122,940 → 2,173,040 (**+50,100 = 50,000 boss + 100**). Fight
  duration ≈ **14 s**.
- **64:02–64:08** `CONGRATULATION` (red text in a black box, top-center) →
  `YOU ARE / THE BEST OF PLAYER !` (yellow) → `FIGHT LAST ONE STAGE` (white),
  over the empty ocean. No carrier, no tally yet — the message *is* the beat.
- **64:10–64:16** carrier in, landing, tally (+11,000 total — likely 10,000 %
  bonus + 1,000 for 1 remaining loop, i.e. the player spent 2 loops in this fight;
  split not legible).
- **64:16** next card: `( % AND POINT UP STAGE ) / OKINAWA / LAST STAGE / READY /
  PLAYER 1`.

**Boss color note (stage 02):** bosses 1–3 render green from entry to death. The
final boss renders tan/khaki on entry (63:46–63:56) and green at the top (63:58)
before dying green (64:00). What the stills establish: one plane, one continuous
climb, color change in the last ~2 s before death. What they do *not* establish:
whether the tan→green shift is a damage-threshold palette swap, a hit-flash state,
or a separate sprite — see §10. (The "second bomber" seen in the small contact
sheet at 63:50–63:52 is the player + two side fighters in formation, confirmed at
full resolution.)

### 5.5 Boss pattern summary (the choreography to mirror)

1. **Lull** (~8–16 s): spawns stop, ocean empties, score freezes.
2. **Entry** (~2 s): giant bomber rises from the bottom edge (3 of 4) or dives from
   the top (1 of 4), nose toward the player, ~50–85% of screen width.
3. **Climb** (~2–4 s): boss travels to the top third, firing aimed shots as it goes.
4. **Hover + strafe** (~4–8 s): boss sits near the top, drifts side to side, fires
   aimed singles and 5–7-shot fans; the player must stay under it and pour fire in.
5. **Death** (~1–2 s): multi-fireball explosion across the airframe (3–4 blasts),
   score popup ("30000" seen at 30:48), +20k/30k/40k/50k by boss.
6. **Calm** (~6–10 s): empty ocean, no spawns.
7. **Carrier** (~6 s): scrolls in, landing, tally.

---

## 6. Stage transitions — exactly how a stage ends and the next begins

Measured frame-by-frame at 2 s sampling for the stage 29 → 28 transition
(07:50–08:20), and confirmed at 15 s sampling across all 31 transitions. The
beat is identical every time; only the text changes.

| Time | What happens | Duration |
|---|---|---|
| ~T−10 s to T | Last wave clears; player flies over empty ocean; no new spawns | ~10 s of calm (part of the stage's last stretch) |
| T | **Carrier scrolls DOWN into view from the top edge** (stern/bow first); the player keeps flying below it | ~4 s |
| T+4 s | Player lands on the deck (plane sprite sits on the carrier); **all remaining enemy planes on screen explode** and their points are awarded (docs; the sampled frames show an empty sky at this point) | instant |
| T+4–8 s | **Tally types out on the carrier:** `SHOOTING DOWN NN%` (white, % in yellow), then `BONUS` (red) + `NNNNN PTS` (yellow), then `R x1000= NNNN PTS` (R in red). The score jumps by bonus + loops at this point | ~4 s |
| T+8 s | Tally is replaced on the same carrier image by the **next-stage card:** `( % AND POINT UP STAGE )` (only on bonus stages) / area name in red (`MIDWAY`, `MARSHALL`, `ATTU`, `RABAUL`, `LEYTE`, `SAIPAN`, `IWOJIMA`, `OKINAWA`) / `LAST NN STAGE` (yellow; the final stage reads `LAST STAGE`) / `READY` / `PLAYER 1` (white). The carrier deck shows parked planes (X shapes) and the bow is marked `88` | ~2 s |
| T+10 s | **Takeoff:** the carrier scrolls UP off the top of the screen with the player plane sitting on the deck; as the stern clears the top edge the player is airborne over the ocean | ~6 s |
| T+16–20 s | First wave of the new stage arrives immediately (small planes from the top); combat resumes with no pause | — |

**Total transition: ~20 s** from the last kill to the first new wave. The stage
counter is the card itself — there is no separate "stage clear" screen, no
intermission menu, and no loading. The player never leaves the game view.

**First stage (00:00–00:15):** title screen (`1942`, `PUSH START BUTTON`,
`ONE PLAYER ONLY`, `© 1984 CAPCOM`, `CREDIT 01`, high score 40000) → the carrier
card (`MIDWAY / LAST 32 STAGE / READY / PLAYER 1`) → takeoff, same as any other
stage. The run starts with the player already on the deck.

**HUD (throughout):** top-left `1UP` + score; top-center `HIGH SCORE` (starts
40,000, then tracks the player's score once passed); top-right `2UP`. Bottom edge:
small plane icons (lives) bottom-left and a red `R` (loop stock) bottom-right —
**partially clipped in this capture; counts not legible** (see §10). The only
loop evidence is the tally line `R x1000= NNNN PTS`.

---

## 7. Scoring & POW systems (documented, spot-verified on video)

### 7.1 Scoring

| Event | Points |
|---|---|
| Small plane (gray/green) | 30 / 50 / 70 / 100 / 150 / 200 (by type) |
| Red formation plane | 100 each |
| Clearing a 5-plane red formation | +500 bonus |
| Clearing a 10-plane red formation | +1,000 bonus |
| Clearing any red formation | drops a power-up marker worth 1,000 when collected |
| Medium plane | 1,000 or 1,500 |
| Large bomber (Daihiryu) | 2,000 first; +500 per consecutive bomber without dying, max 9,000; resets to 2,000 on death |
| Hit on any multi-hit plane | 100 per hit |
| Boss 1 (stage 26) / 2 (18) / 3 (10) / 4 (02) | 20,000 / 30,000 / 40,000 / 50,000 |
| Yashichi | 5,000 |
| Stage-end shoot-down % bonus | 100% = 50,000 special; 95–99% = 20,000; 90–94% = 10,000; 85–89% = 5,000; 80–84% = 4,000; 70–79% = 3,000; 60–69% = 2,000; 50–59% = 1,000; <50% = 0 |
| Unused loops at stage end | 1,000 each (`R x1000`) |
| Clearing the final stage | **10,000,000** |

**Verified on video:** 93% → 10,000 (stages 29, 28); 88% → 5,000 (stage 27);
95% → 20,000 (stage 26); 92% → 10,000 (stage 18); boss values 20,000 (14:20),
30,000 (30:45, with a "30000" popup), 40,000 (47:18), 50,000 (64:00); Yashichi
"5000" popups at 20:15, 13:52, 49:15, 64:45; `R x1000= 3000` at every captured
tally except the final-boss stage (+11,000 total, i.e. 10,000 + 1 loop left);
final score 12,250,140 = 2,250,140 + 10,000,000.

### 7.2 POWs (power-ups)

POWs are lettered pickups that drift down the screen; the player collects them by
flying through them. Observed on video as small red balls and a legible `POW` letter
(24:00, 30:10), drifting slowly down-screen over ~10–14 s. The red ball seen
drifting in the POW window (23:45–24:19) is a POW pickup in flight.

| POW color | Effect (docs) |
|---|---|
| Green | Powers up the main weapon |
| White | Destroys all enemies on screen |
| Gray | Adds the Side Fighters (two small planes that flank the player and add firepower) |
| Orange | Enemies cannot shoot for a limited time |
| Yellow | +1 loop for the current stage |
| Black | +1 extra life |
| Red | 1,000 points |
| Yashichi (special plane) | 5,000 points |

**Side fighters:** two small P-38s that attach to the player's flanks and fire
with the player. Observed from ~12:45 onward for the rest of the run — the player
holds them through nearly the whole game (consistent with a no-death or low-death
run after the early stages; death loses them). They vanish during the loop maneuver
and return after it (13:49.5–13:52).

### 7.3 The loop maneuver

- **Input:** second button. **Stock:** 3 per stage; +1 per yellow POW; unused ones
  pay 1,000 each at stage end; stock resets each stage.
- **Observed (13:49.5–13:50.5, 0.5 s sampling):** the P-38 somersaults end-over-end
  for ~1 s; the sprite rotates with a red/orange flash; the player is invulnerable
  and cannot shoot during it; side fighters disappear for the duration and return
  after; a Yashichi is collected immediately after the loop ends.
- **Use in this run:** sparing — the player ends almost every captured stage with
  all 3 loops (R×1000 = 3,000). The final-boss stage is the exception (+11,000
  total implies 2 loops spent). **Tension flagged:** the player visibly loops at
  13:49.5 during stage 26, yet the stage-26 tally still pays 3,000 for loops. The
  documented rule (3 per stage + yellow POWs) allows this if the player had banked
  a 4th loop via a yellow POW earlier in the stage; that pickup is not visible in
  the sampled frames — see §10.
- **Player fire:** twin parallel streams from the P-38; upgraded firepower widens
  the spread; each side fighter adds one stream (max 4 parallel streams observed).
  The player can have only a limited number of shots on screen at once (docs: 2-shot
  limit at base firepower), which is why the streams read as short paired dashes
  rather than a continuous beam.

---

## 8. Bullet density — the tracer counts

Counted from frames (enemy bullets = red dots / red fan rows; player bullets =
white-yellow tracer streaks). 1942's density is low by modern bullet-hell standards
and that is the point: with a one-hit death, 15 aimed bullets are already lethal.

| Situation | Enemy bullets on screen (peak, counted) | Notes |
|---|---|---|
| Early stage, normal wave (e.g. 00:30–01:45) | 3–8 | Aimed singles from 2–4 fodder planes |
| Mid stage, normal wave (e.g. 11:30, 20:00) | 6–12 | Singles + one 5-shot fan |
| Daihiryu pass (e.g. 13:42, 21:15, 25:15, 46:48) | 12–18 | Two 5–7-shot fans + aimed singles |
| Red-formation stage, dense moment (e.g. 32:00, 39:45) | 8–14 | Fans from a large plane + singles |
| Boss hover (14:14, 30:42, 47:12, 63:52) | 10–15 | Aimed dots + 1–2 fans of 5–7 |
| Boss entry (47:08, 63:46) | 7–10 | One 7-shot fan + 3 aimed dots already in flight |
| Bonus stage (e.g. 06:15–07:45, 23:45–24:19) | 5–15 | Small planes do not shoot; all bullets are large-aircraft fans |
| Player tracers | 2 main streams + 1 per side fighter (max 4 streams); each stream shows ~4–6 tracer segments | Twin shots at base; wider spread when powered up |

**Fan shape:** large-plane spreads are short horizontal rows/arcs of 5–7 red dots,
fired downward in the player's general direction — not aimed precisely, but wide
enough to cover a dodge lane. **Aimed shots:** single red dots fired directly at
the player's position at the moment of firing. There are no curving, spiraling, or
screen-filling bullet patterns anywhere in the run.

---

## 9. The 1918 mirror — what to build

### 9.1 Grounding: what 1918 already has (verified in `1918-ace-of-aces.html` this session)

- **32 sorties**, campaign entries with real 1918 dates/locales (S1 "Seven Against
  One", Billy, 25 Sep 1918 → S32). **Boss every sortie** (doctrine, 2026-10-05):
  `sortiePlans` trigger the boss at `bossAfter` 95–105 s once `claimGate` 6–14 kills
  are met. Boss roster HP **50 → 170 (+4/sortie)**, S32 **The Crimson Ghost HP 220**
  (file values; the older doctrine figure "S1 25 → S32 500" differs — the file is
  current). No health bars; enemy HP hidden.
- **Player dies in ONE hit** (doctrine). Loop maneuver exists. Bombs exist.
  Power-ups drop on kill (~18%): `firepower` / `wing` (side fighters — the 1942
  Side Fighters analog) / `blast` (screen clear). There are **no lettered POW
  pickups** in the file today (the "POW" matches are the substring of "POWER").
- **WaveManager:** formations every `(5 + rand×5) / wave-factor` seconds
  (~5.7–11.4 s at medium), patterns `vee` / `beam` / `split`, paths `loop` /
  `sine` / `swoop`, `maxWaves` 18, wave sizes 4–6 (the roster spec fixes this to
  2–7), an elite triplane every 4th wave, `MAX_ACTIVE_ENEMIES` 10.
- **Enemy fire:** single tracers, `fan2`, `fan5heavy`, `fan3lead`, `fan2lead`,
  rear-observer gold shots, `arc` — the exact fan vocabulary 1942 needs. Enemy
  bullet cap 520 (far above 1942's ~20 live bullets — the cap is not the tuning;
  the *spawn* rate is).
- **Roster spec (`docs/roster-port-spec.md`):** 10 new archetypes with era-banded
  `SORTIE_ROSTER` pools (early scouts → two-seaters → D.VII / Dr.I / Gotha /
  Jasta), Jasta liveries, Gotha raids. The pools below are taken from that spec.
- **End of sortie today:** a `SORTIE CLEAR` debrief screen ("MISSION
  ACCOMPLISHED" + date/locale). No `SORTIES LEFT` counter, no aerodrome
  takeoff, no shoot-down % tally yet — the pacing doc
  (`docs/1942-pacing-reference.md`) already targets all three.

### 9.2 Enemy-role mapping (1942 → 1918)

| 1942 role | 1918 aircraft (archetype, HP) | Entry / behavior to copy |
|---|---|---|
| Gray fodder, 1 hit | **E.III** (hp 3, single) and **Taube** (hp 2, 60% fire skip) | Top / top corners; fly at player, half-loop back |
| Green circler | **Albatros D.Va** (hp 5, single) / **Pfalz D.XII** (hp 16, fan2) | Wide circles, can re-enter the screen |
| Red 5/10 formation | **red** Jasta flights (hp 4, single) in 5-plane V or 10-plane column | Top entry, straight lines; **full-clear bonus 500 / 1,000 + power marker drop** |
| Mid-size, ~6 hits | **Halberstadt CL.II** (hp 12, single) / **Rumpler** (hp 9, rear gold) | Top / sides; Rumpler's rear-observer gold shot is the 1942 "shoots behind" beat |
| Daihiryu large bomber, ~12 hits | **Gotha G.IV/V** (hp 40, `arc` fire) as the in-wave heavy; **riser** (hp 12, `fan5heavy`) as the lighter heavy | **Bottom-entry climb-and-hover** (rise from below, stop near top, strafe, 5–7-shot fans); also top-entry fly-down passes |
| Yashichi plane | A lone **Rumpler** photo-recon drifting up from a bottom corner | Shoot it → drops the 5,000 pickup |
| Ayako boss, ~30 hits | The **boss roster** (Gotha / Zeppelin / Staaken / Dr.I / Jasta command); see §9.4 for the four majors | Bottom-entry (3 of 4), climb, hover-top, strafe, aimed + fans; multi-fireball death |
| POW colors | 1918 powers, extended (§9.5) | Drifting lettered pickups, ~10–14 s on screen |

### 9.3 Per-sortie distribution — all 32 sorties

Mapped by **play order** (1942 stage 32 = 1918 Sortie 1). "Waves" is the target
count per sortie at ~8–10 s cadence; "bullets" is the peak live enemy-bullet target.
1918 aircraft pools are from the roster spec's `SORTIE_ROSTER`.

| 1918 | 1942 stage | Length | Type | 1918 aircraft (pool) | Waves | Bullet peak |
|---:|---:|---:|---|---|---|---:|
| S1 | 32 | ~105–120 s | normal | taube, eiii, small | 10–11 | 6–8 |
| S2 | 31 | ~120 s | normal | taube, eiii, small, clii | 11 | 6–8 |
| S3 | 30 | ~120 s | normal | eiii, taube, small | 11 | 8 |
| S4 | 29 | ~120 s | **BONUS** | taube, eiii, clii, small | 11 | 8 (fans only) |
| S5 | 28 | ~120 s | normal | eiii, small, clii | 11 | 8–10 |
| S6 | 27 | ~120 s | normal | small, eiii, clii, red | 11–12 | 8–10 |
| S7 | 26 | **~150 s** | **BOSS 1 (major)** | small, clii, red, eiii | 10 + boss | 12–15 |
| S8 | 25 | ~120 s | **BONUS** | clii, red, small, green | 11 | 10 (fans only) |
| S9 | 24 | ~120 s | normal | rumpler, small, red, green | 12 | 10–12 |
| S10 | 23 | ~120 s | normal | rumpler, dva, green, red | 12 | 10–12 |
| S11 | 22 | ~120 s | normal | dva, pfalz, rumpler, green | 12 | 12 |
| S12 | 21 | ~120 s | **BONUS** | pfalz, dva, green, rumpler | 12 | 12 (fans only) |
| S13 | 20 | ~120 s | normal | rumpler, dva, pfalz, green | 12 | 12 |
| S14 | 19 | ~120 s | normal | dva, pfalz, green, red | 12 | 12–15 |
| S15 | 18 | **~150 s** | **BOSS 2 (major)** | pfalz, junkers, dva, green | 10 + boss | 15 |
| S16 | 17 | ~120 s | **BONUS** | junkers, pfalz, rumpler, green | 12 | 12 (fans only) |
| S17 | 16 | ~120 s | normal | dva, pfalz, junkers, riser | 12 | 12–15 |
| S18 | 15 | ~120 s | normal | pfalz, dva, rumpler, junkers | 12 | 15 |
| S19 | 14 | ~120 s | normal | junkers, pfalz, dva, rumpler | 12 | 15 |
| S20 | 13 | ~120 s | **BONUS** | pfalz, dva, green, rumpler | 12 | 15 (fans only) |
| S21 | 12 | ~120 s | normal | dvii, pfalz, dva, green; ace dri; Jasta 36 | 12–13 | 15 |
| S22 | 11 | ~120 s | normal | dvii, dri, pfalz, riser; ace dri; gotha | 12–13 | 15–18 |
| S23 | 10 | **~150 s** | **BOSS 3 (major)** | dvii, dri, pfalz; ace dri; Jasta 18 | 10 + boss | 15–18 |
| S24 | 09 | ~120 s | **BONUS** | dri, dvii, riser; ace dri; gotha; Jasta 11 | 12 | 15 (fans only) |
| S25 | 08 | ~120 s | normal | dvii, dri, pfalz, riser; ace dri; Jasta 15 | 13 | 15–18 |
| S26 | 07 | ~120 s | normal | dri, dvii, riser; ace dri; gotha; Jasta 11 | 13 | 18 |
| S27 | 06 | ~120 s | normal | dvii, dri, pfalz; ace dri; Jasta 27 | 13 | 18 |
| S28 | 05 | ~120 s | **BONUS** | dri, dvii, riser; ace dri; gotha | 13 | 18 (fans only) |
| S29 | 04 | ~120 s | normal | dvii, dri, pfalz, riser; ace dri; Jasta 11 + 36 | 13 | 18–20 |
| S30 | 03 | ~120 s | normal | dri, dvii, riser; ace dri; gotha; Jasta 11 | 13 | 18–20 |
| S31 | 02 | **~165 s** | **FINAL BOSS (major)** | dvii, dri, riser, pfalz; ace dri; Jasta 18 + 11 | 10 + boss | 20 |
| S32 | 01 | ~120 s | **BONUS · LAST** | dri, dvii, riser; ace dri; gotha; Jasta 11 + 15 | 12 | 18 (fans only) |

**Totals:** 32 sorties ≈ 64 minutes (28 × 120 s + 3 × 150 s + 1 × 165 s +
transitions inside those figures) — the same arc as the video (66:00 of play).
Per sortie: ~10–13 waves, 3–6 planes per wave (5–7 late), 1 heavy (riser/Gotha)
per sortie, 2 late; 1 Yashichi plane per sortie; 1 red 5- or 10-formation per
sortie with the clear-bonus.

### 9.4 The four major bosses (1942's bosses → 1918)

1942 has 4 bosses; 1918 has a boss every sortie by doctrine. **Keep the doctrine**,
but give the four play-order majors the full Ayako choreography (lull → bottom
entry → climb → hover-top strafe → fans → multi-fireball death → calm → carrier).
The other 28 sorties keep their roster boss with a shorter version of the same
entry (climb-and-hover, no lull required).

| 1918 sortie | 1942 boss | 1942 value | 1918 boss (roster) | Notes |
|---|---|---|---|---|
| S7 | Stage 26 | 20,000 | Albatros D.V · Jasta 21 (hp 74) | First major; top-entry variant is acceptable here (1942's boss 1 entered from the top) |
| S15 | Stage 18 | 30,000 | Fokker D.VII · Jasta 45 (hp 106) | Bottom-entry; "30000" score popup at death |
| S23 | Stage 10 | 40,000 | Zeppelin Dreadnought (hp 138) | Bottom-entry; the biggest entry in the run (~85% width) |
| S31 | Stage 02 (final) | 50,000 | Jasta Command · Final Wall (hp 170) | Bottom-entry; tan→green damage palette idea (§5.4); CONGRATULATION beat after death |

**Boss fight length in 1918:** 1942's bosses died in ~7–14 s against max firepower
because the player could sit under the hovering boss and hold fire. 1918's bosses
have far more HP (74–220 vs ~30 hits) and the player dies in one hit, so the same
choreography will run longer — budget **~20–40 s** per major boss (the pacing doc's
20 s boss budget is the floor, not the ceiling). The hover-top strafe is what makes
it survivable: the boss is *above* the player, firing down in fans the player can
dodge, while the player fires up into it. Do not make the boss chase the player
around the screen — the 1942 boss barely moves once it reaches the top.

### 9.5 Systems to mirror (and how)

- **Transition (highest value, cheapest):** replace the current debrief-only ending
  with the 1942 beat — boss dies → `SORTIE CLEAR` banner → tally on the aerodrome
  (`SHOOT DOWN NN%` / `BONUS` / `LOOPS LEFT ×1000`) → one-line launch card
  (`SORTIES LEFT: N` + sector + `READY`) → aerodrome takeoff (field scrolls away
  with the SPAD on it) → next waves. ~20 s total. This is the pacing doc's item 3
  and the single biggest feel win.
- **Tally:** shoot-down % per sortie (kills ÷ spawned) with 1942's exact bonus
  brackets (§7.1) + 1,000 per unused loop. Keep 1918's debrief flavor (date/locale)
  on the same screen — the tally is the score game, the debrief is the lore.
- **Loops:** 3 per sortie, +1 per yellow POW, 1,000 each unused at sortie end,
  reset each sortie. Verify the build's current loop stock/reset rules against this
  (not extracted this session).
- **POWs:** lettered drifting pickups (10–14 s on screen). Map: green → firepower,
  gray → wing (side fighters), white → blast (clear screen), yellow → +1 loop,
  red → 1,000 pts, orange → flak suppression (enemies can't shoot, timed — new),
  black → +1 life (new mechanic — or map to a bomb refill if no extra-life system
  is wanted). Yashichi: a lone Rumpler drifting up from a bottom corner; shooting
  it drops a 5,000 pickup.
- **Bonus sorties (S4, S8, S12, S16, S20, S24, S28, S32):** small planes do not
  shoot; only heavies (riser/Gotha) spray fans. Label them `( % AND POINT UP
  SORTIE )` on the launch card. Same wave counts, same formations — the *absence*
  of aimed fire is the breather, and the % bonus is the reward for clearing them.
- **Red formations:** 5-plane V / 10-plane column, 100 pts each, +500/+1,000 for
  clearing the whole formation, power marker drop on clear. One per sortie minimum.
- **Daihiryu heavy:** one Gotha/riser per sortie (two late), bottom-entry
  climb-and-hover with 5–7-shot fans, 2,000 base rising +500 per consecutive kill
  without dying (max 9,000), reset on death.
- **Pre-boss lull / post-boss calm:** ~10 s of near-empty sky before each major
  boss; ~6–10 s of empty sky after it dies, before the aerodrome arrives. Do not
  fill these with spawns — the silence is the design.
- **Finale:** after S31's final boss, the `CONGRATULATION / YOU ARE THE BEST OF
  PILOT ! / FIGHT LAST ONE SORTIE` beat over empty sky, then S32 as the bonus
  victory lap, then the 10,000,000 end bonus and a `WE GIVE UP!`-style armistice
  screen. See the open decision below.

### 9.6 Keep vs. change

**Keep (1942's shape, 1918's skin):** 32-sortie arc; ~120 s sorties; countdown
counter as `SORTIES LEFT: N`; carrier→aerodrome transition beat; tally with %
brackets + unused-loop bonus; POW drops; 3 loops per sortie; side fighters;
red 5/10 formations with clear-bonus; bottom-entry heavies; boss bottom-entry +
hover-top + fans; pre-boss lull and post-boss calm; bonus sorties every 4th;
10,000,000 finale bonus; shallow difficulty curve (density and fire frequency,
not new mechanics).

**Change (1918 doctrine / lore wins):** a boss at the end of **every** sortie
(1942: 4 in 32) — already decided; player dies in **one hit** (1942: 3 lives) —
already decided, and it makes 1942's modest bullet counts more than lethal enough;
**ground targets** (balloons, trains, batteries) stay — 1942 has none, but they
are 1918's flavor; keep them out of the air-wave budget so they don't inflate
density; **scoring values** stay 1918's (use 1942's *brackets and structure*, not
its point numbers); **terrain** stays the Western Front (sectors already in the
campaign data) instead of 1942's Pacific areas; **no score overflow** — the video
shows no overflow at 999,999, so don't copy the bug.

**Do NOT copy:** 1942's bullet *volume* is the ceiling, not the floor. 1942 peaks
at ~20 live enemy bullets. 1918's enemy-bullet cap (520) and fan patterns could
easily produce a bullet hell that 1942 never was. Tune spawn rates to the §9.3
peaks (6–8 early → 18–20 late), not to the cap.

### 9.7 Open decisions (for Steven — not decided here)

1. **Final-boss placement.** 1942 puts its final boss on the 31st-played stage
   (02) and makes the last stage (01) a bonus victory lap with no boss. 1918's
   doctrine puts the Crimson Ghost at S32. **Option A (doctrine):** Ghost at S32
   as the finale; S32 is a normal boss sortie, not a bonus. **Option B (faithful
   mirror):** the final-boss fight moves to S31 (Jasta Command · Final Wall
   becomes the Ghost's first form or the Ghost arrives a sortie early) and S32 is
   the bonus victory lap ending in the armistice screen. B matches the video's
   emotional shape (climax, then a calm last flight, then "we give up"); A keeps
   the current roster order.
2. **Extra life (black POW).** 1942 awards extra lives; 1918's one-hit doctrine
   has no life system in the file. Either add a spare-SPAD mechanic or map black
   POW to a bomb refill.
3. **Loop stock.** Verify the build's current loop stock/reset rules and align to
   3-per-sortie + yellow POW + 1,000-per-unused.
4. **Wave count.** `maxWaves` is 18 today; the 1942 mirror wants ~10–13 waves per
   ~100 s of combat. Lower it (or let `bossAfter` 95–105 s do the work and accept
   ~12–16 waves at the current cadence — the difference is small).

---

## 10. Could NOT verify (stated plainly — do not guess)

- **Full per-stage wave census.** Exact wave counts and compositions per stage
  cannot be counted from stills (15 s and 2 s samples show snapshots, not every
  wave). The per-stage numbers in §3/§9.3 are measured lengths + observed snapshot
  ranges, not a census.
- **The 30:18 top-right green bomber** (boss 2's first pass or a Daihiryu) — not
  resolvable at the sampled resolution.
- **The stage-02 boss tan→green palette shift** (63:46–63:58) — observed, mechanism
  unknown (damage-threshold swap, hit-flash state, or separate sprite).
- **Loop-stock arithmetic for stage 26.** The player visibly loops at 13:49.5, yet
  the stage-26 tally pays 3,000 for loops. The documented rule allows it via a
  banked yellow POW, but no such pickup is visible in the sampled frames.
- **Bottom-HUD lives/loop icons.** The video capture clips the bottom ~10 px; the
  small plane icons (lives) and red `R` (loop stock) are not legible. Only the
  tally line `R x1000= NNNN PTS` evidences the loop stock.
- **Most stage tallies.** Only 5 tallies were fully captured (stages 29, 28, 27,
  26, 18) and 3 partially (10: 92%; 02: +11,000 total; 01: 93%). The rest were not
  legible in the sampled frames.
- **Whether the player died.** No death/respawn was observed in any of the 270
  sampled frames, and side fighters + max firepower were held from ~12:45 to the
  end — consistent with a no-death run after the early stages. Deaths between
  samples cannot be ruled out.
- **The "6863" figure on the final tally** (66:15) — plausibly the total planes
  destroyed in the run; not confirmed.
- **"ANDERS 33"** in the ranking (67:00) — the "33" is unexplained (stage count?
  internal counter?). Recorded as shown.
- **Exact bullet peaks in the densest boss seconds.** Counts are from 2 s stills;
  a sub-second burst could hold a few more bullets than any single frame shows.
- **Stage 32's length (~105 s vs ~120 s).** The 15 s grid gives ±15 s; the first
  stage may simply be 120 s with the card caught early.
- **Bonus flags for stages 13, 09, 05 and the stage-16 "Leyte" card.** Inferred
  from the confirmed every-4th-stage rule (cards directly read for 29, 25, 21, 17,
  01) and the documented area blocks; those specific cards were not legible in this
  capture.
- **Enemy HP values** (~30 hits for the boss, ~12 for Daihiryu, ~6 for mid-size)
  are from the docs (GameFAQs/Fandom), not measured — the game shows no HP bars.
- **Yashichi spawn timing** per stage (roughly once per stage; 4 "5000" popups
  captured) — frequency not precisely measured.
- **No transcript exists** for this video (no captions/subtitles); all findings are
  from the frames and the cited docs.

---

## Sources & evidence

- Video: "1942 (Arcade) Playthrough", Longplay Center,
  https://www.youtube.com/watch?v=jl5WWgmvIQA — 1:07:23, 360p, downloaded
  2026-11-02. Local copy + frames: `1942-research/1942-playthrough.mp4`,
  `1942-research/frames/` (270 frames @ 15 s), `1942-research/dense/` (171 frames
  @ 2 s: boss1_s26, boss2_s18, boss3_s10, boss4_s02, trans_s29_s28, pow_s21),
  `1942-research/loop/` (13 frames @ 0.5 s, 13:47–13:53),
  `1942-research/sheets/` (14 contact sheets), `1942-research/dense_sheets/`.
- Docs: nineteenforty.fandom.com/wiki/1942 (scoring, POWs, bosses, stages);
  GameFAQs 1942 FAQ by Joshua Harring (enemies, boss, stage-end, carrier);
  en.namu.wiki/w/1942 (bonus stages, % bonus, stage/area table);
  mobygames.com/game/7949/1942 (stage flow, carrier landings).
- 1918 ground truth: `1918-ace-of-aces.html` (bossRoster, sortiePlans, WaveManager,
  spawnPower, SORTIE CLEAR), `docs/1942-pacing-reference.md`,
  `docs/roster-port-spec.md` — read 2026-11-02/03.
- Related prior work: the repo's `docs/1942-pacing-reference.md` (Oct 19, 2026)
  used a different playthrough (hirudov, Revision A, 1:07:41) and web sources only;
  this document is the first frame-by-frame analysis, on the Longplay Center run.
  Its pacing math (~127 s/stage, ~120 s sortie budget) is confirmed by this video.
