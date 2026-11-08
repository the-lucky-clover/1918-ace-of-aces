#!/usr/bin/env node
/* v59 static QA — arcade CONTINUE with countdown after death + the secret
   prestige Sortie 33 "WILD BLUE YONDER": a mirror duel against yourself
   (5x the Sortie 32 final boss, per Steven's revised order — was 10x when v59 shipped) above a scrolling
   photographic cloud sea at magic-hour sunrise, unlocked only by a
   zero-continue campaign clear, host-earned in co-op, behind the bonus
   entitlement gate (ships open at launch; a free-acquired copy vests
   permanent entitlement — "if you got it free its always free").
   Plates: ONE real NASA astronaut photograph (ISS073-E-0028091, orbital
   sunrise above the clouds, public domain), crop + warm grade only.
   Usage: node QA/v59-qa.js [path-to-html]
   Exit 0 = all checks pass, 1 = a failure. Warnings never fail the run. */
'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const HTML = process.argv[2] || path.join(ROOT, '1918-ace-of-aces.html');
const html = fs.readFileSync(HTML, 'utf8');
const version = fs.readFileSync(path.join(ROOT, 'VERSION'), 'utf8').trim();
const changelog = fs.readFileSync(path.join(ROOT, 'CHANGELOG.md'), 'utf8');
const buildScript = fs.readFileSync(path.join(ROOT, 'bin', 'build-v59-cloudsea.py'), 'utf8');

let pass = 0, fail = 0, warn = 0;
const failures = [], warnings = [];
function ok(name, cond, detail) {
  if (cond) { pass++; console.log('  PASS  ' + name); }
  else { fail++; failures.push(name + (detail ? ' — ' + detail : '')); console.log('  FAIL  ' + name + (detail ? ' — ' + detail : '')); }
}
function note(name, detail) { warn++; warnings.push(name + (detail ? ' — ' + detail : '')); console.log('  WARN  ' + name + (detail ? ' — ' + detail : '')); }

console.log('v59 static QA — ' + HTML);

// --- minimal JPEG header parse (SOI + SOF0/SOF2 dimensions) ------------------
function jpegInfo(file) {
  const buf = fs.readFileSync(file);
  if (buf.length < 4 || buf[0] !== 0xff || buf[1] !== 0xd8) return null;
  let off = 2;
  while (off + 4 <= buf.length) {
    if (buf[off] !== 0xff) return null;
    const marker = buf[off + 1];
    if (marker === 0xc0 || marker === 0xc2) {
      return { width: buf.readUInt16BE(off + 7), height: buf.readUInt16BE(off + 5) };
    }
    if (marker === 0xda) return null; // SOS before SOF — not a normal JFIF
    const len = buf.readUInt16BE(off + 2);
    if (len < 2) return null;
    off += 2 + len;
  }
  return null;
}

