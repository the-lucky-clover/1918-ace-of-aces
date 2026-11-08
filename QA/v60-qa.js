#!/usr/bin/env node
/* v60 static QA — the 1943-style FUEL GAUGE replacing lives (drains in flight,
   chunked by hits, empty = down; wingman buffers a gauge-emptying hit and
   leaves a sliver; full at every sortie start; boss fights — the 5x mirror
   duel included — are fed by fuel drums on the existing powerup channel,
   no exemption), the Sortie 33 mirror cut from 10x to 5x the final boss,
   the SCREEN-BOMB rule (detonates on collection; every non-boss on screen
   dies regardless of HP; bosses lose exactly 40% of MAX HP; the L-48
   fighter ceiling turns it aside), and the secret P-38 LIGHTNING: a
   true-scale photographic player aircraft, invisible until Sortie 33 is
   completed with no continues, behind the v59 bonus entitlement gate.
   Plates: ONE real USAAF photograph, 1944, public domain (Wikimedia
   Commons) — palette grade (silver / olive) over the photo's own pixels.
   Usage: node QA/v60-qa.js [path-to-html]
   Exit 0 = all checks pass, 1 = a failure. Warnings never fail the run. */
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const HTML = process.argv[2] || path.join(ROOT, '1918-ace-of-aces.html');
const html = fs.readFileSync(HTML, 'utf8');
const version = fs.readFileSync(path.join(ROOT, 'VERSION'), 'utf8').trim();
const changelog = fs.readFileSync(path.join(ROOT, 'CHANGELOG.md'), 'utf8');
const buildScript = fs.readFileSync(path.join(ROOT, 'bin', 'build-v60-p38.py'), 'utf8');

let pass = 0, fail = 0, warn = 0;
const failures = [], warnings = [];
function ok(name, cond, detail) {
  if (cond) { pass++; console.log('  PASS  ' + name); }
  else { fail++; failures.push(name + (detail ? ' — ' + detail : '')); console.log('  FAIL  ' + name + (detail ? ' — ' + detail : '')); }
}
function note(name, detail) { warn++; warnings.push(name + (detail ? ' — ' + detail : '')); console.log('  WARN  ' + name + (detail ? ' — ' + detail : '')); }

console.log('v60 static QA — ' + HTML);

function pngInfo(file) {
  const buf = fs.readFileSync(file);
  if (buf.length < 24 || buf[0] !== 0x89 || buf[1] !== 0x50 || buf[2] !== 0x4e || buf[3] !== 0x47) return null;
  return { width: buf.readUInt32BE(16), height: buf.readUInt32BE(20), bytes: buf.length };
}

// --- version -----------------------------------------------------------------
ok('VERSION file is 60', version === '60', 'got ' + version);
ok('in-game version badge is v60', html.includes('ver-badge">v60</span>'));
ok('CHANGELOG has a v60 entry in pirate speak (gauge + Lightning + screen bomb)',
  /## v60 —/.test(changelog) && /Arrr/.test(changelog.split('## v60 —')[1].split('## ')[0] || '') &&
  /FUEL GAUGE/.test(changelog.split('## v60 —')[1].split('## ')[0]) && /P-38 LIGHTNING/.test(changelog.split('## v60 —')[1].split('## ')[0]));

// --- the P-38 plates + their provenance ---------------------------------------
const plateNames = ['player-p38-level', 'player-p38-bank-left', 'player-p38-bank-right', 'player-p38-damaged',
  'player-p38-2-level', 'player-p38-2-bank-left', 'player-p38-2-bank-right', 'player-p38-2-damaged'];
