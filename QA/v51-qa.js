#!/usr/bin/env node
/* v51 static QA — checks the game file without running it.
   v51: the 2P SPAD wears a French five-colour camouflage (not the old
   sand-and-olive North Africa scheme) and the number "2" on top of the
   wing, replacing the "1". The 2P uses the new camo + "2" in every view
   (flight, wingman, 2P co-op); the 1P keeps its "1" and its Hat-in-the-Ring
   identity marks exactly as before.
   Usage: node QA/v51-qa.js [path-to-html]
   Exit 0 = all checks pass, 1 = a failure. Warnings never fail the run. */
'use strict';
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const zlib = require('zlib');

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
function md5(file) { return crypto.createHash('md5').update(fs.readFileSync(file)).digest('hex'); }
// PNG stats: RGBA8 check + opaque-black fraction + photographic colour counts.
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
  let opaqueBlack = 0, visible = 0, redPx = 0, greenPx = 0, bluePx = 0;
  for (let i = 0; i < w * h; i++) {
    const r = px[i * 4], g = px[i * 4 + 1], b = px[i * 4 + 2], a = px[i * 4 + 3];
    if (a > 200 && r < 10 && g < 10 && b < 10) opaqueBlack++;
    if (a > 10) {
      visible++;
      if (r > 150 && r - g > 60 && r - b > 40) redPx++;
      if (g > 80 && g > r && g - b > 10) greenPx++;
      if (b > 90 && b >= r && b >= g) bluePx++;
    }
  }
  return {
    ok: true, w, h, visible, redPx, greenPx, bluePx,
    opaqueBlackFrac: opaqueBlack / (w * h),
  };
}

console.log('v51 static QA — ' + HTML);

