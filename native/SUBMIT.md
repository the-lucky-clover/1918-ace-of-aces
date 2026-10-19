# 1918 — App Store Submission, One Step at a Time

Do these in order. One step, then the next. If any step looks different on
your Mac, STOP and send me a screenshot of what you see — don't guess.

Your bundle ID everywhere: `com.luckyclover.aceofaces`
Your IAP product ID: `com.luckyclover.aceofaces.removeads` ($2.99, non-consumable)

---

## PART 1 — Open the project in Xcode (your Mac)

**Step 1.** Install Xcode from the Mac App Store if you don't have it. It's free, but it's huge — let it finish.

**Step 2.** In Finder, open `~/workspace/1918-ace-of-aces/native/ios/App/`
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
open **Terminal** (in Applications → Utilities), paste this line, press Enter:

```bash
cd ~/workspace/1918-ace-of-aces/native/ios/App && pod install
```

(If it says `command not found: pod`, first run `sudo gem install cocoapods`,
type your Mac password, then run the line above again.) When it finishes,
quit Xcode completely and re-open `App.xcworkspace` from Step 2.

## PART 2 — Add Mac as a destination (for the Mac App Store)

**Step 7.** Still on the App target, click the **General** tab at the top.
Find the **Supported Destinations** section. Click the **+** button under it
and choose **Mac**. (This turns on Mac Catalyst — one binary, both stores.)

## PART 3 — Archive and upload the build

**Step 8.** At the top of the Xcode window, click the run-destination
dropdown (it probably says an iPhone simulator name). Change it to
**Any iOS Device (arm64)**.

**Step 9.** Menu bar: **Product → Archive**. Wait — this takes a few minutes.
A window called **Organizer** opens when it finishes.

**Step 10.** In Organizer, select your new archive, click **Distribute App**.

**Step 11.** Choose **App Store Connect**, click **Next**.

**Step 12.** Choose **Upload**, click **Next**, then **Next** again, then
**Upload**. Wait for "Upload Successful".

## PART 4 — Create the App Store Connect listing

**Step 13.** Go to https://appstoreconnect.apple.com and sign in.

**Step 14.** Click **My Apps**, then the **+** (top left), then **New App**.

**Step 15.** Fill in, exactly:
- **Platforms:** check **iOS** (macOS appears automatically via Catalyst later)
- **Name:** `1918`
  (If it says the name is taken, use `1918: Ace of Aces` and tell me.)
- **Primary Language:** English (U.S.)
- **Bundle ID:** open the dropdown, choose `com.luckyclover.aceofaces`
- **SKU:** `ACEOFACES001` (your private code, Apple never shows it)
- **User Access:** Full Access
Click **Create**.

**Step 16.** You're on the new app's page. Click **App Information** (left).
Set **Category** to **Games**. Leave the rest, click **Save** (top right).

**Step 17.** Click **Pricing and Availability** (left). Confirm **Price** is
**Free**. Click **Save**.

**Step 18.** Still on the version page, find **Age Rating**, click **Edit**,
answer the questionnaire honestly (it's a war game with combat). Click **Done**.

## PART 5 — The $2.99 Remove Ads product (your meal ticket)

**Step 19.** Before Apple lets you sell anything: click **Agreements, Tax, and
Banking** (top of App Store Connect home). Under **Paid Apps**, complete the
agreement, tax forms, and banking info. You cannot skip this — no paid
agreement, no $2.99.

**Step 20.** Back in your app: left sidebar, click **In-App Purchases** (under
Monetization), then **+**.

**Step 21.** Choose **Non-Consumable**, click **Create**.

**Step 22.** Fill in:
- **Reference Name:** `Remove Ads` (only you see this)
- **Product ID:** `com.luckyclover.aceofaces.removeads` (must match EXACTLY)
Click **Create**.

**Step 23.** On the product page: set **Price** to **$2.99** (that's Tier 3),
click **Save**. Fill the **Display Name** (`Remove Ads`) and **Description**
(`Removes all ads from 1918, forever.`) under App Store Localization.

**Step 24.** Go back to your app's **version page** (App Store tab, left).
Scroll to **In-App Purchases**, click **+**, add **Remove Ads**.

## PART 6 — Screenshots, build, submit

**Step 25.** On the version page, scroll to **App Store Screenshots**.
You need iPhone shots: play the game on your iPhone 17 Pro Max, take
screenshots with the side buttons (6.7" display). Upload at least 3.
(6.5" shots are also required — one set of 6.7" uploads usually covers it;
App Store Connect will tell you if anything's missing.)

**Step 26.** Scroll to the **Build** section, click **+**, choose the build
you uploaded in Part 3. (If no build is listed, Apple's still processing it —
wait 10–30 minutes and come back.)

**Step 27.** Fill **Description**, **Keywords** (`wwi,shooter,arcade,biplane,1918`),
and **Support URL** (any page you own).

**Step 28.** Top right: click **Submit for Review**. Done — Apple reviews in
~1–2 days. You'll get an email.

---

## If something breaks

- **Signing error in Xcode:** Step 5's Team dropdown is empty → your Apple ID
  in Step 3 isn't on the Developer Program team. Fix it there, not in the project.
- **"No bundle ID available" in Step 15:** the upload in Part 3 registers it —
  finish Part 3 first.
- **Send me the EXACT error text** (copy/paste) and a screenshot. I'll fix the
  scaffold here and tell you the next one step.
