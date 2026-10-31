# UMP 3 patch — AdMob plugin 6.2.0 + GoogleUserMessagingPlatform 3.1.0

`npx cap sync ios` resolves GoogleUserMessagingPlatform **3.1.0** (Google-Mobile-Ads-SDK
11.3.0 only requires `>= 1.1`). UMP 3.0 renamed its Swift API (dropped the `UMP`
prefix, `sharedInstance` -> `shared`). The AdMob plugin 6.2.0 was written against
UMP 2.x, so Xcode fails to build `ConsentExecutor.swift` until it is patched.

This patch lives in `node_modules` and is **wiped by a fresh `npm install`**.
Re-apply it after any fresh install, before pressing Run in Xcode.

## File

`node_modules/@capacitor-community/admob/ios/Sources/AdMobPlugin/Consent/ConsentExecutor.swift`

## Renames (UMP 2 -> UMP 3, per Google's UMP 3.0.0 release notes)

- `UMPRequestParameters` -> `RequestParameters`
- `UMPDebugSettings` -> `DebugSettings`
- `UMPDebugGeography` -> `DebugGeography`
- `UMPConsentInformation.sharedInstance` -> `ConsentInformation.shared`
- `UMPFormStatus` -> `FormStatus`
- `UMPConsentForm` -> `ConsentForm`
- `UMPConsentStatus` -> `ConsentStatus`
- `tagForUnderAgeOfConsent` (on RequestParameters) -> `isTaggedForUnderAgeOfConsent`
- `ConsentForm.load(completionHandler:)` -> `ConsentForm.load(with:)` — the
  `with:` label takes the completion handler itself:
  `ConsentForm.load(with: { form, loadError in ... })`
  (from the framework header: `+loadWithCompletionHandler:` is
  `NS_SWIFT_NAME(load(with:))`).

Other calls in the file need no change: `requestConsentInfoUpdate(with:completionHandler:)`
and `present(from:completionHandler:)` already match the UMP 3 Swift names.

## Also re-apply after a fresh npm install

The Firebase Analytics no-crash guard, documented in `ANALYTICS_SETUP.md`
("Maintenance note"): in
`node_modules/@capacitor-firebase/analytics/ios/Plugin/FirebaseAnalytics.swift`,
only call `FirebaseApp.configure()` when `GoogleService-Info.plist` exists in the
bundle, otherwise the app crashes on launch with no plist present.
