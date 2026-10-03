# 1918 Test Plan

Automated checks run every night via `QA/run-nightly.sh`, which writes a
dated report to `QA/reports/YYYY-MM-DD.md`. Manual checks are run by a human
after each nightly passes.

## Automated (run-nightly.sh)

### Godot build (project: `~/workspace/1918-godot`, binary: `~/workspace/godot/`)
- [ ] **Import clean** — headless `--import` completes; zero script errors in output.
- [ ] **30s smoke** — headless `-- --autostart` runs 1800 frames (~30s) with an
      invincible auto-firing player; zero script errors.
- [ ] **Boss-rush loop** — headless `-- --autostart --autoboss` runs 3600 frames;
      boss 0 spawns at 8x damage; zero script errors.

### Web build (`1918-ace-of-aces.html`)
- [ ] **Photo-frame keyframes** — the `artifactFlyIn` keyframes contain no
      `transform:none` in the `to` state (regression guard for bug 001).
- [ ] **Intro-play removal timeout** — the `intro-play` class removal timeout
      is >= 1000ms (regression guard for bug 001).
- [ ] **Version sync** — the `VERSION` file, the splash `ver-badge` span, and the
      `const VERSION` in both `scripts/global.gd` copies all agree.

## Manual — web build
- [ ] Page loads with no console errors.
- [ ] Splash -> flight desk flow works; "Open flight desk" button responds.
- [ ] The four framed flight-desk photos hold their tilted rest angles after
      the intro (bug 001 verify).
- [ ] WASD flight, Q loop-de-loop, X bomb, ESC pause menu all respond.
- [ ] Death -> debrief -> retry works; game never hard-freezes.

## Manual — Godot build
- [ ] Title screen shows the current version (v-label under the tagline).
- [ ] Sortie 1 starts and runs 60 seconds without script errors.
- [ ] Boss 1 duel: three phases trigger, ENRAGE below 15% HP.
- [ ] Minimap icons animate; objective markers pulse.
- [ ] Takeoff reel plays (~7s, skippable); landing reel plays on victory only.