let platesOk = true, plateDetail = '';
for (const n of plateNames) {
  const f = path.join(ROOT, 'assets', 'sprites', 'v60', n + '.png');
  if (!fs.existsSync(f)) { platesOk = false; plateDetail = n + ' missing'; break; }
  const info = pngInfo(f);
  if (!info || info.width !== 256 || info.height !== 256 || info.bytes < 8000) {
    platesOk = false; plateDetail = n + ' bad: ' + JSON.stringify(info); break;
  }
}
ok('all 8 P-38 plates exist (2 ships x level/bank-left/bank-right/damaged), 256x256 photographic PNGs', platesOk, plateDetail);
const fuelInfo = pngInfo(path.join(ROOT, 'assets', 'sprites', 'v60', 'v60-power-fuel.png'));
ok('fuel drum plate exists (v60-power-fuel.png, 192x192)', !!fuelInfo && fuelInfo.width === 192 && fuelInfo.height === 192);
ok('build script records the exact photo source + licence (USAAF 1944, public domain, Wikimedia Commons)',
  /upload\.wikimedia\.org\/wikipedia\/commons\/8\/87\//.test(buildScript) &&
  /A_96th_FS_P-38_clearly_displays_the_distinctive_twin-boom_design\.jpg/.test(buildScript) &&
  /United States Army Air Forces/.test(buildScript.replace(/\s+/g, ' ')) && /Public domain/.test(buildScript) &&
  /bin\/build-v60-p38\.py/.test(buildScript));

// --- P-38 wiring ----------------------------------------------------------------
ok('sprite sets registered (p38 silver, p38p2 olive) from the v60 plates',
  /p38:loadBankedSprites\('v60\/player-p38'\)/.test(html) && /p38p2:loadBankedSprites\('v60\/player-p38-2'\)/.test(html));
ok('TRUE SCALE: P-38 span 15.85 m on the v54 yardstick (drawn ~132.8 px at pilot scale)',
  /P38_SPAN_M=15\.85/.test(html) && /P38_DRAWN_PX=SPAD_DRAWN_PX\*\(P38_SPAN_M\/SPAD_SPAN_M\)/.test(html) &&
  /aircraft==='p38'\?64\*\(P38_SPAN_M\/SPAD_SPAN_M\)/.test(html));
ok('unlock: a clean Sortie 33 banks s.p38 in the prestige record (finish, prestigeActive, continuesUsed===0)',
  /function markP38Unlocked\(\)/.test(html) && /s\.p38=true/.test(html) &&
  /if\(prestigeActive\)\{markPrestige\(true,true\);if\(continuesUsed===0\)markP38Unlocked\(\)\}/.test(html));
ok('P-38 rides the v59 entitlement gate exactly (p38Access = unlocked && bonusEntitled)',
  /function p38Access\(\)\{return p38Unlocked\(\)&&bonusEntitled\(\)\}/.test(html));
ok('SECRET: the aircraft toggle ships hidden and follows p38Access — no menu trace while locked',
  /id="chooseAircraft" hidden/.test(html) && /ab\.hidden=!p38Access\(\)/.test(html) &&
  /function hostAircraft\(\)\{return aircraftSel==='p38'&&p38Access\(\)\?'p38':'spad'\}/.test(html));
ok('host pick covers the flight: pilots build with hostAircraft, wingmen inherit, net packet carries it',
  /aircraft:\(id<=2\?hostAircraft\(\):'spad'\)/.test(html) && /w\.aircraft=owner\.aircraft\|\|'spad'/.test(html) &&
  /aircraft:p\.aircraft\|\|'spad'/.test(html));
ok('rendering: plane() draws the P-38 set at true scale, SPAD decal overlay skipped, nose-pod guns',
  /function plane\(x,y,rot,enemy,scale,ace,playerVariant,bank,aircraft\)/.test(html) &&
  /if\(aircraft!=='p38'\)drawHatRingMarkings\(dw,playerVariant\)/.test(html) &&
  /p\.aircraft==='p38'\?2:7/.test(html));

