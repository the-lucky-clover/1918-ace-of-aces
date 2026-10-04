# 1918 — Ads & Remove-Ads Setup (Steven's moves)

The game ships with **TEST MODE on**: every ad is one of Google's official test
units, and the $2.99 purchase is simulated (the pause-menu button says
`REMOVE ADS — $2.99 (TEST)`). Nothing can charge you or earn revenue in this
state. When you're ready to go live, work this list top to bottom.

## 1. AdMob account + app IDs (your moves)

1. Create an account at <https://apps.admob.com>.
2. Register the app (one for Android, one for iOS). AdMob gives you an **App ID**
   for each — it looks like `ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY`
   (note the **~**).
3. In AdMob, create two ad units per platform: **Interstitial** and **Rewarded**.
   Each gives you an **Ad Unit ID** like `ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY`
   (note the **/**).

## 2. Swap the test IDs for real ones (one file)

Open `godot/scripts/ads_config.gd` and:

1. Set `TEST_MODE` to `false`.
2. Replace the six `*_APP_ID` / `*_INTERSTITIAL_ID` / `*_REWARDED_ID` values
   with your real ones from step 1.

The nightly QA check `gdscript-ads-no-real-ids` will fail the build if a
real-looking ad unit ID is committed while `TEST_MODE` is still on — flip the
flag first, then commit the IDs.

## 3. Install the AdMob plugin (Godot editor)

1. In the editor: **AssetLib** tab → search `AdMob` by **Poing Studios** →
   Download → Install.
2. **Project → Project Settings → Plugins** → enable **AdMob**.
3. **Project → Tools → AdMob Manager → Android → Download & Install**
   (same for iOS). Libraries land in `res://addons/admob/`.
4. The game's `scripts/ads.gd` facade detects the plugin automatically
   (it looks for `res://addons/admob`) and starts calling the real SDK —
   no game-code changes needed.

Reference: <https://poingstudios.github.io/godot-admob-plugin/latest/>

## 4. Wire the App IDs into the exports

- **Android**: install the Android build template
  (**Project → Install Android Build Template**), then in
  **Project → Project Settings → AdMob → General → Android** check Enabled
  and paste your real App ID. Export with **Use Gradle Build**.
- **iOS**: same screen, **iOS** section, paste the iOS App ID. The plugin's
  iOS export plugin handles the Xcode side.

## 5. The $2.99 remove-ads product (your moves)

1. **Google Play Console**: create a one-time (non-consumable) product with
   product ID exactly `1918_remove_ads`, price $2.99.
2. **App Store Connect**: create the matching non-consumable IAP
   (`1918_remove_ads`, $2.99 tier).
3. Install the **GodotGooglePlayBilling** plugin
   (<https://github.com/godot-sdk-integrations/godot-google-play-billing>)
   via AssetLib for Android; pick a StoreKit plugin for iOS.
4. With `TEST_MODE` off, the hooks `_billing_purchase_remove_ads`,
   `_billing_restore` (Android) and `_storekit_purchase_remove_ads` (iOS) in
   `godot/scripts/iaps.gd` are clearly marked — implement them against your
   installed plugin version's docs (method names vary by version, so they're
   intentionally not guessed).

## 6. Sanity checklist before release

- [ ] `TEST_MODE = false` in `ads_config.gd`
- [ ] Real App IDs in the Android manifest / iOS Info.plist (via the plugin UI)
- [ ] Real ad unit IDs in `ads_config.gd`
- [ ] `1918_remove_ads` product live in Play Console + App Store Connect
- [ ] Billing hooks implemented in `iaps.gd`
- [ ] Test on a real device: watch a rewarded revive, buy remove-ads,
      confirm zero ads afterwards, restore purchases on a second device
- [ ] Nightly QA green (`QA/run-nightly.sh`)

## What the game does with ads (already wired)

- **Rewarded (opt-in only):** death debrief offers `✚ FLY AGAIN — WATCH AD`
  → grants a mid-sortie revive at 60% hull. Never forced, never mid-action.
- **Interstitial:** only after a *victorious* debrief, before the next sortie —
  never mid-sortie, never on the first sortie ever, max 3 per session,
  180s cooldown between them.
- **Remove-ads:** pause-menu button. When owned, the game requests and shows
  zero ads, period. State persists in `user://1918.cfg`.
