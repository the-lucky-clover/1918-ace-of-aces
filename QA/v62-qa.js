#!/usr/bin/env node
/* v62 static QA — GERMAN SKIES, A GENTLER WAR, A MEMORIAL DRESS.
   The Cap'n's five orders after his v61 playtest: (1) no Allied
   aircraft in enemy squadrons — the two Allied shapes hiding in the
   generic classes (a de-badged SPAD 'scout', a Sopwith 'triplane')
   are rebuilt photographically as a Pfalz D.III in line finish and a
   Fokker Dr.I in streaked olive (bin/build-v62-roster.py; the
   player's SPAD, the Sortie 33 mirror, and the black challenger are
   exempt by design — they are the pilot's own aircraft, not
   squadrons); (2) the second tune-down — bullet peak 22 -> 16,
   bullet speed x0.9, fire intervals x1.2, sortie ramp 6% -> 4%, boss
   patterns one step gentler, fuel drain x0.9, mechanics untouched;
   (3) enemy bullets as pre-rendered pulsing orange-red glow sprites,
   phase-offset per bullet, no per-frame shadowBlur; (4) every screen
   reskinned to the memorial system — blackletter display, black
   grounds, white text, imperial red spent sparingly, no cheering
   copy; (5) the reading slashed — one-line briefings (<= 90 chars),
   one-sentence almanac entries, source credits merged to one line
   with every credit kept. Plus the shadow rulings: the challenger
   now arms at exactly 777 on the cumulative campaign counter
   (approach band 711-776, loss re-arms at 776), and the shadow path
   demands campaign purity — any continue used burns the flag for
   that campaign (progress.shadowPure), silently; continues
   themselves are untouched, and Sortie 33 / the P-38 keep their
   zero-continue gates.
   Constants updated in older QA per the tune-down: QA/v46-qa.js
   (BULLET_PEAK late >= 22 -> >= 16, S32 peak 22 -> 16, boss radial
   cap 12 -> 10); QA/v61-qa.js + QA/v61-playtest.js (shadow 666/665/
   600 assertions -> 777/776/711 + purity). v43-era peak pins (>= 30)
   were already superseded by v46 and are history.
   Usage: node QA/v62-qa.js [path-to-html]
   Exit 0 = all checks pass, 1 = a failure. Warnings never fail. */
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const HTML = process.argv[2] || path.join(ROOT, '1918-ace-of-aces.html');
const html = fs.readFileSync(HTML, 'utf8');
const version = fs.readFileSync(path.join(ROOT, 'VERSION'), 'utf8').trim();
const changelog = fs.readFileSync(path.join(ROOT, 'CHANGELOG.md'), 'utf8');
const rosterScript = fs.readFileSync(path.join(ROOT, 'bin', 'build-v62-roster.py'), 'utf8');

let pass = 0, fail = 0, warn = 0;
const failures = [], warnings = [];
function ok(name, cond, detail) {
  if (cond) { pass++; console.log('  PASS  ' + name); }
  else { fail++; failures.push(name + (detail ? ' — ' + detail : '')); console.log('  FAIL  ' + name + (detail ? ' — ' + detail : '')); }
}
function note(name, detail) { warn++; warnings.push(name + (detail ? ' — ' + detail : '')); console.log('  WARN  ' + name + (detail ? ' — ' + detail : '')); }

console.log('v62 static QA — ' + HTML);

function bodyOf(name) {
  const at = html.indexOf('function ' + name + '(');
  if (at < 0) return '';
  const next = html.indexOf('\nfunction ', at + 10);
  return html.slice(at, next < 0 ? at + 4000 : next);
}
function pngSize(file) {
  const buf = fs.readFileSync(file);
  if (buf.length < 24 || buf[0] !== 0x89 || buf[1] !== 0x50) return null;
  return { width: buf.readUInt32BE(16), height: buf.readUInt32BE(20), bytes: buf.length };
}