// --- the screen-bomb rule ---------------------------------------------------------
const blastAt = html.indexOf("pow.type==='blast'");
const blastSeg = blastAt >= 0 ? html.slice(blastAt, blastAt + 1400) : '';
ok('SCREEN BOMB: detonates on collection and kills every non-boss on screen (air + ground, any HP)',
  blastAt >= 0 && /enemies\.forEach/.test(blastSeg) && /groundTargets\.forEach/.test(blastSeg) && /g\.hp=0/.test(blastSeg));
ok('SCREEN BOMB: bosses take exactly 40% of MAX HP — never a one-hit kill (old flat 16 gone)',
  /boss\.hp-=Math\.round\(boss\.max\*\.4\)/.test(blastSeg) && !/boss\.hp-=16/.test(html));
ok('SCREEN BOMB: the L-48 fighter ceiling turns the blast aside, with the standing shield message',
  /boss\.ceilingShield/.test(blastSeg) && /boss\.shieldSaid=true/.test(blastSeg) &&
  /FIGHTER CEILING HOLDS · CLEAR THE ESCORT FIRST/.test(blastSeg));

// --- the mirror at 5x ---------------------------------------------------------------
ok('STEVEN\'S REVISION: the Sortie 33 mirror is 5x the final boss (was 10x in v59)',
  /var hp=mirrorBaseHp\(\)\*5/.test(html) && !/mirrorBaseHp\(\)\*10/.test(html) &&
  /out\.hpIs5x=!!boss&&boss\.max===out\.ghostHp\*5/.test(html));

// --- the fuel gauge (1943 model) ------------------------------------------------------
ok('gauge constants (drain .3/s, hit 25, sliver 12, drum +40, drum period 16s)',
  /FUEL_MAX=100,FUEL_DRAIN=\.3,FUEL_HIT=25,FUEL_SLIVER=12,FUEL_DRUM_GAIN=40,FUEL_DRUM_PERIOD=16/.test(html));
ok('the gauge drains continuously while flying; empty downs the pilot',
  /p\.fuel-=dt\*FUEL_DRAIN;if\(p\.fuel<=0\)\{p\.fuel=0;if\(p\.hp>0\)p\.hp=0\}/.test(html));
ok('hits chunk the gauge; a gauge-emptying hit is buffered by a wingman onto a sliver',
  /if\(p\.fuel-FUEL_HIT<=0\)/.test(html) && /p\.fuel=FUEL_SLIVER/.test(html) &&
  /WINGMAN DOWN · PILOT ON FUMES/.test(html));
