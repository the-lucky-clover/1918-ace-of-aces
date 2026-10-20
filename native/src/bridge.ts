/**
 * 1918 — native monetization bridge (www/bridge.js, built from src/bridge.ts).
 *
 * Exposes `window.GameBridge` to the web game with exactly the contract the
 * game expects (see BRIDGE.md):
 *   GameBridge.isAdsRemoved()    -> Promise<boolean>
 *   GameBridge.showInterstitial() -> Promise<boolean> (true = an ad showed)
 *   GameBridge.showRewardedAd()   -> Promise<boolean> (true = reward earned)
 *   GameBridge.buyRemoveAds()     -> Promise<boolean> (true = purchase done)
 *   GameBridge.restorePurchases() -> Promise<boolean>
 *
 * When NOT running inside the Capacitor native shell (plain browser), every
 * method resolves false and the game degrades gracefully (its bridgeCall
 * wrapper already handles `available:false`).
 *
 * HONEST MONETIZATION RULES (do not weaken):
 * - Interstitials: only between sorties (the game calls showInterstitial on
 *   the retry/briefing path), never mid-combat, never on the title screen.
 *   Frequency-capped: max 1 per 90 seconds.
 * - Rewarded ads: always opt-in (the player taps "Continue" first).
 * - Remove-ads IAP ($2.99, non-consumable) permanently disables ALL ads.
 *   Entitlement persisted in Preferences + re-checked from the store receipt.
 */

import { AdMob } from '@capacitor-community/admob';
import { Preferences } from '@capacitor/preferences';
import { FirebaseAnalytics } from '@capacitor-firebase/analytics';

// ---------------------------------------------------------------------------
// CONFIG — Google TEST ad unit IDs. Swap for real IDs per ADMOB_IDS.md.
// These are Google's official test IDs; they always serve test ads.
// ---------------------------------------------------------------------------
const INTERSTITIAL_AD_ID = 'ca-app-pub-3940256099942544/4411468910'; // TEST
const REWARDED_AD_ID = 'ca-app-pub-3940256099942544/1712485313'; // TEST
const REMOVE_ADS_PRODUCT_ID = 'com.luckyclover.aceofaces.removeads'; // $2.99 non-consumable
const PREF_ADS_REMOVED = 'ace1918_ads_removed_v1';
const INTERSTITIAL_MIN_GAP_MS = 90_000; // honest frequency cap

declare const CdvPurchase: any; // cordova-plugin-purchase (may be absent)

let adsRemoved = false;
let purchaseTracked = false; // analytics: count each purchase once
let lastInterstitialAt = 0;
let inNativeShell = false;
let pendingBuy: ((ok: boolean) => void) | null = null;

// ---------------------------------------------------------------------------
// AdMob
// ---------------------------------------------------------------------------
async function initAdMob(): Promise<void> {
  await AdMob.initialize({
    initializeForTesting: true, // TEST MODE — remove when real IDs go live
  });
  // iOS 14+ App Tracking Transparency prompt (separate call in this plugin).
  await safe(() => AdMob.requestTrackingAuthorization());
  // Pre-load both formats so show* never stalls the game.
  await safe(() => AdMob.prepareInterstitial({ adId: INTERSTITIAL_AD_ID }));
  await safe(() => AdMob.prepareRewardVideoAd({ adId: REWARDED_AD_ID }));
}

// ---------------------------------------------------------------------------
// Google Analytics (Firebase) — standard events only, NO PII, NO user IDs.
// The native side stays silent (and never crashes) until Steven drops his own
// GoogleService-Info.plist into the app — see ANALYTICS_SETUP.md and the
// guarded FirebaseApp.configure() patch described there.
//
// Today the bridge can only observe events that flow through it:
//   shell_boot            — bridge started inside the native shell
//   ad_shown              — an interstitial or rewarded actually displayed
//   reward_earned         — a rewarded ad was watched to completion
//   remove_ads_purchased  — the $2.99 unlock completed (once per purchase)
// `app_open` is collected automatically by Firebase; we never log it by hand.
// A future game build can call the same tracker for sortie_start /
// sortie_complete via GameBridge.trackEvent(name, params).
// ---------------------------------------------------------------------------
async function trackEvent(
  name: string,
  params?: Record<string, string | number | boolean>,
): Promise<void> {
  if (!inNativeShell) return;
  await safe(() => FirebaseAnalytics.logEvent({ name, params: params ?? {} }));
}

async function showInterstitial(): Promise<boolean> {
  if (adsRemoved) return false;
  if (Date.now() - lastInterstitialAt < INTERSTITIAL_MIN_GAP_MS) return false;
  try {
    await AdMob.showInterstitial();
    lastInterstitialAt = Date.now();
    // Pre-load the next one in the background.
    safe(() => AdMob.prepareInterstitial({ adId: INTERSTITIAL_AD_ID }));
    void trackEvent('ad_shown', { format: 'interstitial' });
    return true;
  } catch {
    return false;
  }
}

async function showRewardedAd(): Promise<boolean> {
  if (adsRemoved) return false;
  try {
    const reward = await AdMob.showRewardVideoAd();
    safe(() => AdMob.prepareRewardVideoAd({ adId: REWARDED_AD_ID }));
    // showRewardVideoAd resolves with the reward item ONLY if earned.
    const earned = !!reward;
    if (earned) {
      void trackEvent('ad_shown', { format: 'rewarded' });
      void trackEvent('reward_earned', {});
    }
    return earned;
  } catch {
    return false; // dismissed early / failed -> game shows "Reward not completed"
  }
}

