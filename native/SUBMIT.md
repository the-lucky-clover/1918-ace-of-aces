# 1918 — App Store Submission, One Step at a Time

Do these in order. One step, then the next. If any step looks different on
your Mac, STOP and send me a screenshot of what you see — don't guess.

Your bundle ID everywhere: `com.luckyclover.aceofaces`
Your IAP product ID: `com.luckyclover.aceofaces.removeads` ($2.99, one-time
purchase, non-consumable — **not** a subscription)

---

## PART 1 — Open the project in Xcode (your Mac)

**Step 1.** Install Xcode from the Mac App Store if you don't have it. It's free, but it's huge — let it finish.

**Step 2.** In Finder, open the `native` folder you just unzipped
(it's probably in Downloads), then open `ios` → `App`,
and double-click **`App.xcworkspace`** (white icon).
⚠️ Open the `.xcworkspace`, NOT the `.xcodeproj` (blue icon). The workspace
includes the ad and purchase libraries; the plain project won't build.

**Step 3.** In Xcode's menu bar: **Xcode → Settings → Accounts**.
Click **+** (bottom left), choose **Apple ID**, sign in with the Apple ID
on your Developer account.

**Step 4.** In Xcode's left sidebar (Project Navigator), click **App** at the
very top (blue icon). In the middle pane, click the **App** target, then the
**Signing & Capabilities** tab at the top.

**Step 5.** Check the box **Automatically manage signing**.
In the **Team** dropdown, choose your team (your name).

**Step 6.** Confirm the **Bundle Identifier** field reads
`com.luckyclover.aceofaces`. If it doesn't, type it in exactly.

**Step 6b.** The ad libraries install via CocoaPods — do this once in Terminal:
open **Terminal** (in Applications → Utilities). Type `cd`, press the Space bar,
then drag the `App` folder (the one holding `App.xcworkspace`) from Finder
into the Terminal window, and press Enter. Then paste this line and press Enter:

```bash
pod install
```

(If it says `command not found: pod`, first run `sudo gem install cocoapods`,
type your Mac password, then run the line above again.) When it finishes,
quit Xcode completely and re-open `App.xcworkspace` from Step 2.

## PART 2 — Add Mac as a destination (for the Mac App Store)

**Step 7.** Still on the App target, click the **General** tab at the top.
Find the **Supported Destinations** section. Click the **+** button under it
and choose **Mac**. (This turns on Mac Catalyst — one binary, both stores.)

## PART 3 — Connect ads + analytics (BEFORE you archive)

Do these two now, so the build you upload in Part 4 already carries your
real ads and your analytics. If you skip them, nothing breaks: the build
uploads fine with test ads and analytics off, and you can redo the archive
later.

**Step 8 — AdMob (real ads).** Follow **ADMOB_SETUP.md** in this folder:
Part 1 signup → Part 2 add the app → Part 3 the Interstitial unit →
Part 4 the Rewarded unit → Part 5 paste your three IDs into the project
and rebuild the bridge. Come back here when its Step 25 is done.
(Skip it and the game shows Google's test ads, which pay $0.)

**Step 9 — Google Analytics (your dashboard).** Follow
**ANALYTICS_SETUP.md** Parts 1–3: create the Firebase project → register
the iOS app (bundle ID `com.luckyclover.aceofaces`) → download
`GoogleService-Info.plist` → add it to the App target in Xcode.
Come back here when its Step 13 is done.

## PART 4 — Archive and upload the build

**Step 10.** At the top of the Xcode window, click the run-destination
dropdown (it probably says an iPhone simulator name). Change it to
**Any iOS Device (arm64)**.

**Step 11.** Menu bar: **Product → Archive**. Wait — this takes a few minutes.
A window called **Organizer** opens when it finishes.

**Step 12.** In Organizer, select your new archive, click **Distribute App**.

**Step 13.** Choose **App Store Connect**, click **Next**.

**Step 14.** Choose **Upload**, click **Next**, then **Next** again, then
**Upload**. Wait for "Upload Successful".

## PART 5 — Create the App Store Connect listing

**Step 15.** Go to https://appstoreconnect.apple.com and sign in.

**Step 16.** Click **My Apps**, then the **+** (top left), then **New App**.

**Step 17.** Fill in, exactly:
- **Platforms:** check **iOS** (macOS appears automatically via Catalyst later)
- **Name:** `1918`
  (If it says the name is taken, use `1918: Ace of Aces` and tell me.)
- **Primary Language:** English (U.S.)
- **Bundle ID:** open the dropdown, choose `com.luckyclover.aceofaces`
- **SKU:** `ACEOFACES001` (your private code, Apple never shows it)
- **User Access:** Full Access
Click **Create**.

**Step 18.** You're on the new app's page. Click **App Information** (left).
Set **Category** to **Games**. Leave the rest, click **Save** (top right).

**Step 19.** Click **Pricing and Availability** (left). Confirm **Price** is
**Free**. Click **Save**.

**Step 20.** Still on the version page, find **Age Rating**, click **Edit**,
and answer the questionnaire **honestly**: this build has realistic combat,
blood spurts, and parachuting pilots the player can shoot. Click **Done**.

**Step 20b.** Also on the left: **App Privacy**. The app collects two kinds
of data — **ads** (AdMob) and **analytics** (Google Analytics, usage data
only, not linked to the user, not used to track them). If the questionnaire
asks anything you can't map to that, STOP and do this step with me — don't
guess Apple's definitions.

## PART 6 — The $2.99 Remove Ads product (your meal ticket)

**Step 21.** Before Apple lets you sell anything: click **Agreements, Tax, and
Banking** (top of App Store Connect home). Under **Paid Apps**, complete the
agreement, tax forms, and banking info. You cannot skip this — no paid
agreement, no $2.99.

**Step 22.** Back in your app: left sidebar, click **In-App Purchases** (under
Monetization), then **+**.

**Step 23.** Choose **Non-Consumable**, click **Create**.
(Non-consumable = one-time payment, theirs forever. Never pick
"Auto-Renewable Subscription" — that's not this product.)

**Step 24.** Fill in:
- **Reference Name:** `Remove Ads` (only you see this)
- **Product ID:** `com.luckyclover.aceofaces.removeads` (must match EXACTLY)
Click **Create**.

**Step 25.** On the product page: set **Price** to **$2.99** (that's Tier 3),
click **Save**. Fill the **Display Name** (`Remove Ads`) and **Description**
(`Removes all ads from 1918, forever.`) under App Store Localization.

**Step 26.** Go back to your app's **version page** (App Store tab, left).
Scroll to **In-App Purchases**, click **+**, add **Remove Ads**.

## PART 7 — Screenshots, build, submit

**Step 27.** On the version page, scroll to **App Store Screenshots**.
You need iPhone shots: play the game on your iPhone 17 Pro Max, take
screenshots with the side buttons (6.7" display). Upload at least 3.
(6.5" shots are also required — one set of 6.7" uploads usually covers it;
App Store Connect will tell you if anything's missing.)

**Step 28.** Scroll to the **Build** section, click **+**, choose the build
you uploaded in Part 4. (If no build is listed, Apple's still processing it —
wait 10–30 minutes and come back.)

**Step 29.** Fill **Description**, **Keywords** (`wwi,shooter,arcade,biplane,1918`),
and **Support URL** (any page you own).

**Step 30.** Top right: click **Submit for Review**. Done — Apple reviews in
~1–2 days. You'll get an email.

**Step 31 — After you're live (one last AdMob step).** Open
**ADMOB_SETUP.md** Part 6 and link the app in AdMob to its App Store
listing. Google runs a readiness review (usually 2–3 days); until it passes,
ad serving is limited.

---

## If something breaks

- **Signing error in Xcode:** Step 5's Team dropdown is empty → your Apple ID
  in Step 3 isn't on the Developer Program team. Fix it there, not in the project.
- **"No bundle ID available" in Step 17:** the upload in Part 4 registers it —
  finish Part 4 first.
- **Send me the EXACT error text** (copy/paste) and a screenshot. I'll fix the
  scaffold here and tell you the next one step.
