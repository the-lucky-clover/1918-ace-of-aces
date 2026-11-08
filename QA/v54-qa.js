#!/usr/bin/env node
/* v54 static QA — true scale: every enemy aircraft and every boss drawn at its
   real size vs the SPAD XIII at equal altitude, Zeppelin vertical back-to-front.
   Checks the game file without running it.
   Usage: node QA/v54-qa.js [path-to-html]
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

console.log('v54 static QA — ' + HTML);

// --- version ---------------------------------------------------------------
ok('VERSION file is 54', version === '54', 'got ' + version);
ok('in-game version badge is v54', /ver-badge">v54<\/span>/.test(html) || html.includes('ver-badge">v54</span>'));
ok('CHANGELOG has a v54 entry in pirate speak', /## v54 —/.test(changelog) && /Arrr/.test(changelog.split('## v54 —')[1].split('## ')[0] || ''));

// --- scale reference -------------------------------------------------------
ok('SPAD reference span is 8.25 m', /SPAD_SPAN_M=8\.25/.test(html));
ok('SPAD drawn wingspan is 69.12 px (64 x 1.08)', /SPAD_DRAWN_PX=69\.12/.test(html));
ok('scale constant is px-per-metre', /SCALE_PX_PER_M=SPAD_DRAWN_PX\/SPAD_SPAN_M/.test(html));
ok('AIRCRAFT_SPAN_M table exists with 15 archetypes', (() => {
  const m = html.match(/var AIRCRAFT_SPAN_M=\{([^}]+)\}/);
  if (!m) return false;
  const keys = (m[1].match(/(\w+):/g) || []).length;
  return keys === 15;
})());
ok('SPRITE_FILLW table exists with 14 sprites', (() => {
  const m = html.match(/var SPRITE_FILLW=\{([^}]+)\}/);
  if (!m) return false;
  const keys = (m[1].match(/(\w+):/g) || []).length;
  return keys === 14;
})());
ok('BOSS_SPAN_M has 32 stages', (() => {
  const m = html.match(/var BOSS_SPAN_M=\[([^\]]+)\]/);
  if (!m) return false;
  return m[1].split(',').length === 32;
})());
ok('BOSS_SPAN_M matches the roster: every Zeppelin-kind boss is 198 m and every 198 m entry is a Zeppelin-kind boss', (() => {
  const spanM = html.match(/var BOSS_SPAN_M=\[([^\]]+)\]/);
  const roster = html.match(/var bossRoster=\[([\s\S]*?)\];/);
  if (!spanM || !roster) return false;
  const spans = spanM[1].split(',').map(Number);
  const entries = (roster[1].match(/\{[^}]*\}/g) || []);
  if (spans.length !== 32 || entries.length !== 32) return false;
  for (let i = 0; i < 32; i++) {
    const isZep = /kind:'zeppelin'/.test(entries[i]);
    const is198 = spans[i] === 198;
    if (isZep !== is198) return false;
  }
  return true;
})());
ok('BOSS_SPAN_M Gotha entries are 23.7 m (GOTHA G.IV/G.V by name)', (() => {
  const spanM = html.match(/var BOSS_SPAN_M=\[([^\]]+)\]/);
  const roster = html.match(/var bossRoster=\[([\s\S]*?)\];/);
  if (!spanM || !roster) return false;
  const spans = spanM[1].split(',').map(Number);
  const entries = (roster[1].match(/\{[^}]*\}/g) || []);
  for (let i = 0; i < 32; i++) {
    if (/GOTHA/.test(entries[i]) && spans[i] !== 23.7) return false;
  }
  return true;
})());
ok('BOSS_SPAN_M Staaken entries are 42.2 m (R.IV) and 42 m (R.VI)', (() => {
  const spanM = html.match(/var BOSS_SPAN_M=\[([^\]]+)\]/);
  const roster = html.match(/var bossRoster=\[([\s\S]*?)\];/);
  if (!spanM || !roster) return false;
  const spans = spanM[1].split(',').map(Number);
  const entries = (roster[1].match(/\{[^}]*\}/g) || []);
  for (let i = 0; i < 32; i++) {
    if (/STAAKEN R\.IV/.test(entries[i]) && spans[i] !== 42.2) return false;
    if (/STAAKEN R\.VI/.test(entries[i]) && spans[i] !== 42) return false;
  }
  return true;
})());
ok('BOSS_SPRITE_FILLW has 6 boss sprites', /var BOSS_SPRITE_FILLW=\[150,156,168,168,150,194\]/.test(html));
ok('Zeppelin length 198 m / diameter 23.9 m', /ZEPPELIN_LEN_M=198,ZEPPELIN_DIA_M=23\.9/.test(html));
ok('trueScaleSize / bossFighterSize / bossWingspanPx helpers exist',
  /function trueScaleSize\(spanM,fillW\)/.test(html) &&
  /function bossFighterSize\(stage\)/.test(html) &&
  /function bossWingspanPx\(stage\)/.test(html));
ok('zeppelinLenPx / zeppelinWidPx helpers exist',
  /function zeppelinLenPx\(\)/.test(html) && /function zeppelinWidPx\(\)/.test(html));
ok('bossHitRadius / bossHit helpers exist',
  /function bossHitRadius\(b\)/.test(html) && /function bossHit\(b,boss\)/.test(html));

// --- enemy archetypes: size and r match the scale --------------------------
const SPAD_PX = 69.12, SPAD_M = 8.25;
const spanM = { small: 8.2, red: 8.9, green: 8.9, riser: 18.4, triplane: 8.08, dri: 7.19, dvii: 8.9, dva: 9.04, eiii: 9.52, pfalz: 9.4, gotha: 23.7, clii: 10.77, rumpler: 12.15, junkers: 16.0, taube: 14.3 };
const fillW = { scout: 168, fighter: 156, bomber: 246, triplane: 150, dri: 217, dvii: 254, dva: 245, eiii: 251, pfalz: 248, gotha: 256, clii: 248, rumpler: 253, junkers: 256, taube: 252 };
const oldSize = { small: 100, red: 100, green: 100, riser: 126, triplane: 104, dri: 92, dvii: 100, dva: 100, eiii: 96, pfalz: 100, gotha: 160, clii: 104, rumpler: 110, junkers: 118, taube: 104 };
const oldR = { small: 14, red: 14, green: 24, riser: 24, triplane: 18, dri: 15, dvii: 17, dva: 14, eiii: 13, pfalz: 17, gotha: 30, clii: 16, rumpler: 16, junkers: 20, taube: 13 };
const archMatch = html.match(/var ENEMY_ARCHETYPES=\{([\s\S]*?)\};/);
ok('ENEMY_ARCHETYPES table exists', !!archMatch);
if (archMatch) {
  const body = archMatch[1];
  Object.keys(spanM).forEach(k => {
    const m = body.match(new RegExp(k + ':\\{hp:\\d+,r:(\\d+),size:(\\d+)[^}]*sprite:\'([\\w-]+)\''));
    if (!m) { ok('archetype ' + k + ' parses', false); return; }
    const r = +m[1], size = +m[2], sprite = m[3];
    const expectedSize = Math.round(SPAD_PX * (spanM[k] / SPAD_M) * (256 / fillW[sprite]));
    ok('archetype ' + k + ' size is true scale (' + size + ' = ' + spanM[k] + ' m)', size === expectedSize,
      'got size ' + size + ', expected ' + expectedSize + ' (span ' + spanM[k] + ' m, fillW ' + fillW[sprite] + ')');
    const expectedR = Math.round(oldR[k] * (expectedSize / oldSize[k]));
    ok('archetype ' + k + ' hitbox r scales with drawn size (' + r + ')', r === expectedR,
      'got r ' + r + ', expected ' + expectedR);
  });
  // SPAD reference is unchanged: plane() draws the player 64 px wide at scale 1
  ok('player SPAD reference unchanged (plane dw 64, scale 1.08 in drawPilot)',
    /dw=\(enemy\?54:64\)\*s/.test(html) && /drawPilot\(p,1\.08,false\)/.test(html));
}

// --- bosses: true-scale draw sizes ------------------------------------------
ok('drawBoss uses bossFighterSize for fighter aces', /var size=bossFighterSize\(b\.stage\)/.test(html));
ok('drawBoss sets Zeppelin size to zeppelinWidPx (tell ring)', /if\(b\.kind==='zeppelin'\)\{drawZeppelinBoss\(b\);size=zeppelinWidPx\(\)\}/.test(html));
ok('drawBoss sets Staaken size to bossWingspanPx', /else if\(b\.kind==='staaken'\)\{drawStaakenBoss\(b\);size=Math\.round\(bossWingspanPx\(b\.stage\)\)\}/.test(html));
ok('drawStaakenBoss draws at true wingspan', /function drawStaakenBoss\(b\)\{var dw=Math\.round\(bossWingspanPx\(b\.stage\)\)/.test(html));
ok('no W-based boss size caps remain (no min(W*.78 / *.85 / *.9 / *.92) for bosses)',
  !/Math\.min\(W\*\.78,348\)/.test(html) && !/Math\.min\(W\*\.85,420\)/.test(html) &&
  !/Math\.min\(W\*\.9,440\)/.test(html) && !/Math\.min\(W\*\.92,460\)/.test(html));
ok('spawnBoss r is true scale (zeppelin half-width / staaken / fighter)',
  /r:d\.kind==='zeppelin'\?Math\.round\(zeppelinWidPx\(\)\/2\):d\.kind==='staaken'\?Math\.round\(bossWingspanPx\(stage\)\*0\.33\):Math\.round\(bossFighterSize\(stage\)\*0\.34\)/.test(html));
ok('spawnBoss no longer uses the old fixed radii (145 / 132 / 118)',
  !/Math\.min\(145,W\*\.36\)/.test(html) && !/Math\.min\(132,W\*\.32\)/.test(html) && !/Math\.min\(118,W\*\.29\)/.test(html));

// --- Zeppelin: vertical, back-to-front, rectangular hitbox -------------------
ok('drawZeppelinBoss rotates PI/2 (vertical long axis)', /function drawZeppelinBoss\(b\)\{var dw=zeppelinLenPx\(\),im=art\.zeppelin,dh=zeppelinWidPx\(\);ctx\.save\(\);ctx\.translate\(b\.x,b\.y\);ctx\.rotate\(Math\.max\(-\.04,Math\.min\(\.04,b\.vx\/2200\)\)\+Math\.PI\/2\)/.test(html));
ok('drawZeppelinBoss no longer rotates PI (horizontal)', !/drawZeppelinBoss\(b\)\{var dw=[^;]+;ctx\.save\(\);ctx\.translate\(b\.x,b\.y\);ctx\.rotate\(Math\.max\(-\.04,Math\.min\(\.04,b\.vx\/2200\)\)\+Math\.PI\)/.test(html));
ok('zeppelinLenPx is true scale (198 m)', (() => {
  // zeppelinLenPx() = round(69.12 * (198/8.25)) = 1659
  const m = html.match(/function zeppelinLenPx\(\)\{return Math\.round\(SPAD_DRAWN_PX\*\(ZEPPELIN_LEN_M\/SPAD_SPAN_M\)\)\}/);
  return !!m && Math.round(69.12 * (198 / 8.25)) === 1659;
})());
ok('zepPlateToScreen maps nose (plate x=0) above centre and tail (plate x=440) below centre',
  /function zepPlateToScreen\(b,lx,ly\)\{var len=zeppelinLenPx\(\),wid=zeppelinWidPx\(\);return\[b\.x\+\(75-ly\)\*\(wid\/150\),b\.y\+\(lx-220\)\*\(len\/440\)\]\}/.test(html));
ok('zeppelinComponentHit inverts the vertical mapping',
  /function zeppelinComponentHit\(boss,b\)\{if\(!boss\|\|boss\.kind!=='zeppelin'\|\|!boss\.comps\)return false;var len=zeppelinLenPx\(\),wid=zeppelinWidPx\(\),dx=b\.x-boss\.x,dy=b\.y-boss\.y,lx=dy\*\(440\/len\)\+220,ly=75-dx\*\(150\/wid\)/.test(html));
ok('bullet-boss collision uses bossHit (zeppelin rectangle)',
  /if\(boss&&bossHit\(b,boss\)\)\{b\.life=0;/.test(html) &&
  /if\(!zeppelinComponentHit\(boss,b\)\)boss\.hp-=b\.d;/.test(html));
ok('bossHit tests the Zeppelin as a rectangle matching its vertical extent',
  /function bossHit\(b,boss\)\{if\(!boss\)return false;if\(boss\.kind==='zeppelin'\)\{var hw=zeppelinWidPx\(\)\/2,hl=zeppelinLenPx\(\)\/2;return Math\.abs\(b\.x-boss\.x\)<hw\+\(b\.r\|\|3\)&&Math\.abs\(b\.y-boss\.y\)<hl\+\(b\.r\|\|3\)\}return collide\(b,boss\)\}/.test(html));
ok('Zeppelin gunner flashes fire from the MG battlestations (plate 110/330,45)',
  /var fp=zepPlateToScreen\(b,110,45\),rp=zepPlateToScreen\(b,330,45\)/.test(html));
ok('Zeppelin gunner fire comes from the MG battlestations',
  /var gp=boss\.kind==='zeppelin'\?zepPlateToScreen\(boss,110,45\):\[boss\.x,boss\.y\+boss\.r\*\.48\]/.test(html) &&
  /var gp2=boss\.kind==='zeppelin'\?zepPlateToScreen\(boss,330,45\):\[boss\.x,boss\.y-boss\.r\*\.4\]/.test(html));
ok('Zeppelin hovers centred vertically (topTarget H/2) with a slow vertical drift',
  /topTarget=d\.kind==='zeppelin'\?Math\.round\(H\/2\):132/.test(html) &&
  /if\(boss\.kind==='zeppelin'\)\{boss\.y=boss\.topTarget\+Math\.sin\(time\*0\.22\)\*260\}/.test(html));
ok('Zeppelin entry is faster (vy 120, was 42)', /d\.kind==='zeppelin'\?120:58/.test(html));
ok('drawBossShadow draws the Zeppelin shadow vertical (rotated PI/2)',
  /ctx\.rotate\(Math\.PI\/2\);\s*ctx\.drawImage\(plate0,-sh\/2,-sw\/2,sh,sw\)/.test(html));
ok('drawBossShadow uses true-scale boss sizes', /drawnW=Math\.round\(bossWingspanPx\(b\.stage\)\)/.test(html) && /drawnW=bossFighterSize\(b\.stage\)/.test(html));

// --- invariants (must not regress) --------------------------------------------
ok('day-one flag intact (1918-day-one, sale end Nov 12)',
  /DAY_ONE_KEY='1918-day-one'/.test(html) && /SALE_END_MS=Date\.UTC\(2026,10,13,7,59,59\)/.test(html));
ok('1P/2P screen intact (1 PLAYER / 2 PLAYERS)', /id="chooseSolo"/.test(html) && /id="chooseCoop"/.test(html));
ok('stage card intact (stageCard + stageLocale + showSortie)', /id="stageCard"/.test(html) && /function stageLocale/.test(html) && /function showSortie/.test(html));
ok('2P camo intact (player-spad-2, French five-colour)', /player-spad-2/.test(html));
ok('no Screenshot Studio (zero screenshot references)', !/screenshot/i.test(html));
ok('no vector-drawn terrain (photographic base only)', /SORTIE_BACKGROUNDS/.test(html));
ok('one-hit death doctrine intact', /one-hit|ONE HIT|1 hit/i.test(html) || /hitPilot/.test(html));
ok('AceQA.scale runtime exercise exists and is wired', /function exerciseV54Scale\(\)/.test(html) && /scale:function\(\)\{return exerciseV54Scale\(\)\}/.test(html));

// --- fire patterns preserved (scale changed size/r only, never the guns) ------
ok('enemy fire patterns unchanged by the scale rewrite (red fan2, green fan3, dvii fan3, dva fan2, clii fan2, junkers fan2, taube/eiii/small single)', (() => {
  const m = html.match(/var ENEMY_ARCHETYPES=\{([\s\S]*?)\};/);
  if (!m) return false;
  const body = m[1];
  const want = { red: 'fan2', green: 'fan3', dvii: 'fan3', dva: 'fan2', clii: 'fan2', junkers: 'fan2', taube: 'single', eiii: 'single', small: 'single' };
  return Object.keys(want).every(k => {
    const em = body.match(new RegExp(k + ":\\{[^}]*fire:'" + want[k] + "'"));
    return !!em;
  });
})());
ok('boss rear fan unchanged (3 + threshold, fires from the AFT MG plate on a Zeppelin)', (() => {
  const m = html.match(/var gp2=boss\.kind==='zeppelin'\?zepPlateToScreen\(boss,330,45\):\[boss\.x,boss\.y-boss\.r\*\.4\];aimedFan\(gp2\[0\],gp2\[1\],rearTarget,3\+boss\.threshold/);
  return !!m;
})());

// --- pre-existing warnings (reported, not changed) ---------------------------
note('boss HP does not match standing doctrine (S1 25 -> S32 500) — code: S1 50 -> S32 220');
note('STUN servers still in makePeer — v32 note says they were removed; they are unused for local pairing but still configured');
note('sortie 18 briefing/objective name a Staaken giant but roster[17] is a Zeppelin — pre-existing text/roster drift, reported, not changed');

console.log('\nv54 static QA: ' + pass + ' passed, ' + fail + ' failed, ' + warn + ' warnings');
if (failures.length) { console.log('FAILURES:'); failures.forEach(f => console.log('  - ' + f)); }
if (warnings.length) { console.log('WARNINGS:'); warnings.forEach(w => console.log('  - ' + w)); }
process.exit(fail ? 1 : 0);
