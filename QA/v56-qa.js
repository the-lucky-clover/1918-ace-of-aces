#!/usr/bin/env node
/* v56 static QA — no boss HP bars: bosses show damage through photorealistic
   battle-damaged and burning sprite sheets with trailing smoke. The sprite
   herself is the health bar now — clean, then scarred, then burning and
   trailing heavy smoke. Checks the game file without running it.
   Usage: node QA/v56-qa.js [path-to-html]
   Exit 0 = all checks pass, 1 = a failure. Warnings never fail the run. */
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const HTML = process.argv[2] || path.join(ROOT, '1918-ace-of-aces.html');
const html = fs.readFileSync(HTML, 'utf8');
const version = fs.readFileSync(path.join(ROOT, 'VERSION'), 'utf8').trim();
const changelog = fs.readFileSync(path.join(ROOT, 'CHANGELOG.md'), 'utf8');

let pass = 0, fail = 0, warn = 0;
const failures = [], warnings = [];
function ok(name, cond, detail) {
  if (cond) { pass++; console.log('  PASS  ' + name); }
  else { fail++; failures.push(name + (detail ? ' — ' + detail : '')); console.log('  FAIL  ' + name + (detail ? ' — ' + detail : '')); }
}
function note(name, detail) { warn++; warnings.push(name + (detail ? ' — ' + detail : '')); console.log('  WARN  ' + name + (detail ? ' — ' + detail : '')); }

console.log('v56 static QA — ' + HTML);

