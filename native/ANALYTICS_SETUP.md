# Google Analytics Setup — Free Dashboard for 1918, One Step at a Time

The app's analytics wiring is **already built** — the native shell logs
standard events (app starts, ads shown, the $2.99 unlock) with **no personal
data, no user IDs, no ad IDs**. These steps connect it to YOUR Google
Analytics dashboard so you can see real player numbers. Do them in order.
If any screen looks different, STOP and send me a screenshot — don't guess.

**What the shell logs** (nothing else is collected):

| Event | Meaning |
|---|---|
| `shell_boot` | App opened (in addition to Firebase's automatic `app_open`) |
| `ad_shown` | An interstitial or rewarded ad was displayed |
| `reward_earned` | A rewarded ad was watched to the end |
| `remove_ads_purchased` | The $2.99 one-time unlock completed |

**What you'll end up with:** a `GoogleService-Info.plist` file dropped into
your Xcode project. Without it, analytics simply stays off — **the app
cannot crash for lack of it** (the Firebase init is guarded; see
"Maintenance note" at the bottom).

---

## PART 1 — Create the Firebase project

**Step 1.** Go to https://console.firebase.google.com and sign in with
your Google account.

**Step 2.** Click **Create a project** (or **Add project**).

**Step 3.** Project name: type `1918`. Click **Continue**.

**Step 4.** It asks about Google Analytics. Leave it **enabled** (that's the
whole point of this guide) and click **Continue**, then **Create project**.

**Step 5.** Wait for the "Your new project is ready" screen, then click
**Continue**.

## PART 2 — Add your iOS app to the project

**Step 6.** On the project overview page, click **+ Add app** (or the
**iOS** icon `</>`-style button next to iOS).

**Step 7.** **Apple bundle ID** — type exactly:

```
com.luckyclover.aceofaces
```

One wrong letter and analytics silently goes nowhere. Nickname: `1918`
(optional). Click **Register app**.

**Step 8.** Firebase shows **Download GoogleService-Info.plist** — click it
and save the file somewhere you can find (Downloads is fine).

**Step 9.** **Skip** the SDK-installation steps on the page (the Firebase SDK
is already installed in the project via CocoaPods) — just click through to
**Continue to the console**.

## PART 3 — Put the file in Xcode

**Step 10.** Open the project in Xcode: double-click
`native/ios/App/App.xcworkspace` (the workspace, not the blue project file).

**Step 11.** In Xcode's left sidebar (Project Navigator), right-click the
top-level **App** folder (the one with `AppDelegate.swift` in it) and
choose **Add Files to "App"…**.

**Step 12.** Select the **GoogleService-Info.plist** you downloaded.
Check **Copy items if needed** and make sure the **App** target box is
checked. Click **Add**.

**Step 13.** The next time you Archive (SUBMIT.md Part 4), analytics starts
reporting. You do **not** need to rebuild `bridge.js` or re-run `cap sync`
for this step — the file rides inside the Xcode target.

## PART 4 — See your data

**Step 14.** In the Firebase console, click **Analytics** (left sidebar) →
**Dashboard**. New installs and events appear in **Realtime** within
minutes; full reports take up to 24 hours to populate.

**Step 15.** For the full Google Analytics experience, go to
https://analytics.google.com — your `1918` property is there with the same
events.

## Honest notes (read these)

- **No personal data, ever.** The shell never logs user IDs, emails,
  device identifiers, locations, or anything you could tie to a person.
  Just counts of events. Apple's **App Privacy** questionnaire (SUBMIT.md
  Step 20b): answer it as Analytics collecting usage data, **not** linked to
  the user, **not** used for tracking.
- **No plist = no analytics, no crash.** Until your
  GoogleService-Info.plist is in the target, Firebase never initializes.
  Everything else (ads, purchases, the game) works exactly the same.
- **Maintenance note (Mac-side, rare):** the Firebase plugin's native init
  was patched on this machine so a missing plist can't crash the app:
  `node_modules/@capacitor-firebase/analytics/ios/Plugin/FirebaseAnalytics.swift`
  only calls `FirebaseApp.configure()` when the plist exists. If you ever
  run a fresh `npm install` on this project, re-apply that one change —
  the patch is documented here in this file, and `cap sync` never touches
  `node_modules`, so normal syncs are safe.