ok('wingmen carry no gauge (their old fuel drain is gone)',
  !/w\.fuel=Math\.max\(0,w\.fuel-dt/.test(html));
ok('HUD: the integrity bar IS the fuel gauge (fuel ratio, Fuel gauge label, FUEL tag)',
  /player\.fuel\/FUEL_MAX/.test(html) && /aria-label="Fuel gauge"/.test(html) && />FUEL<\/span>/.test(html));
ok('boss fights are fed by fuel drums on the powerup channel — no exemption, duel included',
  /bossFuelT-=dt/.test(html) && /type:'fuel',hp:1/.test(html) &&
  /pow\.type==='fuel'/.test(html) && /fo\.fuel=Math\.min\(FUEL_MAX/.test(html) &&
  !/player\.alt01=1;player\.fuel=9999;/.test(html));
ok('pilot damage smoke/trails track the gauge, not the legacy hp field',
  /if\(!enemy&&o\.id&&o\.id<=2\)ratio=Math\.max\(0,\(o\.fuel\|\|0\)\/FUEL_MAX\)/.test(html));

// --- runtime exercises are wired -------------------------------------------------------
ok('v60 exercises exist (P-38, blast rule, fuel gauge) + image waiter',
  /function exerciseV60P38\(\)/.test(html) && /function exerciseV60Blast\(\)/.test(html) &&
  /function exerciseV60Fuel\(\)/.test(html) && /function waitForV60Images\(\)/.test(html));
ok('AceQA exposes the v60 exercises and the campaign playtest gates on them',
  /p38:function\(\)\{return exerciseV60P38\(\)\}/.test(html) &&
  /blastRule:function\(\)\{return exerciseV60Blast\(\)\}/.test(html) &&
  /fuelGauge:function\(\)\{return exerciseV60Fuel\(\)\}/.test(html) &&
  /report\.p38=AceQA\.p38\(\)/.test(html) && /report\.p38\.pass&&report\.blastRule\.pass&&report\.fuelGauge\.pass/.test(html));
ok('the wingman-buffer exercise now asserts the gauge doctrine (chunk, then buffer-to-sliver)',
  /s0\.fuel===75/.test(html) && /s1\.fuel===FUEL_SLIVER/.test(html));

// --- invariants (must not regress) ------------------------------------------------------
ok('v59 continue + prestige + entitlement intact',
  /function exerciseV59Continue\(\)/.test(html) && /PRESTIGE_KEY='1918-prestige'/.test(html) &&
  /function bonusEntitled\(\)/.test(html) && /LAUNCH_FREE_GRANT=true/.test(html));
ok('day-one flag intact (1918-day-one, sale end Nov 12)',
  /DAY_ONE_KEY='1918-day-one'/.test(html) && /SALE_END_MS=Date\.UTC\(2026,10,13,7,59,59\)/.test(html));
ok('1P/2P screen intact (1 PLAYER / 2 PLAYERS)', /id="chooseSolo"/.test(html) && /id="chooseCoop"/.test(html));
ok('stage card intact (stageCard + stageLocale + showSortie)', /id="stageCard"/.test(html) && /function stageLocale/.test(html) && /function showSortie/.test(html));
ok('2P camo intact (player-spad-2, French five-colour)', /player-spad-2/.test(html));
ok('continuous sortie flow intact (v53)', /function exerciseV53ContinuousFlow/.test(html));
ok('true scale intact (v54)', /function exerciseV54TrueScale/.test(html) || /SPAD_SPAN_M=8\.25/.test(html));
ok('Zeppelin fleet intact (v55)', /function exerciseV55ZeppelinFleet/.test(html));
ok('boss battle-damage intact (v56)', /function exerciseV56BossDamage/.test(html));
ok('enemy aircraft un-pinned intact (v57 airborne)', /function exerciseV57Airborne/.test(html));
ok('trench variety intact (v58)', /function exerciseV58TrenchVariety/.test(html));
ok('no Screenshot Studio (zero screenshot references)', !/screenshot/i.test(html));
ok('no HP bars on bosses or enemies (no hpbar / hp-bar)', !/hpbar/i.test(html) && !/hp-bar/i.test(html));

// --- pre-existing warnings (reported, not changed) ---------------------------------------
note('boss HP does not match standing doctrine (S1 25 -> S32 500) — code: S1 50 -> S32 220; the Sortie 33 mirror is 5x the CODE S32 boss per Steven\'s revised order');
note('the v59 prestige-sortie exercise still tops its scripted pilot up with player.fuel=9999 (QA-side convenience inside that exercise only; the game itself has no fuel exemption anywhere)');
note('the P-38 photo\'s length/span ratio (~0.59) is shorter than the book figure (11.53/15.85 = 0.73) — mild aerial perspective in the 1944 print; the plate ships as photographed, span true to the v54 yardstick, nothing stretched');
note('live-fire sim was tuned under one-hit rules; its baseline WILL move under the gauge — reported exactly by the playtest, never tuned to');

console.log('\nv60 static QA: ' + pass + ' passed, ' + fail + ' failed, ' + warn + ' warnings');
if (failures.length) { console.log('FAILURES:'); failures.forEach(f => console.log('  - ' + f)); }
if (warnings.length) { console.log('WARNINGS:'); warnings.forEach(w => console.log('  - ' + w)); }
process.exit(fail ? 1 : 0);
