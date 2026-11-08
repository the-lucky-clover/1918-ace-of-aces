// apply-patches.js — 1918 iOS wrapper postinstall hook.
//
// Makes the two node_modules patches permanent and automatic: a fresh
// `npm install` wipes node_modules, so this script re-applies them every
// time packages are (re)installed.
//
//   1. UMP 3 patch (AdMob 6.x only): the @capacitor-community/admob plugin
//      6.2.0 was written against UMP 2.x, but `npx cap sync ios` resolves
//      GoogleUserMessagingPlatform 3.1.0, which renamed its Swift API
//      (dropped the `UMP` prefix, `sharedInstance` -> `shared`). Without
//      this patch Xcode fails to build ConsentExecutor.swift.
//      Applied ONLY when the installed AdMob major version is 6 —
//      applying it to AdMob 5.x would break that build.
//   2. Firebase Analytics no-crash guard: only call FirebaseApp.configure()
//      when GoogleService-Info.plist exists in the bundle, otherwise the
//      app crashes on launch with no plist present.
//
// Idempotent: safe to run twice. Never fails the install — a missing file
// or unreadable version only logs a warning. Exits 0 always.
//
// See also: native/UMP3-PATCH.md

'use strict';

const fs = require('fs');
const path = require('path');

const NATIVE_DIR = path.join(__dirname, '..');
const ADMOB_PKG = path.join(NATIVE_DIR, 'node_modules', '@capacitor-community', 'admob', 'package.json');
const CONSENT_EXECUTOR = path.join(
    NATIVE_DIR, 'node_modules', '@capacitor-community', 'admob',
    'ios', 'Sources', 'AdMobPlugin', 'Consent', 'ConsentExecutor.swift'
);
const FIREBASE_ANALYTICS = path.join(
    NATIVE_DIR, 'node_modules', '@capacitor-firebase', 'analytics',
    'ios', 'Plugin', 'FirebaseAnalytics.swift'
);

// UMP 2.x -> UMP 3 renames, per Google's UMP 3.0.0 release notes.
// Order matters: the ConsentForm.load call is renamed as a whole first,
// then the bare type name — otherwise the load call would be left with
// the old `completionHandler:` label.
// `tagForUnderAgeOfConsent` is scoped to `parameters.` so the local Swift
// parameter/variable of the same name is never touched.
const UMP3_RENAMES = [
    ['UMPConsentForm.load(completionHandler:', 'ConsentForm.load(with:'],
    ['UMPConsentInformation.sharedInstance', 'ConsentInformation.shared'],
    ['UMPRequestParameters', 'RequestParameters'],
    ['UMPDebugSettings', 'DebugSettings'],
    ['UMPDebugGeography', 'DebugGeography'],
    ['UMPFormStatus', 'FormStatus'],
    ['UMPConsentForm', 'ConsentForm'],
    ['UMPConsentStatus', 'ConsentStatus'],
    ['parameters.tagForUnderAgeOfConsent', 'parameters.isTaggedForUnderAgeOfConsent'],
];

const FIREBASE_GUARD_MARKER = 'GoogleService-Info';
const FIREBASE_UNPATCHED =
    '        if FirebaseApp.app() == nil {';
const FIREBASE_PATCHED =
    '        // 1918 patch: never crash the app when GoogleService-Info.plist\n' +
    '        // hasn\'t been dropped in yet — analytics just stays off until it is.\n' +
    '        if FirebaseApp.app() == nil,\n' +
    '           Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {';

function log(msg) {
    console.log('[1918 apply-patches] ' + msg);
}

function warn(msg) {
    console.warn('[1918 apply-patches] WARNING: ' + msg);
}

function replaceAll(text, from, to) {
    return text.split(from).join(to);
}

function countOccurrences(text, needle) {
    return text.split(needle).length - 1;
}

function readAdMobMajor() {
    try {
        const pkg = JSON.parse(fs.readFileSync(ADMOB_PKG, 'utf8'));
        const version = String(pkg.version || '');
        const major = parseInt(version.split('.')[0], 10);
        if (!Number.isFinite(major)) {
            warn('could not parse AdMob version from ' + ADMOB_PKG + ' (got "' + version + '") — skipping UMP 3 patch');
            return null;
        }
        log('installed AdMob version: ' + version);
        return major;
    } catch (err) {
        warn('could not read AdMob package.json (' + err.message + ') — skipping UMP 3 patch');
        return null;
    }
}

function applyUmp3Patch() {
    if (!fs.existsSync(CONSENT_EXECUTOR)) {
        warn('ConsentExecutor.swift not found at ' + CONSENT_EXECUTOR + ' — skipping UMP 3 patch');
        return;
    }
    let text = fs.readFileSync(CONSENT_EXECUTOR, 'utf8');
    let changed = false;
    for (const [from, to] of UMP3_RENAMES) {
        const n = countOccurrences(text, from);
        if (n > 0) {
            text = replaceAll(text, from, to);
            log('UMP 3: replaced ' + n + 'x "' + from + '" -> "' + to + '"');
            changed = true;
        }
    }
    if (changed) {
        fs.writeFileSync(CONSENT_EXECUTOR, text, 'utf8');
        log('UMP 3 patch applied to ConsentExecutor.swift');
    } else {
        log('UMP 3 patch already applied to ConsentExecutor.swift (no UMP 2.x names left) — nothing to do');
    }
}

function applyFirebaseGuard() {
    if (!fs.existsSync(FIREBASE_ANALYTICS)) {
        warn('FirebaseAnalytics.swift not found at ' + FIREBASE_ANALYTICS + ' — skipping Firebase guard');
        return;
    }
    const text = fs.readFileSync(FIREBASE_ANALYTICS, 'utf8');
    if (text.includes(FIREBASE_GUARD_MARKER)) {
        log('Firebase no-crash guard already present in FirebaseAnalytics.swift — nothing to do');
        return;
    }
    if (!text.includes(FIREBASE_UNPATCHED)) {
        warn('FirebaseAnalytics.swift does not contain the expected "if FirebaseApp.app() == nil {" line — leaving it alone (guard NOT applied, check by hand)');
        return;
    }
    const patched = text.replace(FIREBASE_UNPATCHED, FIREBASE_PATCHED);
    fs.writeFileSync(FIREBASE_ANALYTICS, patched, 'utf8');
    log('Firebase no-crash guard applied to FirebaseAnalytics.swift');
}

function main() {
    log('running (postinstall)');
    const major = readAdMobMajor();
    if (major === null) {
        // Version unreadable: skip UMP 3, still try the Firebase guard.
    } else if (major >= 6) {
        applyUmp3Patch();
    } else {
        log('AdMob ' + major + '.x uses UMP 2.x names — leaving ConsentExecutor.swift alone (UMP 3 patch is 6.x only)');
    }
    applyFirebaseGuard();
    log('done');
}

try {
    main();
} catch (err) {
    // Never fail the install.
    warn('unexpected error: ' + (err && err.message ? err.message : err) + ' — continuing without patches');
}
process.exit(0);