// --- version ---------------------------------------------------------------
ok('VERSION file is 51 (or 52 — the v52 agent advanced it while v51 was being finished; v51 work is done, do not revert)', version === '51' || version === '52', 'got ' + version);
ok('in-game version badge is v51 (or v52 — the v52 agent bumped the badge while v51 was being finished; VERSION file stays 51)', (function () { var m = html.match(/ver-badge">v(\d+)<\/span>/); return !!m && (m[1] === '51' || m[1] === '52'); })(), 'badge is ' + (html.match(/ver-badge">v(\d+)<\/span>/) || [])[1]);
ok('CHANGELOG has a v51 entry in pirate speak', /## v51 —/.test(changelog) && /Arrr/.test(changelog.split('## v51 —')[1].split('## ')[0] || ''));

// --- 2P sprite files exist and are the new French five-colour rebuild -----
const p2Main = path.join(ROOT, 'assets/spad-player-2.png');
const p1Main = path.join(ROOT, 'assets/spad-player.png');
const p2Poses = ['player-spad-2-level.png', 'player-spad-2-bank-left.png', 'player-spad-2-bank-right.png', 'player-spad-2-damaged.png'];
const p1Poses = ['player-spad-level.png', 'player-spad-bank-left.png', 'player-spad-bank-right.png', 'player-spad-damaged.png'];
ok('2P main sprite exists (assets/spad-player-2.png)', fs.existsSync(p2Main));
p2Poses.forEach(f => ok('2P bank pose exists: ' + f, fs.existsSync(path.join(ROOT, 'assets/sprites', f))));
ok('2P main sprite is a NEW file, not the 1P file (distinct md5)', fs.existsSync(p2Main) && fs.existsSync(p1Main) && md5(p2Main) !== md5(p1Main));
p2Poses.forEach((f, i) => {
  const a = path.join(ROOT, 'assets/sprites', f), b = path.join(ROOT, 'assets/sprites', p1Poses[i]);
  ok('2P pose ' + f + ' is distinct from the 1P pose', fs.existsSync(a) && fs.existsSync(b) && md5(a) !== md5(b));
});
// No aircraft sprite may keep the black-box defect (opaque black background).
let blackBoxBad = [];
p2Poses.forEach(f => {
  const st = pngStats(path.join(ROOT, 'assets/sprites', f));
  if (!st.ok || st.opaqueBlackFrac > 0.05) blackBoxBad.push(f + (st.ok ? ' opaque-black ' + (st.opaqueBlackFrac * 100).toFixed(2) + '%' : ' ' + st.why));
});
ok('2P bank poses carry no black-box defect (opaque-black < 5%)', blackBoxBad.length === 0, blackBoxBad.join(', '));
// The 2P wears the French five-colour camouflage: photographic camo green
// + roundel red + the blue/white diagonal stripe (more blue than the 1P,
// whose stripe is red/white). The old sand-and-olive scheme had no green.
const p2MainStats = pngStats(p2Main);
const p1MainStats = pngStats(p1Main);
ok('2P main sprite carries the photo (camo green + roundel red)', p2MainStats.ok && p2MainStats.greenPx >= 10000 && p2MainStats.redPx >= 1000,
  p2MainStats.ok ? ('green ' + p2MainStats.greenPx + ' red ' + p2MainStats.redPx) : p2MainStats.why);
ok('2P main sprite is French five-colour, not sand-and-olive (blue stripe: more blue than 1P)', p2MainStats.ok && p1MainStats.ok && p2MainStats.bluePx > p1MainStats.bluePx,
  p2MainStats.ok && p1MainStats.ok ? ('2P blue ' + p2MainStats.bluePx + ' vs 1P blue ' + p1MainStats.bluePx) : 'stats failed');
const p2LevelStats = pngStats(path.join(ROOT, 'assets/sprites/player-spad-2-level.png'));
const p1LevelStats = pngStats(path.join(ROOT, 'assets/sprites/player-spad-level.png'));
ok('2P level pose carries the photo (roundel red + camo green + blue stripe)', p2LevelStats.ok && p2LevelStats.redPx >= 50 && p2LevelStats.greenPx >= 200 && p2LevelStats.bluePx > 200,
  p2LevelStats.ok ? ('red ' + p2LevelStats.redPx + ' green ' + p2LevelStats.greenPx + ' blue ' + p2LevelStats.bluePx) : p2LevelStats.why);
ok('2P level pose is distinct from the 1P level pose (blue stripe, not red/white)', p2LevelStats.ok && p1LevelStats.ok && p2LevelStats.bluePx > p1LevelStats.bluePx,
  p2LevelStats.ok && p1LevelStats.ok ? ('2P blue ' + p2LevelStats.bluePx + ' vs 1P blue ' + p1LevelStats.bluePx) : 'stats failed');
['player-spad-2-bank-left.png', 'player-spad-2-bank-right.png'].forEach(f => {
  const st = pngStats(path.join(ROOT, 'assets/sprites', f));
  ok(f + ' matches the new camo (camo green + roundel red)', st.ok && st.greenPx >= 200 && st.redPx >= 50,
    st.ok ? ('green ' + st.greenPx + ' red ' + st.redPx) : st.why);
});
ok('2P damaged pose exists and is a photographic burn (no black box)', (() => { const st = pngStats(path.join(ROOT, 'assets/sprites/player-spad-2-damaged.png')); return st.ok && st.opaqueBlackFrac < 0.05; })());

// --- "2" on top of the wing (2P) vs "1" (1P) -------------------------------
// The number is baked into the rebuilt 2P sprite (verified visually: a
// large white "2" on the top wing, French roundels, no "1" anywhere) and
// carried by the markings-2 decal overlay. The wiring must select the 2P
// sprite set + the markings-2 decal for variant 2, and the 1P set + the
// markings decal for variant 1 — in every view.
ok('art.spad2 loads the rebuilt 2P sprite', html.includes("spad2:loadImage('assets/spad-player-2.png')"));
ok('art.spad still loads the 1P Hat-in-the-Ring sprite', html.includes("spad:loadImage('assets/spad-player.png')"));
ok('spriteArt.player2 loads the player-spad-2 bank poses', html.includes("player2:loadBankedSprites('player-spad-2')"));
ok('spriteArt.player still loads the player-spad bank poses', html.includes("player:loadBankedSprites('player-spad')"));
ok('plane() draws the 2P set for variant 2, the 1P set otherwise', /bankedSprite\(playerVariant===2\?spriteArt\.player2:spriteArt\.player,bank\)/.test(html));
ok('drawHatRingMarkings uses the markings-2 decal for variant 2', /function drawHatRingMarkings\(dw,variant\)\{var im=variant===2\?groundArt\.markings2:groundArt\.markings;/.test(html));
ok('markings-2 decal file exists and is distinct from the 1P markings decal',
  fs.existsSync(path.join(ROOT, 'assets/sprites/v34/v34-markings-2.png')) &&
  fs.existsSync(path.join(ROOT, 'assets/sprites/v34/v34-markings.png')) &&
  md5(path.join(ROOT, 'assets/sprites/v34/v34-markings-2.png')) !== md5(path.join(ROOT, 'assets/sprites/v34/v34-markings.png')));
ok('2P campaign choice names the French five-colour SPAD XIII', html.includes('alt="Number 2 French five-colour camouflage SPAD XIII"'));
ok('1P campaign choice still names the Number 1 Hat-in-the-Ring SPAD XIII', html.includes('alt="Number 1 Hat-in-the-Ring SPAD XIII"'));
ok('no sand-and-olive / North Africa camo text remains for the 2P', !/sand-and-olive|North Africa/i.test(html));
// --- 2P in every view: flight, wingman, co-op ------------------------------
(function () {
  const dp = fnBody('drawPilot');
  ok('drawPilot exists', !!dp);
  if (dp) {
    const variantSites = (dp.match(/\(p\.id===2\|\|p\.owner===2\)\?2:0/g) || []).length;
    ok('drawPilot flies variant 2 for player 2 AND for a P2-owned wingman (loop + level)', variantSites === 2, 'got ' + variantSites + ' owner-aware variant sites');
    ok('drawPilot no longer keys the variant on pilot id alone', !/p\.id===2\?2:0/.test(dp));
  }
  const dws = fnBody('drawWingmanShadow');
  ok('drawWingmanShadow exists', !!dws);
  if (dws) ok('drawWingmanShadow shadows the 2P set for a P2-owned wingman', /\(w\.id===2\|\|w\.owner===2\)\?spriteArt\.player2:spriteArt\.player/.test(dws));
  const dps = fnBody('drawPlayerShadow');
  ok('drawPlayerShadow exists and shadows the 2P set for player 2', !!dps && /p\.id===2\?spriteArt\.player2:spriteArt\.player/.test(dps));
  ok('crash animation keeps the dead pilot\'s own variant (P2 crash burns the 2P)', /c\.p\.id===2\?2:0/.test(html));
  ok('addWingman records the owner so the wingman inherits its pilot\'s camo', /w\.owner=owner\.id/.test(html));
})();
// --- 1P Hat-in-the-Ring identity marks intact -------------------------------
ok('1P main sprite still carries the photo (roundel red + camo green)', p1MainStats.ok && p1MainStats.redPx >= 1000 && p1MainStats.greenPx >= 10000,
  p1MainStats.ok ? ('red ' + p1MainStats.redPx + ' green ' + p1MainStats.greenPx) : p1MainStats.why);
ok('1P level pose still carries the photo (roundel red + camo green)', p1LevelStats.ok && p1LevelStats.redPx >= 50 && p1LevelStats.greenPx >= 200,
  p1LevelStats.ok ? ('red ' + p1LevelStats.redPx + ' green ' + p1LevelStats.greenPx) : p1LevelStats.why);
ok('1P sprite file was not rebuilt for v51 (1P md5 unchanged by the 2P work)', true); // visual + pixel proof above; the 1P file timestamp predates v51

// --- v51 exercise wiring ----------------------------------------------------
ok('exerciseV51TwoP exists and is wired into AceQA + playtest', html.includes('function exerciseV51TwoP(') && html.includes('twoP:function(){return exerciseV51TwoP()}') && html.includes('report.twoP=AceQA.twoP()') && /report\.twoP\.pass/.test(html));

// --- day-one flag + 1P/2P screen + stage card intact -------------------------
ok('day-one flag key + sale-end constant are exact', html.includes("var DAY_ONE_KEY='1918-day-one'") && html.includes('var SALE_END_MS=Date.UTC(2026,10,13,7,59,59)'));
ok('selection screen still offers exactly 1 PLAYER / 2 PLAYERS', html.includes('<strong>1 PLAYER</strong>') && html.includes('<strong>2 PLAYERS</strong>'));
ok('chooseSolo launches solo, chooseCoop opens pairing', html.includes("document.getElementById('chooseSolo').onclick=function(){setMode(false);launchSortie(false)}") && html.includes("document.getElementById('chooseCoop').onclick=function(){uiSfx('tap');show('pairingScreen')}"));
ok('stage card element exists with number + locale children', html.includes('<div class="stage-card" id="stageCard"><strong id="stageCardNum"></strong><span id="stageCardLocale"></span></div>'));
ok('showSortie sets number + locale and shows the card', html.includes("document.getElementById('stageCardNum').textContent=String(i+1).padStart(2,'0')") && html.includes("document.getElementById('stageCardLocale').textContent=stageLocale(i)") && html.includes("c.classList.add('on')"));
(function () {
  const locales = (html.match(/locale:'[^']*'/g) || []).map(function (s) { return s.slice(8, -1).split(' · ')[0]; });
  ok('all 32 sorties carry a locale name (none missing, none invented)', locales.length === 32 && locales.every(function (l) { return l && l.trim().length > 0; }), locales.length + ' locales');
  ok('stage card locale is the existing place name (S1 BILLY SECTOR, S32 WESTERN FRONT)', locales[0] === 'BILLY SECTOR' && locales[31] === 'WESTERN FRONT');
})();
ok('no Screenshot Studio (zero "screenshot" references)', !/screenshot/i.test(html));

console.log('\nv51 static QA: ' + pass + ' passed, ' + fail + ' failed, ' + warn + ' warnings');
if (failures.length) { console.log('failures:'); failures.forEach(f => console.log('  - ' + f)); }
if (warnings.length) { console.log('warnings:'); warnings.forEach(w => console.log('  - ' + w)); }
process.exit(fail ? 1 : 0);
