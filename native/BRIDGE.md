# Game ↔ Native Bridge Contract

The web game (`www/index.html`) was already written with a monetization
contract. The native shell (`www/bridge.js`, built from `src/bridge.ts`)
fulfills it. Neither side may change the contract without updating both.

## Native → Game: `window.GameBridge`

`bridge.js` sets `window.GameBridge` at boot and dispatches
`gamebridge:ready` on `window` (the game re-renders its store UI on it).

| Method | Returns | Game behavior |
|---|---|---|
| `isAdsRemoved()` | `Promise<boolean>` | Game sets `monetization.adsRemoved`; hides ad UI |
| `showInterstitial()` | `Promise<boolean>` — `true` = ad showed | Called on the retry/briefing path (`requestInterstitial()`) |
| `showRewardedAd()` | `Promise<boolean>` — `true` = **reward earned** | "Continue" button → `resumeAfterReward()` only on `true` |
| `buyRemoveAds()` | `Promise<boolean>` | "Remove ads · $2.99" button in the Hangar store |
| `restorePurchases()` | `Promise<boolean>` | "Restore purchases" button (App Store review requires this) |
| `trackEvent(name, params)` | `Promise<void>` | **Reserved for a future game build** — the game can log analytics events it can see (e.g. `sortie_start`, `sortie_complete`) through the native shell. Unused by the current game build. |

## Google Analytics (Firebase) — what the shell logs today

Standard events only, **no PII, no user IDs, no ad-ID collection**. Events the
bridge can observe without game-code changes:

| Event | When | Params |
|---|---|---|
| `shell_boot` | bridge starts in the native shell | — |
| `ad_shown` | an interstitial or rewarded ad actually displayed | `format: interstitial\|rewarded` |
| `reward_earned` | rewarded ad watched to completion | — |
| `remove_ads_purchased` | the $2.99 unlock completed | `price_usd: 2.99` |

`app_open` is collected automatically by Firebase — the shell never logs it by
hand. The native side stays silent until Steven drops his own
`GoogleService-Info.plist` into the app (see `ANALYTICS_SETUP.md`); if the
plist is absent, Firebase never configures and the app behaves exactly as
before — **it cannot crash for this reason** (guarded `FirebaseApp.configure()`).

If the game runs in a plain browser (no native shell), `window.GameBridge`
is undefined and the game's `bridgeCall()` wrapper resolves
`{available:false}` — the store UI shows "Web preview · Ads disabled until
a native shell connects". Nothing breaks.

## Game → Native: what the game already does

- `requestInterstitial()` → `bridgeCall('showInterstitial')` (retry path only)
- `#rewardContinue` button → `bridgeCall('showRewardedAd')` → on `true`,
  `resumeAfterReward()` revives the player (2 HP, fuel top-up, bullets cleared,
  once per sortie via `monetization.continueUsed`)
- `syncAdsState()` → `bridgeCall('isAdsRemoved')` → updates store UI
- `#removeAds` button (added in this bundle) → `bridgeCall('buyRemoveAds')`
- `#restorePurchases` button (added in this bundle) → `bridgeCall('restorePurchases')`

## Rebuilding the bridge

```bash
# In Terminal: type cd, press Space, drag your unzipped 'native' folder
# from Finder into the window, press Enter — then run:
npx esbuild src/bridge.ts --bundle --format=iife --outfile=www/bridge.js --minify
npx cap sync ios
```

Always re-sync after rebuilding — `cap sync` copies `www/` into the Xcode
project.
