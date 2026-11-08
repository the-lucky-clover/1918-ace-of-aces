#!/usr/bin/env node
/* v61 static QA — the SECRETS PACKAGE: rare photographic silhouette
   flyovers (an airship, a bomber, and one black shape that only crosses
   while a pilot's campaign tally climbs toward the mark); a challenger
   in a black SPAD — the game's own SPAD photographic set re-graded to a
   black livery, alpha untouched — who interrupts the sortie when the
   cumulative campaign count crosses its mark and duels over the v59
   cloud sea at 75% of the final boss's strength, on a sky where dark
   thunderhead plates (cut from the same NASA photograph) hurt pilot
   and challenger alike and the challenger's own steering avoids them;
   and a photographic engine-start cut-in with a +250 bonus for a kill
   made mid-loop, never during a boss fight. The package explains
   nothing: no hint strings, no toasts, no banners — the only words it
   adds are the stage card's locale and the cut-in's period shout.
   It rides the v59 bonus-entitlement law exactly (free vests forever,
   launch grant ships open); the host alone banks the hidden mark.
   Plates: bin/build-v61-secrets.py (user's own SPAD photograph, NASA
   public-domain cloud sea, the game's own v48/bomber plates).
   Usage: node QA/v61-qa.js [path-to-html]
   Exit 0 = all checks pass, 1 = a failure. Warnings never fail the run. */
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const HTML = process.argv[2] || path.join(ROOT, '1918-ace-of-aces.html');
const html = fs.readFileSync(HTML, 'utf8');
const version = fs.readFileSync(path.join(ROOT, 'VERSION'), 'utf8').trim();
const changelog = fs.readFileSync(path.join(ROOT, 'CHANGELOG.md'), 'utf8');
const buildScript = fs.readFileSync(path.join(ROOT, 'bin', 'build-v61-secrets.py'), 'utf8');

let pass = 0, fail = 0, warn = 0;
const failures = [], warnings = [];
function ok(name, cond, detail) {
  if (cond) { pass++; console.log('  PASS  ' + name); }
  else { fail++; failures.push(name + (detail ? ' — ' + detail : '')); console.log('  FAIL  ' + name + (detail ? ' — ' + detail : '')); }
}
function note(name, detail) { warn++; warnings.push(name + (detail ? ' — ' + detail : '')); console.log('  WARN  ' + name + (detail ? ' — ' + detail : '')); }

console.log('v61 static QA — ' + HTML);

function pngInfo(file) {
  const buf = fs.readFileSync(file);
  if (buf.length < 24 || buf[0] !== 0x89 || buf[1] !== 0x50 || buf[2] !== 0x4e || buf[3] !== 0x47) return null;
  return { width: buf.readUInt32BE(16), height: buf.readUInt32BE(20), bytes: buf.length };
}
function jpegInfo(file) {
  const buf = fs.readFileSync(file);
  if (buf.length < 4 || buf[0] !== 0xFF || buf[1] !== 0xD8) return null;
  let i = 2;
  while (i < buf.length - 9) {
    if (buf[i] !== 0xFF) { i++; continue; }
    const m = buf[i + 1];
    if (m >= 0xC0 && m <= 0xCF && m !== 0xC4 && m !== 0xC8 && m !== 0xCC) {
      return { height: buf.readUInt16BE(i + 5), width: buf.readUInt16BE(i + 7), bytes: buf.length };
    }
    i += 2 + buf.readUInt16BE(i + 2);
  }
  return null;
}
function bodyOf(name) {
  const at = html.indexOf('function ' + name + '(');
  if (at < 0) return '';
  const next = html.indexOf('\nfunction ', at + 10);
  return html.slice(at, next < 0 ? at + 4000 : next);
}

