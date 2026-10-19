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
cd ~/workspace/1918-ace-of-aces/native
npx esbuild src/bridge.ts --bundle --format=iife --outfile=www/bridge.js --minify
npx cap sync ios
```

Always re-sync after rebuilding — `cap sync` copies `www/` into the Xcode
project.
