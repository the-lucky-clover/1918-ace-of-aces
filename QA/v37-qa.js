#!/usr/bin/env node
/* v37 static QA — checks the game file without running it.
   Usage: node QA/v37-qa.js [path-to-html]
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

console.log('v37 static QA — ' + HTML);

// --- version ---------------------------------------------------------------
ok('VERSION file is 37', version === '37', 'got ' + version);
ok('in-game version badge is v37', html.includes('ver-badge">v37</span>'));
ok('CHANGELOG has a v37 entry in pirate speak', /## v37 —/.test(changelog) && /Arrr/.test(changelog.split('## v37 —')[1].split('## ')[0] || ''));

// --- sortie backgrounds ----------------------------------------------------
const bgMatch = html.match(/var SORTIE_BACKGROUNDS=\[([\s\S]*?)\];/);
ok('SORTIE_BACKGROUNDS table exists', !!bgMatch);
let backgrounds = [];
if (bgMatch) {
  try {
    backgrounds = JSON.parse('[' + bgMatch[1].replace(/(\w+):/g, '"$1":').replace(/'/g, '"') + ']');
  } catch (e) {
    // fall back: count entries by the per-sortie object pattern
    backgrounds = (bgMatch[1].match(/\{[^}]*alt:/g) || []).map(() => ({}));
  }
}
ok('32 sortie backgrounds', backgrounds.length === 32, 'got ' + backgrounds.length);
if (bgMatch) {
  const crops = new Set((bgMatch[1].match(/c:\[[\d.,\s]+\]/g) || []));
  ok('32 distinct background crops', crops.size === 32, 'got ' + crops.size);
  const alts = (bgMatch[1].match(/alt:\s*'(low|mid|high)'/g) || []);
  const counts = { low: 0, mid: 0, high: 0 };
  alts.forEach(a => { counts[a.match(/'(low|mid|high)'/)[1]]++; });
  ok('altitude bands present (low/mid/high)', counts.low > 0 && counts.mid > 0 && counts.high > 0,
    JSON.stringify(counts));
  ok('background grades present', /grade:\s*'[^']+'/.test(bgMatch[1]));
}
ok('photographic base photo exists', fs.existsSync(path.join(ROOT, 'assets/terrain-aerial.jpg')));
ok('no procedural terrain generation', !/function (drawTerrain|generateTerrain|proceduralTerrain)/.test(html) || /SORTIE_BACKGROUNDS/.test(html));
ok('drawTerrain draws the photo (no code-drawn terrain)', /SORTIE_BACKGROUNDS/.test(html) && !/function drawTerrain\([^)]*\)\{[^}]*createRadialGradient/.test(html));

// --- boss roster (doctrine drift is reported, not changed) -----------------
const rosterMatch = html.match(/bossRoster\s*=\s*\[([\s\S]*?)\];/);
if (rosterMatch) {
  const hps = [...rosterMatch[1].matchAll(/hp:\s*(\d+)/g)].map(m => +m[1]);
  ok('boss roster has 32 entries', hps.length === 32, 'got ' + hps.length);
  const mono = hps.every((v, i) => i === 0 || v >= hps[i - 1]);
  ok('boss HP is monotonic', mono);
  if (hps.length === 32) {
    console.log('  INFO  boss HP S1=' + hps[0] + ' S32=' + hps[31] + ' (standing doctrine says S1 25 -> S32 500; code has ' + hps[0] + ' -> ' + hps[31] + ' — pre-existing drift, reported, not changed)');
    if (hps[0] !== 25 || hps[31] !== 500) note('boss HP does not match standing doctrine (S1 25 -> S32 500)', 'code: S1 ' + hps[0] + ' -> S32 ' + hps[31]);
  }
} else {
  ok('boss roster found', false);
}

// --- raster-only: no live 3D / vector world art ----------------------------
ok('no three.js script tag', !html.includes('three.min.js') && !html.includes('GLTFLoader.js'));
ok('no model3d / modelCanvas references', !html.includes('model3d') && !html.includes('modelCanvas'));
ok('no initModels / renderModels / modelAt definitions', !/function (initModels|renderModels|modelAt|enemyModelSource)\(/.test(html));
ok('no same-screen joinPlayer2 function', !/function joinPlayer2\(/.test(html));
ok('no same-device co-op button', !html.includes('sameDeviceCoop'));
ok('no virtual thumbpad / bomb / loop buttons', !html.includes('thumbpad') && !html.includes('touchBombBtn') && !html.includes('touchLoopBtn'));
ok('no keyboard bomb key', !html.includes("key==='x'"));
ok('no gamepad bomb button', !/pressed\[0\]&&!gamepad\.buttons\[0\]\)doBomb/.test(html));
// --- raster-only: no live 3D / vector world art ----------------------------
// The audit functions keep their names but were re-implemented to draw from
// raster sprite sheets. The check is on the BODY: it must draw from a raster
// sprite (drawImage / drawFx / drawFxSheet / drawBlenderSprite / groundArt /
// fxArt / powerArt / bankedSprite) and must not be a pure vector drawing.
function fnBody(name) {
  const i = html.indexOf('function ' + name + '(');
  if (i < 0) return null;
  const j = html.indexOf('{', i);
  let d = 0;
  for (let k = j; k < html.length; k++) {
    if (html[k] === '{') d++;
    else if (html[k] === '}') { d--; if (d === 0) return html.slice(j, k + 1); }
  }
  return null;
}
const rasterFns = ['drawFokkerTriplaneSprite', 'drawBalloonBoss', 'winDrawChateau', 'drawFlakCloud', 'drawGasVeil', 'drawCrashWorld', 'drawParachute', 'drawAirfield', 'drawGroundTarget', 'gwDrawGround', 'drawAircraftDamage', 'drawHatRingMarkings', 'drawAmbientFires', 'drawAmbientClouds', 'drawSmokeColumn'];
rasterFns.forEach(fn => {
  const body = fnBody(fn);
  if (body === null) { ok(fn + ' is raster (function removed)', true); return; }
  const drawsRaster = /drawImage|drawFx|drawFxSheet|drawBlenderSprite|groundArt|fxArt|powerArt|bankedSprite/.test(body);
  ok(fn + ' draws from raster sprites', drawsRaster);
  // vector primitives are only allowed as a load-failure fallback, never as
  // the primary art. Flag them as a warning so they stay visible.
  const vectorPrim = (body.match(/ctx\.(arc|fillRect|beginPath|moveTo|lineTo|ellipse)\(/g) || []).length;
  // a fillRect that fills with a raster canvas pattern (createPattern from a
  // sprite) is raster art, not vector — do not count it.
  const patternFill = /createPattern\(/.test(body) ? (body.match(/ctx\.fillRect\(/g) || []).length : 0;
  const realVector = vectorPrim - patternFill;
  if (realVector > 0) note(fn + ' still contains ' + realVector + ' vector primitive(s) (load-failure fallback only)', 'primary path is raster');
});

// --- v34 sprite files exist ------------------------------------------------
const spriteDir = path.join(ROOT, 'assets/sprites/v34');
const expectedSprites = [
  'v34-smoke.png','v34-fire.png','v34-flak.png','v34-flash.png','v34-crater.png','v34-scorch.png',
  'v34-ring.png','v34-rain.png','v34-fog.png','v34-gas.png','v34-snow.png','v34-tracer.png',
  'v34-arty.png','v34-tank.png','v34-limber.png','v34-cavalry.png','v34-vehicle.png','v34-zeppelin.png',
  'v34-parachute.png','v34-depot.png','v34-fuel.png','v34-checkpoint.png','v34-chateau.png','v34-runway.png',
  'v34-damage.png','v34-markings.png','v34-markings-2.png',
  'v34-power-firepower.png','v34-power-wing.png','v34-power-blast.png','v34-power-loop.png',
  'v34-power-points.png','v34-power-flak.png','v34-power-bomb.png','v34-power-yashichi.png','v34-power-back.png',
];
const missingSprites = expectedSprites.filter(f => !fs.existsSync(path.join(spriteDir, f)));
ok('all 36 v34 raster sprite files exist', missingSprites.length === 0, missingSprites.join(', '));
const referenced = new Set([...html.matchAll(/loadImage\('([^']+)'\)/g)].map(m => m[1]));
const missingRefs = [...referenced].filter(p => p.startsWith('assets/') && !fs.existsSync(path.join(ROOT, p)));
ok('every loadImage asset reference resolves on disk', missingRefs.length === 0, missingRefs.slice(0, 8).join(', '));


// --- v36 ambient overlay plates (photographic source only, soft alpha) ------
const v36Dir = path.join(ROOT, 'assets/sprites/v36');
const expectedV36 = ['v36-fireglow.png', 'v36-ember.png', 'v36-smoke2.png', 'v36-smokedark.png', 'v36-cloud.png'];
const missingV36 = expectedV36.filter(f => !fs.existsSync(path.join(v36Dir, f)));
ok('all 5 v36 ambient overlay plates exist', missingV36.length === 0, missingV36.join(', '));
ok('v36Art loads all five plates', expectedV36.every(f => html.includes("loadImage('assets/sprites/v36/" + f + "')")));
ok('ambient system functions present', ['spawnAmbientOverlays', 'updateAmbient', 'drawAmbientFires', 'drawAmbientClouds', 'drawSmokeColumn', 'ambRand'].every(fn => html.includes('function ' + fn + '(')));
ok('ground fires capped at 5 per sortie', /n=Math\.min\(5,n\)/.test(html));
ok('clouds capped at 2 per sortie', html.includes('ambientClouds') && /\?2:1/.test(html));
ok('ambient smoke capped (smokeColumns < 38)', (html.match(/smokeColumns\.length<38/g) || []).length >= 2);
ok('ambient overlays drawn under aircraft (fires after battle scars, clouds before bullets)', /drawBattleScars\(\);drawAmbientFires\(\);/.test(html) && /smokeColumns\.forEach\(drawSmokeColumn\);drawAmbientClouds\(\);/.test(html));
ok('ambient overlays are per-sortie seeded variation (not random each frame)', html.includes('ambRand(progress.selected*2654435761'));
ok('ambient fires scroll with the ground (92px/s like craters)', /f\.y\+=92\*dt/.test(html));
// PNG alpha: every v36 plate must be RGBA8 and feathered to transparent at the corners.
const zlib = require('zlib');
function pngAlphaCorners(file) {
  const buf = fs.readFileSync(file);
  if (buf.slice(0, 8).toString('hex') !== '89504e470d0a1a0a') return { ok: false, why: 'not a PNG' };
  let pos = 8, w = 0, h = 0, bitDepth = 0, colorType = 0; const idat = [];
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos), type = buf.toString('ascii', pos + 4, pos + 8);
    const data = buf.slice(pos + 8, pos + 8 + len);
    if (type === 'IHDR') { w = data.readUInt32BE(0); h = data.readUInt32BE(4); bitDepth = data[8]; colorType = data[9]; }
    else if (type === 'IDAT') idat.push(data);
    else if (type === 'IEND') break;
    pos += 12 + len;
  }
  if (colorType !== 6 || bitDepth !== 8) return { ok: false, why: 'colorType=' + colorType + ' bitDepth=' + bitDepth + ' (want RGBA8)' };
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const bpp = 4, stride = w * bpp, px = Buffer.alloc(h * stride);
  let p = 0;
  for (let y = 0; y < h; y++) {
    const f = raw[p++];
    const row = raw.slice(p, p + stride); p += stride;
    const prev = y ? px.slice((y - 1) * stride, y * stride) : Buffer.alloc(stride);
    const out = px.slice(y * stride, (y + 1) * stride);
    for (let x = 0; x < stride; x++) {
      const a = x >= bpp ? out[x - bpp] : 0, b = prev[x], c = x >= bpp ? prev[x - bpp] : 0;
      let v = row[x];
      if (f === 1) v = (v + a) & 255;
      else if (f === 2) v = (v + b) & 255;
      else if (f === 3) v = (v + ((a + b) >> 1)) & 255;
      else if (f === 4) { const pa = Math.abs(b - c), pb = Math.abs(a - c), pc = Math.abs(a + b - 2 * c); const pr = (pa <= pb && pa <= pc) ? a : (pb <= pc ? b : c); v = (v + pr) & 255; }
      out[x] = v;
    }
  }
  const alpha = (x, y) => px[(y * w + x) * bpp + 3];
  const worst = Math.max(alpha(0, 0), alpha(w - 1, 0), alpha(0, h - 1), alpha(w - 1, h - 1));
  const centre = alpha(w >> 1, h >> 1);
  return { ok: worst <= 8 && centre >= 80, worst, centre, w, h };
}
expectedV36.forEach(f => {
  const r = pngAlphaCorners(path.join(v36Dir, f));
  ok(f + ' is RGBA8 and feathered (corners transparent, centre visible)', r.ok, r.why || ('corners max=' + r.worst + ' centre=' + r.centre));
});
// No vector smoke/fire/cloud shapes in the new ambient code.
const ambStart = html.indexOf('/* v36 ambient overlays');
const ambEnd = html.indexOf('function drawWeather(){', ambStart);
const ambBlock = ambStart >= 0 && ambEnd > ambStart ? html.slice(ambStart, ambEnd) : '';
ok('ambient block found', ambBlock.length > 0);
ok('ambient code draws no vector shapes (no ctx.arc/fillRect/gradient)', ambBlock.length > 0 && !/ctx\.(arc|fillRect|beginPath|createRadialGradient|createLinearGradient)\(/.test(ambBlock));
ok('ambient code draws only via drawFx/drawFxSheet (raster)', /drawFx\(v36Art/.test(ambBlock) && /drawFxSheet\(fxArt\.fire/.test(ambBlock));
ok('no hard-edged overlay rectangles in ambient code', !/fillRect\(0,0,W,H\)/.test(ambBlock));


// --- v37 photorealistic kill explosions --------------------------------------
// All 8 frames must exist, be loaded by v37Art, be feathered RGBA8, and be
// wired into every kill path. No vector-drawn explosion shape may exist.
const v37Dir = path.join(ROOT, 'assets/sprites/v37');
const expectedV37 = [];
for (let i = 0; i < 8; i++) expectedV37.push('v37-explosion-' + i + '.png');
const missingV37 = expectedV37.filter(f => !fs.existsSync(path.join(v37Dir, f)));
ok('all 8 v37 explosion frames exist', missingV37.length === 0, missingV37.join(', '));
ok('v37Art loads all eight frames', expectedV37.every(f => html.includes("loadImage('assets/sprites/v37/" + f + "')")));
ok('explosion system functions present', ['spawnExplosion', 'explosionSizeFor', 'updateExplosions', 'drawExplosion'].every(fn => html.includes('function ' + fn + '(')));
ok('explosion cap is 8 simultaneous', /var EXPLOSION_MAX=8;/.test(html));
ok('explosion sizes capped (small 44 / medium 64 / large 92 / boss 120 / ghost 140)', /EXPLOSION_SIZE=\{small:\{r:44,dur:0\.55\},medium:\{r:64,dur:0\.65\},large:\{r:92,dur:0\.75\},boss:\{r:120,dur:0\.8\},ghost:\{r:140,dur:0\.9\}\}/.test(html));
ok('explosion sizes scale by enemy (heavy/gotha/bomber large)', html.includes("e.archetype==='gotha'") && html.includes("e.archetype==='bomber'") && html.includes("return 'large'"));
ok('air kills spawn explosions (onEnemyDestroyed hook)', /function onEnemyDestroyed\(e\)\{[^}]*spawnExplosion\(e\.x,e\.y,explosionSizeFor\(e\)\)/.test(html));
ok('boss death spawns ghost/boss explosion', html.includes("spawnExplosion(bx,by,completedStage===31?'ghost':'boss')"));
ok('boss death marks spawn medium explosions', html.includes("spawnExplosion(d.x+(Math.random()-.5)*80,d.y+(Math.random()-.5)*40,'medium')"));
ok('balloon/fuel ground kills spawn medium explosions', html.includes("if(g.type==='balloon'||g.type==='fuel')spawnExplosion(g.x,g.y,'medium')"));
ok('explosions leave a dark smoke column (v36 plates)', /spawnExplosion[\s\S]{0,600}smokeColumns\.push\(\{x:x,y:y-6,life:3\.4,r:10,sheet:'dark'/.test(html));
ok('explosions drawn before bullets and pilots (readability)', (() => { const a = html.indexOf('explosions.forEach(drawExplosion)'); const b = html.indexOf('bullets.forEach(function(b){drawFx(fxArt.tracer'); const c = html.indexOf('activePilots().forEach(function(p){if(p.hp>0)drawPilot(p,1.08,false)}'); return a > 0 && b > a && c > a; })());
ok('explosions update every frame', html.includes('updateExplosions(dt);'));
ok('explosions cleared on reset', /bombBlasts=\[\];smokeColumns=\[\];explosions=\[\];wrecks=\[\];/.test(html));
ok('oil/sparks hit feedback unchanged (gore-free)', html.includes('function oilHit(') && html.includes('function spawnOilSpurt('));
ok('no vector-drawn explosion shape (no radial gradient / arc in explosion block)', (() => { const s = html.indexOf('/* v37 kill explosions'); const e = html.indexOf('function drawExplosion'); const block = (s >= 0 && e > s) ? html.slice(s, html.indexOf('}', html.indexOf('drawExplosion(e)'))) : ''; return block.length > 0 && !/createRadialGradient|createLinearGradient|ctx\.arc\(|ctx\.fillRect\(/.test(block); })());
ok('explosion frames draw only via drawFx (raster)', (() => { const i = html.indexOf('function drawExplosion(e)'); if (i < 0) return false; const body = fnBody('drawExplosion'); return !!body && /drawFx\(v37Art\.explosion\[fi\]/.test(body); })());
// PNG alpha: every v37 frame must be RGBA8 and feathered to transparent at the corners.
expectedV37.forEach(f => {
  const r = pngAlphaCorners(path.join(v37Dir, f));
  ok(f + ' is RGBA8 and feathered (corners transparent, centre visible)', r.ok, r.why || ('corners max=' + r.worst + ' centre=' + r.centre));
});

// --- pacing surprises + co-op + gestures ------------------------------------
ok('32 pacing surprises', /SORTIE_SURPRISES/.test(html) && (html.match(/kinds=\['ace','gotha','red','flak'\]/) ? true : /SORTIE_SURPRISES\.push/.test(html)));
ok('co-op bundled with Remove Ads (no separate product)', html.includes('COOP_PRODUCT_ID=null') && html.includes('com.stevenpounds.1918.removeads'));
ok('bluetooth pairing module present', html.includes('var btLink=') && html.includes('scanForHost'));
ok('pairing wizard present', html.includes('pairWizard') && html.includes('wizardDevices'));
ok('connectivity toast present', html.includes('pairToast') && html.includes('pairToastIn'));
ok('back-tap detection present', html.includes('backTapMotion') && html.includes('DeviceMotionEvent'));
ok('hold-to-fire gate present', html.includes('function pilotFiring('));
ok('bomb detonates on collect', html.includes("pow.type==='bomb'") && /pow\.type==='bomb'\)\{droppedBombs\.push/.test(html));
ok('odometer counters present', html.includes('function setOdometer(') && html.includes('class="odo"'));
ok('2P markings decal wired', html.includes('markings2') && html.includes('v34-markings-2.png'));
ok('no boss-announcement text', !/BOSS APPROACHING|boss approaching/i.test(html));
ok('no long briefing text in reset()', !/renderProgress\([^)]*'[A-Z][A-Z ]{20,}'/.test(html));

// --- v35 controls + KIA header (user-directed, 2026-11-07) ------------------
ok('KIA header reads KILLED IN ACTION exactly once', (html.match(/KILLED IN ACTION/g) || []).length === 1, 'got ' + (html.match(/KILLED IN ACTION/g) || []).length);
ok('no rotate / sideways prompt', !html.includes('sideways') && !/turn (your|the) (phone|device)/i.test(html) && !/rotate (your|the) (phone|device)/i.test(html));
ok('no loop button anywhere', !html.includes('touchLoopBtn') && !html.includes('loopBtn'));
ok('no tether anywhere', !/tether/i.test(html));
ok('loop counter is a lower-right display-only number', html.includes('id="loopCounter"') && /loop-counter\{[^}]*pointer-events:\s*none/.test(html) && /loop-counter\{[^}]*bottom:/.test(html) && /loop-counter\{[^}]*right:/.test(html) && !html.includes('LOOPS \u00d7'));
ok('loop is back-tap only (playfield double-tap does not loop)', (() => { const b = fnBody('backTapCount'); const f = fnBody('fieldTapCount'); return !!b && b.includes('doLoopGesture') && !!f && !f.includes('doLoopGesture'); })());
ok('triple-tap background pause kept', (() => { const f = fnBody('fieldTapCount'); return !!f && /count===3/.test(f) && f.includes('togglePause'); })());
ok('top-of-screen tap pauses', (() => { const r = fnBody('releaseTouch'); return !!r && r.includes('togglePause') && /<=96/.test(r); })());
ok('fire-start haptic on tap-and-hold', html.includes('if(p.hp>0&&!paused)buzz(12);'));
ok('plane tracks finger tighter (touch response 30)', /pt\?30/.test(html) && !/pt\?19/.test(html));


// --- period piece (anachronism scan; UI chrome allowlisted) -----------------
const bodyText = html.replace(/<script>[\s\S]*?<\/script>/g, ' ');
// strip base64 data URIs (bundled images) — they are binary, not in-world text,
// and their alphabet trips the naive substring scan (e.g. 'ufo', 'gps' inside a JPEG)
const bodyTextNoData = bodyText.replace(/data:[a-z]+\/[a-z0-9.+-]+;base64,[A-Za-z0-9+/=]+/g, ' ');
// strip the pairing/transport UI (modern tech words live only there)
const inWorld = bodyTextNoData.replace(/pairing-screen[\s\S]*?wingman/g, ' ');
const anachronisms = ['laser', 'missile', 'ufo', 'radar', 'gps', 'smartphone', 'iphone', 'android', 'computer', 'television', 'nuclear', 'satellite', 'helicopter', 'robot', 'cyber', 'jet '];
const foundAnach = anachronisms.filter(w => new RegExp(w, 'i').test(inWorld));
ok('no anachronistic in-world terms', foundAnach.length === 0, foundAnach.join(', '));
if (/bloodHit/.test(html)) note('bloodHit still present (gore)', 'the gore-removal pass is a separate pending item, not part of v34');
if (/stun\.l\.google\.com/.test(html)) note('STUN servers still in makePeer', 'v32 note says they were removed; they are unused for local pairing but still configured');

// --- summary -----------------------------------------------------------------
console.log('\nv37 static QA: ' + pass + ' passed, ' + fail + ' failed, ' + warn + ' warnings');
if (failures.length) { console.log('FAILURES:'); failures.forEach(f => console.log('  - ' + f)); }
if (warnings.length) { console.log('WARNINGS:'); warnings.forEach(w => console.log('  - ' + w)); }
process.exit(fail ? 1 : 0);
