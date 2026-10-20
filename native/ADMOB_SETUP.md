# AdMob Setup — Real Ads for 1918, One Step at a Time

Right now the app shows **Google's test ads** (they pay nothing). These steps
swap them for your real, money-earning IDs. Do them in order. One step, then
the next. If any screen looks different, STOP and send me a screenshot —
don't guess.

**What you'll end up with:** 3 IDs from Google —
an **App ID** (`ca-app-pub-…~…`, with a `~`), and two **ad unit IDs**
(`ca-app-pub-…/…`, with a `/`).

**Sources for these steps:** Google's official AdMob help pages
(support.google.com/admob) — the app-add and ad-unit flows were verified
there on 2026-10-19.

---

## PART 1 — Sign up for AdMob

**Step 1.** Go to https://apps.admob.com and sign in with your Google
account. If you don't have an AdMob account, click **Sign up**, accept the
terms, and finish the signup wizard. It will ask for your **country** and
**currency** — you cannot change the currency later, so pick the one you
want to be paid in.

**Step 2.** If AdMob asks you to create a payments profile, do it — you
can't get paid without one. (Later, once you earn enough, Google also asks
you to verify your identity and address before your first payout.)

## PART 2 — Add your app (unpublished — it's not on the store yet)

**Step 3.** On the AdMob home page, click **Apps** in the left sidebar.

**Step 4.** Click **Add app**.

**Step 5.** It asks *"Is your app listed on a supported app store?"* —
choose **No** (1918 isn't published yet). You'll link it to the App Store
later in Part 6.

**Step 6.** Choose **iOS** as the platform.

**Step 7.** In the app-name box, type `1918`.

**Step 8.** Confirm **Enable user metrics for this app**, then click
**Add app**.

**Step 9.** AdMob shows your **App ID** — it looks like
`ca-app-pub-1234567890~1234567890` (note the **`~`**). Copy it.

**Step 10.** On your Mac, open the unzipped `native` folder, then
`ios` → `App` → `App`, and open **Info.plist** in Xcode (double-click it).
Find this line:

```xml
<string>ca-app-pub-3940256099942544~1458002511</string>
```

Replace just that ID with YOUR App ID (keep the `~` format). Save the file.

## PART 3 — Create the Interstitial ad unit (between-sortie ad)

**Step 11.** In AdMob, go back to **Apps** in the sidebar and click your
**1918** app.

**Step 12.** Click **Ad units** in the left sidebar (under your app).

**Step 13.** Click **Get started** (first time) or **Add ad unit**.

**Step 14.** Click **Select** on the **Interstitial** format card.

**Step 15.** Name it `1918 Interstitial` and click **Create ad unit**.

**Step 16.** Copy the **ad unit ID** it shows — it looks like
`ca-app-pub-1234567890/1234567890` (note the **`/`**). Paste it somewhere
safe (a note on your Mac) for Part 5.

## PART 4 — Create the Rewarded ad unit (continue-after-death ad)

**Step 17.** Still in **Ad units**, click **Add ad unit** again.

**Step 18.** Click **Select** on the **Rewarded** format card.

**Step 19.** Name it `1918 Rewarded Continue`.

**Step 20.** Fill in the reward settings (AdMob requires these — they
describe the reward on the ad network side; the game's actual revive works
the same either way):
- **Reward amount:** `1`
- **Reward item:** `Continue`

**Step 21.** Click **Create ad unit** and copy this **ad unit ID** too.

## PART 5 — Put your real IDs in the project

**Step 22.** Open `native/src/bridge.ts` in a text editor. Near the top,
find these two lines:

```ts
const INTERSTITIAL_AD_ID = 'ca-app-pub-3940256099942544/4411468910'; // TEST
const REWARDED_AD_ID = 'ca-app-pub-3940256099942544/1712485313'; // TEST
```

Replace the IDs with your two real ad unit IDs (keep the single quotes).
Save the file.

**Step 23.** In the same file, find:

```ts
await AdMob.initialize({
  initializeForTesting: true, // TEST MODE — remove when real IDs go live
});
```

Change `true` to `false` (or delete the `initializeForTesting` line).
Save the file.

**Step 24.** Rebuild the bridge. Open **Terminal**, type `cd`, press the
Space bar, drag the `native` folder from Finder into the window, press
Enter, then paste these two lines:

```bash
npx esbuild src/bridge.ts --bundle --format=iife --outfile=www/bridge.js --minify
npx cap sync ios
```

**Step 25.** That's it for now — AdMob goes live in the build. **But read
the honest note at the bottom of this file first.**

## PART 6 — After 1918 hits the App Store

**Step 26.** Back in AdMob: **Apps** → click **1918** → **App settings** →
**App store** → add the **App Store listing** (search `1918`, select it).
Google then runs an **app readiness review** — usually 2–3 days. Until it
passes, ad serving is limited. You'll get an email when it's done.

## Honest notes (read these)

- **Test ads pay zero.** Until your real IDs are in and the readiness review
  passes, every "ad" is a test ad. That's by design — test first, earn later.
- **One-time unlock only.** Buying **Remove Ads ($2.99)** kills every ad
  forever. There is no subscription anywhere in this app.
- **Ad placement rules (baked in, don't change):** interstitials fire only
  between sorties (max 1 per 90 seconds), never mid-combat, never on the
  title screen. Rewarded ads are always opt-in — the player taps Continue
  first.
- **Tracking permission:** the app asks "Allow tracking?" on first launch
  (that's Apple law for ads). The message is in Info.plist: *"1918 uses ads
  to stay free."* The game plays identically either way.
