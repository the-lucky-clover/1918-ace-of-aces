# 1918 — Build & Test on Your iPhones and Mac

**What this guide does:** gets a fresh copy of 1918 onto BOTH of your
iPhones (15 Pro Max + 17 Pro Max) and your Mac, using **one command**.

**How it works:** the command builds the app and uploads it to
**TestFlight** (Apple's testing service). Both phones install the *same*
build from the TestFlight app. No cables after the one-time setup in
Part 2, no copying files, no version mix-ups — one upload, every device
in sync.

**The two commands you'll actually use:**

| What you want | Command (from the `native` folder) |
|---|---|
| New build on both phones | `bundle exec fastlane beta` |
| Run the automated smoke tests | `bundle exec fastlane test` |

**This guide is for TESTING.** When you're ready to submit the real
release to the App Store, that's [SUBMIT.md](SUBMIT.md) — different guide.

> **The golden rule for every part below:** if anything prints red text
> or shows an error, **don't improvise.** Copy the exact red text (or
> take a screenshot of it) and send it to Sailor Ron. Every step here was
> written to match the real screens — if your screen disagrees with a
> step, that's a bug in the guide, and the red text is how we fix it.

---

## Part 1 — One-time setup on your Mac

You only do this part once, ever.

1. **Install Xcode** from the Mac App Store if it isn't installed yet.
2. **Open Xcode once.** Wait until it finishes its "installing
   components" progress — don't skip this.
3. **Sign in to Xcode:** menu **Xcode → Settings… → Accounts**. Click
   the **+** at the bottom left, choose **Apple ID**, and sign in with
   the same Apple ID you use for App Store Connect.
4. **Install Homebrew** (a tool installer). Open the **Terminal** app
   and paste this one line, then press Enter. It will ask for your Mac
   password partway through — that's normal. The line comes from
   https://brew.sh — check there if you want to see it first.
   ```
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   ```
5. **Do what Homebrew tells you at the end.** When it finishes it prints
   two lines starting with `echo` and `eval` under a heading like
   "Next steps". Copy-paste those two lines exactly as printed — they
   connect Homebrew to your Terminal.
6. **Install a modern Ruby** (fastlane needs a newer one than macOS
   ships):
   ```
   brew install ruby
   ```
7. **Check it worked.** Close the Terminal window, open a fresh one,
   and run:
   ```
   ruby --version
   ```
   It should say `ruby 3.` something. If it says `ruby 2.6`, stop and
   send Ron what the Terminal printed.
