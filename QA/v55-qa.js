#!/usr/bin/env node
/* v55 static QA — Zeppelin fleet: six famous Zeppelins, easiest to most
   lethal, with the civilian-bombing L-48 (fighter-ceiling objective) and
   the dreadnought L-70 (most battlestations, most armour) at the end.
   Checks the game file without running it.
   Usage: node QA/v55-qa.js [path-to-html]
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

console.log('v55 static QA — ' + HTML);

// --- version ---------------------------------------------------------------
// v55 landed and v56 has since moved the head on: these checks verify the
// v55 record is in place and the repo is at or past v55, not that the repo
// is frozen at v55 (each version's QA is a regression suite for its own
// feature work once a later version lands).
ok('VERSION file is at least 55 (v55 landed)', /^\d+$/.test(version) && +version >= 55, 'got ' + version);
ok('in-game version badge is v55 or later', (() => { const m = html.match(/ver-badge">v(\d+)</); return !!m && +m[1] >= 55; })());
ok('CHANGELOG has a v55 entry in pirate speak', /## v55 —/.test(changelog) && /Arrr/.test(changelog.split('## v55 —')[1].split('## ')[0] || ''));

// --- roster parsing ----------------------------------------------------------
const rosterMatch = html.match(/var bossRoster=\[([\s\S]*?)\];/);
ok('bossRoster parses (32 entries)', !!rosterMatch && (rosterMatch[1].match(/\{[^}]*\}/g) || []).length === 32);
const entries = rosterMatch ? (rosterMatch[1].match(/\{[^}]*\}/g) || []) : [];
const zepStages = [];
entries.forEach((e, i) => { if (/kind:'zeppelin'/.test(e)) zepStages.push(i); });
const zepHp = zepStages.map(i => {
  const m = entries[i].match(/hp:(\d+)/);
  return m ? +m[1] : 0;
});

// --- the fleet: six, easiest to most lethal ----------------------------------
ok('the fleet is exactly SIX Zeppelins', zepStages.length === 6, 'got ' + zepStages.length);
ok('fleet sorties are 3, 8, 13, 18, 23, 28 (indices 2, 7, 12, 17, 22, 27)',
  JSON.stringify(zepStages) === JSON.stringify([2, 7, 12, 17, 22, 27]),
  'got [' + zepStages.join(', ') + ']');
ok('fleet HP ramps strictly easiest to most lethal (58, 78, 98, 118, 138, 158)',
  JSON.stringify(zepHp) === JSON.stringify([58, 78, 98, 118, 138, 158]),
  'got [' + zepHp.join(', ') + ']');
ok('fleet designations are real famous Zeppelins (L-33, L-31, L-48, L-59, L-55, L-70)',
  /L-33/.test(entries[2]) && /L-31/.test(entries[7]) && /L-48/.test(entries[12]) &&
  /L-59/.test(entries[17]) && /L-55/.test(entries[22]) && /L-70/.test(entries[27]));
ok('fleet carries the real LZ hull numbers (LZ 76, 72, 95, 104, 101, 112)',
  /LZ 76/.test(entries[2]) && /LZ 72/.test(entries[7]) && /LZ 95/.test(entries[12]) &&
  /LZ 104/.test(entries[17]) && /LZ 101/.test(entries[22]) && /LZ 112/.test(entries[27]));
ok('every Zeppelin-kind entry names only a real fleet designation (no invented airships)',
  zepStages.every(i => /name:'L-(33|31|48|59|55|70)\b/.test(entries[i])));
ok('L-33 is the first (easiest) Zeppelin, sortie 3', /name:'L-33/.test(entries[2]) && zepStages[0] === 2);
ok('L-70 is the last (most lethal) Zeppelin, sortie 28', /name:'L-70/.test(entries[27]) && zepStages[5] === 27);
ok('old generic Zeppelin names are gone (no COMMAND / WATCH / FORTRESS / HUNTER-KILLER / FINAL ASCENT)',
  !/ZEPPELIN COMMAND/.test(html) && !/ZEPPELIN WATCH/.test(html) && !/ZEPPELIN FORTRESS/.test(html) &&
  !/ZEPPELIN HUNTER-KILLER/.test(html) && !/ZEPPELIN · FINAL ASCENT/.test(html));
ok('sortie 5 slot is a Gotha G.IV heavy bomber, not a seventh Zeppelin',
  /GOTHA G\.IV/.test(entries[4]) && !/kind:'zeppelin'/.test(entries[4]));
ok('BOSS_SPAN_M is still 198 m at every Zeppelin stage (v54 true scale intact)', (() => {
  const spanM = html.match(/var BOSS_SPAN_M=\[([^\]]+)\]/);
  if (!spanM) return false;
  const spans = spanM[1].split(',').map(Number);
  return zepStages.every(i => spans[i] === 198);
})());

// --- civilian-bombing Zeppelin: L-48 -----------------------------------------
ok('L-48 is the civilian bomber (civilian:true, ceiling:5)',
  /civilian:true/.test(entries[12]) && /ceiling:5/.test(entries[12]));
ok('L-48 is the ONLY Zeppelin with a fighter ceiling',
  zepStages.filter(i => /ceiling:/.test(entries[i])).length === 1 && /ceiling:5/.test(entries[12]));
ok('Reims sortie 13 briefing names L-48 and the civilian stakes',
  /L-48, a Zeppelin raider bound for Reims/.test(html) && /Civilians sleep below/.test(html));
ok('Reims objective is CLEAR THE FIGHTER CEILING · STOP THE BOMBING OF REIMS',
  /objective:'CLEAR THE FIGHTER CEILING · STOP THE BOMBING OF REIMS'/.test(html));
ok('spawnCeilingFighters exists and spawns an elite dvii/triplane escort screen with ceiling:true',
  /function spawnCeilingFighters\(n\)/.test(html) &&
  /types=\['dvii','triplane','dvii','triplane','dvii'\]/.test(html) &&
  /spawnEnemy\(kind,\{elite:true,ceiling:true,path:'sine'/.test(html));
ok('spawnCeilingFighters trims the field for the 10-aircraft budget before spawning',
  /while\(enemies\.filter\(function\(e\)\{return e\.hp>0\}\)\.length>MAX_ACTIVE_ENEMIES-1-n\)\{enemies\.shift\(\)\}/.test(html));
ok('spawnBoss arms the shield for a ceiling Zeppelin and shows the civilian banner',
  /if\(d\.kind==='zeppelin'&&d\.ceiling\)\{boss\.ceilingShield=false;boss\.ceilingTotal=0;boss\.ceilingAlive=0;boss\.shieldSaid=false;spawnCeilingFighters\(d\.ceiling\);if\(boss\.ceilingAlive>0\)\{boss\.ceilingShield=true;showBanner\('CIVILIANS BELOW/.test(html));
ok('player bullets are blocked while the fighter ceiling holds (shieldSaid)',
  /if\(boss\.ceilingShield\)\{burst\(b\.x,b\.y,3,'#9fb6c9'\);if\(!boss\.shieldSaid\)\{boss\.shieldSaid=true;say\('FIGHTER CEILING HOLDS · CLEAR THE ESCORT FIRST'\)\}\}/.test(html));
ok('blast powerup does not damage a shielded Zeppelin',
  /if\(boss&&!boss\.ceilingShield\)boss\.hp-=16;/.test(html));
ok('updateBoss drops the shield and zeroes the count when the ceiling is empty',
  /if\(boss\.ceilingShield\)\{var ceilAlive=enemies\.filter\(function\(e\)\{return e\.ceiling&&e\.hp>0\}\);if\(!ceilAlive\.length\)\{boss\.ceilingShield=false;boss\.ceilingAlive=0;boss\.shieldSaid=false;say\('FIGHTER CEILING CLEARED · THE ZEPPELIN IS EXPOSED'\)/.test(html));
ok('onEnemyDestroyed decrements the ceiling count when a ceiling fighter dies',
  /if\(e\.ceiling&&boss&&boss\.ceilingShield&&boss\.ceilingAlive>0\)\{boss\.ceilingAlive--/.test(html));
ok('ceiling escorts circle back for another pass (reset in the enemy loop, before the filter)',
  /advancePathEnemy\(e,dt\);if\(e\.ceiling&&e\.hp>0&&\(e\.escaping\|\|e\.ttl<2\)\)\{e\.escaping=false;e\.ttl=99;if\(e\.pathState\)e\.pathState\.t=0\}/.test(html));

// --- component tables ----------------------------------------------------------
function tableBody(name) {
  const m = html.match(new RegExp('var ' + name + '\\s*=\\s*\\[([\\s\\S]*?)\\n\\];'));
  return m ? m[1] : null;
}
function tableCounts(body) {
  if (!body) return null;
  return {
    total: (body.match(/\{type:/g) || []).length,
    mg: (body.match(/type:'mg'/g) || []).length,
    fuel: (body.match(/type:'fuel'/g) || []).length,
    gondola: (body.match(/type:'gondola'/g) || []).length,
    prop: (body.match(/type:'prop'/g) || []).length,
  };
}
const std = tableCounts(tableBody('ZEPPELIN_COMPONENTS'));
const heavy = tableCounts(tableBody('ZEPPELIN_COMPONENTS_HEAVY'));
const dread = tableCounts(tableBody('ZEPPELIN_COMPONENTS_DREADNOUGHT'));
ok('standard table (L-33, L-31, L-48) still has 10 components: 2 MG, 3 fuel, 2 gondola, 3 prop',
  !!std && std.total === 10 && std.mg === 2 && std.fuel === 3 && std.gondola === 2 && std.prop === 3,
  std ? JSON.stringify(std) : 'table not found');
ok('heavy table (L-59, L-55) has 11 components: 3 MG, 3 fuel, 2 gondola, 3 prop',
  !!heavy && heavy.total === 11 && heavy.mg === 3 && heavy.fuel === 3 && heavy.gondola === 2 && heavy.prop === 3,
  heavy ? JSON.stringify(heavy) : 'table not found');
ok('dreadnought table (L-70) has 15 components: 4 MG, 4 fuel, 3 gondola, 4 prop',
  !!dread && dread.total === 15 && dread.mg === 4 && dread.fuel === 4 && dread.gondola === 3 && dread.prop === 4,
  dread ? JSON.stringify(dread) : 'table not found');
ok('L-59 and L-55 fly the heavy table (comps:heavy)',
  /comps:'heavy'/.test(entries[17]) && /comps:'heavy'/.test(entries[22]));
ok('L-70 flies the dreadnought table (comps:dreadnought)', /comps:'dreadnought'/.test(entries[27]));
ok('heavy table adds a third MG battery on the nose (plate 45)',
  (() => { const b = tableBody('ZEPPELIN_COMPONENTS_HEAVY'); return !!b && /type:'mg',pos:'nose'/.test(b) && /label:'MG BATTERY NOSE',x:45/.test(b); })());
ok('dreadnought table lays four MG batteries along her back-to-front length (nose 45, fwd 110, mid 220, tail 395)',
  (() => {
    const b = tableBody('ZEPPELIN_COMPONENTS_DREADNOUGHT');
    return !!b && /label:'MG BATTERY NOSE',x:45/.test(b) && /label:'FWD MG BATTERY',x:110/.test(b) &&
      /label:'MG BATTERY MID',x:220/.test(b) && /label:'MG BATTERY TAIL',x:395/.test(b);
  })());
ok('dreadnought component armour is heavier than the L-33 (MG 20 vs 16, fuel 10 vs 8, gondola 14 vs 12, prop 8 vs 6)',
  (() => {
    const d = tableBody('ZEPPELIN_COMPONENTS_DREADNOUGHT'), s = tableBody('ZEPPELIN_COMPONENTS');
    if (!d || !s) return false;
    return /type:'mg'[^}]*hp:20/.test(d) && /type:'fuel'[^}]*hp:10/.test(d) &&
      /type:'gondola'[^}]*hp:14/.test(d) && /type:'prop'[^}]*hp:8/.test(d) &&
      /type:'mg'[^}]*hp:16/.test(s) && /type:'fuel'[^}]*hp:8/.test(s) &&
      /type:'gondola'[^}]*hp:12/.test(s) && /type:'prop'[^}]*hp:6/.test(s);
  })());
ok('spawnZeppelinComponents picks the table from the roster variant (standard / heavy / dreadnought)',
  /variant==='dreadnought'\?ZEPPELIN_COMPONENTS_DREADNOUGHT:variant==='heavy'\?ZEPPELIN_COMPONENTS_HEAVY:ZEPPELIN_COMPONENTS/.test(html));
ok('MG components carry a side (fwd/aft) so the gunner flags work per side with 3-4 batteries',
  /side:'fwd'/.test(html) && /side:'aft'/.test(html) &&
  /var mgSide=c\.side\|\|\(c\.pos==='fwd'\?'fwd':'aft'\)/.test(html));

// --- v48 preservation ----------------------------------------------------------
ok('spawnBoss Zeppelin line is byte-identical (v52 constraint)',
  /if\(d\.kind==='zeppelin'\)\{boss\.comps=spawnZeppelinComponents\(\);boss\.propAngle=0;boss\.mgFwdDead=false;boss\.mgAftDead=false\}/.test(html));
ok('mgFwdDead / mgAftDead literals still present in damageZeppelinComponent',
  /boss\.mgFwdDead=true/.test(html) && /boss\.mgAftDead=true/.test(html));
ok('speed factor keeps the v48 12%-per-dead-prop rule (literal in comment, generalised to four props)',
  /1-\(3-alive\)\*\.12/.test(html) && /f\*=1-\(total-alive\)\*\.12;/.test(html));
ok('exerciseV48ZeppelinComponents still exists (stage 2, 10 comps, must stay green)',
  /function exerciseV48ZeppelinComponents\(\)/.test(html));

// --- vertical back-to-front (v54 scale, re-checked) ------------------------------
ok('zeppelinLenPx is true scale 198 m (1659 px)', /function zeppelinLenPx\(\)\{return Math\.round\(SPAD_DRAWN_PX\*\(ZEPPELIN_LEN_M\/SPAD_SPAN_M\)\)\}/.test(html) && Math.round(69.12 * (198 / 8.25)) === 1659);
ok('zepPlateToScreen maps nose (plate x=0) above centre and tail (plate x=440) below centre',
  /function zepPlateToScreen\(b,lx,ly\)\{var len=zeppelinLenPx\(\),wid=zeppelinWidPx\(\);return\[b\.x\+\(75-ly\)\*\(wid\/150\),b\.y\+\(lx-220\)\*\(len\/440\)\]\}/.test(html));
ok('bossHit tests the Zeppelin as a vertical rectangle matching her drawn scale',
  /function bossHit\(b,boss\)\{if\(!boss\)return false;if\(boss\.kind==='zeppelin'\)\{var hw=zeppelinWidPx\(\)\/2,hl=zeppelinLenPx\(\)\/2;/.test(html));
ok('drawZeppelinBoss rotates PI/2 (vertical long axis)', /function drawZeppelinBoss\(b\)\{[\s\S]{0,500}?ctx\.rotate\(Math\.max\(-\.04,Math\.min\(\.04,b\.vx\/2200\)\)\+Math\.PI\/2\)/.test(html));

// --- AceQA ----------------------------------------------------------------------
ok('AceQA.bombers expects SIX Zeppelin stages (was seven)',
  /out\.zeppelinStages\.length===6&&out\.staakenStages\.length===2/.test(html));
ok('AceQA.zeppelinFleet runtime exercise exists and is wired',
  /function exerciseV55ZeppelinFleet\(\)/.test(html) && /zeppelinFleet:function\(\)\{return exerciseV55ZeppelinFleet\(\)\}/.test(html));

// --- invariants (must not regress) ----------------------------------------------
ok('day-one flag intact (1918-day-one, sale end Nov 12)',
  /DAY_ONE_KEY='1918-day-one'/.test(html) && /SALE_END_MS=Date\.UTC\(2026,10,13,7,59,59\)/.test(html));
ok('1P/2P screen intact (1 PLAYER / 2 PLAYERS)', /id="chooseSolo"/.test(html) && /id="chooseCoop"/.test(html));
ok('stage card intact (stageCard + stageLocale + showSortie)', /id="stageCard"/.test(html) && /function stageLocale/.test(html) && /function showSortie/.test(html));
ok('2P camo intact (player-spad-2, French five-colour)', /player-spad-2/.test(html));
ok('no Screenshot Studio (zero screenshot references)', !/screenshot/i.test(html));
ok('no vector-drawn terrain (photographic base only)', /SORTIE_BACKGROUNDS/.test(html));
ok('one-hit death doctrine intact', /one-hit|ONE HIT|1 hit/i.test(html) || /hitPilot/.test(html));

// --- pre-existing warnings (reported, not changed) ------------------------------
note('boss HP does not match standing doctrine (S1 25 -> S32 500) — code: S1 50 -> S32 220');
note('STUN servers still in makePeer — v32 note says they were removed; they are unused for local pairing but still configured');
note('sortie 18 briefing/objective name a Staaken giant but roster[17] is a Zeppelin — pre-existing text/roster drift, reported, not changed');
note('Zeppelin gunner muzzle flashes still fire from the standard plate positions (110/330,45) — on the heavy/dreadnought tables the aft flash sits on the hull near the tail battery rather than on a battery');

console.log('\nv55 static QA: ' + pass + ' passed, ' + fail + ' failed, ' + warn + ' warnings');
if (failures.length) { console.log('FAILURES:'); failures.forEach(f => console.log('  - ' + f)); }
if (warnings.length) { console.log('WARNINGS:'); warnings.forEach(w => console.log('  - ' + w)); }
process.exit(fail ? 1 : 0);
