#!/usr/bin/env node
/* v63 static QA — ONE CONTINUOUS PHOTOGRAPH, A TIDY SHIP, A NEW VOICE.
   (1) Photorealism restored: the audit found the last drawn scenery
   in the game — the four setpiece strips (flat vector illustrations
   from the game's infancy: red barn, hangar silhouettes, drawn
   crater rings, sandbag pattern) — replaced at the same paths with
   feathered photographic cuts of the project's own battlefield
   aerial (bin/build-v63-battlefields.py; drawn originals preserved
   in assets/sprites/.v63-backup/). The chateau Steven flagged from
   the older artifact build was already photographic in the repo
   (v38). The flat-green loading fallback is gone: the background
   draws the aerial itself. (2) Density: 13 new photographic plates
   (ruins, crater fields, trench systems, hedgerow) in a seeded
   per-sortie system whose count and weight grow with the campaign
   (3 spots early / 4 mid / 5 late). (3) Cleanup: the canvas-drawn
   minimap is removed from the flight draw entirely; the flight HUD
   carries score, fuel and sortie only (loop counter + bonus chips
   retired; the header line reads SORTIE NN · SECTOR); the CSS-drawn
   desk props (helmet/goggles/gloves/compass) are removed from the
   debrief screen; the dead bombBtn guard is gone (the repo never
   had soft LOOP/BOMB buttons — loop is back-tap, the screen bomb
   detonates on pickup). (4) Custom sound design: the continuous
   74 Hz sawtooth engine drone (gain .7) is replaced by a scheduled
   rotary putter (short lowpassed pulses at RPM rhythm, silence
   between, ~14 dB under the guns); the gun's 138 Hz square blip is
   replaced by a throttled, pitch-jittered layered tick; explosions
   are sized (noise body + triangle thump, no sawtooth below
   200 Hz); the pilot death loses its 1.4 s 82 Hz sawtooth groan;
   the KIA moment gains a solemn four-note triangle sting; pickups
   brighten to square; duplicate flakSfx/uiSfx definitions are
   struck so the chiptune kind-based uiSfx rules. (5) Pause menu
   gains SOUND and HAPTICS toggle rows (persisted in localStorage
   '1918-sound' / '1918-haptics', both default ON); haptics gate on
   their own flag, decoupled from the sound mute; the flight header
   keeps only the pause control.
   Usage: node QA/v63-qa.js [path-to-html]
   Exit 0 = all checks pass, 1 = a failure. Warnings never fail. */
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const HTML = process.argv[2] || path.join(ROOT, '1918-ace-of-aces.html');
const html = fs.readFileSync(HTML, 'utf8');
const version = fs.readFileSync(path.join(ROOT, 'VERSION'), 'utf8').trim();
const changelog = fs.readFileSync(path.join(ROOT, 'CHANGELOG.md'), 'utf8');
const buildScript = fs.readFileSync(path.join(ROOT, 'bin', 'build-v63-battlefields.py'), 'utf8');

let pass = 0, fail = 0, warn = 0;
const failures = [], warnings = [];
function ok(name, cond, detail) {
  if (cond) { pass++; console.log('  PASS  ' + name); }
  else { fail++; failures.push(name + (detail ? ' — ' + detail : '')); console.log('  FAIL  ' + name + (detail ? ' — ' + detail : '')); }
}
function note(name, detail) { warn++; warnings.push(name + (detail ? ' — ' + detail : '')); console.log('  WARN  ' + name + (detail ? ' — ' + detail : '')); }
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

console.log('v63 static QA — ' + HTML);