// --- version -----------------------------------------------------------------
ok('VERSION file is 61', version === '61', 'got ' + version);
ok('in-game version badge is v61', html.includes('ver-badge">v61</span>'));
const v61Log = (changelog.split('## v61 —')[1] || '').split('## ')[0] || '';
ok('CHANGELOG has a v61 entry in pirate speak (tall tale, the sea keeps secrets)',
  /## v61 —/.test(changelog) && /Arrr/.test(v61Log) && /sea keeps secrets/.test(v61Log) && /THREE-QUARTER/.test(v61Log));

// --- the plates + their provenance ---------------------------------------------
let platesOk = true, plateDetail = '';
for (const n of ['player-shadow-level', 'player-shadow-bank-left', 'player-shadow-bank-right', 'player-shadow-damaged']) {
  const f = path.join(ROOT, 'assets', 'sprites', 'v61', n + '.png');
  if (!fs.existsSync(f)) { platesOk = false; plateDetail = n + ' missing'; break; }
  const info = pngInfo(f);
  if (!info || info.width !== 256 || info.height !== 256 || info.bytes < 8000) { platesOk = false; plateDetail = n + ' bad: ' + JSON.stringify(info); break; }
}
ok('all 4 black-SPAD plates exist (level/bank-left/bank-right/damaged), 256x256 photographic PNGs', platesOk, plateDetail);
let stormOk = true;
for (const n of ['storm-a', 'storm-b']) {
  const info = pngInfo(path.join(ROOT, 'assets', 'sprites', 'v61', n + '.png'));
  if (!info || info.width !== 512 || info.height !== 256) stormOk = false;
}
ok('both killer-cloud plates exist (storm-a/storm-b, 512x256, cut from the cloud-sea photograph)', stormOk);
const fz = pngInfo(path.join(ROOT, 'assets', 'sprites', 'v61', 'fly-zeppelin.png'));
const fb = pngInfo(path.join(ROOT, 'assets', 'sprites', 'v61', 'fly-bomber.png'));
ok('flyover silhouette plates exist (fly-zeppelin 440x150, fly-bomber 256x256)', !!fz && fz.width === 440 && fz.height === 150 && !!fb && fb.width === 256 && fb.height === 256);
const cj = jpegInfo(path.join(ROOT, 'assets', 'sprites', 'v61', 'contact-cutin.jpg'));
ok('cut-in plate exists (contact-cutin.jpg, 440x330 photographic JPEG)', !!cj && cj.width === 440 && cj.height === 330 && cj.bytes > 10000, JSON.stringify(cj));
ok('build script records provenance (SPAD photo set + user spad-player.png, NASA ISS073-E-0028091 public domain, v48/bomber plates)',
  /player-spad-/.test(buildScript) && /spad-player\.png/.test(buildScript) &&
  /ISS073-E-0028091/.test(buildScript) && /public\s+domain/.test(buildScript) &&
  /v48-zeppelin\.png/.test(buildScript) && /enemy-bomber-level\.png/.test(buildScript) &&
  /bin\/build-v61-secrets\.py/.test(buildScript));

// --- registration ---------------------------------------------------------------
ok('black SPAD set registered in spriteArt (auto-covered by the sprite-evidence walk)',
  /shadow:loadBankedSprites\('v61\/player-shadow'\)/.test(html));
ok('v61 plates registered (stormA/stormB/flyZep/flyBomber/contact)',
  /stormA:loadImage\('assets\/sprites\/v61\/storm-a\.png'\)/.test(html) &&
  /stormB:loadImage\('assets\/sprites\/v61\/storm-b\.png'\)/.test(html) &&
  /flyZep:loadImage\('assets\/sprites\/v61\/fly-zeppelin\.png'\)/.test(html) &&
  /flyBomber:loadImage\('assets\/sprites\/v61\/fly-bomber\.png'\)/.test(html) &&
  /contact:loadImage\('assets\/sprites\/v61\/contact-cutin\.jpg'\)/.test(html));

// --- the trigger ------------------------------------------------------------------
const watchBody = bodyOf('watchShadowCrossing');
const triggerBody = bodyOf('checkShadowTrigger');
ok('crossing watch: arms only on the upward crossing of the mark, mark unearned, entitled',
  />=777/.test(watchBody) && /shadowLastLive<777/.test(watchBody) && /shadowMarkEarned\(\)/.test(watchBody) && /progress\.shadowPure!==false/.test(watchBody) && /bonusEntitled\(\)/.test(watchBody));
ok('trigger gate: QA sim can never fire it (!qaMode, like the continue offer), guests never self-trigger, entitlement re-checked at the door',
  /qaMode/.test(triggerBody) && /net\.role==='guest'/.test(triggerBody) && /bonusEntitled\(\)/.test(triggerBody));
ok('trigger fires only on a clean combat frame (no boss, no death/calm sequence, combat phase)',
  /boss\|\|bossDeath\|\|postBossCalm>0\|\|endPhase!=='combat'/.test(triggerBody));
ok('live campaign count is the banked total plus the running sortie (banking paths agree)',
  /function liveCampaignKills\(\)\{return \(progress\.totalKills\|\|0\)\+kills\}/.test(html));
ok('launch banks the interrupted sortie before the reset; the win banks the duel and carries the score back into the same sortie',
  /progress\.totalKills\+=kills;shadowStage=progress\.selected;reset\(\)/.test(bodyOf('launchShadowDuel')) &&
  /progress\.totalKills\+=kills;var keepScore=score/.test(bodyOf('returnFromShadowDuel')) &&
  /progress\.selected=shadowStage/.test(bodyOf('returnFromShadowDuel')));

// --- the challenger ------------------------------------------------------------------
ok('challenger strength: HP is 75% of the final boss effective HP (the code S32 base)',
  /Math\.round\(mirrorBaseHp\(\)\*\.75\)/.test(bodyOf('spawnShadowBoss')));
ok('challenger is a boss kind of its own, drawn from the black set with the v56 damaged swap at 72%',
  /kind:'shadow'/.test(bodyOf('spawnShadowBoss')) &&
  /b\.kind==='shadow'/.test(html) && /spriteArt\.shadow/.test(html) &&
  /updateShadowBoss\(dt\)/.test(html) && /beginShadowDeath\(\)/.test(html));
ok('the duel sky is the v59 sky (terrain routes to the prestige sky while the duel runs) and keeps scrolling',
  /if\(prestigeActive\|\|shadowActive\)\{drawPrestigeSky\(\);return\}/.test(html));
ok('stage card: the current sortie number, and the locale reads only NOWHERE — assigned as game text exactly once',
  /stageCardLocale'\)\.textContent='NOWHERE'/.test(bodyOf('showShadowCard')) &&
  (html.match(/textContent='NOWHERE'/g) || []).length === 1);
ok('silence: the whole secrets block and the duel-death path contain no say() and no showBanner() calls',
  !/say\(|showBanner\(/.test(html.slice(html.indexOf('THE SECRETS PACKAGE'), html.indexOf('function v59State'))) &&
  !/say\(|showBanner\(/.test(bodyOf('beginShadowDeath')));
ok('the duel death earns no banner (advanceBossDeath skips it explicitly)',
  /else if\(d\.shadow\)\{\/\* no banner/.test(html) &&
  /shadow:!!d\.shadow/.test(html) && /pl\.shadow\)\{returnFromShadowDuel\(\)\}/.test(html));

// --- killer clouds ---------------------------------------------------------------------
const stormBody = bodyOf('updateStormClouds');
ok('killer clouds hurt the player through hitPilot (fuel-gauge chunk, wingman buffer — the ordinary path)',
  /hitPilot\(p,p\.x,p\.y,false,'storm'\)/.test(stormBody));
ok('killer clouds hurt the challenger on the same tick rule (STORM_BOSS_HITS)',
  /STORM_BOSS_HITS=6/.test(html) && /boss\.hp=Math\.max\(0,boss\.hp-STORM_BOSS_HITS\)/.test(stormBody) && /boss\.stormTick=\.82/.test(stormBody));
ok('the challenger steers out of the clouds (repulsion computed from the cloud field and used in its pacing)',
  /function shadowCloudRepulsion\(\)/.test(html) && /shadowCloudRepulsion\(\)/.test(bodyOf('updateShadowBoss')));
ok('clouds spawn only on the duel sky, capped at three, drawn from the photographic plates',
  /if\(shadowActive\)\{stormT-=dt/.test(stormBody) && /stormClouds\.length<3/.test(stormBody) &&
  /stormClouds\.forEach\(drawStormCloud\)/.test(html));

// --- flyovers ----------------------------------------------------------------------------
const flyKindBody = bodyOf('flyoverKindForSortie');
ok('flyovers: airship and bomber on their sortie patterns; the black shape only in the approach band below the mark, mark unearned, entitled',
  /progress\.selected%4===1/.test(flyKindBody) && /progress\.selected%5===3/.test(flyKindBody) &&
  /lk>=711&&lk<777/.test(flyKindBody) && /progress\.shadowPure!==false/.test(flyKindBody) && /shadowMarkEarned\(\)/.test(flyKindBody));
ok('flyovers are drawn behind the fight and never on the duel or prestige sky',
  /drawTerrain\(\);if\(landingSeq\|\|takeoffSeq\)drawAirfield\(\);drawFlyovers\(\)/.test(html) &&
  /!prestigeActive&&!shadowActive/.test(bodyOf('updateFlyovers')));

// --- the cut-in ----------------------------------------------------------------------------
ok('cut-in: fires only from the bullet-kill branch when the shooting pilot is mid-loop, +250, suppressed while any boss is up',
  /kp\.immelmannT>0\)triggerContact\(\)/.test(html) &&
  /function triggerContact\(\)\{if\(boss\|\|contactT>0\|\|contactCd>0\)return;score\+=250/.test(html));
ok('cut-in renders the photographic plate with the period shout and the bonus — the shout exists exactly once in the game',
  /fillText\('CONTACT!',/.test(bodyOf('drawContactCutin')) && /fillText\('\+250',/.test(bodyOf('drawContactCutin')) &&
  (html.match(/CONTACT!/g) || []).length === 1);

// --- the hidden mark + bonus law ----------------------------------------------------------
ok('winning banks the hidden mark in the prestige record; a guest banks nothing (host-only credit rule)',
  /s\.shadow=true/.test(bodyOf('markShadow')) && /PRESTIGE_KEY/.test(bodyOf('markShadow')) &&
  /if\(prestigeEarnsCredit\(\)\)markShadow\(\)/.test(bodyOf('returnFromShadowDuel')));
ok('co-op: the duel state rides the net snapshot both ways (host sky + storm field for the guest)',
  /shadow:shadowActive,storm:stormClouds/.test(html) && /shadowActive=!!m\.shadow;stormClouds=m\.storm\|\|\[\]/.test(html));
ok('losing re-arms the watch just below the mark (he comes back next fight, never in a menu)',
  /shadowLastLive=776/.test(bodyOf('onFatalCrashSettled')) &&
  /shadowLastLive=776/.test(html.slice(html.indexOf('function finish(win){'), html.indexOf('function finish(win){') + 300)));

// --- exercises wired ---------------------------------------------------------------------------
ok('v61 exercises exist (duel, flyovers, cut-in) + image waiter',
  /function exerciseV61ShadowDuel\(\)/.test(html) && /function exerciseV61Flyovers\(\)/.test(html) &&
  /function exerciseV61Contact\(\)/.test(html) && /function waitForV61Images\(\)/.test(html));
ok('AceQA exposes the v61 exercises and the campaign playtest gates on them',
  /shadowDuel:function\(\)\{return exerciseV61ShadowDuel\(\)\}/.test(html) &&
  /flyovers:function\(\)\{return exerciseV61Flyovers\(\)\}/.test(html) &&
  /contactCutin:function\(\)\{return exerciseV61Contact\(\)\}/.test(html) &&
  /waitV61:function\(\)\{return waitForV61Images\(\)\}/.test(html) &&
  /report\.shadowDuel\.pass&&report\.flyovers\.pass&&report\.contactCutin\.pass/.test(html));

// --- NO text hints, NO naming ---------------------------------------------------------------------
const sayStrings = (html.match(/say\('[^']*'\)/g) || []).concat(html.match(/showBanner\('[^']*'/g) || []);
ok('no toast or banner anywhere names the secrets (no mark count, no locale, no shout in text channels)',
  !sayStrings.some(s => /777|NOWHERE|CONTACT/.test(s)), sayStrings.filter(s => /777|NOWHERE|CONTACT/.test(s)).join(' | '));
// the homage's source stays unnamed: patterns are assembled from fragments
// so the forbidden strings themselves never appear in this file either.
const forbidden = ['Mor' + 'tal Kom' + 'bat', 'Kom' + 'bat', 'Shao' + ' Kahn', 'Toa' + 'sty', 'Dan ' + 'For' + 'den', 'Ed ' + 'Boon', 'Mid' + 'way Games'];
const namedIn = forbidden.filter(f => new RegExp(f.replace(/ /g, '\\s'), 'i').test(html) || new RegExp(f.replace(/ /g, '\\s'), 'i').test(changelog));
ok('no naming violation in the game file or the log (the inspiration is never named anywhere)', namedIn.length === 0, namedIn.join(', '));

// --- invariants (must not regress) ------------------------------------------------------
ok('v59/v60 intact: continue + prestige + entitlement, mirror at 5x, fuel constants, P-38 behind the gate',
  /function exerciseV59Continue\(\)/.test(html) && /PRESTIGE_KEY='1918-prestige'/.test(html) &&
  /function bonusEntitled\(\)/.test(html) && /LAUNCH_FREE_GRANT=true/.test(html) &&
  /var hp=mirrorBaseHp\(\)\*5/.test(html) &&
  /FUEL_MAX=100,FUEL_DRAIN=\.27,FUEL_HIT=25,FUEL_SLIVER=12,FUEL_DRUM_GAIN=40,FUEL_DRUM_PERIOD=16/.test(html) && /* v62: drain x0.9 (.3 -> .27) per the tune-down; the rest of the fuel law is unchanged */
  /function p38Access\(\)\{return p38Unlocked\(\)&&bonusEntitled\(\)\}/.test(html));
ok('day-one flag intact (1918-day-one, sale end Nov 12)',
  /DAY_ONE_KEY='1918-day-one'/.test(html) && /SALE_END_MS=Date\.UTC\(2026,10,13,7,59,59\)/.test(html));
ok('1P/2P screen intact (1 PLAYER / 2 PLAYERS)', /id="chooseSolo"/.test(html) && /id="chooseCoop"/.test(html));
ok('stage card intact (stageCard + stageLocale + showSortie)', /id="stageCard"/.test(html) && /function stageLocale/.test(html) && /function showSortie/.test(html));
ok('continuous flow / true scale / fleet / boss damage / airborne / trench variety intact',
  /function exerciseV53ContinuousFlow/.test(html) && /SPAD_SPAN_M=8\.25/.test(html) &&
  /function exerciseV55ZeppelinFleet/.test(html) && /function exerciseV56BossDamage/.test(html) &&
  /function exerciseV57Airborne/.test(html) && /function exerciseV58TrenchVariety/.test(html));
ok('no Screenshot Studio (zero screenshot references)', !/screenshot/i.test(html));
ok('no HP bars on bosses or enemies (no hpbar / hp-bar)', !/hpbar/i.test(html) && !/hp-bar/i.test(html));

// --- pre-existing warnings (reported, not changed) ---------------------------------------
note('boss HP does not match standing doctrine (S1 25 -> S32 500) — code: S1 50 -> S32 220; the challenger takes 75% of the CODE S32 effective HP, per the brief');
note('the v60 static QA version-stamp checks (VERSION/badge) will read 61 and fail by design — superseded by this file; its other 38 checks are re-verified here and in the v61 playtest');
note('the duel cannot fire inside the QA campaign sim: the trigger is !qaMode-gated and the sim runs start-to-finish under qaMode — the v60 live-fire baseline (10/32) is structurally untouchable by this package');
note('live-fire sim was tuned under one-hit rules; its baseline WILL move under the gauge — reported exactly by the playtest, never tuned to');

console.log('\nv61 static QA: ' + pass + ' passed, ' + fail + ' failed, ' + warn + ' warnings');
if (failures.length) { console.log('FAILURES:'); failures.forEach(f => console.log('  - ' + f)); }
if (warnings.length) { console.log('WARNINGS:'); warnings.forEach(w => console.log('  - ' + w)); }
process.exit(fail ? 1 : 0);