// ---------------------------------------------------------------------------
// In-app purchase — $2.99 Remove Ads (non-consumable, StoreKit)
// ---------------------------------------------------------------------------
function purchasePlugin(): any | null {
  try {
    return typeof CdvPurchase !== 'undefined' ? CdvPurchase : null;
  } catch {
    return null;
  }
}

async function setAdsRemoved(on: boolean): Promise<void> {
  adsRemoved = on;
  await Preferences.set({ key: PREF_ADS_REMOVED, value: on ? '1' : '0' });
  // Log the purchase exactly once (restores re-read the pref but skip re-log).
  if (on && !purchaseTracked) {
    purchaseTracked = true;
    void trackEvent('remove_ads_purchased', { price_usd: 2.99 });
  }
  if (pendingBuy) {
    pendingBuy(on);
    pendingBuy = null;
  }
}

async function initIAP(): Promise<void> {
  // Restore the persisted entitlement first (fast path, works offline).
  const { value } = await Preferences.get({ key: PREF_ADS_REMOVED });
  if (value === '1') {
    adsRemoved = true;
    purchaseTracked = true; // restore, not a new purchase — don't re-log
  }

  const Cdv = purchasePlugin();
  if (!Cdv) return;
  const { store, ProductType, Platform } = Cdv;

  store.register([
    {
      id: REMOVE_ADS_PRODUCT_ID,
      type: ProductType.NON_CONSUMABLE,
      platform: Platform.APPLE_APPSTORE,
    },
  ]);

  store
    .when()
    .approved((tx: any) => tx.verify())
    .verified((receipt: any) => receipt.finish())
    .finished((tx: any) => {
      const ids: string[] = (tx.products || []).map((p: any) =>
        typeof p === 'string' ? p : p.id,
      );
      if (ids.indexOf(REMOVE_ADS_PRODUCT_ID) >= 0) void setAdsRemoved(true);
    })
    .cancelled(() => {
      if (pendingBuy) {
        pendingBuy(false);
        pendingBuy = null;
      }
    })
    .owned((p: any) => {
      const id = typeof p === 'string' ? p : p.id;
      if (id === REMOVE_ADS_PRODUCT_ID) {
        purchaseTracked = true; // restore path — don't re-log the purchase
        void setAdsRemoved(true);
      }
    });

  await store.initialize([Platform.APPLE_APPSTORE]);
}

function buyRemoveAds(): Promise<boolean> {
  const Cdv = purchasePlugin();
  if (!Cdv) return Promise.resolve(false);
  if (adsRemoved) return Promise.resolve(true);
  return new Promise((resolve) => {
    pendingBuy = resolve;
    // Safety net: never leave the buy button hanging.
    setTimeout(() => {
      if (pendingBuy) {
        pendingBuy(false);
        pendingBuy = null;
      }
    }, 120_000);
    Cdv.store.order(REMOVE_ADS_PRODUCT_ID).catch(() => {
      if (pendingBuy) {
        pendingBuy(false);
        pendingBuy = null;
      }
    });
  });
}

async function restorePurchases(): Promise<boolean> {
  const Cdv = purchasePlugin();
  if (!Cdv) return false;
  try {
    await Cdv.store.restore();
    return adsRemoved;
  } catch {
    return false;
  }
}

// ---------------------------------------------------------------------------
// Boot
// ---------------------------------------------------------------------------
async function safe(fn: () => Promise<unknown>): Promise<void> {
  try {
    await fn();
  } catch {
    /* ads are best-effort; the game must never break */
  }
}

async function boot(): Promise<void> {
  inNativeShell =
    typeof (window as any).Capacitor !== 'undefined' &&
    !!(window as any).Capacitor.isNativePlatform?.();

  if (inNativeShell) {
    await safe(initAdMob);
    // cordova.js (CdvPurchase) initializes asynchronously — wait for it.
    await waitForCordova(8000);
    await safe(initIAP);
  }

  (window as any).GameBridge = {
    isAdsRemoved: async () => adsRemoved,
    showInterstitial: () => showInterstitial(),
    showRewardedAd: () => showRewardedAd(),
    buyRemoveAds: () => buyRemoveAds(),
    restorePurchases: () => restorePurchases(),
    // Reserved for a future game build: lets the game log analytics events
    // it can see (e.g. sortie_start / sortie_complete) through the shell.
    trackEvent: (name: string, params?: Record<string, string | number | boolean>) =>
      trackEvent(name, params),
  };

  if (inNativeShell) {
    void trackEvent('shell_boot', {});
  }

  // The game listens for this to refresh its store UI.
  window.dispatchEvent(new Event('gamebridge:ready'));
}

/** Resolve once Cordova's deviceready fires (or timeout — web/Capacitor-only). */
function waitForCordova(timeoutMs: number): Promise<void> {
  if (purchasePlugin()) return Promise.resolve();
  return new Promise((resolve) => {
    const done = () => resolve();
    const timer = setTimeout(done, timeoutMs);
    document.addEventListener(
      'deviceready',
      () => {
        clearTimeout(timer);
        done();
      },
      { once: true },
    );
  });
}

void boot();

export {};