// --- version -----------------------------------------------------------------
ok('VERSION file is 63', version === '63', 'got ' + version);
ok('in-game version badge is v63', html.includes('ver-badge">v63</span>'));
ok('CHANGELOG has a v63 entry in pirate speak', /## v63 —/.test(changelog) && /Arrr/.test(changelog.split('## v63 —')[1].split('## ')[0] || ''));

// --- 1. the drawn setpieces are dead ------------------------------------------
for (const name of ['setpiece-aerodrome', 'setpiece-farm', 'setpiece-nomansland', 'setpiece-trench']) {
  const f = path.join(ROOT, 'assets', 'sprites', name + '.png');
  const bak = path.join(ROOT, 'assets', 'sprites', '.v63-backup', name + '.png');
  const info = fs.existsSync(f) ? pngSize(f) : null;
  ok(name + ' is now a 768x768 photographic plate (differs from the drawn original, which is backed up)',
    !!info && info.width === 768 && info.height === 768 && fs.existsSync(bak) && !fs.readFileSync(f).equals(fs.readFileSync(bak)));
}
ok('build script documents the audit, the sources and the rejected village plates',
  /flat vector/i.test(buildScript) && /terrain-aerial/.test(buildScript) && /REJECTED/.test(buildScript));
ok('zero procedural background fills remain: the #59664c flat fill is gone and the fallback draws the aerial itself',
  !html.includes('#59664c') && /if\(!bgTile\)\{if\(art\.terrain&&art\.terrain\.complete/.test(html) && /Math\.max\(W\/tw,H\/th\)/.test(html));
ok('the repo chateau plate is the photographic v38 ruins plate', html.includes("chateau:loadImage('assets/sprites/v38/v38-chateau.png')"));

// --- 2. density system -----------------------------------------------------------
const V63_PLATES = ['farmhouse', 'barn', 'factory', 'ruin', 'ruin-row', 'houses', 'farm', 'crater-dense', 'crater-water', 'crater-wide', 'trench-long', 'trench-zigzag', 'hedgerow'];
for (const p of V63_PLATES) {
  const f = path.join(ROOT, 'assets', 'sprites', 'v63', 'v63-' + p + '.png');
  ok('plate v63-' + p + '.png exists', fs.existsSync(f) && !!pngSize(f));
}
ok('v63 system wired: loader, seeded spawner, draw, terrain-pass call, AceQA exercise',
  /var v63Art=\{/.test(html) && /function spawnBattlefieldSystems\(\)/.test(html) && /function drawBattlefieldSystems\(\)/.test(html) &&
  /drawFrontlineSystems\(\);drawBattlefieldSystems\(\);wzWinterTerrain\(\)/.test(html) && /battlefieldV63:function\(\)\{return exerciseV63Battlefield\(\)\}/.test(html));
ok('density grows with the campaign (3 spots early, 4 mid, 5 late; pools shift rear -> shattered front)',
  /count=sel<8\?3:sel<20\?4:5/.test(bodyOf('spawnBattlefieldSystems')) && /craterWater/.test(bodyOf('spawnBattlefieldSystems')));

// --- 3. cleanup ---------------------------------------------------------------------
ok('minimap removed entirely (no draw function, no seeding, no call in the flight draw)',
  !/function drawMinimap/.test(html) && !/seedMinimapPuddles/.test(html) && !/drawMinimap\(\)/.test(html) && !/minimapRoutes|minimapCodes/.test(html));
ok('flight header line is the sortie readout (SORTIE NN · SECTOR), ALT/AMMO decoration gone',
  /textContent='SORTIE '\+String\(prestigeActive\?33:progress\.selected\+1\)/.test(html) && !html.includes('AMMO ∞'));
ok('loop counter + bonus chips retired from the flight HUD (writers force hidden; systems still run)',
  /lc\.hidden=true/.test(html) && /el\.hidden=true/.test(bodyOf('updateOptionalHud')));
ok('no soft LOOP/BOMB buttons exist in the DOM (and the dead bombBtn guard is gone)',
  !html.includes('id="bombBtn"') && !html.includes('bombBtn') && !/id="loopBtn"/.test(html));
ok('CSS-drawn desk props removed from the debrief screen (helmet/goggles/gloves/compass + their CSS)',
  !html.includes('prop helmet') && !/\.helmet\{/.test(html) && !/\.goggles\{/.test(html) && !/\.compass\{/.test(html) && !/\.gloves\{/.test(html));

// --- 4. sound design ------------------------------------------------------------------
const tick = bodyOf('audioTick');
ok('the engine drone is dead: audioTick holds the old oscillator gain at 0 and schedules putter pulses',
  /audio\.g\.gain\.setTargetAtTime\(0/.test(tick) && /puttPulse\(audio\.puttNext/.test(tick) && !/74\+swell/.test(tick) && /function puttPulse\(/.test(html));
ok('putter pulses are short lowpassed saws at RPM rhythm (9.5-16 pulses/s), peak .05-.07',
  /o\.frequency\.setValueAtTime\(58,when\)/.test(bodyOf('puttPulse')) && /f\.frequency\.value=210/.test(bodyOf('puttPulse')) && /rate=looping\?16:9\.5/.test(tick));
ok('gun: throttled layered tick with pitch jitter; the 138 Hz square blip is gone',
  /lastGunSfx<45/.test(bodyOf('gunSfx')) && /Math\.random\(\)\*\.12/.test(bodyOf('gunSfx')) && !html.includes('blip(138'));
ok('explosions are sized (small/medium/large) with triangle thumps; no sawtooth lows remain',
  /function explosionSfx\(size\)/.test(html) && /size==='large'/.test(bodyOf('explosionSfx')) && /size==='medium'/.test(bodyOf('explosionSfx')) &&
  !/'sawtooth'/.test(bodyOf('explosionSfx')) && !html.includes("blip(82,1.4,'sawtooth'"));
ok('bomb blast and boss booms call the grand explosion', (html.match(/explosionSfx\('large'\)/g) || []).length >= 3);
ok('exactly one flakSfx and one uiSfx definition (the chiptune kind-based uiSfx rules)',
  (html.match(/function flakSfx/g) || []).length === 1 && (html.match(/function uiSfx\(/g) || []).length === 1 && /function uiSfx\(kind\)/.test(html));
ok('KIA sting present and hooked at the fatal settle (four descending triangle notes)',
  /function kiaSting\(\)/.test(html) && /onFatalCrashSettled\(\)\{kiaSting\(\);/.test(html) && /\[196,147,131,98\]/.test(bodyOf('kiaSting')));
ok('pickup is a bright two-note square; impact is a knock; loop is an airy rise',
  /uiTone\(1318,.06,'square'/.test(bodyOf('pickupSfx')) && /uiTone\(150,.1,'triangle'/.test(bodyOf('impactSfx')) && /uiTone\(300,.4,'triangle'/.test(bodyOf('loopSfx')));

// --- 5. toggles -------------------------------------------------------------------------
ok('pause menu carries SOUND + HAPTICS rows (no text labels added anywhere else)',
  html.includes('id="pauseMusicBtn">SOUND · ON</button>') && html.includes('id="pauseHapticsBtn">HAPTICS · ON</button>'));
ok('both toggles persist (1918-sound / 1918-haptics) with ON defaults',
  /localStorage\.setItem\('1918-sound'/.test(html) && /localStorage\.getItem\('1918-sound'\)==='0'/.test(html) &&
  /localStorage\.setItem\('1918-haptics'/.test(html) && /localStorage\.getItem\('1918-haptics'\)!=='0'/.test(html));
ok('haptics gate on their own flag (decoupled from the sound mute)',
  /if\(!hapticsOn\|\|!\('vibrate' in navigator\)/.test(bodyOf('buzz')));
ok('audio init respects the persisted sound preference', /audio\.master\.gain\.value=muted\?0:\.095/.test(html));
ok('flight header keeps only the pause control (no new header buttons)', !/id="soundBtn"|id="hapticsBtn"|id="muteBtn"/.test(html));

// --- integrity spot checks -----------------------------------------------------------------
ok('launch law intact (day-one, SALE_END, entitlement)', /DAY_ONE_KEY='1918-day-one'/.test(html) && /SALE_END_MS=Date\.UTC\(2026,10,13,7,59,59\)/.test(html) && /function bonusEntitled/.test(html));
ok('continues + purity + mirror x5 intact', /function openContinueOffer/.test(html) && /progress\.shadowPure=false/.test(html) && /mirrorBaseHp\(\)\*5/.test(html));

note('sound is judged by ear: the mix table (pre-master gains) — engine putter .05, wind .012-.03, gun .045-.055, impact .04-.05, flak .035-.05, explosions .09-.20 by size, pickup .032, UI .02-.035, KIA sting .045 — is recorded in bin/../QA/../CHANGELOG v63 and the build report');
note('boss HP doctrine drift (S1 50 -> S32 220 in code vs 25 -> 500 standing) is pre-existing and untouched by v63');

console.log('\nv63 static QA: ' + pass + ' passed, ' + fail + ' failed, ' + warn + ' warnings');
if (failures.length) { console.log('FAILURES:'); failures.forEach(f => console.log('  - ' + f)); }
if (warnings.length) { console.log('WARNINGS:'); warnings.forEach(w => console.log('  - ' + w)); }
process.exit(fail ? 1 : 0);
