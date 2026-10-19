# AdMob: Swapping TEST IDs for Real IDs

Right now the app uses **Google's official TEST ad unit IDs**. Test ads always
show. Real ads (that pay you) need your own IDs from your AdMob account.

## Step 1 — Create your AdMob App ID

1. Go to https://apps.admob.com and sign in.
2. Click **Apps** in the left sidebar, then **Add app**.
3. Select **iOS**, enter app name `1918`.
4. AdMob gives you an **App ID** that looks like `ca-app-pub-1234567890~1234567890`.
5. Open `native/ios/App/App/Info.plist`, find this line:
   `<string>ca-app-pub-3940256099942544~1458002511</string>`
   Replace it with YOUR App ID. (Keep the `~` format — App IDs use `~`.)

## Step 2 — Create the two ad units

In your AdMob app page:

1. Click **Ad units**, then **Add ad unit**.
2. Create an **Interstitial** ad unit. Name it `1918 Interstitial`.
   Copy its ID — looks like `ca-app-pub-1234567890/1234567890`. (Ad unit IDs use `/`.)
3. Create a **Rewarded** ad unit. Name it `1918 Rewarded Continue`.
   Copy its ID.

## Step 3 — Paste them into the bridge

Open `native/src/bridge.ts`, find these two lines near the top:

```ts
const INTERSTITIAL_AD_ID = 'ca-app-pub-3940256099942544/4411468910'; // TEST
const REWARDED_AD_ID = 'ca-app-pub-3940256099942544/1712485313'; // TEST
```

Replace with your real IDs. Then rebuild the bridge:

```bash
cd ~/workspace/1918-ace-of-aces/native
npx esbuild src/bridge.ts --bundle --format=iife --outfile=www/bridge.js --minify
npx cap sync ios
```

## Step 4 — Turn off test mode

In the same file, find:

```ts
await AdMob.initialize({
  initializeForTesting: true, // TEST MODE — remove when real IDs go live
});
```

Change `initializeForTesting: true` to `initializeForTesting: false`
(or delete the line). Rebuild + re-sync as above.

## Honest-placement rules (baked into bridge.ts — don't weaken)

- Interstitials fire ONLY on the game's retry/briefing path (between sorties),
  never mid-combat, never on the title screen. Frequency-capped: max 1 per
  90 seconds.
- Rewarded ads are always opt-in — the player taps "Continue" first.
- Buying Remove Ads ($2.99 IAP) permanently disables every ad call.