8. **Install Bundler** (the tool that reads this project's Gemfile):
   ```
   gem install bundler
   ```
9. **Go to the project folder.** In Terminal, type `cd` and a space
   (don't press Enter yet), then drag the unzipped **`native`** folder
   from Finder into the Terminal window, then press Enter. Your prompt
   should now end in `native`.
10. **Install the project's fastlane:**
    ```
    bundle install
    ```
    First run takes a few minutes. It ends with `Bundle complete!` —
    that's success.

### Why setup works this way

- **Why not the Ruby built into macOS?** It's too old for current
  fastlane. Homebrew's Ruby is the standard fix.
- **Why Bundler instead of `brew install fastlane`?** The project pins
  its exact fastlane version in a file called `Gemfile`. Bundler always
  installs *that* version, so your builds behave the same every time.
  Homebrew's fastlane is a separate copy that can drift to a different
  version than the project expects.

### The password file (so uploads don't nag you)

Uploading to TestFlight needs an **app-specific password** — a special
password just for tools, separate from your real Apple ID password.

1. On your Mac, go to https://appleid.apple.com and sign in.
2. Open **Sign-In and Security → App-Specific Passwords**.
3. Click **Generate an app-specific password**, name it `fastlane`,
   and copy the password it shows (looks like `xxxx-xxxx-xxxx-xxxx`).
4. Back in Terminal (still in the `native` folder), paste this line,
   replacing `PASTE-IT-HERE` with that password, then press Enter:
   ```
   echo 'FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD=PASTE-IT-HERE' > fastlane/.env
   ```
5. Done. That file lives only on your Mac — it's listed in `.gitignore`
   so it never gets committed or uploaded anywhere by accident.

---

## Part 2 — First run on each iPhone (one time per phone)

This registers each phone with your developer team. Xcode does the
registering automatically the first time it runs the app on the phone —
you just plug in and press Run. Do these steps for the **iPhone 15 Pro
Max**, then repeat them for the **iPhone 17 Pro Max**.

1. **Turn on Developer Mode on the phone:** Settings → Privacy &
   Security → Developer Mode → turn it **on**. The phone restarts —
   after it does, tap **Turn On** on the prompt and enter your passcode.
2. **Plug the phone into the Mac** with a cable.
3. On the phone, tap **Trust** if it asks, and enter your passcode.
4. On the Mac, **double-click** `ios/App/App.xcworkspace` inside the
   `native` folder to open the project in Xcode. (Always the
   `.xcworkspace`, never the `.xcodeproj`.)
5. At the top of the Xcode window, set the scheme to **App** and the
   destination to **your iPhone** (it appears by name).
6. **If Xcode shows a signing warning:** click the **App** target in
   the left sidebar → **Signing & Capabilities** tab → under **Team**,
   pick your name / your team.
7. **Press the ▶ Run button** (top left). The app builds, installs on
   the phone, and launches. The first build takes a while — normal.
8. Your phone is now registered. Unplug it.
9. **Repeat steps 1–8 for the other iPhone.**

> **Good to know:** this cable dance is one-time. From here on, new
> builds arrive through TestFlight (Part 3 + Part 4) — no cables.

---

## Part 3 — The one command: send a new build to both phones

1. Open **Terminal**.
2. Go to the `native` folder (same drag trick as Part 1, step 9).
3. Run:
   ```
   bundle exec fastlane beta
   ```
4. **What you'll see, in order:**
   - Lines about copying files and installing pods (`cap sync` keeping
     the iOS project matched to the newest game files).
   - The build number going up by 1 (1 → 2 → 3…). That's on purpose —
     it's how TestFlight tells builds apart.
   - `Building...` and an archive step — a few minutes.
   - An upload progress line, then green text saying the build was
     uploaded, plus: *"After Apple finishes processing, the build shows
     up in the TestFlight app."*
5. **If Apple asks for a 6-digit verification code** (can happen the
   first time): type the code from your phone. Normal, not an error.
6. **Now just wait.** Apple processes the build on their side —
   usually **5–30 minutes** for a first build, often faster later.
   Nothing is broken while you wait. You'll get an email from App
   Store Connect when it's ready.

> Red text anywhere? Copy it exactly and send it to Ron. Don't retry
> with random changes — the first error message is the useful one.

---

## Part 4 — Install the build from TestFlight (both iPhones + Mac)

1. On **each iPhone**, install **TestFlight** from the App Store:
   https://apps.apple.com/app/testflight/id899247664
2. Open TestFlight and make sure you're signed in with the **same
   Apple ID** as your developer account.
3. After the processing email arrives, **1918** appears in TestFlight
   with the newest build at the top. Tap **Install**, then **Open**.
4. **Check both phones match:** in TestFlight, under the app name it
   shows the version and build, like `1.0 (2)`. Both phones should show
   the **same build number** — that's your proof they're in sync.
5. **If 1918 doesn't appear in TestFlight on a phone:** on your Mac go
   to https://appstoreconnect.apple.com → **1918 → TestFlight tab →
   Internal Testing** → create a group (name it anything, e.g.
   `Just Me`) → add **yourself** as a tester → add the build to the
   group. Then check the phone again.
6. **On the Mac:** the Mac version needs one thing first — "Turn on
   Mac" in [SUBMIT.md](SUBMIT.md) (it switches on the Mac Catalyst
   version of the app). After that, send Mac builds with:
   ```
   bundle exec fastlane beta_mac
   ```
   and install them from the **TestFlight app on the Mac** (free from
   the Mac App Store), same as the phones.

**Honest notes about TestFlight:**

- **Internal testing has NO review wait.** Builds for your own account
  skip App Review entirely. (Only *external* testers trigger Apple's
  beta review — we're not using those.)
- **TestFlight builds expire after 90 days.** When one does, just run
  Part 3 again for a fresh build.
- The **first** build for the app can take longer to process. Later
  builds are usually quicker.

---

## Part 5 — Automated tests

The project has a smoke test: it boots the game in a simulator and
checks the title screen's web view really loads, and it saves a
screenshot so a human can eyeball it.

1. Open **Terminal**, go to the `native` folder (drag trick).
2. Run:
   ```
   bundle exec fastlane test
   ```
3. **What happens:** an **iPhone 17 Pro Max simulator** window opens on
   your Mac (no physical phone needed), the app launches inside it,
   the test waits for the game to load, and takes a screenshot.
4. **Passing looks like this:**
   - Green **TEST SUCCEEDED** text.
   - A summary table at the very end with green check marks for every
     step, and `fastlane finished with success`.
5. **Then it tries the Mac version.** Until "Turn on Mac" (SUBMIT.md)
   is done, you'll see a yellow note saying the Mac tests were skipped
   and that it's expected. **That is not a failure** — the iPhone
   results above it are the ones that count.
6. Screenshots and the full report land in `fastlane/test_output/` if
   Ron ever asks you to send them.
7. **If anything fails:** you know the rule — copy the exact red text
   back to Ron, don't improvise.

---

## Appendix — the optional `devices` lane (usually skip this)

TestFlight makes UDIDs unnecessary. This lane exists only for direct
cable installs outside the App Store, if that ever comes up:

1. In Terminal (in the `native` folder):
   ```
   cp fastlane/devices.txt.example fastlane/devices.txt
   ```
2. Open `fastlane/devices.txt` in TextEdit. For each phone, replace the
   fake Identifier with the real one: plug the phone in → Xcode →
   **Window → Devices and Simulators** → click the phone → copy its
   **Identifier**.
3. Run:
   ```
   bundle exec fastlane devices
   ```
   With no `devices.txt` present, the lane just prints these same
   instructions and changes nothing.

---

## Smryx — the other project

Smryx has the same fastlane setup (same Part 1 — if you did it for
1918, the Mac is already set up; you only repeat `bundle install` once
inside the `smryx` folder). **Difference:** Smryx is a **Mac-only** app,
so there are no iPhone installs for it — its TestFlight builds land on
this Mac, and its tests run on this Mac. Its own step-by-step lives in
`TESTING.md` inside the `smryx` folder.

**Helpful links:**

- Homebrew — https://brew.sh
- Fastlane docs — https://docs.fastlane.tools
- App Store Connect — https://appstoreconnect.apple.com
- App-specific passwords — https://appleid.apple.com
- TestFlight (iPhone) — https://apps.apple.com/app/testflight/id899247664
- About TestFlight — https://developer.apple.com/testflight
