# 1918 — Handover Notes (2026-11-08, from Muse / Sailor Ron)

For whoever picks this project up. Everything below is verified state, not intention.

## Where things stand

- **Current build: v77, commit `0fa379e`**, pushed to BOTH GitHub repos (they must stay in sync — push to both, every time):
  - `the-lucky-clover/1918-ace-of-aces` (remote `origin`)
  - `the-lucky-clover/1918-final` (remote `final`) — Steven ruled this one canonical.
- The `v1.0` git tag still points at an old v61-era commit (`1d4d0ff`). Move it only when Steven confirms which build is the submission build.
- **Browser build** (Muse artifact "1918"): updated to v77. Its public link still serves an older approved version; it updates only when Steven explicitly asks to share again.
- **App Store Connect: everything is done except the build.** App "1918 WW1", App ID 6832082093, SKU `1918`, bundle `com.stevenpounds.1918`. Metadata, description, keywords, screenshots (1206×2622), age rating (13+ global calc), App Privacy (5 data types, AdMob only), App Review notes, category (Games → Action / Entertainment), pricing (Free, all territories) — all saved. Agreements, tax (W-9), and banking all Active. **One check remains: confirm the subtitle "Vertical Scrolling Shooter" actually saved** on the App Information page.
- Release option is set to **automatic release on approval** (Steven's choice).

## What remains, in order

1. Steven pulls, runs `npx cap sync ios` **from inside `native/`** (from the repo root it fails — known npm quirk), rebuilds in Xcode, playtests v77 on his iPhone.
2. Product → Archive (workspace `native/ios/App/App.xcworkspace` — never the .xcodeproj), upload, select the build in App Store Connect, verify the subtitle, Submit for Review.
3. **v1.1 on Nov 12, 2026**: resubmit with AdMob ON — ads only for downloads after the free window; day-one players never see ads (see locked rules).
4. Post-launch: re-register the AdMob app under bundle `com.stevenpounds.1918` (it's still under the old bundle ID). Apple Developer Program renews Nov 25, 2026.

## Locked rules — do not backtrack these (Steven's standing orders)

- **Photorealism only.** Every asset raster/photographic, top-down. No vector art, no code-drawn terrain, ever. Photographs are the base; procedural work is for variation only (a procedural terrain pass was reverted on sight — don't redo it).
- **Backgrounds**: 32 bespoke photographic plates, one per sortie (`assets/sprites/bg/sortie-01..32.jpg`, 1024×3072, extended with their own mirrored ground — never stretched). All 32 verified top-down.
- **Survival is the fuel gauge** (1943 model): drains in flight, a hit tears out fuel, refills at the aerodrome between sorties. Wingmen die in one hit and buffer the pilot.
- **Ground sprites do not attack** (fixed v77 — AA/railway/artillery/trench fire removed). **The red POW formation does not fire** — it's a bonus. **Shadows never exceed the plane's size.** Black smoke uses the soft-edge sheet at `assets/sprites/v34/v34-smoke.png`.
- **Departure run** (v77): aerodrome (feathered edges) → base perimeter/checkpoint → chateaus/vineyards → trench battlefield, photographic dissolves, no gradients.
- **Money model**: v1.0 free with NO ads from release through **Nov 12, 2026**. Copies acquired in the window are flagged (`localStorage '1918-day-one'`) and **never get ads, ever**. Co-op **never** has ads, for anyone. The $2.99 Remove Ads IAP is **CANCELLED — do not create it**. Bonus content (Sortie 33, P-38, secrets) sits behind an entitlement gate that ships **open** at launch; a free-acquired copy is entitled forever.
- **Badge rule** (browser artifact): no version badge on the splash; the version badge lives only on the 1P/2P select screen.
- Co-op is device-to-device only (local Wi-Fi/Bluetooth). No remote co-op.

## How the build works

- One game file, **three copies** that must stay identical except the version badge: `1918-ace-of-aces.html` (badge = dev version), `native/www/index.html` and `native/ios/App/App/public/index.html` (badge "v1"). The Capacitor wrapper wraps THIS game — not the Godot project (Godot web export black-screened on iPhone; the `godot/` folder is legacy).
- Version = `VERSION` file + badge + a `CHANGELOG.md` entry (pirate speak — repo bookkeeping only, never in game text). Bump manually; the bump script touches Godot constants, don't use it.
- `git add` aborts on ignored paths in this repo — add files one at a time with `git add -f -A -- <path>`, commit only explicit paths (the working tree carries unrelated build noise; never commit it).
- **QA**: `node QA/v61-playtest.js` is the only faithful test instrument, plus `node --check` on the extracted inline script after every edit. **One check is permanently red by design**: "every sortie killed its boss" fails on zeppelin sorties (S3/S8/S18/S23/S28, run-dependent) because the sim finishes those sorties with the ship crippled/driven off rather than sunk. That is a legitimate outcome and a design question for Steven — **do not silently edit the game to make it pass.**
- Known unresolved drift (Steven's call, don't fix uninvited): boss HP doctrine says S1 25 → S32 500; the code roster runs S1 50 → S32 220 × difficulty profile.
- The QA harness stubs the canvas — **it cannot see visuals. Steven's phone screenshots are the only visual QA that counts.** Verify every asset by viewing it before wiring it in (mislabeled assets have bitten this project twice).

## Working with Steven

- One step at a time, plain English first, exact values, real links. Never give an instruction you haven't verified exists — he has been burned by invented steps.
- Don't add anything he didn't ask for. When he gives a fix list, fix exactly that list.
- His terse verdicts are the full review. When he says "revert," revert immediately and say plainly what was restored.
- He playtests everything himself; his screenshot outranks any automated result.

Good luck. It's a good game — 32 sorties over the Western Front, and it deserves its Armistice Day launch.