// --- version -----------------------------------------------------------------
ok('VERSION file is 59', version === '59', 'got ' + version);
ok('in-game version badge is v59', html.includes('ver-badge">v59</span>'));
ok('CHANGELOG has a v59 entry in pirate speak', /## v59 —/.test(changelog) && /Arrr/.test(changelog.split('## v59 —')[1].split('## ')[0] || ''));

// --- the two v59 sky plates (on disk, real JPEG photographs) -----------------
const PLATES = [
  { name: 'v59-skyband.jpg', w: 1600, h: 260, minBytes: 10000, kind: 'photographic blue sky band (still, top of screen)' },
  { name: 'v59-cloudsea.jpg', w: 1600, h: 500, minBytes: 30000, kind: 'photographic cloud sea (scrolls, mirror-tiled)' },
];
PLATES.forEach(p => {
  const file = path.join(ROOT, 'assets', 'sprites', 'v59', p.name);
  const exists = fs.existsSync(file);
  ok(p.name + ' exists (' + p.kind + ')', exists);
  if (!exists) return;
  const size = fs.statSync(file).size;
  ok(p.name + ' is a real photographic plate (>' + p.minBytes + ' bytes, not a placeholder)',
    size > p.minBytes, 'got ' + size + ' bytes');
  const info = jpegInfo(file);
  ok(p.name + ' is a ' + p.w + 'x' + p.h + ' JPEG',
    !!info && info.width === p.w && info.height === p.h,
    info ? info.width + 'x' + info.height : 'unreadable');
});

// --- provenance: one NASA public-domain photograph, crop + grade only -------
ok('build script exists and documents the NASA source + public-domain licence',
  fs.existsSync(path.join(ROOT, 'bin', 'build-v59-cloudsea.py')) &&
  /ISS073-E-0028091/.test(buildScript) && /[Pp]ublic domain/.test(buildScript) &&
  /images-assets\.nasa\.gov/.test(buildScript));
ok('build script draws nothing (no ImageDraw — crop/resize/grade only)',
  !/ImageDraw/.test(buildScript) && /\.crop\(/.test(buildScript) && /ImageEnhance/.test(buildScript));
ok('game file documents the plate source in the v59Art comment',
  /v59 — Sortie 33 prestige sky plates/.test(html) && /ISS073-E-0028091/.test(html));

// --- wiring: plates + sky draw ------------------------------------------------
ok('v59Art declares both plates',
  /var v59Art=\{skyband:loadImage\('assets\/sprites\/v59\/v59-skyband\.jpg'\),cloudsea:loadImage\('assets\/sprites\/v59\/v59-cloudsea\.jpg'\)\}/.test(html));
ok('v59Art is NOT inside spriteArt (sprite-proof key list untouched)',
  !/spriteArt=\{[^}]*v59Art/.test(html));
ok('drawPrestigeSky draws sky band + cloud sea and records both draws',
  /function drawPrestigeSky\(\)/.test(html) && /noteSpriteDraw\(sky\)/.test(html) && /noteSpriteDraw\(sea\)/.test(html));
ok('cloud sea scrolls at the 92px/s world speed, derived from time (never stops)',
  /prestigeScrollPx=\(time\*92\)%\(tileH\*2\)/.test(html));
ok('drawTerrain branches to the prestige sky only when prestigeActive',
  /function drawTerrain\(\)\{if\(prestigeActive\)\{drawPrestigeSky\(\);return\}/.test(html));
ok('ground clutter gated off in the sky (ambient fires, weather/snow, minimap)',
  /if\(!prestigeActive\)drawAmbientFires\(\)/.test(html) &&
  /if\(!prestigeActive\)\{drawWeather\(\);wzSnowFx\(\)\}/.test(html) &&
  /if\(!prestigeActive\)drawMinimap\(\)/.test(html));

// --- wiring: CONTINUE ----------------------------------------------------------
ok('continue overlay markup (CONTINUE? + real countdown + honest count)',
  /id="continueOffer"/.test(html) && /id="continueCount"/.test(html) &&
  /id="continueBtn"/.test(html) && /CONTINUES USED · 0/.test(html));
ok('fatal crash settle routes to the continue offer (not straight to finish)',
  /crashSeq=null;onFatalCrashSettled\(\)/.test(html) &&
  /function onFatalCrashSettled\(\)\{if\(!qaMode&&fatalLoss\)\{openContinueOffer\(\)\}else\{finish\(false\)\}\}/.test(html));
ok('offer is QA-gated (the live-fire sim death handling is untouched)',
  /function openContinueOffer\(\)\{if\(qaMode\|\|continueOffer\)return/.test(html));
ok('countdown ticks in update() and expiry declines into the KIA flow',
  /if\(continueOffer\)\{continueOffer\.t-=dt;updateContinueUi\(\);audioTick\(\);if\(continueOffer\.t<=0\)declineContinue\(\);return\}/.test(html));
ok('accepting increments the run counter and restarts the current sortie (reset / prestige relaunch)',
  /function acceptContinue\(\)\{if\(!continueOffer\)return;closeContinueOffer\(\);continuesUsed\+\+;if\(prestigeActive\)\{launchPrestigeSortie\(\)\}else\{reset\(\)\}/.test(html));
ok('continue button is bound; new runs zero the counter (solo, co-op launches, campaign load)',
  /getElementById\('continueBtn'\)\.onclick=function\(\)\{acceptContinue\(\)\}/.test(html) &&
  (html.match(/continuesUsed=0/g) || []).length >= 4);

// --- wiring: prestige + entitlement gate --------------------------------------
ok('prestige flag persists under its own key (1918-prestige)',
  /PRESTIGE_KEY='1918-prestige'/.test(html) && /function markPrestige/.test(html) && /function prestigeUnlocked/.test(html));
ok('finish() banks prestige: S32 win with zero continues; S33 win completes it; QA never banks',
  /if\(win&&!qaMode&&prestigeEarnsCredit\(\)\)\{if\(prestigeActive\)\{markPrestige\(true,true\);if\(continuesUsed===0\)markP38Unlocked\(\)\}else if\(progress\.selected===campaign\.length-1&&continuesUsed===0\)markPrestige\(true,false\)\}/.test(html));
ok('co-op: only the host earns prestige (guests participate, never earn)',
  /function prestigeEarnsCredit\(\)\{return !\(net\.connected&&net\.role==='guest'\)\}/.test(html));
ok('guests receive the duel over snapshot sync (prestige flag carried both ways)',
  /landingSeq:landingSeq,prestige:prestigeActive/.test(html) && /prestigeActive=!!m\.prestige/.test(html));
ok('entitlement record: 1918-entitlement stores the acquisition source, written at first launch',
  /ENTITLEMENT_KEY='1918-entitlement'/.test(html) && /ACQUISITION_SOURCE='free'/.test(html) &&
  /function entitlementRecord\(\)/.test(html) && /try\{entitlementRecord\(\)\}catch\(e\)\{\}/.test(html));
ok('IF YOU GOT IT FREE IT\'S ALWAYS FREE: free or paid acquisition vests entitlement',
  /function bonusEntitled\(\)\{if\(LAUNCH_FREE_GRANT\)return true;var r=entitlementRecord\(\);return !!\(r&&\(r\.source==='free'\|\|r\.source==='paid'\)\)\}/.test(html));
ok('gate ships open at launch (LAUNCH_FREE_GRANT) and access = prestige AND entitlement',
  /var LAUNCH_FREE_GRANT=true/.test(html) &&
  /function prestigeAccess\(\)\{return prestigeUnlocked\(\)&&bonusEntitled\(\)\}/.test(html));
ok('no purchase/IAP was created for the gate (no new product ids, no store calls)',
  !/1918-paid/.test(html) && !/sortie33.*product/i.test(html));
ok('prestige menu entry is secret: SORTIE 33 button exists but starts hidden, visibility follows access',
  /id="choosePrestige" hidden/.test(html) &&
  /var pb=document\.getElementById\('choosePrestige'\);if\(pb\)pb\.hidden=!prestigeAccess\(\)/.test(html));
ok('launchPrestigeSortie refuses without access and refuses for guests',
  /function launchPrestigeSortie\(\)\{if\(!prestigeAccess\(\)\)return;if\(net\.connected&&net\.role==='guest'\)/.test(html));
ok('stage card 33 in the v50/v52 style (33 / WILD BLUE YONDER via the same card + timer)',
  /function showSortie33\(\)/.test(html) && /textContent='33'/.test(html) && /textContent='WILD BLUE YONDER'/.test(html));

// --- wiring: the mirror duel ---------------------------------------------------
ok('mirror boss spawns as kind mirror, stage 32, in the player\'s own SPAD art set',
  /function spawnMirrorBoss\(\)/.test(html) && /kind:'mirror'/.test(html) && /stage:32/.test(html));
ok('STEVEN\'S ORDER (v60 revision): mirror HP = 5x the final boss (mirrorBaseHp from the S32 roster entry, x5; was x10 in v59)',
  /function mirrorBaseHp\(\)\{return Math\.round\(bossRoster\[campaign\.length-1\]\.hp\*difficultyProfile\(\)\.bossHp\)\}/.test(html) &&
  /var hp=mirrorBaseHp\(\)\*5/.test(html));
ok('mirror is NOT in bossRoster (the 32-sortie campaign structure is untouched)',
  (html.match(/kind:'mirror'/g) || []).length === 1 && /campaign\.length===32/.test(html));
ok('mirror PACES up and down the scroll axis (sine pace cycle, not a fixed station)',
  /function updateMirrorBoss\(dt\)/.test(html) && /boss\.pacePhase\+=dt/.test(html) &&
  /wantY=H\*0\.44\+Math\.sin\(boss\.pacePhase\)/.test(html));
ok('mirror aggression scales past the finale (5 phases, twin-Vickers cadence, signatures)',
  /MIRROR_PHASE_NAMES=\['','PHASE II','FULL THROTTLE','LAST STAND','NO MERCY','FINAL LIGHT'\]/.test(html) &&
  /function mirrorSignature\(level\)/.test(html) && /5\+boss\.threshold/.test(html));
ok('mirror drawn from the 1P SPAD set at the SPAD\'s own true-scale size, damaged swap at <=.72',
  /MIRROR_DRAW_PX=69/.test(html) && /b\.kind==='mirror'\)\{var mset=spriteArt\.player/.test(html) &&
  /b\.kind==='mirror'\)\{im=bankedSprite\(spriteArt\.player/.test(html));
ok('mirror death is its own path (no tally, prestige landing routes to finish(true))',
  /function beginMirrorDeath\(\)/.test(html) && /prestige:true/.test(html) &&
  /if\(pl\.prestige\)\{finish\(true\)\}else\{beginLanding\(pl\.stage,pl\.fallen\)\}/.test(html) &&
  /if\(boss\.kind==='mirror'\)beginMirrorDeath\(\);else beginBossDeath\(\)/.test(html));
ok('duel sits outside the campaign loop (endPhase duel, spawns frozen, boss dispatch routes mirror)',
  /endPhase='duel'/.test(html) && /spawnT=formationT=powerT=groundT=flakT=gasT=9999/.test(html) &&
  /if\(boss\.kind==='mirror'\)updateMirrorBoss\(dt\);else updateBoss\(dt\)/.test(html));
ok('Sortie 33 result presentation reuses the debrief (prestige rank/lines, duel retry)',
  /WILD BLUE YONDER · 94TH AERO · SPAD XIII/.test(html) && /YOU OUT-FLEW<br>YOURSELF/.test(html) && /Retry the duel/.test(html));

// --- runtime exercises are wired ----------------------------------------------
ok('v59 exercises exist (continue flow, prestige gate, prestige sortie)',
  /function exerciseV59Continue\(\)/.test(html) && /function exerciseV59PrestigeGate\(\)/.test(html) && /function exerciseV59PrestigeSortie\(\)/.test(html));
ok('AceQA exposes the v59 exercises + state',
  /continueFlow:function\(\)\{return exerciseV59Continue\(\)\}/.test(html) &&
  /prestigeGate:function\(\)\{return exerciseV59PrestigeGate\(\)\}/.test(html) &&
  /prestigeSortie:function\(\)\{return exerciseV59PrestigeSortie\(\)\}/.test(html) &&
  /v59State:function\(\)\{return v59State\(\)\}/.test(html));
ok('the campaign playtest pass gate is untouched by v59 (no new sub-checks inside runCampaignPlaytest)',
  !/report\.continueFlow|report\.prestigeGate|report\.prestigeSortie/.test(html));

// --- invariants (must not regress) --------------------------------------------
ok('day-one flag intact (1918-day-one, sale end Nov 12)',
  /DAY_ONE_KEY='1918-day-one'/.test(html) && /SALE_END_MS=Date\.UTC\(2026,10,13,7,59,59\)/.test(html));
ok('1P/2P screen intact (1 PLAYER / 2 PLAYERS)', /id="chooseSolo"/.test(html) && /id="chooseCoop"/.test(html));
ok('stage card intact (stageCard + stageLocale + showSortie)', /id="stageCard"/.test(html) && /function stageLocale/.test(html) && /function showSortie/.test(html));
ok('2P camo intact (player-spad-2, French five-colour)', /player-spad-2/.test(html));
ok('continuous sortie flow intact (v53)', /function exerciseV53ContinuousFlow/.test(html));
ok('Zeppelin fleet intact (v55)', /function exerciseV55ZeppelinFleet/.test(html));
ok('boss battle-damage intact (v56)', /function exerciseV56BossDamage/.test(html));
ok('enemy aircraft un-pinned intact (v57 airborne)', /function exerciseV57Airborne/.test(html));
ok('trench variety intact (v58)', /function exerciseV58TrenchVariety/.test(html));
ok('no Screenshot Studio (zero screenshot references)', !/screenshot/i.test(html));
ok('no HP bars on bosses or enemies (no hpbar / hp-bar)',
  !/hpbar/i.test(html) && !/hp-bar/i.test(html));
ok('one-hit death doctrine intact', /hitPilot/.test(html));

// --- pre-existing warnings (reported, not changed) ---------------------------
note('boss HP does not match standing doctrine (S1 25 -> S32 500) — code: S1 50 -> S32 220; the Sortie 33 mirror is 5x the CODE S32 boss per Steven\'s revised order (10x in v59, cut to 5x in v60)');
note('STUN servers still in makePeer — v32 note says they were removed; they are unused for local pairing but still configured');
note('sortie 18 briefing/objective name a Staaken giant but roster[17] is a Zeppelin — pre-existing text/roster drift, reported, not changed');
note('v60 supersedes the v59 duel fuel=9999: survival is now the 1943-style fuel gauge in every mode; the duel flies on the gauge, fed by boss-fight fuel drums through the powerup channel — no boss exemption (Steven\'s final fuel ruling)');
note('live-fire survival sim pilot rebuilt 2026-11-07 — beats 4–6/32 sorties across seeds; Steven\'s iPhone playtest remains the proof for the rest');

console.log('\nv59 static QA: ' + pass + ' passed, ' + fail + ' failed, ' + warn + ' warnings');
if (failures.length) { console.log('FAILURES:'); failures.forEach(f => console.log('  - ' + f)); }
if (warnings.length) { console.log('WARNINGS:'); warnings.forEach(w => console.log('  - ' + w)); }
process.exit(fail ? 1 : 0);
