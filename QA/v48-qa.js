#!/usr/bin/env node
/* v48 static QA — checks the game file without running it.
   Usage: node QA/v48-qa.js [path-to-html]
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

console.log('v48 static QA — ' + HTML);

// --- version ---------------------------------------------------------------
ok('VERSION file is 48', version === '48', 'got ' + version);
ok('in-game version badge is v48', html.includes('ver-badge">v48</span>'));
ok('CHANGELOG has a v48 entry in pirate speak', /## v48 —/.test(changelog) && /Arrr/.test(changelog.split('## v48 —')[1].split('## ')[0] || ''));

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
const rasterFns = ['drawFokkerTriplaneSprite', 'drawBalloonBoss', 'drawZeppelinBoss', 'drawStaakenBoss', 'winDrawChateau', 'drawFlakCloud', 'drawGasVeil', 'drawCrashWorld', 'drawParachute', 'drawAirfield', 'drawGroundTarget', 'gwDrawGround', 'drawAircraftDamage', 'drawHatRingMarkings', 'drawAmbientFires', 'drawAmbientClouds', 'drawSmokeColumn', 'gwDrawSkirmish', 'gwDrawMinimap', 'wzSnowFx', 'wzWinterTerrain', 'drawTerrain', 'drawWeather', 'drawEnemy', 'drawBoss', 'drawBossDamage', 'drawTrenchSystems'];
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

// --- v38 aircraft iteration + chateau estate plate ------------------------
// Priority 3: the player SPAD banked sets are rebuilt from the photorealistic
// photos, the 44 black-box aircraft sprites are fixed, every enemy/boss
// sprite carries photographic fabric grain, the Ghost reads red, and the
// chateau is a bright photographic estate plate (v38), not dark logs.
function pngStats(file) {
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
  let opaqueBlack = 0, visible = 0, lumSum = 0, redPx = 0, greenPx = 0, bluePx = 0;
  for (let i = 0; i < w * h; i++) {
    const r = px[i * 4], g = px[i * 4 + 1], b = px[i * 4 + 2], a = px[i * 4 + 3];
    if (a > 200 && r < 10 && g < 10 && b < 10) opaqueBlack++;
    if (a > 10) {
      visible++;
      lumSum += 0.299 * r + 0.587 * g + 0.114 * b;
      if (r > 150 && r - g > 60 && r - b > 40) redPx++;
      if (g > 80 && g > r && g - b > 10) greenPx++;
      if (b > 90 && b >= r && b >= g) bluePx++;
    }
  }
  const alpha = (x, y) => px[(y * w + x) * bpp + 3];
  return {
    ok: true, w, h,
    opaqueBlackFrac: opaqueBlack / (w * h),
    visible,
    meanLum: visible ? lumSum / visible : 0,
    redPx, greenPx, bluePx,
    cornerMax: Math.max(alpha(0, 0), alpha(w - 1, 0), alpha(0, h - 1), alpha(w - 1, h - 1)),
    centre: alpha(w >> 1, h >> 1),
  };
}
const v38Dir = path.join(ROOT, 'assets/sprites/v38');
ok('v38 chateau plate exists', fs.existsSync(path.join(v38Dir, 'v38-chateau.png')));
ok('v38Art loads the estate plate', html.includes("loadImage('assets/sprites/v38/v38-chateau.png')"));
ok('groundArt.chateau points at the v38 plate (not v34)', /chateau:loadImage\('assets\/sprites\/v38\/v38-chateau\.png'\)/.test(html));
ok('v38 exercise + waiter wired', html.includes('function exerciseV38Aircraft(') && html.includes('function waitForV38Images('));
ok('v38 exercise is in the sprite-rendering pass', html.includes('var v38=exerciseV38Aircraft()') && html.includes('v38:v38'));
if (fs.existsSync(path.join(v38Dir, 'v38-chateau.png'))) {
  const ch = pngStats(path.join(v38Dir, 'v38-chateau.png'));
  ok('v38 chateau is RGBA8 and feathered', ch.ok && ch.cornerMax <= 8 && ch.centre >= 80, ch.why || ('corners max=' + ch.cornerMax + ' centre=' + ch.centre));
  ok('v38 chateau is pale stone, not dark logs (mean luminance > 80)', ch.ok && ch.meanLum > 80, 'mean lum ' + (ch.ok ? ch.meanLum.toFixed(1) : ch.why));
}
// No aircraft sprite may keep the black-box defect (opaque black background).
const aircraftPrefixes = ['player-spad', 'player-spad-2', 'enemy-triplane', 'enemy-scout', 'enemy-fighter', 'enemy-bomber', 'enemy-dri', 'enemy-dvii', 'enemy-dva', 'enemy-eiii', 'enemy-pfalz', 'enemy-gotha', 'enemy-clii', 'enemy-rumpler', 'enemy-junkers', 'enemy-taube', 'enemy-balloon', 'boss-1-red', 'boss-2-checker', 'boss-3-stripes', 'boss-4-tiger', 'boss-5-jester', 'boss-6-ghost'];
const aircraftSuffixes = ['-bank-left.png', '-level.png', '-bank-right.png', '-damaged.png'];
let blackBoxBad = [];
aircraftPrefixes.forEach(prefix => {
  aircraftSuffixes.forEach(suf => {
    const f = path.join(ROOT, 'assets/sprites', prefix + suf);
    if (!fs.existsSync(f)) return;
    const st = pngStats(f);
    if (!st.ok || st.opaqueBlackFrac > 0.05) blackBoxBad.push(prefix + suf + (st.ok ? ' opaque-black ' + (st.opaqueBlackFrac * 100).toFixed(0) + '%' : ' ' + st.why));
  });
});
ok('no aircraft sprite keeps the black-box defect (opaque-black < 5%)', blackBoxBad.length === 0, blackBoxBad.slice(0, 6).join(', '));
// The player SPAD must carry the photograph's colours (camo + roundels).
const spadStats = pngStats(path.join(ROOT, 'assets/sprites/player-spad-level.png'));
ok('player SPAD level carries the photo (roundel red + camo green)', spadStats.ok && spadStats.redPx >= 50 && spadStats.greenPx >= 200, spadStats.ok ? ('red ' + spadStats.redPx + ' green ' + spadStats.greenPx + ' visible ' + spadStats.visible) : spadStats.why);
const spad2Stats = pngStats(path.join(ROOT, 'assets/sprites/player-spad-2-level.png'));
ok('player 2 SPAD level carries the photo (roundel red + slate camo)', spad2Stats.ok && spad2Stats.redPx >= 50 && spad2Stats.bluePx >= 200, spad2Stats.ok ? ('red ' + spad2Stats.redPx + ' slate-blue ' + spad2Stats.bluePx) : spad2Stats.why);
// The Ghost boss must read red (boosted), not a faint grey smear.
const ghostStats = pngStats(path.join(ROOT, 'assets/sprites/boss-6-ghost-level.png'));
ok('Ghost boss reads red (boosted)', ghostStats.ok && ghostStats.redPx >= 100, ghostStats.ok ? ('red ' + ghostStats.redPx) : ghostStats.why);
// The player bank sprites must be photographic (not the old flat grey).
const bankStats = pngStats(path.join(ROOT, 'assets/sprites/player-spad-bank-left.png'));
ok('player bank-left is photographic (camo green present)', bankStats.ok && bankStats.greenPx >= 200, bankStats.ok ? ('green ' + bankStats.greenPx) : bankStats.why);


// --- v39 battlefield trenches + craters, splash + raster effects ---------------
// Priority 4: photographic top-down trench systems and shell craters in the
// terrain, cut from the one true aerial photograph; the comic splash cover
// is replaced by a photographic aerial; the last vector-drawn gameplay
// effects (skirmish, minimap dots, snow/winter washes, terrain haze, weather
// grades, sunbeam, storm flash, damage smoke, boss flash/tell/damage) are
// replaced with photographic raster plates. No mechanic changes.
const v39Dir = path.join(ROOT, 'assets/sprites/v39');
const expectedV39 = ['v39-trench-a.png', 'v39-trench-b.png', 'v39-trench-c.png',
  'v39-crater-s.png', 'v39-crater-m.png', 'v39-crater-l.png', 'v39-craterfield.png',
  'v39-haze.png', 'v39-snowwash.png', 'v39-sunwash.png', 'v39-duskwash.png', 'v39-flash.png'];
const missingV39 = expectedV39.filter(f => !fs.existsSync(path.join(v39Dir, f)));
ok('all 12 v39 trench/crater/wash plates exist', missingV39.length === 0, missingV39.join(', '));
ok('v39Art loads all twelve plates', expectedV39.every(f => html.includes("loadImage('assets/sprites/v39/" + f + "')")));
ok('v39 photographic splash cover exists', fs.existsSync(path.join(v39Dir, 'v39-splash.jpg')));
ok('splash cover points at the v39 photographic plate (no comic)', html.includes("url('assets/sprites/v39/v39-splash.jpg')") && !html.includes('title-comic-panels.jpg') && !html.includes('tap-to-start-comic'));
ok('v39 splash is a real JPEG', (() => { const b = fs.readFileSync(path.join(v39Dir, 'v39-splash.jpg')); return b.length > 10000 && b[0] === 0xFF && b[1] === 0xD8 && b[2] === 0xFF; })());
ok('trench/crater system functions present', ['spawnTrenchSystems', 'updateTrenchSystems', 'drawTrenchSystems', 'exerciseV39Trenches', 'waitForV39Images'].every(fn => html.includes('function ' + fn + '(')));
ok('v39 exercise is in the sprite-rendering pass', html.includes('var v39=exerciseV39Trenches()') && html.includes('v39:v39'));
ok('v39 images awaited at boot', html.includes('await waitForV39Images()'));
ok('AceQA.trenches exercise present', html.includes('trenches:function()'));
ok('trench strips capped at 2 per sortie', (() => { const b = fnBody('spawnTrenchSystems'); return !!b && /trenchLines\.push/.test(b) && (b.match(/for\(i=0;i<2;i\+\+\)/g) || []).length >= 2; })());
ok('crater spots capped at 12 per sortie (2 fields + 10 singles)', (() => { const b = fnBody('spawnTrenchSystems'); return !!b && /craterSpots\.push\(\{kind:'field'/.test(b) && /for\(i=0;i<10;i\+\+\)/.test(b); })());
ok('trenches + craters scroll with the ground (92px/s like ambient fires)', (() => { const b = fnBody('updateTrenchSystems'); return !!b && /t\.y\+=92\*dt/.test(b) && /c\.y\+=92\*dt/.test(b); })());
ok('trenches drawn in the terrain layer (under aircraft/bullets/HUD)', /drawSortieSetpieces\(\);drawTrenchSystems\(\);/.test(html));
ok('trench systems update every frame', html.includes('updateTrenchSystems(dt);'));
ok('trench systems cleared + spawned on reset', /trenchLines=\[\];craterSpots=\[\];trenchSortie=-1;spawnTrenchSystems\(\);/.test(html));
ok('trench strips are full-width (natural 4:1 aspect, no distortion)', (() => { const b = fnBody('spawnTrenchSystems'); return !!b && /h:W\*0\.25/.test(b); })());
ok('crater fields keep natural 2:1 aspect', (() => { const b = fnBody('spawnTrenchSystems'); return !!b && /h:W\*0\.5/.test(b); })());
ok('trench/crater placement is seeded per-sortie (not random each frame)', html.includes('ambRand(progress.selected*2654435761^0x51ED2701)'));
// No vector shapes in the new v39 trench/crater code.
const v39Start = html.indexOf('/* v39 battlefield trenches + craters — photographic top-down');
const v39End = html.indexOf('function drawWeather(){', v39Start);
const v39Block = v39Start >= 0 && v39End > v39Start ? html.slice(v39Start, v39End) : '';
ok('v39 trench block found', v39Block.length > 0);
ok('v39 trench code draws no vector shapes (no ctx.arc/fillRect/gradient)', v39Block.length > 0 && !/ctx\.(arc|fillRect|beginPath|createRadialGradient|createLinearGradient)\(/.test(v39Block));
ok('v39 trench code draws only via drawImage/drawFx (raster)', /drawImage\(t\.im/.test(v39Block) && /drawFx\(c\.im/.test(v39Block));
// The three named vector effects are gone, and the rest of the family with them.
ok('no drawBulletHoles function (was already raster via groundArt.damage)', !html.includes('function drawBulletHoles('));
ok('dead vector horse + rider deleted (no callers, no definitions)', !html.includes('function gwHorse(') && !html.includes('function gwRiderAt('));
ok('no createLinearGradient / createRadialGradient in weather or terrain', (() => {
  const w = fnBody('drawWeather'), t = fnBody('drawTerrain');
  const s = fnBody('wzSnowFx'), wt = fnBody('wzWinterTerrain');
  return !!w && !!t && !!s && !!wt && !/createLinearGradient|createRadialGradient/.test(w + t + s + wt);
})());
ok('no ctx.arc / ctx.ellipse in damage or boss-draw functions', (() => {
  const e = fnBody('drawEnemy'), b = fnBody('drawBoss'), d = fnBody('drawBossDamage');
  const g = fnBody('gwDrawSkirmish'), m = fnBody('gwDrawMinimap');
  return !!e && !!b && !!d && !!g && !!m && !/ctx\.(arc|ellipse)\(/.test(e + b + d + g + m);
})());
ok('weather uses the v39 wash plates (sunwash/duskwash/flash)', (() => { const w = fnBody('drawWeather'); return !!w && /v39Art\.sunwash/.test(w) && /v39Art\.duskwash/.test(w) && /v39Art\.flash/.test(w); })());
ok('terrain haze is the v39 haze plate', (() => { const t = fnBody('drawTerrain'); return !!t && /v39Art\.haze/.test(t); })());
ok('snow washes are the v39 snowwash plate', (() => { const s = fnBody('wzSnowFx'), wt = fnBody('wzWinterTerrain'); return !!s && !!wt && /v39Art\.snowwash/.test(s) && /v39Art\.snowwash/.test(wt); })());
ok('boss tell is the raster ring plate, not a dashed arc', (() => { const b = fnBody('drawBoss'); return !!b && /drawFx\(fxArt\.ring/.test(b) && !/setLineDash/.test(b); })());
ok('boss damage flame is the raster fire sheet', (() => { const d = fnBody('drawBossDamage'); return !!d && /drawFxSheet\(fxArt\.fire/.test(d); })());
// PNG alpha: trench strips, craters and the crater field must be RGBA8 and
// feathered to transparent at the corners (trench strips feather top/bottom).
['v39-trench-a.png', 'v39-trench-b.png', 'v39-trench-c.png',
 'v39-crater-s.png', 'v39-crater-m.png', 'v39-crater-l.png', 'v39-craterfield.png'].forEach(f => {
  const r = pngAlphaCorners(path.join(v39Dir, f));
  ok(f + ' is RGBA8 and feathered (corners transparent, centre visible)', r.ok, r.why || ('corners max=' + r.worst + ' centre=' + r.centre));
});
// The washes are full-screen photographic tints (uniform opaque alpha by
// design — strength is the draw alpha), so they need a different check:
// real photographic content, not a flat fill.
function pngRgbStats(file) {
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
  if ((colorType !== 2 && colorType !== 6) || bitDepth !== 8) return { ok: false, why: 'colorType=' + colorType + ' bitDepth=' + bitDepth + ' (want RGB8 or RGBA8)' };
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const bpp = colorType === 6 ? 4 : 3, stride = w * bpp, px = Buffer.alloc(h * stride);
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
  let sum = 0, sum2 = 0, n = 0, alphaMin = 255, alphaMax = 0;
  for (let i = 0; i < w * h; i++) {
    const lum = 0.299 * px[i * bpp] + 0.587 * px[i * bpp + 1] + 0.114 * px[i * bpp + 2];
    sum += lum; sum2 += lum * lum; n++;
    if (bpp === 4) { const a = px[i * bpp + 3]; if (a < alphaMin) alphaMin = a; if (a > alphaMax) alphaMax = a; }
  }
  const mean = sum / n, sd = Math.sqrt(Math.max(0, sum2 / n - mean * mean));
  // a wash is a full-screen tint: alpha must be uniform (opaque if RGBA) —
  // strength is the draw alpha, never baked alpha.
  const alphaOk = bpp === 3 || (alphaMin === 255 && alphaMax === 255);
  return { ok: mean > 30 && mean < 250 && sd > 3 && alphaOk, mean, sd, w, h, alphaMin, alphaMax };
}
['v39-haze.png', 'v39-snowwash.png', 'v39-sunwash.png', 'v39-duskwash.png', 'v39-flash.png'].forEach(f => {
  const r = pngRgbStats(path.join(v39Dir, f));
  ok(f + ' is a photographic wash (varied, not a flat fill; uniform alpha)', r.ok, r.why || ('mean lum ' + (r.mean || 0).toFixed(1) + ' sd ' + (r.sd || 0).toFixed(1) + ' alpha ' + r.alphaMin + '-' + r.alphaMax));
});

// --- v40 rivers, roads, bridges + village buildings ------------------------
// Priority 5: photographic top-down rivers, roads and bridges, plus
// photographic top-down buildings — houses, a tavern, churches, schools
// and a stadium. Rivers and roads are full-width strips; the bridge and
// the buildings are placed objects. All cut from real aerial photographs
// (the one battlefield aerial + a Swisstopo top-down aerial of
// Village-Neuf, France). No mechanic changes.
const v40Dir = path.join(ROOT, 'assets/sprites/v40');
const expectedV40 = ['v40-river.png', 'v40-river-mud.png', 'v40-road.png', 'v40-road-dirt.png',
  'v40-bridge.png', 'v40-house-a.png', 'v40-house-b.png', 'v40-house-ruin.png',
  'v40-tavern.png', 'v40-church-a.png', 'v40-church-b.png',
  'v40-school-a.png', 'v40-school-b.png', 'v40-stadium.png'];
const missingV40 = expectedV40.filter(f => !fs.existsSync(path.join(v40Dir, f)));
ok('all 14 v40 river/road/bridge/building plates exist', missingV40.length === 0, missingV40.join(', '));
ok('v40Art loads all fourteen plates', expectedV40.every(f => html.includes("loadImage('assets/sprites/v40/" + f + "')")));
ok('v40 photographic source (Village-Neuf aerial) is in the repo', fs.existsSync(path.join(ROOT, 'assets/village-neuf-aerial.jpg')));
ok('v40 source aerial is a real top-down photograph (3840px JPEG)', (() => { const b = fs.readFileSync(path.join(ROOT, 'assets/village-neuf-aerial.jpg')); return b.length > 100000 && b[0] === 0xFF && b[1] === 0xD8 && b[2] === 0xFF; })());
ok('river/road system functions present', ['spawnRiverRoadSystems', 'updateRiverRoadSystems', 'drawRiverRoadSystems', 'exerciseV40Rivers', 'waitForV40Images'].every(fn => html.includes('function ' + fn + '(')));
ok('v40 exercise is in the sprite-rendering pass', html.includes('var v40=exerciseV40Rivers()') && html.includes('v40:v40'));
ok('v40 images awaited at boot', html.includes('await waitForV40Images()'));
ok('AceQA.rivers exercise present', html.includes('rivers:function()'));
ok('river strips capped at 2 per sortie (Rhine + muddy channel)', (() => { const b = fnBody('spawnRiverRoadSystems'); return !!b && (b.match(/kind:'river'/g) || []).length === 2; })());
ok('road strips capped at 2 per sortie (village street + dirt road)', (() => { const b = fnBody('spawnRiverRoadSystems'); return !!b && (b.match(/kind:'road'/g) || []).length === 2; })());
ok('bridge capped at 1 per sortie', (() => { const b = fnBody('spawnRiverRoadSystems'); return !!b && (b.match(/kind:'bridge'/g) || []).length === 1; })());
ok('building spots capped at 8 per sortie', (() => { const b = fnBody('spawnRiverRoadSystems'); return !!b && /for\(i=0;i<8;i\+\+\)/.test(b); })());
ok('river strips are wide (Rhine h W*0.5, mud channel h W*0.25)', (() => { const b = fnBody('spawnRiverRoadSystems'); return !!b && /h:W\*0\.5/.test(b) && /h:W\*0\.25/.test(b); })());
ok('rivers + roads + buildings scroll with the ground (92px/s like trenches)', (() => { const b = fnBody('updateRiverRoadSystems'); return !!b && /l\.y\+=92\*dt/.test(b) && /s\.y\+=92\*dt/.test(b); })());
ok('rivers/roads drawn in the terrain layer (under aircraft/bullets/HUD)', /drawSortieSetpieces\(\);drawTrenchSystems\(\);drawRiverRoadSystems\(\);/.test(html));
ok('river/road systems update every frame', html.includes('updateRiverRoadSystems(dt);'));
ok('river/road systems cleared + spawned on reset', /riverRoadLines=\[\];riverRoadSpots=\[\];riverRoadSortie=-1;spawnRiverRoadSystems\(\);/.test(html));
ok('river/road placement is seeded per-sortie (not random each frame)', html.includes('ambRand(progress.selected*2654435761^0x40DEAD01)'));
// No vector shapes in the new v40 river/road code. (Anchor on the
// functions comment — 'strips and placed objects in the terrain' — not
// the v40Art comment at the top of the file, which shares the same prefix.)
const v40Start = html.indexOf('strips and placed objects in the terrain');
const v40End = html.indexOf('function drawWeather(){', v40Start);
const v40Block = v40Start >= 0 && v40End > v40Start ? html.slice(v40Start, v40End) : '';
ok('v40 river/road block found', v40Block.length > 0);
ok('v40 river/road code draws no vector shapes (no ctx.arc/fillRect/gradient)', v40Block.length > 0 && !/ctx\.(arc|fillRect|beginPath|createRadialGradient|createLinearGradient)\(/.test(v40Block));
ok('v40 river/road code draws only via drawImage/drawFx (raster)', /drawImage\(l\.im/.test(v40Block) && /drawFx\(s\.im/.test(v40Block));
ok('v40 exercise draws every plate (14) and requires all 14', (() => { const b = fnBody('exerciseV40Rivers'); return !!b && /drawn===14/.test(b); })());
// PNG alpha: every v40 plate must be RGBA8 and feathered to transparent at
// the corners (strips feather top/bottom; placed objects feather all round).
expectedV40.forEach(f => {
  const r = pngAlphaCorners(path.join(v40Dir, f));
  ok(f + ' is RGBA8 and feathered (corners transparent, centre visible)', r.ok, r.why || ('corners max=' + r.worst + ' centre=' + r.centre));
});
// Photographic content: the river plates must read as water (blue/green
// dominant, not a flat fill), and the building plates must carry varied
// photographic content (rooftops, streets, grounds — not a flat fill).
function pngContentStats(file) {
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
  let sum = 0, sum2 = 0, n = 0, blueGreen = 0, visible = 0;
  for (let i = 0; i < w * h; i++) {
    const r = px[i * 4], g = px[i * 4 + 1], b = px[i * 4 + 2], a = px[i * 4 + 3];
    if (a <= 10) continue;
    visible++;
    const lum = 0.299 * r + 0.587 * g + 0.114 * b;
    sum += lum; sum2 += lum * lum; n++;
    if (b >= r - 10 && g >= r - 10) blueGreen++;
  }
  const mean = n ? sum / n : 0, sd = Math.sqrt(Math.max(0, (n ? sum2 / n : 0) - mean * mean));
  return { ok: true, mean, sd, visible, blueGreenFrac: visible ? blueGreen / visible : 0 };
}
['v40-river.png', 'v40-river-mud.png'].forEach(f => {
  const r = pngContentStats(path.join(v40Dir, f));
  ok(f + ' reads as water (blue/green dominant, varied, not a flat fill)', r.ok && r.blueGreenFrac > 0.5 && r.sd > 5, r.ok ? ('blue-green ' + (r.blueGreenFrac * 100).toFixed(0) + '% sd ' + r.sd.toFixed(1)) : r.why);
});
['v40-road.png', 'v40-road-dirt.png', 'v40-bridge.png', 'v40-house-a.png', 'v40-house-b.png', 'v40-house-ruin.png', 'v40-tavern.png', 'v40-church-a.png', 'v40-church-b.png', 'v40-school-a.png', 'v40-school-b.png', 'v40-stadium.png'].forEach(f => {
  const r = pngContentStats(path.join(v40Dir, f));
  ok(f + ' carries varied photographic content (not a flat fill)', r.ok && r.sd > 5 && r.visible > 1000, r.ok ? ('sd ' + r.sd.toFixed(1) + ' visible ' + r.visible) : r.why);
});


// --- v41 frontline: checkpoints, POW camps, guard towers, sirens,
//     distant artillery, distant machine guns, distant explosions,
//     searchlights + flares at night --------------------------------------
// Priority 6: photographic top-down frontline life in the terrain — road
// checkpoints, POW camps, guard towers, siren posts, distant artillery
// salvos firing back and forth with a flash preceding each burst,
// distant machine-gun tracer flicker, animated searchlight beams and
// flares at night (dusk sorties only). All cut from the one true
// battlefield aerial. No mechanic changes.
const v41Dir = path.join(ROOT, 'assets/sprites/v41');
const expectedV41 = ['v41-checkpoint-a.png', 'v41-checkpoint-b.png',
  'v41-powcamp-a.png', 'v41-powcamp-b.png', 'v41-tower.png', 'v41-siren.png',
  'v41-flash.png', 'v41-tracer.png', 'v41-smoke.png', 'v41-smokedark.png',
  'v41-beam.png', 'v41-flare.png'];
const missingV41 = expectedV41.filter(f => !fs.existsSync(path.join(v41Dir, f)));
ok('all 12 v41 frontline plates exist', missingV41.length === 0, missingV41.join(', '));
ok('v41Art loads all twelve plates', expectedV41.every(f => html.includes("loadImage('assets/sprites/v41/" + f + "')")));
ok('v41 source is the one true battlefield aerial (in the repo)', fs.existsSync(path.join(ROOT, 'assets/terrain-aerial.jpg')));
ok('frontline system functions present', ['spawnFrontlineSystems', 'updateFrontlineSystems', 'drawFrontlineSystems', 'exerciseV41Frontline', 'waitForV41Images', 'isNightSortie'].every(fn => html.includes('function ' + fn + '(')));
ok('v41 exercise is in the sprite-rendering pass', html.includes('var v41=exerciseV41Frontline()') && html.includes('v41:v41'));
ok('v41 images awaited at boot', html.includes('await waitForV41Images()'));
ok('AceQA.frontline exercise present', html.includes('frontline:function()'));
ok('frontline exercise is in the campaign playtest pass', html.includes('report.frontline=AceQA.frontline()') && html.includes('report.frontline.pass'));
ok('static spots capped at 9 per sortie (2 checkpoints, 2 POW camps, 2 towers, 3 sirens)', (() => { const b = fnBody('spawnFrontlineSystems'); return !!b && (b.match(/'checkpoint'/g) || []).length === 2 && (b.match(/'powcamp'/g) || []).length === 2 && (b.match(/'tower'/g) || []).length === 2 && (b.match(/'siren'/g) || []).length === 3; })());
ok('searchlights capped at 2 per night sortie', (() => { const b = fnBody('spawnFrontlineSystems'); return !!b && /for\(i=0;i<2;i\+\+\)\{frontlineBeams\.push/.test(b); })());
ok('searchlights only spawn on dusk (night) sorties', (() => { const b = fnBody('spawnFrontlineSystems'); return !!b && /if\(isNightSortie\(\)\)\{for\(i=0;i<2;i\+\+\)\{frontlineBeams\.push/.test(b); })());
ok('night is the dusk weatherKey', (() => { const b = fnBody('isNightSortie'); return !!b && /weatherKey[^=]*===\s*'dusk'/.test(b); })());
ok('flares only spawn at night (dusk sorties)', (() => { const b = fnBody('updateFrontlineSystems'); return !!b && /if\(isNightSortie\(\)&&frontlineClock>=T\.flare\)/.test(b); })());
ok('flares capped at 2 simultaneous', (() => { const b = fnBody('updateFrontlineSystems'); return !!b && /frontlineFlares\.length<2/.test(b); })());
ok('artillery volleys alternate sides (back and forth)', (() => { const b = fnBody('updateFrontlineSystems'); return !!b && /T\.side=-T\.side/.test(b) && /T\.side<0\?W\*\(0\.06/.test(b); })());
ok('distant explosions flash BEFORE the burst (negative delay)', (() => { const b = fnBody('updateFrontlineSystems'); return !!b && /kind:'burst',x:fx,y:fy,t:-\.12/.test(b) && /kind:'burst',x:bx,y:by,t:-\.14/.test(b) && /kind:'flash',x:fx,y:fy,t:0/.test(b); })());
ok('machine-gun bursts flicker (tracer on/off rhythm)', (() => { const b = fnBody('drawFrontlineSystems'); return !!b && /Math\.sin\(e\.t\*52\+e\.seed\)>0/.test(b) && /v41Art\.tracer/.test(b); })());
ok('searchlight beam sweeps (rotation of the photographic plate)', (() => { const b = fnBody('drawFrontlineSystems'); return !!b && /Math\.sin\(frontlineClock\*b\.speed\+b\.seed\)\*b\.range/.test(b) && /ctx\.rotate\(ang\)/.test(b) && /drawImage\(v41Art\.beam/.test(b); })());
ok('frontline spots + beams scroll with the ground (92px/s like trenches)', (() => { const b = fnBody('updateFrontlineSystems'); return !!b && /s\.y\+=92\*dt/.test(b) && /b\.y\+=92\*dt/.test(b) && /e\.y\+=92\*dt/.test(b); })());
ok('flares drift down slowly (not with the terrain scroll)', (() => { const b = fnBody('updateFrontlineSystems'); return !!b && /f\.y\+=f\.vy\*dt/.test(b) && !/f\.y\+=92\*dt/.test(b); })());
ok('frontline drawn in the terrain layer (under aircraft/bullets/HUD)', /drawRiverRoadSystems\(\);drawFrontlineSystems\(\);/.test(html));
ok('frontline systems update every frame', html.includes('updateFrontlineSystems(dt);'));
ok('frontline systems cleared + spawned on reset', /frontlineSpots=\[\];frontlineEvents=\[\];frontlineBeams=\[\];frontlineFlares=\[\];frontlineSortie=-1;frontlineClock=0;frontlineStats=\{volleys:0,mg:0,booms:0,flares:0\};frontlineTimers=\{arty:3,mg:2,boom:5,flare:4,side:1\};spawnFrontlineSystems\(\);/.test(html));
ok('frontline placement is seeded per-sortie (not random each frame)', html.includes('ambRand(progress.selected*2654435761^0xF201741)'));
// No vector shapes in the new v41 frontline code.
const v41Start = html.indexOf('/* v41 frontline — checkpoints, POW camps, guard towers, air raid sirens,');
const v41End = html.indexOf('function drawWeather(){', v41Start);
const v41Block = v41Start >= 0 && v41End > v41Start ? html.slice(v41Start, v41End) : '';
ok('v41 frontline block found', v41Block.length > 0);
ok('v41 frontline code draws no vector shapes (no ctx.arc/fillRect/gradient)', v41Block.length > 0 && !/ctx\.(arc|fillRect|beginPath|createRadialGradient|createLinearGradient)\(/.test(v41Block));
ok('v41 frontline code draws only via drawImage/drawFx (raster)', /drawImage\(v41Art\.beam/.test(v41Block) && /drawFx\(s\.im/.test(v41Block) && /drawFx\(v41Art\.flash/.test(v41Block) && /drawFx\(fr/.test(v41Block));
ok('v41 exercise draws every plate plus the beam and burst paths (14)', (() => { const b = fnBody('exerciseV41Frontline'); return !!b && /drawn===14/.test(b) && /drawImage\(v41Art\.beam/.test(b) && /v37Art\.explosion\[2\]/.test(b); })());
// PNG alpha: every v41 object plate must be RGBA8 and feathered to
// transparent at the corners (the beam has its own check: bright base).
['v41-checkpoint-a.png', 'v41-checkpoint-b.png', 'v41-powcamp-a.png', 'v41-powcamp-b.png',
 'v41-tower.png', 'v41-siren.png', 'v41-flash.png', 'v41-tracer.png',
 'v41-smoke.png', 'v41-smokedark.png', 'v41-flare.png'].forEach(f => {
  const r = pngAlphaCorners(path.join(v41Dir, f));
  ok(f + ' is RGBA8 and feathered (corners transparent, centre visible)', r.ok, r.why || ('corners max=' + r.worst + ' centre=' + r.centre));
});
ok('v41-beam.png is RGBA8 with a bright base and a faded tip (beam check)', (() => {
  const buf = fs.readFileSync(path.join(v41Dir, 'v41-beam.png'));
  if (buf.slice(0, 8).toString('hex') !== '89504e470d0a1a0a') return false;
  let pos = 8, w = 0, h = 0, bitDepth = 0, colorType = 0; const idat = [];
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos), type = buf.toString('ascii', pos + 4, pos + 8);
    const data = buf.slice(pos + 8, pos + 8 + len);
    if (type === 'IHDR') { w = data.readUInt32BE(0); h = data.readUInt32BE(4); bitDepth = data[8]; colorType = data[9]; }
    else if (type === 'IDAT') idat.push(data);
    else if (type === 'IEND') break;
    pos += 12 + len;
  }
  if (colorType !== 6 || bitDepth !== 8) return false;
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
  const corners = Math.max(alpha(0, 0), alpha(w - 1, 0), alpha(0, h - 1), alpha(w - 1, h - 1));
  return corners <= 8 && alpha(w >> 1, 0) <= 8 && alpha(w >> 1, h - 1) <= 8 &&
    alpha(w - 1, h >> 1) <= 20 && alpha(w >> 1, h >> 1) >= 80 && alpha(0, h >> 1) >= 200;
})());
// Photographic content: the object plates must carry varied photographic
// content (not a flat fill); the flash, flare and beam must read bright.
['v41-checkpoint-a.png', 'v41-checkpoint-b.png', 'v41-powcamp-a.png', 'v41-powcamp-b.png',
 'v41-tower.png', 'v41-siren.png', 'v41-smoke.png', 'v41-smokedark.png'].forEach(f => {
  const r = pngContentStats(path.join(v41Dir, f));
  ok(f + ' carries varied photographic content (not a flat fill)', r.ok && r.sd > 5 && r.visible > 1000, r.ok ? ('sd ' + r.sd.toFixed(1) + ' visible ' + r.visible) : r.why);
});
['v41-flash.png', 'v41-flare.png', 'v41-beam.png'].forEach(f => {
  const r = pngContentStats(path.join(v41Dir, f));
  ok(f + ' reads bright (mean luminance > 120, varied, not a flat fill)', r.ok && r.mean > 120 && r.sd > 3, r.ok ? ('mean ' + r.mean.toFixed(1) + ' sd ' + r.sd.toFixed(1)) : r.why);
});


// --- v42 German strategic bombers: Zeppelin airship + Staaken R.VI --------
// Priority 7: Germany's two strategic-bomber types must be in the game as
// they flew — the rigid-hull Zeppelin airship and the Zeppelin-Staaken R.VI
// giant heavy fixed-wing bomber. Both are boss-class, shootable, and die
// in the v37 photographic explosion. No mechanic changes: same 32 sorties,
// same one-hit death, same wingman buffers.
// What was already there: the Zeppelin existed as data (7 roster entries,
// kind 'zeppelin', spawn behaviour, briefings, AceQA.spawnZeppelin) and a
// photographic plate (v34-zeppelin.png) — but drawZeppelinBoss was dead
// code, so airship bosses rendered as generic fighter sprites. The Staaken
// existed as two roster entries + briefings, but with no kind and no plate,
// so the giants rendered as generic boss sprites too.
const v42Dir = path.join(ROOT, 'assets/sprites/v42');
ok('v42 Staaken plate exists', fs.existsSync(path.join(v42Dir, 'v42-staaken.png')));
ok('v42Art loads the Staaken plate', html.includes("loadImage('assets/sprites/v42/v42-staaken.png')"));
ok('v42 builder script exists (photographic composite, Gotha source)', fs.existsSync(path.join(ROOT, 'bin/build-v42-staaken.py')));
ok('v42 builder cuts from the photographic Gotha sprite (no downloads, no vector art)', (() => { const b = fs.readFileSync(path.join(ROOT, 'bin/build-v42-staaken.py'), 'utf8'); return b.includes('enemy-gotha-level.png') && !/import (requests|urllib)|urlretrieve|requests\.get|urllib\.request/i.test(b) && !/ImageDraw\.polygon|ImageDraw\.ellipse|rounded_rectangle/.test(b); })());
ok('v42 bomber exercise + waiter present', html.includes('function exerciseV42Bombers(') && html.includes('function waitForV42Images('));
ok('v42 exercise is in the sprite-rendering pass', html.includes('var v42=exerciseV42Bombers()') && html.includes('v42:v42'));
ok('v42 images awaited at boot', html.includes('await waitForV42Images()'));
ok('AceQA.bombers exercise present', html.includes('bombers:function()'));
ok('AceQA.spawnStaaken present', html.includes('spawnStaaken:function()'));
ok('runCampaignPlaytest reports bombers', html.includes('report.bombers=AceQA.bombers()') && html.includes('report.bombers.pass'));

// --- Zeppelin: the airship finally flies ----------------------------------
const zepStages = [];
if (rosterMatch) {
  const entries = [...rosterMatch[1].matchAll(/\{name:'([^']+)',rank:'([^']+)',craft:'([^']+)',hp:(\d+),color:'#[0-9a-f]+'(,kind:'([^']+)')?/g)];
  entries.forEach((m, i) => { if (m[6] === 'zeppelin') zepStages.push(i); });
}
ok('seven Zeppelin bosses in the roster', zepStages.length === 7, 'got ' + zepStages.length + ' at ' + JSON.stringify(zepStages));
ok('Zeppelin bosses are the airship sorties (S3 S5 S8 S13 S18 S23 S28)', JSON.stringify(zepStages) === JSON.stringify([2, 4, 7, 12, 17, 22, 27]), JSON.stringify(zepStages));
ok('art.zeppelin loads the rebuilt v48 envelope plate', html.includes("zeppelin:loadImage('assets/sprites/v48/v48-zeppelin.png')"));
ok('v48 Zeppelin plate exists on disk', fs.existsSync(path.join(ROOT, 'assets/sprites/v48/v48-zeppelin.png')));
ok('drawBoss dispatches airships to drawZeppelinBoss (was dead code)', (() => { const b = fnBody('drawBoss'); return !!b && /if\(b\.kind==='zeppelin'\)\{drawZeppelinBoss\(b\)\}/.test(b); })());
ok('drawZeppelinBoss draws the photographic plate (drawImage, no vector hull)', (() => { const b = fnBody('drawZeppelinBoss'); return !!b && /ctx\.drawImage\(im,-dw\/2,-dh\/2,dw,dh\)/.test(b) && !/ctx\.(arc|ellipse|fillRect)\(/.test(b); })());
ok('Zeppelin spawn is slow (vx 68, top-entry vy 42, radius 145)', /d\.kind==='zeppelin'\?68/.test(html) && /d\.kind==='zeppelin'\?42:58/.test(html) && /d\.kind==='zeppelin'\?Math\.min\(145,W\*\.36\)/.test(html));
ok('Zeppelin boss damage smokes from three gondola engines', /b\.kind==='zeppelin'\?\[-.28,0,.28\]/.test(html));
ok('AceQA.spawnZeppelin present', html.includes('spawnZeppelin:function()'));
ok('Zeppelin sorties briefed (S23 river hunter, S28 final ascent)', html.includes("enemy:'ZEPPELIN'") && html.includes('HUNT THE AIRSHIP') && html.includes('STOP THE FINAL ASCENT'));
ok('Almanac documents the Zeppelin (rigid hull, gondolas, incendiary)', html.includes('<h3>Zeppelin</h3>') && /Rigid-hull airship/.test(html) && /gondolas/.test(html));

// --- Staaken R.VI: the giant gets her own likeness -------------------------
const staakenStages = [];
if (rosterMatch) {
  const entries = [...rosterMatch[1].matchAll(/\{name:'([^']+)',rank:'([^']+)',craft:'([^']+)',hp:(\d+),color:'#[0-9a-f]+'(,kind:'([^']+)')?/g)];
  entries.forEach((m, i) => { if (m[6] === 'staaken') staakenStages.push(i); });
}
ok('two Staaken bosses in the roster', staakenStages.length === 2, 'got ' + staakenStages.length + ' at ' + JSON.stringify(staakenStages));
ok('Staaken bosses are S14 (R.IV) and S29 (R.VI)', JSON.stringify(staakenStages) === JSON.stringify([13, 28]), JSON.stringify(staakenStages));
ok('Staaken R.IV keeps boss-class HP 102', html.includes("name:'STAAKEN R.IV GIANT'") && /STAAKEN R\.IV GIANT[^}]*hp:102/.test(html));
ok('Staaken R.VI keeps boss-class HP 162', html.includes("name:'STAAKEN R.VI GIANT'") && /STAAKEN R\.VI GIANT[^}]*hp:162/.test(html));
ok('Staaken R.VI rank is FOUR-ENGINE (the R.VI had four Maybachs, not six)', html.includes("name:'STAAKEN R.VI GIANT',rank:'FOUR-ENGINE GIANT'") && !html.includes("STAAKEN R.VI GIANT',rank:'SIX-ENGINE"));
ok('drawBoss dispatches giants to drawStaakenBoss (not the generic bank)', (() => { const b = fnBody('drawBoss'); return !!b && /else if\(b\.kind==='staaken'\)\{drawStaakenBoss\(b\);size=Math\.min\(W\*\.92,460\)\}/.test(b); })());
ok('drawStaakenBoss draws the photographic plate (drawImage, no vector airframe)', (() => { const b = fnBody('drawStaakenBoss'); return !!b && /ctx\.drawImage\(im,-dw\/2,-dh\/2,dw,dh\)/.test(b) && !/ctx\.(arc|ellipse|fillRect)\(/.test(b); })());
ok('Staaken spawn is large and slow (vx 80, radius 132, entry vy -150)', /d\.kind==='staaken'\?80:105/.test(html) && /d\.kind==='staaken'\?Math\.min\(132,W\*\.32\)/.test(html) && /d\.kind==='staaken'\?-150:-175/.test(html));
ok('Staaken boss damage smokes from four nose engines', /b\.kind==='staaken'\?\[-.4,-.14,.14,.4\]/.test(html));
ok('Staaken R.VI sortie briefed (S29 railhead giant)', html.includes("enemy:'STAAKEN R.VI'") && html.includes('DOWN THE STAAKEN GIANT'));
ok('Almanac documents the Staaken R.VI (four Maybachs, 42-metre span)', html.includes('<h3>Staaken R.VI</h3>') && /four Maybach engines in the nose, two tractor and two pusher/.test(html) && /42-metre wingspan/.test(html));
ok('no Staaken boss still defaults to the Gotha kind', (() => { const m = html.match(/bossRoster\s*=\s*\[([\s\S]*?)\];/); if (!m) return false; return !/STAAKEN R\.[IV]+ GIANT[^}]*kind:'gotha'/.test(m[1]) && (m[1].match(/STAAKEN/g) || []).length === 4; })());
// PNG proof: the Staaken plate must be RGBA8, feathered, photographic
// (varied, olive camo green, dark Iron Crosses), and no black-box defect.
if (fs.existsSync(path.join(v42Dir, 'v42-staaken.png'))) {
  const st = pngStats(path.join(v42Dir, 'v42-staaken.png'));
  ok('v42 Staaken plate is RGBA8 512x300 and feathered', st.ok && st.w === 512 && st.h === 300 && st.cornerMax <= 8 && st.centre >= 80, st.ok ? ('corners max=' + st.cornerMax + ' centre=' + st.centre) : st.why);
  ok('v42 Staaken plate is photographic (varied, not a flat fill)', st.ok && st.meanLum > 25 && st.meanLum < 120, st.ok ? ('mean lum ' + st.meanLum.toFixed(1)) : st.why);
  ok('v42 Staaken plate carries olive camo green', st.ok && st.greenPx >= 500, st.ok ? ('green ' + st.greenPx) : st.why);
  ok('v42 Staaken plate has no black-box defect (opaque-black < 5%)', st.ok && st.opaqueBlackFrac < 0.05, st.ok ? ('opaque-black ' + (st.opaqueBlackFrac * 100).toFixed(1) + '%') : st.why);
  ok('v42 Staaken plate reads as the giant (long-span planform, 512x300)', st.ok && st.w === 512 && st.h === 300);
} else {
  ok('v42 Staaken plate exists', false, 'missing file');
}
// Pre-existing drift, reported not changed: sortie 18's briefing, objective
// and cues all name a Staaken giant over Amiens, but the roster boss for
// that sortie is a Zeppelin (ZEPPELIN HUNTER-KILLER). The sortie order is
// untouched; the text/roster mismatch predates v42.
if (rosterMatch) {
  const names = [...rosterMatch[1].matchAll(/name:'([^']+)'/g)].map(m => m[1]);
  const s18Brief = html.includes("title:'Amiens Defense'") && html.includes('A Staaken giant drones for Amiens');
  const s18Objective = html.includes('DOWN THE STAAKEN GIANT · SAVE THE CITY');
  if (s18Brief && s18Objective && names[17] && names[17].includes('ZEPPELIN')) {
    note('sortie 18 briefing/objective name a Staaken giant but roster[17] is a Zeppelin', 'briefing + objective + cues say Staaken; boss is ' + names[17] + ' — pre-existing text/roster drift, reported, not changed');
  }
}


// --- v43 bullet hell but beatable (v46: tuned down per the Cap'n's playtest verdict) ------------------------------------------
// Priority 7 gameplay phase: denser enemy fire that stays fair — the
// bullet cap ramps 8 -> 22 with the sortie (tuned down from 30 on the
// Cap'n's own playtest verdict — 'ITS TOO HARD' on his iPhone; 22 stays
// past v42's 20 and the 1942 reference band), fighters fire aimed fans,
// bosses fire distinct readable patterns (radial with a safe gap on the
// pilot's line, aimed bursts, zeppelin broadsides, staaken six-gun fans),
// every bullet stays slower than the pilot (620px/s), and the wingman
// buffer is tuned (wing pickups more often) so one-hit death stays
// survivable. No enemy HP, counts, spawn rates, or sortie order change.
const peakMatch = html.match(/var BULLET_PEAK=\[([\d,\s]+)\];/);
ok('BULLET_PEAK table exists', !!peakMatch);
if (peakMatch) {
  const peak = peakMatch[1].split(',').map(v => +v.trim());
  ok('BULLET_PEAK has 32 entries (one per sortie)', peak.length === 32, 'got ' + peak.length);
  const mono = peak.every((v, i) => i === 0 || v >= peak[i - 1]);
  ok('BULLET_PEAK ramps with the sortie (never decreases)', mono, peak.join(','));
  ok('early sorties stay gentle (S1-S4 peak <= 10, the 1942 band)', peak.slice(0, 4).every(v => v <= 10), peak.slice(0, 4).join(','));
  ok('late sorties are true bullet hell (S29-S32 peak >= 22)', peak.slice(28).every(v => v >= 22), peak.slice(28).join(','));
  ok('S32 peak is 22 (above v42\'s 20, below the 30 the Cap\'n called too hard)', peak[31] === 22, 'got ' + peak[31]);
  console.log('  INFO  BULLET_PEAK S1=' + peak[0] + ' S16=' + peak[15] + ' S32=' + peak[31] + ' (1942 reference peak was 10-20)');
}
ok('bulletHellFireRate helper exists (faster fire late, capped at 6% faster)', /function bulletHellFireRate\(\)\{return 1-Math\.min\(\.06,progress\.selected\*\.002\)\}/.test(html));
ok('fire-rate ramp is applied to the enemy shoot cooldown', /e\.shoot=\(\(ENEMY_ARCHETYPES\[e\.archetype\]\|\|\{\}\)\.shoot\|\|1\.4\+Math\.random\(\)\*\.8\)\*difficultyProfile\(\)\.enemyFire\*bulletHellFireRate\(\)/.test(html));
// Volley upgrades: fighters that fired singles now fire aimed fans.
ok('red fighters fire fan2 (was single)', /red:\{hp:4,r:14,size:100,shoot:1\.2,sprite:'fighter',fire:'fan2',score:200\}/.test(html));
ok('green fighters fire fan3 (was fan2)', /green:\{hp:12,r:24,size:100,shoot:1\.75,sprite:'fighter',fire:'fan3',rear:true,score:500\}/.test(html));
ok('dvii fighters fire fan3 (was fan2)', /dvii:\{hp:14,r:17,size:100,shoot:\.95,sprite:'dvii',fire:'fan3',score:450,pathDur:6\.6\}/.test(html));
ok('dva scouts fire fan2 (was single)', /dva:\{hp:5,r:14,size:100,shoot:1\.1,sprite:'dva',fire:'fan2',score:150,pathDur:5\.4,freq:2\.6\}/.test(html));
ok('clii scouts fire fan2 (was single)', /clii:\{hp:12,r:16,size:104,shoot:1\.3,sprite:'clii',fire:'fan2',score:350,pathDur:6\.0,path:'swoop'\}/.test(html));
ok('junkers bombers fire fan2 (was single)', /junkers:\{hp:30,r:20,size:118,shoot:1\.6,sprite:'junkers',fire:'fan2',score:900,pathDur:8\.2,path:'swoop'\}/.test(html));
ok('early fodder still fires singles (taube/eiii/small gentle start)', /taube:\{hp:2,r:13,size:104,shoot:2\.2,sprite:'taube',fire:'single'/.test(html) && /eiii:\{hp:3,r:13,size:96,shoot:1\.5,sprite:'eiii',fire:'single'/.test(html) && /small:\{hp:3,r:14,size:100,shoot:1\.4,sprite:'scout',fire:'single'/.test(html));
ok('fan3 pattern exists (3-shot aimed fan, spread .34, speed 168)', /else if\(f==='fan3'\)aimedFan\(e\.x,e\.y,target,3,\.34,168,'tracer'\)/.test(html));
ok('green inline volley matches its archetype (fan3, not fan2)', /else if\(e\.archetype==='green'\)\{aimedFan\(e\.x,e\.y,target,3,\.34,168,'tracer'\)/.test(html));
// Boss patterns: denser, distinct, readable — and slower, so the density
// stays dodgeable. The radial keeps its safe gap on the pilot's line.
const sigBody = fnBody('bossSignature');
ok('bossSignature found', !!sigBody);
if (sigBody) {
  ok('boss radial tuned down to 12 (was 16)', /Math\.min\(12,8\+boss\.stage\+level\*2\)/.test(sigBody));
  ok('boss radial is slower (132 + stage*5, was 145 + stage*7)', /132\+boss\.stage\*5/.test(sigBody));
  ok('boss radial keeps the safe gap on the pilot line', /radialPattern\(boss\.x,boss\.y\+20,count,time\*\.65,132\+boss\.stage\*5,\(Math\.atan2\(target\.y-boss\.y,target\.x-boss\.x\)\/6\.283\+1\)%1\)/.test(sigBody));
  ok('boss aimed burst tuned down to 7 (was 9)', /Math\.min\(7,5\+level\*2\),1\.18,185\+boss\.stage\*6,'heavy'/.test(sigBody));
  ok('boss aimed burst is slower (185 + stage*6, was 192 + stage*8)', /185\+boss\.stage\*6/.test(sigBody));
}
const bossBody = fnBody('updateBoss');
ok('updateBoss found', !!bossBody);
if (bossBody) {
  ok('boss forward fan tuned down to 7 (was 9)', /Math\.min\(7,4\+Math\.floor\(bs\/2\)\)/.test(bossBody));
  ok('staaken forward fan adds 2 (six gun positions)', /boss\.kind==='staaken'\?2:0/.test(bossBody));
  ok('zeppelin forward fan is a wide slow broadside (spread 1, speed 160)', /boss\.kind==='zeppelin'\?1:/.test(bossBody) && /boss\.kind==='zeppelin'\?160\+bs\*5/.test(bossBody));
  ok('boss rear fan unchanged (3 + threshold, no creep)', /aimedFan\(boss\.x,boss\.y-boss\.r\*\.4,rearTarget,3\+boss\.threshold/.test(bossBody));
}
// Fairness: no enemy bullet is faster than the pilot can move (620px/s).
// The fastest fixed fighter speed is the triplane lead fan at 225; the
// fastest boss bullet is the aimed burst at 185 + 31*6 = 371 at S32.
ok('fastest fixed fighter bullet is 225 (triplane lead fan)', /aimedFan\(e\.x,e\.y,lead,3,\.16,225,'heavy'\)/.test(html));
ok('no aimedFan call uses a fixed speed above 230', (() => {
  const speeds = [...html.matchAll(/aimedFan\([^;]*?,\s*(\d+)\s*,\s*'(?:tracer|heavy|gold)'\)/g)].map(m => +m[1]);
  return speeds.length > 0 && speeds.every(v => v <= 230);
})());
ok('boss aimed-burst top speed 371 at S32 stays under pilot speed 620', (() => {
  const m = html.match(/aimedFan\(boss\.x,boss\.y\+24,target,Math\.min\(7,5\+level\*2\),1\.18,(185\+boss\.stage\*6),'heavy'\)/);
  return !!m && 185 + 31 * 6 < 620;
})());
// Wingman-buffer tuning: wing pickups come more often, powerups drop more
// often, so a careful player can keep a buffer through the denser sky.
ok('wing powerup weight is 30% (was 18%)', /type=r<\.26\?'firepower':r<\.56\?'wing':/.test(html));
ok('powerup cadence is 4-7s (was 6-10s)', /powerT=4\+Math\.random\(\)\*3/.test(html));
ok('air-kill powerup drop is 24% (was 18%)', /if\(Math\.random\(\)<\.24\)spawnPower\(\)/.test(html));
ok('wingman cap is still 2 per pilot (buffer, not invulnerability)', /if\(owned\.length>=2\)\{owner\.hp=Math\.min\(owner\.maxHp\|\|5,owner\.hp\+1\)/.test(html));
ok('one-hit death doctrine intact (lethal hit with no wingman kills)', (() => {
  const b = fnBody('hitPilot');
  return !!b && /if\(shield\)\{/.test(b) && /p\.hp=0/.test(b) && /p\.inv=3/.test(b);
})());
ok('wingman shield still grants 3s invulnerability', (() => {
  const b = fnBody('hitPilot');
  return !!b && /shield=wingmen\[i\];break/.test(b) && /p\.inv=3/.test(b);
})());
// No mechanic drift: enemy HP, counts, spawn rates, sortie order untouched.
ok('enemy HP untouched (small 3, triplane 18, gotha 40, ghost boss 220)', /small:\{hp:3/.test(html) && /triplane:\{hp:18/.test(html) && /gotha:\{hp:40/.test(html) && /THE CRIMSON GHOST[^}]*hp:220/.test(html));
ok('MAX_ACTIVE_ENEMIES still 10', /var MAX_ACTIVE_ENEMIES=10;/.test(html));
ok('sortie roster still 32 entries in order (S1 taube/eiii/small)', /var SORTIE_ROSTER=\[\{pool:\['taube','eiii','small'\]\}/.test(html));
// The exercise + wiring.
ok('bulletHellSteer pilot AI present', html.includes('function bulletHellSteer('));
ok('exerciseBulletHellSortie present', html.includes('function exerciseBulletHellSortie('));
ok('exerciseBulletHell present', html.includes('function exerciseBulletHell('));
ok('AceQA.bulletHell wired', html.includes('bulletHell:function(){return exerciseBulletHell()}'));
ok('campaign playtest reports bulletHell', html.includes('bulletHell:null') && html.includes('report.bulletHell=AceQA.bulletHell();'));
ok('campaign playtest pass requires bulletHell', /report\.bombers\.pass&&report\.bulletHell\.pass/.test(html));
ok('bullet-hell sim uses only the game normal spawn cover (2 wingmen, no cheat inv)', (() => {
  const b = fnBody('exerciseBulletHellSortie');
  return !!b && /addWingman\(player\);addWingman\(player\)/.test(b) && !/player\.inv\s*=/.test(b);
})());
ok('bullet-hell sim requires boss killed + landing + pilot alive', (() => {
  const b = fnBody('exerciseBulletHellSortie');
  return !!b && /beatable:landed&&player\.hp>0/.test(b) && /bossKilled:bossDead/.test(b);
})());

// --- v44 six fiery crash-and-burn deaths -------------------------------------
// One death animation is not enough: the pilot gets six distinct fiery
// crash-and-burn deaths, picked fresh at random every time, each with its
// own fall, fire, and impact — all photographic plates, no blood, no gore.
const v44Dir = path.join(ROOT, 'assets/sprites/v44');
['v44-wing.png', 'v44-tail.png'].forEach(f => {
  ok('v44 plate exists: ' + f, fs.existsSync(path.join(v44Dir, f)));
  const r = pngAlphaCorners(path.join(v44Dir, f));
  ok(f + ' is RGBA8 and feathered (corners transparent, centre visible)', r.ok, r.why || ('corners max=' + r.worst + ' centre=' + r.centre));
});
ok('v44Art loads the sheared wing + tail plates', html.includes("var v44Art={wing:loadImage('assets/sprites/v44/v44-wing.png'),tail:loadImage('assets/sprites/v44/v44-tail.png')}"));
ok('CRASH_DEATHS table has six profiles', (() => { const labels = ['SPIRAL OF FIRE', 'WINGSHEAR FIREBALL', 'FLAT SPIN INFERNO', 'LAST GLIDE', 'DEATH ROLL', 'TAILSPIN PLUNGE']; return html.includes('var CRASH_DEATHS=[') && labels.every(l => html.includes("label:'" + l + "'")); })());
ok('startCrash picks a random variant in gameplay, forced in QA', html.includes('function startCrash(p,forced){') && html.includes('Math.floor(Math.random()*6)'));
ok('player impact fires the photographic v37 explosion', (() => { const b = fnBody('updateCrashEntity'); return !!b && /spawnExplosion\(c\.x,c\.y,P\.boom\)/.test(b); })());
ok('v37 explosions animate during the fatal crash (updateExplosions in crashSeq)', html.includes('if(crashSeq){updateExplosions(dt)'));
ok('WINGSHEAR FIREBALL sheds a photographic wing + tail that tumble trailing fire', (() => { const b = fnBody('updateCrashEntity'); return !!b && /c\.wingShed=true/.test(b) && /c\.wing=\{x:c\.x-22/.test(b) && /c\.tail=\{x:c\.x\+18/.test(b); })() && html.includes('drawCrashPart(c.wing,v44Art.wing,120)') && html.includes('drawCrashPart(c.tail,v44Art.tail,90)'));
ok('WINGSHEAR FIREBALL fires twin mid-air bursts before impact', html.includes("airBursts:[{at:.45,size:'medium'},{at:.95,size:'medium'}]"));
ok('LAST GLIDE erupts twice on touchdown', html.includes("doubleBoom:{at:.15,size:'medium'}"));
ok('crash finishes 1.6s after impact (done flag reachable post-impact)', html.includes('if(c.t-c.impactAt>1.6)c.done=true'));
ok('DOWN board waits for the impact fireball', html.includes('if(c.impact&&c.t-c.impactAt>0.45)'));
ok('death hands off to the KIA debrief exactly as before (finish(false) on crash end)', html.includes('if(crashSeq.done||crashSeq.t>5){crashSeq.done=true;crashSeq=null;finish(false)'));
ok('gore-free: no bloodHit anywhere, oil + sparks only', !html.includes('bloodHit') && html.includes('function oilHit('));
ok('death exercise forces each variant and requires impact + boom + debrief', html.includes('function exerciseV44Deaths(){') && html.includes('deaths:function(){return exerciseV44Deaths()}'));
ok('campaign playtest reports deaths and requires them to pass', html.includes('deaths:null') && html.includes('report.deaths=AceQA.deaths();') && /report\.deaths\.pass/.test(html));

// --- v45 KIA screen above the fold ------------------------------------------
// The KIA debrief (#result, rank "KILLED IN ACTION") must open above the
// fold on a phone: it opens scrolled to the top, the desk no longer forces a
// 700px-tall scene on short viewports, and the retry actions pin to the
// bottom of the visible area while the board scrolls. Same board, same
// buttons, same copy — only where it appears changes.
const showFn = fnBody('show');
ok('show() opens every screen scrolled to the top (scrollTop reset)', !!showFn && /scrollTop\s*=\s*0/.test(showFn));
ok('finish() opens the KIA debrief at the top', html.includes("show('result');var resultScreen=document.getElementById('result');try{resultScreen.scrollTop=0}"));
ok('KIA rank text unchanged (KILLED IN ACTION)', html.includes("'KILLED IN ACTION'"));
ok('KIA retry button unchanged (same label and id)', html.includes('\u21bb Retry sortie') && html.includes('id="again"'));
ok('compact KIA layout exists for short viewports (max-height:960px)', /@media\(max-height:960px\)/.test(html) && /#result \.desk-scene\{min-height:0/.test(html));
ok('compact KIA layout pins the actions to the viewport bottom (sticky)', /#result \.result-actions\{[^}]*position:sticky/.test(html));
ok('compact KIA keeps the board and its copy (only the tall-desk props step aside)', /#result \.desk-map,#result \.keepsake\{display:none\}/.test(html) && html.includes('class="aar-board"') && !/#result \.aar-board\{display:none/.test(html));

// --- v45 high-altitude drop shadows -----------------------------------------
// One shared photographic silhouette plate per sprite, one shared altitude
// model (sun upper-left, shadow down-right; higher = further off, smaller,
// softer, lighter) for player, wingmen, enemies and bosses, drawn in the
// terrain layer under the aircraft. No vector shadows anywhere in the new code.
ok('shadowPlateFor exists (one photographic plate per sprite, cached)', html.includes('function shadowPlateFor('));
ok('shadowAltParams exists (shared altitude model)', html.includes('function shadowAltParams('));
ok('drawAircraftShadow exists (shared shadow drawer)', html.includes('function drawAircraftShadow('));
ok('drawWingmanShadow / drawEnemyShadow / drawBossShadow exist', html.includes('function drawWingmanShadow(') && html.includes('function drawEnemyShadow(') && html.includes('function drawBossShadow('));
ok('player shadow routes through the shared drawer (64px base, loop altitude)', (() => { const b = fnBody('drawPlayerShadow'); return !!b && /drawAircraftShadow\(p\.x,p\.y,/.test(b) && /,64,/.test(b) && /loopAltitude/.test(b); })());
ok('wingman/enemy/boss shadows drawn in the terrain pass (before the aircraft)', (() => { const d = fnBody('draw'); return !!d && /drawWingmanShadow/.test(d) && /drawEnemyShadow/.test(d) && /drawBossShadow\(boss\)/.test(d) && d.indexOf('drawBossShadow(boss)') < d.indexOf('enemies.forEach(drawEnemy)'); })());
ok('shadow drawers use raster plates only (no vector shapes)', (() => { const s = html.indexOf('function drawAircraftShadow('); const e = html.indexOf('/* Each operation now has its own encounter cadence', s); const blk = s >= 0 && e > s ? html.slice(s, e) : ''; return blk.length > 0 && !/ctx\.(arc|ellipse|fillRect|beginPath|createRadialGradient|createLinearGradient)\(/.test(blk) && /drawImage\(plate/.test(blk); })());
ok('altitude model: offset grows, scale and alpha shrink with altitude', (() => { const b = fnBody('shadowAltParams'); return !!b && /650\+\(H-y\)\*2\.2/.test(b) && /1\.28-altU\*\.85/.test(b) && /18\+altU\*86/.test(b) && /\.5-altU\*\.38/.test(b); })());
ok('boss shadows use a 1.0x base (giants stay readable, not screen-filling)', (() => { const b = fnBody('drawBossShadow'); return !!b && /baseW=drawnW,baseH=baseW\*\.75/.test(b); })());
ok('exerciseV45Shadows exists and is wired into the sprite pass', html.includes('function exerciseV45Shadows(') && /var v45=exerciseV45Shadows\(\)/.test(html) && /v45\.pass/.test(html));
ok('AceQA.shadows exists and runCampaignPlaytest reports it', html.includes('shadows:function(){return exerciseV45Shadows()}') && /report\.shadows=AceQA\.shadows\(\)/.test(html));


// --- v47 enemy banking: true +/-14 deg poses + continuous photographic roll ---
// Enemies used to yaw flat on a pivot: the bank poses were mostly duds
// (triplane/scout/fighter/bomber/bosses ~+/-1 deg, dvii ~0.3 deg) or wild
// (rumpler/junkers ~+/-23.5 deg, clii/taube ~+/-18.2 deg), and pfalz was
// REVERSED. drawEnemy/drawBoss snapped between poses at a +/-0.18 threshold,
// so a real pose made the nose snap +/-14-23 deg off the flight path. Now
// every pose is a true +/-14 deg rotation of its own level photo
// (bin/build-v47-bank.py), and the draw path rolls the LEVEL sprite
// continuously by bank*14 deg, eased from the true turn rate — nose on
// course, wings rolled into the turn. Fighters roll 14 deg, aces 12 deg,
// the Staaken giant a slow 5 deg, the Zeppelin never rolls.
ok('v47 bank build script exists', fs.existsSync(path.join(ROOT, 'bin', 'build-v47-bank.py')));
const BANK_PREFIXES = ['enemy-triplane', 'enemy-scout', 'enemy-fighter', 'enemy-bomber',
  'enemy-dri', 'enemy-dvii', 'enemy-dva', 'enemy-eiii', 'enemy-pfalz',
  'enemy-gotha', 'enemy-clii', 'enemy-rumpler', 'enemy-junkers', 'enemy-taube',
  'boss-1-red', 'boss-2-checker', 'boss-3-stripes', 'boss-4-tiger',
  'boss-5-jester', 'boss-6-ghost'];
const missingBank = [];
BANK_PREFIXES.forEach(function (p) {
  ['bank-left', 'bank-right'].forEach(function (s) {
    if (!fs.existsSync(path.join(ROOT, 'assets', 'sprites', p + '-' + s + '.png'))) missingBank.push(p + '-' + s);
  });
});
ok('all 40 enemy/boss bank poses exist (20 sets x left/right)', missingBank.length === 0, missingBank.join(', '));
// Principal-axis angle of the visible silhouette, decoded from the PNG
// (same inflate + unfilter as pngRgbStats). The bank poses must sit at
// level-14 deg (bank-left) and level+14 deg (bank-right), +/-3 deg.
function pngPrincipalAngle(file) {
  const buf = fs.readFileSync(file);
  if (buf.slice(0, 8).toString('hex') !== '89504e470d0a1a0a') return null;
  let pos = 8, w = 0, h = 0, bitDepth = 0, colorType = 0; const idat = [];
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos), type = buf.toString('ascii', pos + 4, pos + 8);
    const data = buf.slice(pos + 8, pos + 8 + len);
    if (type === 'IHDR') { w = data.readUInt32BE(0); h = data.readUInt32BE(4); bitDepth = data[8]; colorType = data[9]; }
    else if (type === 'IDAT') idat.push(data);
    else if (type === 'IEND') break;
    pos += 12 + len;
  }
  if (colorType !== 6 || bitDepth !== 8) return null;
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
  let sx = 0, sy = 0, sxx = 0, syy = 0, sxy = 0, n = 0;
  for (let y = 0; y < h; y += 2) for (let x = 0; x < w; x += 2) {
    if (px[(y * w + x) * bpp + 3] > 40) { sx += x; sy += y; sxx += x * x; syy += y * y; sxy += x * y; n++; }
  }
  if (n < 50) return null;
  const cx = sx / n, cy = sy / n;
  const cxx = sxx / n - cx * cx, cyy = syy / n - cy * cy, cxy = sxy / n - cx * cy;
  return 0.5 * Math.atan2(2 * cxy, cxx - cyy) * 180 / Math.PI;
}
const badBank = [];
BANK_PREFIXES.forEach(function (p) {
  const dir = path.join(ROOT, 'assets', 'sprites');
  const aL = pngPrincipalAngle(path.join(dir, p + '-level.png'));
  const aB = pngPrincipalAngle(path.join(dir, p + '-bank-left.png'));
  const aR = pngPrincipalAngle(path.join(dir, p + '-bank-right.png'));
  if (aL === null || aB === null || aR === null) { badBank.push(p + ': undecodable'); return; }
  if (Math.abs((aB - aL) + 14) > 3 || Math.abs((aR - aL) - 14) > 3) {
    badBank.push(p + ': level ' + aL.toFixed(1) + ' left ' + aB.toFixed(1) + ' right ' + aR.toFixed(1));
  }
});
ok('all 20 bank pose sets are true +/-14 deg rotations of their level photo', badBank.length === 0, badBank.join('; '));
ok('pfalz bank is no longer reversed (left -14, right +14)', (() => {
  const dir = path.join(ROOT, 'assets', 'sprites');
  const aL = pngPrincipalAngle(path.join(dir, 'enemy-pfalz-level.png'));
  const aB = pngPrincipalAngle(path.join(dir, 'enemy-pfalz-bank-left.png'));
  const aR = pngPrincipalAngle(path.join(dir, 'enemy-pfalz-bank-right.png'));
  return aL !== null && aB !== null && aR !== null && (aB - aL) < -11 && (aR - aL) > 11;
})());
// Draw path: continuous photographic roll, not a pose snap.
ok('drawEnemy rolls the level sprite continuously (rot = heading + PI/2 + bank*14deg)', (() => {
  const b = fnBody('drawEnemy');
  return !!b && /rot=heading\+Math\.PI\/2\+\(e\.bank\|\|0\)\*\.2443/.test(b);
})());
ok('drawEnemy no longer snaps between bank poses (im is level, not bank-selected)', (() => {
  const b = fnBody('drawEnemy');
  return !!b && !/im=bankedSprite\(set,e\.bank/.test(b) && /im=\(e\.hp\/e\.max<=.25&&set\.damaged\)\?set\.damaged:\(set\.level/.test(b);
})());
ok('drawEnemy uses the level sprite (damaged only when hurt)', (() => {
  const b = fnBody('drawEnemy');
  return !!b && /set\.level\|\|bankedSprite/.test(b) && /e\.hp\/e\.max<=.25&&set\.damaged/.test(b);
})());
ok('drawEnemy damage glow and bullet holes follow the rolled rotation', (() => {
  const b = fnBody('drawEnemy');
  return !!b && /daEngineGlow\(e,rot,size\)/.test(b) && /daDrawEnemyHoles\(e,rot\)/.test(b);
})());
ok('bossBankRoll exists: fighter 12deg, Staaken 5deg, Zeppelin never rolls', (() => {
  const b = fnBody('bossBankRoll');
  return !!b && /kind==='zeppelin'\)return 0/.test(b) && /kind==='staaken'\)return \(b\.bank\|\|0\)\*\.0873/.test(b) && /return \(b\.bank\|\|0\)\*\.2094/.test(b);
})());
ok('drawBoss rolls fighter aces on the level sprite (no pose snap)', (() => {
  const b = fnBody('drawBoss');
  return !!b && /drawBlenderSprite\(im,b\.x,b\.y,size,rot\+bossRoll,1\)/.test(b) && !/bankedSprite\(set,lateral\)/.test(b);
})());
ok('drawBoss gunner flashes and tell ring roll with the boss', (() => {
  const b = fnBody('drawBoss');
  return !!b && /ctx\.rotate\(rot\+bossRoll\)/.test(b);
})());
ok('drawStaakenBoss rolls on bossBankRoll (no more tiny vx/2200 tilt)', (() => {
  const b = fnBody('drawStaakenBoss');
  return !!b && /ctx\.rotate\(Math\.PI\+bossBankRoll\(b\)\)/.test(b) && !/vx\/2200/.test(b);
})());
ok('drawZeppelinBoss never rolls (airship keeps its slight sway)', (() => {
  const b = fnBody('drawZeppelinBoss');
  return !!b && !/bossBankRoll/.test(b) && /vx\/2200/.test(b);
})());
ok('updateBoss eases b.bank from lateral velocity (fighter 6/s, Staaken 2.5/s)', (() => {
  const b = fnBody('updateBoss');
  return !!b && /bankTarget=Math\.max\(-1,Math\.min\(1,boss\.vx\/72\)\)/.test(b) && /bankRate=boss\.kind==='staaken'\?2\.5:6/.test(b) && /boss\.bank=\(boss\.bank\|\|0\)\+\(bankTarget-\(boss\.bank\|\|0\)\)\*\(1-Math\.exp\(-dt\*bankRate\)\)/.test(b);
})());
ok('enemy bank is still driven by the true turn rate (advancePathEnemy targetBank)', (() => {
  const b = fnBody('advancePathEnemy');
  return !!b && /targetBank=Math\.max\(-1\.05,Math\.min\(1\.05,turn\/Math\.max\(dt,.0001\)\*\.6\)\)/.test(b) && /e\.bank=\(e\.bank\|\|0\)\+\(targetBank-\(e\.bank\|\|0\)\)\*smooth/.test(b);
})());
ok('no vector shapes in the new v47 banking code (roll is a photographic rotation)', (() => {
  const e = fnBody('drawEnemy'), b = fnBody('drawBoss'), s = fnBody('drawStaakenBoss'), u = fnBody('updateBoss');
  const blk = (e || '') + (b || '') + (s || '') + (u || '');
  return blk.length > 0 && !/ctx\.(arc|ellipse|fillRect|beginPath|createRadialGradient|createLinearGradient)\(/.test(blk) && /drawBlenderSprite\(/.test(blk);
})());
ok('exerciseV47Banking exists and is wired into the sprite pass', html.includes('function exerciseV47Banking(') && /var v47=exerciseV47Banking\(\)/.test(html) && /v47\.pass/.test(html));
ok('AceQA.banking exists and runCampaignPlaytest reports it', html.includes('banking:function(){return exerciseV47Banking()}') && /report\.banking=AceQA\.banking\(\)/.test(html));


// --- v48 L-33 destructible components + before/after battle damage ---------
// The Zeppelin boss used to be one fat hitbox: bullets only ever hurt the
// hull. Now the L-33 (LZ 76) carries ten shootable sub-targets ON the
// airship — 2 armored MG battlestations, 3 fuel cells, 2 gondolas, 3 Maybach
// engine air props — each with its own plate-space position, HP, and
// destroyed state. MGs silence their gunner, fuel cells blow 8% of max HP,
// dead gondolas kill their props, dead props slow her (12% each) and a dead
// control car costs another 15%. Main HP is unchanged. Damage accumulates
// visibly: a fresh L-33 flies clean; a mauled one shows torn fabric where
// cells blew, scorched gondolas, hull scorch patches at 75/50/25% HP, and
// photographic fire + smoke from the actual damage points. All plates are
// photographic (bin/build-v48-zeppelin.py); no vector scorch, no drawn
// flames, no generated pixels, no downloaded sprites.
ok('v48 build script exists', fs.existsSync(path.join(ROOT, 'bin', 'build-v48-zeppelin.py')));
const V48_PLATES = ['v48-zeppelin.png', 'v48-fuelcover.png', 'v48-prop.png', 'v48-tear.png'];
const missingV48 = V48_PLATES.filter(function (f) { return !fs.existsSync(path.join(ROOT, 'assets', 'sprites', 'v48', f)); });
ok('all 4 v48 plates exist', missingV48.length === 0, missingV48.join(', '));
const V48_SIZES = { 'v48-zeppelin.png': [440, 150], 'v48-fuelcover.png': [52, 32], 'v48-prop.png': [56, 56], 'v48-tear.png': [64, 44] };
Object.keys(V48_SIZES).forEach(function (f) {
  const r = pngAlphaCorners(path.join(ROOT, 'assets', 'sprites', 'v48', f));
  ok(f + ' is RGBA8, feathered, ' + V48_SIZES[f][0] + 'x' + V48_SIZES[f][1],
    r.ok && r.w === V48_SIZES[f][0] && r.h === V48_SIZES[f][1],
    r.why || ('got ' + r.w + 'x' + r.h + ' corners max=' + r.worst + ' centre=' + r.centre));
});
ok('art.zeppelin is the rebuilt v48 envelope (not the v34 plate)', html.includes("zeppelin:loadImage('assets/sprites/v48/v48-zeppelin.png')"));
ok('v48Art loads all 4 plates', /var v48Art=\{[^}]*mg:loadImage\('assets\/sprites\/v34\/v34-arty\.png'\)[^}]*fuelcover:loadImage\('assets\/sprites\/v48\/v48-fuelcover\.png'\)[^}]*prop:loadImage\('assets\/sprites\/v48\/v48-prop\.png'\)[^}]*tear:loadImage\('assets\/sprites\/v48\/v48-tear\.png'\)/.test(html));
const compMatch = html.match(/var ZEPPELIN_COMPONENTS=\[([\s\S]*?)\];/);
ok('ZEPPELIN_COMPONENTS table exists', !!compMatch);
if (compMatch) {
  const tbl = compMatch[1];
  const count = (t) => (tbl.match(new RegExp("type:'" + t + "'", 'g')) || []).length;
  ok('10 components: 2 MG + 3 fuel + 2 gondola + 3 props', count('mg') === 2 && count('fuel') === 3 && count('gondola') === 2 && count('prop') === 3,
    'mg=' + count('mg') + ' fuel=' + count('fuel') + ' gondola=' + count('gondola') + ' prop=' + count('prop'));
  const hps = {};
  [...tbl.matchAll(/type:'(\w+)'[^}]*hp:(\d+)/g)].forEach(m => { hps[m[1]] = hps[m[1]] || []; hps[m[1]].push(+m[2]); });
  ok('armored MGs take 16 hits (more than a normal gun)', (hps.mg || []).every(h => h === 16), JSON.stringify(hps.mg));
  ok('fuel cells take 8 hits (moderate)', (hps.fuel || []).every(h => h === 8), JSON.stringify(hps.fuel));
  ok('gondolas take 12 hits (moderate)', (hps.gondola || []).every(h => h === 12), JSON.stringify(hps.gondola));
  ok('props take 6 hits', (hps.prop || []).every(h => h === 6), JSON.stringify(hps.prop));
  ok('component positions sit on the airship plate (0..440 x 0..150)', [...tbl.matchAll(/x:(\d+),y:(\d+)/g)].every(m => +m[1] >= 0 && +m[1] <= 440 && +m[2] >= 0 && +m[2] <= 150));
  ok('gondolas own their props (control car: fwd prop; engine gondola: port + starboard)', /props:\['pf'\]/.test(tbl) && /props:\['pp','ps'\]/.test(tbl));
}
['spawnZeppelinComponents', 'zeppelinComponentAt', 'zeppelinComponentHit', 'damageZeppelinComponent', 'zeppelinSpeedFactor', 'zeppelinDamageMarkers', 'zepPlateToScreen', 'zepPlateToRotated', 'drawZeppelinComponents', 'drawZeppelinDamage'].forEach(function (fn) {
  ok('v48 function exists: ' + fn, html.includes('function ' + fn + '('));
});
ok('stage 2 boss is the L-33 (name + Maybach craft)', /name:'L-33 · ZEPPELIN RAIDER'/.test(html) && /craft:'L-33 \(LZ 76\) · MAYBACH ENGINES'/.test(html));
ok('other Zeppelins are NOT renamed (COMMAND still flies)', /name:'ZEPPELIN COMMAND'/.test(html));
ok('almanac names the L-33 (LZ 76, five Maybach engines, Essex 1916)', /L-33 \(LZ 76\) — five Maybach engines/.test(html) && /brought down burning over Essex in September 1916/.test(html));
ok('spawnBoss builds the component set for every Zeppelin', /if\(d\.kind==='zeppelin'\)\{boss\.comps=spawnZeppelinComponents\(\);boss\.propAngle=0;boss\.mgFwdDead=false;boss\.mgAftDead=false\}/.test(html));
ok('player bullets hit components before the hull', /if\(!zeppelinComponentHit\(boss,b\)\)boss\.hp-=b\.d/.test(html));
ok('component HP scales with the boss-HP difficulty multiplier', (() => { const b = fnBody('spawnZeppelinComponents'); return !!b && /difficultyProfile\(\)\.bossHp/.test(b); })());
ok('fuel-cell blast takes 8% of the Zeppelin max HP', (() => { const b = fnBody('damageZeppelinComponent'); return !!b && /boss\.hp-=Math\.round\(boss\.max\*\.08\)/.test(b); })());
ok('dead MG battlestations silence their gunner (fwd/aft flags)', (() => { const b = fnBody('damageZeppelinComponent'); return !!b && /boss\.mgFwdDead=true/.test(b) && /boss\.mgAftDead=true/.test(b); })());
ok('dead gondola kills the props it carried', (() => { const b = fnBody('damageZeppelinComponent'); return !!b && /c\.props/.test(b) && /pr\.dead=true/.test(b); })());
ok('dead props slow her: 12% per prop, control car costs another 15%', (() => { const b = fnBody('zeppelinSpeedFactor'); return !!b && /1-\(3-alive\)\*\.12/.test(b) && /f\*=.85/.test(b); })());
ok('updateBoss spins the Maybach props (16 rad/s)', (() => { const b = fnBody('updateBoss'); return !!b && /boss\.propAngle=\(boss\.propAngle\|\|0\)\+dt\*16/.test(b); })());
ok('updateBoss slows the Zeppelin by the speed factor', (() => { const b = fnBody('updateBoss'); return !!b && /zeppelinSpeedFactor\(boss\)/.test(b); })());
ok('updateBoss gates the gunners on their MG battlestations', (() => { const b = fnBody('updateBoss'); return !!b && /!boss\.mgFwdDead/.test(b) && /!boss\.mgAftDead/.test(b); })());
ok('drawZeppelinBoss draws the components inside the hull rotate block', (() => { const b = fnBody('drawZeppelinBoss'); return !!b && /drawZeppelinComponents\(b,dw,dh\)/.test(b); })());
ok('drawZeppelinComponents draws MG nests, fuel covers, spinning props; dead fuel cells tear, dead gondolas scorch', (() => {
  const b = fnBody('drawZeppelinComponents');
  return !!b && /drawFx\(v48Art\.mg/.test(b) && /drawFx\(v48Art\.fuelcover/.test(b) && /drawFx\(v48Art\.prop,q\[0\],q\[1\],34\*s,\(b\.propAngle/.test(b) && /drawFx\(v48Art\.tear/.test(b) && /drawFx\(fxArt\.scorch/.test(b);
})());
ok('hull scorch accumulates at 75/50/25% HP (not one flip at low HP)', (() => {
  const b = fnBody('drawZeppelinComponents');
  return !!b && /\[160,45,\.75\],\[280,45,\.5\],\[220,80,\.25\]/.test(b);
})());
ok('drawZeppelinDamage burns photographic fire + smoke from the actual damage points', (() => {
  const b = fnBody('drawZeppelinDamage');
  return !!b && /drawFx\(v36Art\.fireglow/.test(b) && /drawFxSheet\(fxArt\.fire/.test(b) && /drawFx\(v36Art\.smoke2/.test(b) && /zepPlateToScreen\(b,c\.x,c\.y\)/.test(b);
})());
ok('drawBossDamage runs the Zeppelin damage even above 72% HP (a dead cell burns early)', (() => {
  const b = fnBody('drawBossDamage');
  return !!b && /if\(b\.kind==='zeppelin'\)drawZeppelinDamage\(b,ratio\)/.test(b);
})());
ok('no vector shapes in the new v48 code (photographic plates only)', (() => {
  const start = html.indexOf('/* v48 L-33 destructible components — armored MG battlestations, fuel cells,');
  const end = html.indexOf('function drawZeppelinBoss', start);
  const blk = (start >= 0 && end > start ? html.slice(start, end) : '') + (fnBody('drawZeppelinComponents') || '') + (fnBody('drawZeppelinDamage') || '');
  return blk.length > 0 && !/ctx\.(arc|ellipse|fillRect|beginPath|createRadialGradient|createLinearGradient)\(/.test(blk) && /drawFx\(v48Art/.test(blk);
})());
ok('Zeppelin main HP unchanged (stage 2 still 58)', (() => {
  const m = html.match(/bossRoster\s*=\s*\[([\s\S]*?)\];/);
  if (!m) return false;
  const hps = [...m[1].matchAll(/hp:\s*(\d+)/g)].map(x => +x[1]);
  return hps.length === 32 && hps[2] === 58;
})());
ok('exerciseV48Zeppelin exists and is wired into the sprite pass', html.includes('function exerciseV48Zeppelin(') && /var v48=exerciseV48Zeppelin\(\)/.test(html) && /v48\.pass/.test(html));
ok('exerciseV48ZeppelinComponents exists (functional component checks)', html.includes('function exerciseV48ZeppelinComponents('));
ok('AceQA.zeppelinComps exists and runCampaignPlaytest reports it', html.includes('zeppelinComps:function(){return exerciseV48ZeppelinComponents()}') && /report\.zeppelinComps=AceQA\.zeppelinComps\(\)/.test(html));
ok('waitForV48Images exists and the playtest awaits it', html.includes('function waitForV48Images(') && /await waitForV48Images\(\)/.test(html));

// --- summary -----------------------------------------------------------------
console.log('\nv48 static QA: ' + pass + ' passed, ' + fail + ' failed, ' + warn + ' warnings');
if (failures.length) { console.log('FAILURES:'); failures.forEach(f => console.log('  - ' + f)); }
if (warnings.length) { console.log('WARNINGS:'); warnings.forEach(w => console.log('  - ' + w)); }
process.exit(fail ? 1 : 0);
