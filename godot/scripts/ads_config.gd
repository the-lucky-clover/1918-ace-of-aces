extends RefCounted
## AdMob + IAP configuration for 1918.
##
## TEST MODE ships ON. Every ad unit below is one of Google's OFFICIAL
## sample/test IDs (verified against
## https://developers.google.com/admob/android/test-ads and the iOS
## equivalent). They always serve test ads and can never generate real
## revenue or invalid-traffic strikes.
##
## GOING LIVE (Steven's moves):
##   1. Create an AdMob account at https://apps.admob.com, register the app.
##   2. Set TEST_MODE = false below.
##   3. Replace the four unit IDs + two app IDs with the real ones from AdMob.
##   4. Put the real Android App ID in the Android export's AndroidManifest.xml
##      (<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" .../>)
##      and the real iOS App ID as GADApplicationIdentifier in Info.plist.
##   5. Create the "1918_remove_ads" ($2.99) one-time product in Play Console /
##      App Store Connect and install the billing plugins (see ADS-SETUP.md).
## The nightly QA check `gdscript-ads-test-ids` pins these exact values, and
## `gdscript-ads-no-real-ids` fails the build if any non-test ad unit ID is
## ever committed while TEST_MODE is on.

const TEST_MODE := true

# --- Official Google test App IDs (the "~" ones; SDK init only) ---
const ANDROID_APP_ID := "ca-app-pub-3940256099942544~3347511713"
const IOS_APP_ID := "ca-app-pub-3940256099942544~1458002511"

# --- Official Google test Ad Unit IDs (the "/" ones) ---
const ANDROID_INTERSTITIAL_ID := "ca-app-pub-3940256099942544/1033173712"
const ANDROID_REWARDED_ID := "ca-app-pub-3940256099942544/5224354917"
const IOS_INTERSTITIAL_ID := "ca-app-pub-3940256099942544/4411468910"
const IOS_REWARDED_ID := "ca-app-pub-3940256099942544/1712485313"

# --- IAP product (one-time, non-consumable) ---
const IAP_PRODUCT_REMOVE_ADS := "1918_remove_ads"
const IAP_PRICE_LABEL := "$2.99"

# --- Honest placement caps ("carefully placed interstitials") ---
## Seconds between interstitials.
const INTERSTITIAL_COOLDOWN_S := 180.0
## Hard cap of interstitials shown per app session.
const INTERSTITIAL_MAX_PER_SESSION := 3
## Interstitials never fire until the player has completed this many sorties
## (covers "never on the first session's first sortie" and then some).
const INTERSTITIAL_MIN_SORTIES_COMPLETED := 1


static func interstitial_id() -> String:
	if OS.get_name() == "iOS":
		return IOS_INTERSTITIAL_ID
	return ANDROID_INTERSTITIAL_ID


static func rewarded_id() -> String:
	if OS.get_name() == "iOS":
		return IOS_REWARDED_ID
	return ANDROID_REWARDED_ID


static func app_id() -> String:
	if OS.get_name() == "iOS":
		return IOS_APP_ID
	return ANDROID_APP_ID


## True when real store billing should be used: TEST_MODE off AND a billing
## provider singleton is actually installed.
static func use_real_billing() -> bool:
	if TEST_MODE:
		return false
	return Engine.has_singleton("GodotGooglePlayBilling")
