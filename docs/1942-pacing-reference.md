# 1942 pacing reference — 32-sortie build

Steven's directive (chat 2026-10-19 ~18:42–18:43 UTC): make enemy waves like the
arcade 1942 playthrough; full run of all 32 sorties + bosses in about an hour;
cut the reading-heavy mission briefings; 1942-style "sortie clear, back in the
air" transitions between sorties.

## Anchor video

"1942 [Arcade Longplay] (1984) Capcom {Revision A}" — hirudov (511K subs),
published Sep 1, 2025. **Total duration: 1:07:41.** No chapters, no transcript
available; description only confirms it's a full arcade Revision A playthrough.
His "about an hour" was dead on.

## The pacing math

- 1:07:41 = 4,061s ÷ 32 stages = **~127 seconds per stage** (waves + boss +
  transition, with NO breaks — 1942 scrolls continuously)
- Design budget per 1918 sortie: **~120s** → ~90s of waves, ~20s boss, ~10s
  carrier transition (clear banner → launch card → takeoff)
- 32 × 120s = 3,840s = **64 minutes** ≈ the anchor video's 1:07:41. This is
  the number the wave/boss tuning should be built against.

## 1942 wave structure (web-verified, checked 2026-10-19)

- **Continuous scrolling, no level breaks.** The only transition is a banner
  showing stages remaining, counted DOWN from 32 to 1. (Nintendo Life review;
  MobyGames)
- **Formations, not conga lines.** Small groups of fodder planes fly in
  formation (V-shapes, columns), then kamikaze-dive at you; waves never stop,
  they spawn continuously throughout the stage. (GameFAQs 1942 FAQ)
- **Enemy roster:** gray fodder planes (fly at you, half-loop back, bullet
  frequency rises per stage); green planes (wide circles, can re-enter the
  screen); larger planes that swing in from BEHIND (bottom edge); big bombers
  with spread bullets. (GameFAQs 1942 FAQ)
- **Boss:** screen-filling giant bomber spraying bullets, roughly every 6
  stages in the NES port. 1918's standing doctrine (a boss at the end of EVERY
  sortie, S1 25 hits → S32 Crimson Ghost 500 hits) is denser than 1942 — that's
  his call, already made 2026-10-05; keep it.
- **Difficulty curve:** shallow. Later stages mostly mean more frequent bullets
  and more simultaneous planes, not new mechanics. One reviewer cleared in
  "maybe an hour" (GameFAQs X1 review); another puts a full 32-round run at "an
  hour or two" (GameFAQs PC88 review).
- **Scoring hooks:** 10,000,000-point bonus for clearing the game; 1,000 points
  per unused evasive roll at each stage end (96,000 total possible). (retroxp
  spotlight)

## What "like the playthrough" means for the build

1. **Spread formations only.** Single-file echelon lines are already killed
   (b386f44). Use 3–5 plane V or staggered columns entering from top-left /
   top-right edges, some breaking into dives — the 1942 look.
2. **Continuous pressure, ~90s per sortie.** New formation every ~8–10s; every
   3rd wave a heavy element (big bomber from behind / ace flight). Bullet
   frequency scales with sortie number (1942's "bullets with increasing
   frequency depending on the stage").
3. **Inter-sortie flow (his "too much reading" fix):** boss dies → SORTIE CLEAR
   banner → one-line launch card ("S14 — Somme sector. Hostiles inbound.") →
   carrier-deck takeoff (2–3s) → next waves. No briefing walls.
4. **Stage counter:** mirror 1942's remaining-stages banner as
   "SORTIES LEFT: 18" at each launch — cheap, authentic, and tracks the
   one-hour arc.
5. **Bomb economy (optional scoring hook):** mirror 1942's unused-roll bonus —
   end-of-sortie points per unused bomb. Rewards the survival-over-panic play
   his one-hit doctrine demands.

## Caveats

- The video was not watched frame-by-frame (no transcript exists); wave cadence
  above is from documented 1942 structure, not a timestamped analysis of
  hirudov's run.
- "Boss every 6 stages" is sourced from the NES-port review; the arcade
  Revision A boss cadence was not verified. Doesn't matter for the build —
  his doctrine has a boss per sortie regardless.
