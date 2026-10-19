# 1918 — Native iOS + Mac (Catalyst) App

Capacitor wrapper around the 1918 web game. Bundle ID `com.luckyclover.aceofaces`.

## What's here

| Path | What |
|---|---|
| `www/` | The game bundle (`index.html` + `assets/`) + `bridge.js` (monetization) |
| `src/bridge.ts` | TypeScript source for `bridge.js` — AdMob + IAP |
| `ios/` | Xcode project (open `App/App.xcworkspace`, never the `.xcodeproj`) |
| `capacitor.config.ts` | App ID `com.luckyclover.aceofaces`, name `1918` |
| `ADMOB_IDS.md` | Where to paste real AdMob IDs (TEST IDs live now) |
| `BRIDGE.md` | Game ↔ native contract |
| `SUBMIT.md` | Baby-steps: Xcode → App Store Connect → review |

## Monetization (honest rules, baked in)

- **Free download.** Interstitial ads between sorties only (never mid-combat,
  never title screen), max 1 per 90 seconds.
- **Rewarded ad** = one "continue after death" per sortie, always opt-in.
- **$2.99 Remove Ads** (non-consumable `com.luckyclover.aceofaces.removeads`)
  kills all ads forever. Restore Purchases included (App Store requires it).

## Rebuild after changing src/ or www/

```bash
cd ~/workspace/1918-ace-of-aces/native
npx esbuild src/bridge.ts --bundle --format=iife --outfile=www/bridge.js --minify
npx cap sync ios
```

## Status / honesty notes

- Built and synced on Linux; **never compiled** (no Xcode here). First real
  compile happens on Steven's Mac — see SUBMIT.md.
- AdMob runs on Google TEST IDs until he pastes real ones (ADMOB_IDS.md).
- IAP product must be created in App Store Connect (SUBMIT.md Part 5) or the
  $2.99 button can't complete a purchase.
- The bundled `www/` is a snapshot of the staged web build (2026-10-19).
  Re-copy from a newer staged build to update the game inside the app.