// --- version -----------------------------------------------------------------
ok('VERSION file is 62', version === '62', 'got ' + version);
ok('in-game version badge is v62', html.includes('ver-badge">v62</span>'));
ok('CHANGELOG has a v62 entry in pirate speak', /## v62 —/.test(changelog) && /Arrr/.test(changelog.split('## v62 —')[1].split('## ')[0] || ''));

// --- 1. roster: German types only ---------------------------------------------
const archMatch = html.match(/var ENEMY_ARCHETYPES=\{([\s\S]*?)\};/);
ok('ENEMY_ARCHETYPES table found', !!archMatch);
const GERMAN_SPRITES = new Set(['scout', 'fighter', 'bomber', 'triplane', 'dri', 'dvii', 'dva', 'eiii', 'pfalz', 'gotha', 'clii', 'rumpler', 'junkers', 'taube']);
let spritesUsed = [];
if (archMatch) {
  spritesUsed = [...archMatch[1].matchAll(/sprite:'([a-z0-9]+)'/g)].map(m => m[1]);
  ok('every enemy archetype flies a German sprite set', spritesUsed.length >= 14 && spritesUsed.every(sp => GERMAN_SPRITES.has(sp)), spritesUsed.join(','));
}
ok('no Allied type names anywhere in the game file (Nieuport/Sopwith/Camel/Bristol/S.E.5)', !/nieuport|sopwith|camel|bristol/i.test(html));
ok('scout class re-based to the Pfalz D.III span (small:9.4) at true scale (size 120, fillW 168)',
  /small:9\.4/.test(html) && /small:\{hp:3,r:15,size:120/.test(html) && /scout:168/.test(html));
ok('triplane class re-based to the Fokker Dr.I span (triplane:7.19) at true scale (size 103, fillW 150)',
  /triplane:7\.19/.test(html) && /triplane:\{hp:18,r:20,size:103/.test(html) && /triplane:150/.test(html));
ok('roster build script documents the Pfalz D.III + Fokker Dr.I photographic sources',
  /Pfalz D\.III/.test(rosterScript) && /Fokker Dr\.I/.test(rosterScript) && /enemy-pfalz-level\.png/.test(rosterScript) && /enemy-dri-level\.png/.test(rosterScript));
for (const set of ['scout', 'triplane']) {
  for (const pose of ['level', 'bank-left', 'bank-right', 'damaged']) {
    const f = path.join(ROOT, 'assets', 'sprites', 'enemy-' + set + '-' + pose + '.png');
    const bak = path.join(ROOT, 'assets', 'sprites', '.v62-backup', 'enemy-' + set + '-' + pose + '.png');
    const info = fs.existsSync(f) ? pngSize(f) : null;
    ok('plate enemy-' + set + '-' + pose + '.png is 256x256 and rebuilt (differs from the v57 original)',
      !!info && info.width === 256 && info.height === 256 && fs.existsSync(bak) && !fs.readFileSync(f).equals(fs.readFileSync(bak)));
  }
}
ok('exemptions untouched: player SPAD set, mirror and shadow still fly the SPAD plates',
  /player-spad-level/.test(html) && /kind:'mirror'/.test(html) && /kind:'shadow'/.test(html) &&
  /v61\/player-shadow/.test(html));

// --- 2. tune-down ---------------------------------------------------------------
const peakMatch = html.match(/var BULLET_PEAK=\[([\d,\s]+)\];/);
ok('BULLET_PEAK table exists', !!peakMatch);
if (peakMatch) {
  const peak = peakMatch[1].split(',').map(v => +v.trim());
  ok('BULLET_PEAK has 32 entries, monotonic, peak exactly 16',
    peak.length === 32 && Math.max(...peak) === 16 && peak.every((v, i) => i === 0 || v >= peak[i - 1]), peak.join(','));
  ok('opening sorties stay gentle (S1 peak <= 7)', peak[0] <= 7, 'S1=' + peak[0]);
}
ok('enemy bullet speed x0.9 at the single spawn gate (hostileBullet)', /speed\*=\.9/.test(bodyOf('hostileBullet')));
ok('per-bullet pulse seed assigned at spawn', /seed:Math\.random\(\)\*6\.283/.test(bodyOf('hostileBullet')));
ok('enemy fire intervals x1.2 at the reset site', /bulletHellFireRate\(\)\*1\.2/.test(html));
ok('sortie fire-rate ramp softened 6% -> 4%', /Math\.min\(\.04,progress\.selected\*\.002\)/.test(html) && !/Math\.min\(\.06,progress\.selected\*\.002\)/.test(html));
const sigBody = bodyOf('bossSignature');
ok('boss radial cap 12 -> 10, aimed fan cap 7 -> 5',
  /Math\.min\(10,8\+boss\.stage\+level\*2\)/.test(sigBody) && /Math\.min\(5,5\+level\*2\)/.test(sigBody));
ok('boss forward-gun fan cap 7 -> 5', /Math\.min\(5,4\+Math\.floor\(bs\/2\)\)/.test(html));
ok('mirror + shadow signatures one step gentler',
  /radialPattern\(boss\.x,boss\.y\+16,10\+level\*2/.test(bodyOf('mirrorSignature')) &&
  /radialPattern\(boss\.x,boss\.y\+16,8\+level\*2/.test(bodyOf('shadowSignature')));
ok('fuel drain x0.9 (.3 -> .27); hit chunk -25 and drums +40 unchanged',
  /FUEL_DRAIN=\.27/.test(html) && /FUEL_HIT=25/.test(html) && /FUEL_DRUM_GAIN=40/.test(html));
ok('enemy/boss HP untouched (small 3, triplane 18, gotha 40, ghost 220)',
  /small:\{hp:3/.test(html) && /triplane:\{hp:18/.test(html) && /gotha:\{hp:40/.test(html) && /THE CRIMSON GHOST[^}]*hp:220/.test(html));

// --- 3. glow bullets --------------------------------------------------------------
ok('glow phases pre-rendered offscreen (6 radial-gradient sprites)',
  /var glowPhases=\[\]/.test(html) && /createRadialGradient\(32,32,0,32,32/.test(html) && /rgba\(255,64,22/.test(html));
const bulletDraw = html.slice(html.indexOf('enemyBullets.forEach(function(b){var gp=glowPulse'), html.indexOf('enemyBullets.forEach(function(b){var gp=glowPulse') + 500);
ok('enemy bullets drawn from the glow phases, phase-offset per bullet (seed-driven pulse)',
  bulletDraw.length > 100 && /drawImage\(glowPhases/.test(bulletDraw) && /glowPulse\(b\)/.test(bulletDraw) && /b\.seed/.test(html.slice(html.indexOf('function glowPulse'), html.indexOf('function glowPulse') + 120)));
ok('no shadowBlur added by the glow renderer', !/shadowBlur/.test(bulletDraw));
ok('player bullets keep their plain tracer look (no glow sprite on the player draw)',
  /bullets\.forEach\(function\(b\)\{drawFx\(fxArt\.tracer,b\.x,b\.y,26/.test(html));

// --- 4. memorial reskin -------------------------------------------------------------
ok('memorial palette on :root (black paper, white ink, imperial red, brass/olive retired to grey/black)',
  /--paper:#070707/.test(html) && /--ink:#f4f1ea/.test(html) && /--red:#a51f26/.test(html));
ok('blackletter is the display face for the key screens (title, manual, almanac, wingman, result, pause, campaign select, pairing, continue)',
  /\.hero h1,\.manual h2,\.almanac h2,\.wingman h2,\.result h2,\.pause-card h2,\.campaign-select h2,\.pairing-screen h2,\.continue-card h2\{font-family:"UnifrakturMaguntia"/.test(html));
ok('stage card restyled: blackletter number in imperial red, locale in white (v50 pink/yellow superseded by the later cascade block)',
  /\.stage-card strong\{font:400 clamp\(30px,7\.5vw,46px\)\/1 "UnifrakturMaguntia",Georgia,serif;color:#b01e24/.test(html) &&
  /\.stage-card span\{color:#f4f1ea\}/.test(html) && html.indexOf('v62 MEMORIAL RESKIN') > html.indexOf('color:#ff2d78'));
ok('continue count restyled by the reskin block (blackletter, white — the v50 pink rule is overridden later in the sheet)',
  /\.continue-count\{font:400 clamp\(44px,11vw,72px\)\/1 "UnifrakturMaguntia",Georgia,serif;color:#f4f1ea/.test(html));
ok('fuel-gauge chrome is black with a white rule (fill colour stays JS-driven: green/amber/red)',
  /\.integrity-track\{background:#050505;border:2px solid rgba\(244,241,234,.78\)\}/.test(html) &&
  /bar\.style\.backgroundColor=ratio>\.6/.test(html));
ok('solemn copy: victory reads "Sortie complete."; no cheering strings remain',
  html.includes("'Sortie complete.'") && !html.includes('SORTIE CLEAR') && !html.includes('MISSION ACCOMPLISHED') &&
  !html.includes('FINISH THE FIGHT') && !html.includes('BACK IN THE FIGHT') && !html.includes('BACK INTO THE FIGHT'));
ok('the honor-roll KIA line stands ("His chair stands empty")', html.includes('His chair<br>stands empty'));
ok('Armistice reverence intact in the finale text', html.includes('the eleventh day, the eleventh month'));

// --- 5. reading slashed ---------------------------------------------------------------
const campAt = html.indexOf('var campaign=[');
const camp = html.slice(campAt, html.indexOf('];', campAt));
const briefs = [...camp.matchAll(/brief:'([^']*)'/g)].map(m => m[1]);
const resps = [...camp.matchAll(/responsibility:'([^']*)'/g)].map(m => m[1]);
ok('all 32 sortie briefings are one line of <= 90 chars', briefs.length === 32 && briefs.every(b => b.length <= 90),
  briefs.length ? 'longest=' + Math.max(...briefs.map(b => b.length)) : 'none found');
ok('all 32 responsibility notes are <= 90 chars', resps.length === 32 && resps.every(r => r.length <= 90),
  resps.length ? 'longest=' + Math.max(...resps.map(r => r.length)) : 'none found');
const almAt = html.indexOf('id="almanac"');
const alm = html.slice(almAt, html.indexOf('</section>', almAt));
const almParas = [...alm.matchAll(/<article class="almanac-entry[^"]*">(?:<h3>[^<]*<\/h3>)?<p>([^<]*)<\/p>/g)].map(m => m[1]);
ok('every almanac entry is headline + at most one sentence',
  almParas.length >= 9 && almParas.every(p => (p.match(/[.!?](\s|$)/g) || []).length <= 1),
  almParas.map(p => (p.match(/[.!?](\s|$)/g) || []).length).join(','));
const notes = [...alm.matchAll(/<p class="source-note">([\s\S]*?)<\/p>/g)].map(m => m[1]);
ok('source credits merged to exactly ONE line, every credit kept (NVMM, NMUSAF, swisstopo, NASA, USAAF)',
  notes.length === 1 && /National Veterans Memorial and Museum/.test(notes[0]) && /National Museum of the U\.S\. Air Force/.test(notes[0]) &&
  /©swisstopo/.test(notes[0]) && /NASA \(public domain\)/.test(notes[0]) && /U\.S\. Army Air Forces \(public domain\)/.test(notes[0]),
  'source-note count=' + notes.length);
const manAt = html.indexOf('id="manual"');
const man = html.slice(manAt, html.indexOf('</section>', manAt));
const manParas = [...man.matchAll(/<div class="manual-item"><strong>[^<]*<\/strong><p>([^<]*)<\/p>/g)].map(m => m[1]);
ok('manual items cut to one short line each', manParas.length === 5 && manParas.every(p => p.length <= 95), manParas.map(p => p.length).join(','));
ok('title hero carries no paragraph beyond the single line', html.includes('<p>Choose the next operation.</p>') && !html.includes('Fly hard. Bring the 94th home.'));
ok('pairing lede cut to labels', html.includes('Pilot 1 hosts. Pilot 2 joins by field signal.'));
ok('no text anywhere hints at the shadow (silence law holds)', (() => {
  const says = [...html.matchAll(/say\('([^']*)'\)/g)].map(m => m[1]);
  return !says.some(t => /777|shadow|purity|pure/i.test(t));
})());

// --- shadow rulings: 777 + campaign purity; continues untouched -------------------------
const watchBody = bodyOf('watchShadowCrossing');
ok('shadow trigger arms at exactly 777 on the cumulative campaign counter, purity-gated',
  />=777/.test(watchBody) && /shadowLastLive<777/.test(watchBody) && /progress\.shadowPure!==false/.test(watchBody) && /liveCampaignKills\(\)/.test(watchBody));
ok('approach silhouette band is 711-776 on the campaign counter, purity-gated',
  /lk>=711&&lk<777/.test(bodyOf('flyoverKindForSortie')) && /progress\.shadowPure!==false/.test(bodyOf('flyoverKindForSortie')));
ok('duel loss re-arms at 776 on both settle paths', (html.match(/shadowLastLive=776/g) || []).length === 2);
ok('purity flag: defaults pure, carried in campaign files, restored on load (pre-v62 files read as pure)',
  /shadowPure:true/.test(html) && /shadowPure:progress\.shadowPure!==false/.test(html) && /progress\.shadowPure=d\.shadowPure!==false/.test(html));
ok('using a continue burns the flag — inside acceptContinue, beside the counter',
  /continuesUsed\+\+;progress\.shadowPure=false/.test(bodyOf('acceptContinue')));
ok('no discarded watch-counter design remains in the file', !/shadowWatch|liveShadowWatch/.test(html));
ok('continue system untouched (10-second offer, counter, host-only co-op)',
  /continueOffer={t:10/.test(bodyOf('openContinueOffer') + html.slice(html.indexOf('var continueOffer'), html.indexOf('var continueOffer') + 60)) &&
  /function openContinueOffer/.test(html) && /CONTINUES USED/.test(html));
ok('Sortie 33 + P-38 zero-continue gates unchanged', (html.match(/continuesUsed===0/g) || []).length >= 2 &&
  /markPrestige\(true,true\);if\(continuesUsed===0\)markP38Unlocked\(\)/.test(html) &&
  /progress\.selected===campaign\.length-1&&continuesUsed===0\)markPrestige\(true,false\)/.test(html));
ok('in-game exercises carry the purity leg and the 776/777 legs',
  /out\.purityBlocks/.test(bodyOf('exerciseV61ShadowDuel')) && /lockedAt776/.test(bodyOf('exerciseV61ShadowDuel')) && /triggersAt777/.test(bodyOf('exerciseV61ShadowDuel')));

// --- integrity: v58-v61 systems -----------------------------------------------------------
ok('fuel gauge + drums intact', /FUEL_MAX=100/.test(html) && /function exerciseV60Fuel/.test(html) && /type:'fuel'/.test(html));
ok('screen bomb intact (blast pickup + its exercise)', /function armBlast/.test(html) && /function exerciseV60Blast/.test(html));
ok('Sortie 33 mirror still at 5x the Ghost', /mirrorBaseHp\(\)\*5/.test(html));
ok('P-38 unlock path + plates intact', /markP38Unlocked/.test(html) && fs.existsSync(path.join(ROOT, 'assets', 'sprites', 'v60', 'player-p38-level.png')));
ok('CONTACT! cut-in intact', /function exerciseV61Contact/.test(html) && /function triggerContact/.test(html) && /function drawContactCutin/.test(html));
ok('entitlement + day-one + SALE_END intact',
  /DAY_ONE_KEY='1918-day-one'/.test(html) && /SALE_END_MS=Date\.UTC\(2026,10,13,7,59,59\)/.test(html) && /function bonusEntitled/.test(html));
ok('no Screenshot Studio, no boss HP bars', !/screenshot/i.test(html) && !/hpbar/i.test(html) && !/hp-bar/i.test(html));

// --- warnings ---------------------------------------------------------------------------------
note('boss HP still does not match standing doctrine (S1 25 -> S32 500) — code S1 50 -> S32 220 x0.86; untouched by v62 per the bounded tune-down');
note('the v61 static QA version-stamp checks (VERSION/badge = 61) fail on this tree by design — superseded by this file; its shadow assertions were updated in place to 777/776/711 + purity');
note('sim beatability is reported by QA/v61-playtest.js exactly as measured — expect it to rise under the tune-down; jitter between runs is normal');

console.log('\nv62 static QA: ' + pass + ' passed, ' + fail + ' failed, ' + warn + ' warnings');
if (failures.length) { console.log('FAILURES:'); failures.forEach(f => console.log('  - ' + f)); }
if (warnings.length) { console.log('WARNINGS:'); warnings.forEach(w => console.log('  - ' + w)); }
process.exit(fail ? 1 : 0);