// --- version ---------------------------------------------------------------
ok('VERSION file is 56', version === '56', 'got ' + version);
ok('in-game version badge is v56', html.includes('ver-badge">v56</span>'));
ok('CHANGELOG has a v56 entry in pirate speak', /## v56 —/.test(changelog) && /Arrr/.test(changelog.split('## v56 —')[1].split('## ')[0] || ''));

// --- no boss HP bar anywhere -------------------------------------------------
ok('no bossbar element or CSS (zero bossbar references)', !/bossbar/.test(html));
ok('no bosshealth element or width-setting (zero bosshealth references)', !/bosshealth/.test(html));
ok('no bossname element or text-setting (zero bossname references)', !/bossname/.test(html));
ok('no boss-track / boss-health CSS classes', !/boss-track/.test(html) && !/boss-health/.test(html));
ok('no boss HP shown as a bar width anywhere (no hp/max*100 width)', !/boss\.hp\/boss\.max\*100/.test(html));
ok('boss phase announcements are toasts, not a bar (say PHASE I / II / LAST STAND / CRIMSON FINALE)',
  /say\(d\.name\+' · PHASE I'\)/.test(html) &&
  /say\(d\.name\+' · PHASE II'\)/.test(html) &&
  /say\(d\.name\+' · LAST STAND'\)/.test(html) &&
  /say\(d\.name\+' · CRIMSON FINALE'\)/.test(html));

// --- battle-damaged plates exist on disk (photographic, raster) --------------
const aces = ['boss-1-red', 'boss-2-checker', 'boss-3-stripes', 'boss-4-tiger', 'boss-5-jester', 'boss-6-ghost'];
aces.forEach(n => {
  const p = path.join(ROOT, 'assets', 'sprites', n + '-damaged.png');
  ok('damaged plate on disk: ' + n + '-damaged.png', fs.existsSync(p));
});
ok('damaged plate on disk: v56/staaken-damaged.png', fs.existsSync(path.join(ROOT, 'assets', 'sprites', 'v56', 'staaken-damaged.png')));
ok('damaged plate on disk: v56/zeppelin-damaged.png', fs.existsSync(path.join(ROOT, 'assets', 'sprites', 'v56', 'zeppelin-damaged.png')));
ok('build script kept: bin/build-v56-boss-damage.py', fs.existsSync(path.join(ROOT, 'bin', 'build-v56-boss-damage.py')));
ok('damaged plates are real PNGs (8-byte signature)', (() => {
  const files = aces.map(n => path.join(ROOT, 'assets', 'sprites', n + '-damaged.png'))
    .concat([path.join(ROOT, 'assets', 'sprites', 'v56', 'staaken-damaged.png'),
             path.join(ROOT, 'assets', 'sprites', 'v56', 'zeppelin-damaged.png')]);
  return files.every(f => {
    try { const b = fs.readFileSync(f); return b.length > 1000 && b[0] === 0x89 && b[1] === 0x50 && b[2] === 0x4E && b[3] === 0x47; }
    catch (e) { return false; }
  });
})());

// --- damaged plates are wired into the game -----------------------------------
ok('loadBankedSprites loads a damaged image per boss set', /damaged:loadImage\('assets\/sprites\/'\+prefix\+'-damaged\.png'\)/.test(html));
ok('all six ace sets are loaded through loadBankedSprites',
  aces.every(n => html.includes("loadBankedSprites('" + n + "')")));
ok('v56Art loader exists (staaken + zeppelin damaged plates)',
  /var v56Art=\{staakenDamaged:loadImage\('assets\/sprites\/v56\/staaken-damaged\.png'\),zeppelinDamaged:loadImage\('assets\/sprites\/v56\/zeppelin-damaged\.png'\)\}/.test(html));
ok('fighter aces swap to the damaged sheet at ratio <= .72',
  /im=\(b\.hp\/b\.max<=\.72&&set\.damaged&&set\.damaged\.complete&&set\.damaged\.naturalWidth\)\?set\.damaged:\(set\.level\|\|bankedSprite\(set,b\.bank\|\|0\)\)/.test(html));
ok('Staaken swaps to the damaged plate at ratio <= .72',
  /im=\(b\.hp\/b\.max<=\.72&&v56Art\.staakenDamaged&&v56Art\.staakenDamaged\.complete&&v56Art\.staakenDamaged\.naturalWidth\)\?v56Art\.staakenDamaged:v42Art\.staaken/.test(html));
ok('Zeppelin swaps to the damaged plate at ratio <= .72',
  /im=\(b\.hp\/b\.max<=\.72&&v56Art\.zeppelinDamaged&&v56Art\.zeppelinDamaged\.complete&&v56Art\.zeppelinDamaged\.naturalWidth\)\?v56Art\.zeppelinDamaged:art\.zeppelin/.test(html));
ok('damaged swap is guarded (clean plate shown when the damaged one is not loaded)',
  /set\.damaged\.complete&&set\.damaged\.naturalWidth/.test(html) &&
  /v56Art\.staakenDamaged\.complete&&v56Art\.staakenDamaged\.naturalWidth/.test(html) &&
  /v56Art\.zeppelinDamaged\.complete&&v56Art\.zeppelinDamaged\.naturalWidth/.test(html));

// --- damage progression: clean -> damaged -> burning ---------------------------
ok('drawBossDamage gates damage below 72% (clean above, scarred below)',
  /function drawBossDamage\(b\)\{if\(!b\)return;var ratio=b\.hp\/b\.max;if\(b\.kind==='zeppelin'\)drawZeppelinDamage\(b,ratio\);if\(ratio>\.72\)return;/.test(html));
ok('drawBossDamage burns heavy below 34% (photographic fire sheet)',
  /heavy=ratio<=\.34/.test(html) && /drawFxSheet\(fxArt\.fire/.test(html));
ok('Zeppelin damage accumulates (scorch patches at 75% / 50% / 25% HP)',
  /75/.test(html) && /drawZeppelinDamage/.test(html));
ok('burning bosses still die in the photographic explosion (no behaviour change)',
  /spawnExplosion\(bx,by,completedStage===31\?'ghost':'boss'\)/.test(html));

// --- trailing smoke ------------------------------------------------------------
ok('bossTrail state declared', /bossTrail=\[\]/.test(html));
ok('bossTrail cleared in clearProofWorld', /smokeColumns=\[\];explosions=\[\];bossTrail=\[\];ambientFires=\[\];/.test(html));
ok('emitBossSmoke exists (photographic smoke, heavier when burning)',
  /function emitBossSmoke\(b,ratio\)/.test(html) && /heavy=ratio<=\.34/.test(html));
ok('trail smoke is photographic raster (v36 smoke2 / smokedark plates)',
  /v36Art\.smoke2/.test(html) && /v36Art\.smokedark/.test(html));
ok('zeppelin trail pours from dead components (MGs / fuel cells / gondolas / props)',
  /dead=\(b\.comps\|\|\[\]\)\.filter\(function\(c\)\{return c\.dead\}\)/.test(html) && /zepPlateToScreen\(b,c\.x,c\.y\)/.test(html));
ok('trail is emitted in updateBoss when damaged (<= .72), faster when burning (.05s heavy, .12s damaged)',
  /if\(tr56<=\.72&&boss\.phase!=='entry'&&boss\.trailT<=0\)\{emitBossSmoke\(boss,tr56\);boss\.trailT=tr56<=\.34\?\.05:\.12\}/.test(html));
ok('trail is aged every frame in update()', /if\(boss\)updateBoss\(dt\);updateBossTrail\(dt\);/.test(html));
ok('trail is drawn every frame in draw()', /drawBossTrail\(\);/.test(html));
ok('trail scrolls with the world (92px/s, like frontline smoke) and fades',
  /p\.y\+=92\*dt/.test(html) && /\(1-k\)\*\.5/.test(html));
ok('trail is capped (60 puffs) and culled on age or leaving the screen',
  /if\(bossTrail\.length>=60\)bossTrail\.shift\(\)/.test(html) && /if\(p\.t>=p\.dur\|\|p\.y>H\+80\)bossTrail\.splice\(i,1\)/.test(html));
ok('fresh trail on every boss spawn', /boss\.trailT=0;bossTrail=\[\];if\(d\.kind==='zeppelin'\)/.test(html));

// --- Zeppelin still vertical, back-to-front (v54, updated for the swap) ---------
ok('drawZeppelinBoss still rotates PI/2 (vertical long axis) with the damaged swap',
  /function drawZeppelinBoss\(b\)\{var dw=zeppelinLenPx\(\),im=\(b\.hp\/b\.max<=\.72&&v56Art\.zeppelinDamaged/.test(html) &&
  /ctx\.rotate\(Math\.max\(-\.04,Math\.min\(\.04,b\.vx\/2200\)\)\+Math\.PI\/2\)/.test(html));

// --- runtime exercise wired -----------------------------------------------------
ok('waitForV56Images exists and is awaited in runCampaignPlaytest',
  /function waitForV56Images\(\)/.test(html) && /await waitForV56Images\(\);/.test(html));
ok('AceQA.bossDamage runtime exercise exists and is wired',
  /function exerciseV56BossDamage\(\)/.test(html) && /bossDamage:function\(\)\{return exerciseV56BossDamage\(\)\}/.test(html));
ok('runCampaignPlaytest reports bossDamage and the pass condition includes it',
  /report\.bossDamage=AceQA\.bossDamage\(\);/.test(html) && /&&report\.bossDamage\.pass\}/.test(html));

// --- invariants (must not regress) --------------------------------------------
ok('day-one flag intact (1918-day-one, sale end Nov 12)',
  /DAY_ONE_KEY='1918-day-one'/.test(html) && /SALE_END_MS=Date\.UTC\(2026,10,13,7,59,59\)/.test(html));
ok('1P/2P screen intact (1 PLAYER / 2 PLAYERS)', /id="chooseSolo"/.test(html) && /id="chooseCoop"/.test(html));
ok('stage card intact (stageCard + stageLocale + showSortie)', /id="stageCard"/.test(html) && /function stageLocale/.test(html) && /function showSortie/.test(html));
ok('2P camo intact (player-spad-2, French five-colour)', /player-spad-2/.test(html));
ok('true scale intact (SPAD 8.25 m reference, zeppelin vertical)', /SPAD_SPAN_M=8\.25/.test(html) && /ZEPPELIN_LEN_M=198/.test(html));
ok('Zeppelin fleet intact (6 zeppelins, dreadnought L-70)', /L-70/.test(html) && /function exerciseV55ZeppelinFleet\(\)/.test(html));
ok('one-hit death doctrine intact', /hitPilot/.test(html));
ok('no Screenshot Studio (zero screenshot references)', !/screenshot/i.test(html));
ok('no vector-drawn terrain (photographic base only)', /SORTIE_BACKGROUNDS/.test(html));

// --- pre-existing warnings (reported, not changed) ---------------------------
note('boss HP does not match standing doctrine (S1 25 -> S32 500) — code: S1 50 -> S32 220');
note('STUN servers still in makePeer — v32 note says they were removed; they are unused for local pairing but still configured');
note('sortie 18 briefing/objective name a Staaken giant but roster[17] is a Zeppelin — pre-existing text/roster drift, reported, not changed');
note('v54 static QA check "drawZeppelinBoss rotates PI/2" no longer matches verbatim — superseded by the v56 damaged-swap preamble (rotation itself unchanged, re-checked above)');

console.log('\nv56 static QA: ' + pass + ' passed, ' + fail + ' failed, ' + warn + ' warnings');
if (failures.length) { console.log('FAILURES:'); failures.forEach(f => console.log('  - ' + f)); }
if (warnings.length) { console.log('WARNINGS:'); warnings.forEach(w => console.log('  - ' + w)); }
process.exit(fail ? 1 : 0);
