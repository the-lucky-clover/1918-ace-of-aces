#!/usr/bin/env node
/* v58 static QA — additional procedural map-generation plates, traced +
   redrawn from Alamy WWI trench aerials: the traced layouts (Kemmel
   S-curve, Ypres road + trenches, Arras zigzag, Ficheux parallels,
   Hindenburg ridge zigzag, churn density, field pattern) read as real
   aerial photos of the Western Front, and the plates are wired into the
   seeded per-sortie background system so the map varies more.
   Licensing: the Alamy comps are TRACING FODDER ONLY — no Alamy pixel
   ships. Every visible RGB pixel is photographic, cut from the one true
   aerial (assets/terrain-aerial.jpg) and tonally modulated by the traced
   layout. This file checks the plates on disk, the wiring in the game
   file, and the licensing status. Usage: node QA/v58-qa.js [path-to-html]
   Exit 0 = all checks pass, 1 = a failure. Warnings never fail the run. */
'use strict';
const fs = require('fs');
const path = require('path');
const zlib = require('zlib');

const ROOT = path.resolve(__dirname, '..');
const HTML = process.argv[2] || path.join(ROOT, '1918-ace-of-aces.html');
const html = fs.readFileSync(HTML, 'utf8');
const version = fs.readFileSync(path.join(ROOT, 'VERSION'), 'utf8').trim();
const changelog = fs.readFileSync(path.join(ROOT, 'CHANGELOG.md'), 'utf8');
const buildScript = fs.readFileSync(path.join(ROOT, 'bin', 'build-v58-trenches.py'), 'utf8');

let pass = 0, fail = 0, warn = 0;
const failures = [], warnings = [];
function ok(name, cond, detail) {
  if (cond) { pass++; console.log('  PASS  ' + name); }
  else { fail++; failures.push(name + (detail ? ' — ' + detail : '')); console.log('  FAIL  ' + name + (detail ? ' — ' + detail : '')); }
}
function note(name, detail) { warn++; warnings.push(name + (detail ? ' — ' + detail : '')); console.log('  WARN  ' + name + (detail ? ' — ' + detail : '')); }

console.log('v58 static QA — ' + HTML);

// --- PNG decoder (8-bit RGBA): full RGBA buffer for stats -------------------
function pngRGBA(file) {
  const buf = fs.readFileSync(file);
  if (buf.length < 8 || buf[0] !== 0x89 || buf[1] !== 0x50 || buf[2] !== 0x4e || buf[3] !== 0x47) return null;
  let off = 8, width = 0, height = 0, bitDepth = 0, colourType = 0;
  const idat = [];
  while (off + 8 <= buf.length) {
    const len = buf.readUInt32BE(off);
    const type = buf.toString('ascii', off + 4, off + 8);
    const data = buf.slice(off + 8, off + 8 + len);
    if (type === 'IHDR') {
      width = data.readUInt32BE(0); height = data.readUInt32BE(4);
      bitDepth = data[8]; colourType = data[9];
    } else if (type === 'IDAT') {
      idat.push(data);
    } else if (type === 'IEND') break;
    off += 8 + len + 4;
  }
  if (!width || !height || bitDepth !== 8 || colourType !== 6) return { width, height, bitDepth, colourType, rgba: null };
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const stride = width * 4;
  const rgba = Buffer.alloc(width * height * 4);
  let prev = Buffer.alloc(stride);
  for (let y = 0; y < height; y++) {
    const filter = raw[y * (stride + 1)];
    const row = raw.slice(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    const out = Buffer.alloc(stride);
    for (let x = 0; x < stride; x++) {
      const a = x >= 4 ? out[x - 4] : 0;
      const b = prev[x];
      const c = x >= 4 ? prev[x - 4] : 0;
      let v = row[x];
      if (filter === 1) v = (v + a) & 0xff;
      else if (filter === 2) v = (v + b) & 0xff;
      else if (filter === 3) v = (v + ((a + b) >> 1)) & 0xff;
      else if (filter === 4) {
        const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c);
        const pr = (pa <= pb && pa <= pc) ? a : (pb <= pc ? b : c);
        v = (v + pr) & 0xff;
      }
      out[x] = v;
    }
    out.copy(rgba, y * stride);
    prev = out;
  }
  return { width, height, bitDepth, colourType, rgba };
}

function plateStats(file) {
  const info = pngRGBA(file);
  if (!info || !info.rgba) return null;
  const { width: w, height: h, rgba } = info;
  const n = w * h;
  let sumR = 0, sumG = 0, sumB = 0, sumA = 0;
  for (let i = 0; i < n; i++) {
    sumR += rgba[i * 4]; sumG += rgba[i * 4 + 1]; sumB += rgba[i * 4 + 2]; sumA += rgba[i * 4 + 3];
  }
  const mean = [sumR / n, sumG / n, sumB / n, sumA / n];
  let vR = 0, vG = 0, vB = 0;
  for (let i = 0; i < n; i++) {
    vR += (rgba[i * 4] - mean[0]) ** 2;
    vG += (rgba[i * 4 + 1] - mean[1]) ** 2;
    vB += (rgba[i * 4 + 2] - mean[2]) ** 2;
  }
  const std = [Math.sqrt(vR / n), Math.sqrt(vG / n), Math.sqrt(vB / n)];
  const alphaAt = (x, y) => rgba[(y * w + x) * 4 + 3];
  return {
    width: w, height: h, mean, std,
    alphaTop: alphaAt(Math.floor(w / 2), 0),
    alphaBottom: alphaAt(Math.floor(w / 2), h - 1),
    alphaCentre: alphaAt(Math.floor(w / 2), Math.floor(h / 2)),
    alphaCornerMax: Math.max(alphaAt(0, 0), alphaAt(w - 1, 0), alphaAt(0, h - 1), alphaAt(w - 1, h - 1)),
  };
}

// --- version -----------------------------------------------------------------
ok('VERSION file is 58', version === '58', 'got ' + version);
ok('in-game version badge is v58', html.includes('ver-badge">v58</span>'));
ok('CHANGELOG has a v58 entry in pirate speak', /## v58 —/.test(changelog) && /Arrr/.test(changelog.split('## v58 —')[1].split('## ')[0] || ''));

// --- the ten v58 plates (on disk, photographic, feathered) -------------------
const PLATES = [
  { name: 'v58-trench-d.png', w: 1024, h: 256, kind: 'Kemmel S-curve pale-spoil trench strip' },
  { name: 'v58-trench-e.png', w: 1024, h: 256, kind: 'Ypres road + flanking trenches strip' },
  { name: 'v58-trench-f.png', w: 1024, h: 256, kind: 'Arras sparse zigzag strip' },
  { name: 'v58-trench-g.png', w: 1024, h: 256, kind: 'Ficheux parallel lines strip' },
  { name: 'v58-trench-h.png', w: 1024, h: 256, kind: 'Hindenburg ridge zigzag strip' },
  { name: 'v58-shelltorn-a.png', w: 1024, h: 256, kind: 'Kemmel churned ground band' },
  { name: 'v58-shelltorn-b.png', w: 1024, h: 256, kind: 'Ypres churned ground band' },
  { name: 'v58-craterfield-b.png', w: 1024, h: 512, kind: 'dense crater field (wide feather)' },
  { name: 'v58-field-a.png', w: 1024, h: 256, kind: 'Ypres rectangular field system strip' },
  { name: 'v58-nomansland.png', w: 1024, h: 256, kind: 'Arras pale open ground band' },
];
const TERRAIN_MEAN = [89.2, 79.8, 63.0]; // assets/terrain-aerial.jpg mean RGB
PLATES.forEach(p => {
  const file = path.join(ROOT, 'assets', 'sprites', 'v58', p.name);
  const exists = fs.existsSync(file);
  ok(p.name + ' exists (' + p.kind + ')', exists);
  if (!exists) return;
  const size = fs.statSync(file).size;
  ok(p.name + ' is a real photographic plate (>100 KB, not a placeholder)',
    size > 100000, 'got ' + size + ' bytes');
  const st = plateStats(file);
  ok(p.name + ' is ' + p.w + 'x' + p.h + ' RGBA',
    !!st && st.width === p.w && st.height === p.h,
    st ? st.width + 'x' + st.height : 'unreadable');
  if (!st) return;
  ok(p.name + ' is feathered (top/bottom alpha 0, corners 0, centre 255)',
    st.alphaTop <= 8 && st.alphaBottom <= 8 && st.alphaCornerMax <= 8 && st.alphaCentre >= 150,
    'top=' + st.alphaTop + ' bottom=' + st.alphaBottom + ' corners max=' + st.alphaCornerMax + ' centre=' + st.alphaCentre);
  ok(p.name + ' has photographic texture (per-channel stddev >= 18)',
    st.std[0] >= 18 && st.std[1] >= 18 && st.std[2] >= 18,
    'std RGB ' + st.std.map(v => v.toFixed(1)).join(', '));
  ok(p.name + ' is in the terrain-aerial colour palette (mean RGB within 30 of the aerial)',
    Math.abs(st.mean[0] - TERRAIN_MEAN[0]) <= 30 && Math.abs(st.mean[1] - TERRAIN_MEAN[1]) <= 30 && Math.abs(st.mean[2] - TERRAIN_MEAN[2]) <= 30,
    'mean RGB ' + st.mean.slice(0, 3).map(v => v.toFixed(1)).join(', ') + ' vs aerial ' + TERRAIN_MEAN.join(', '));
  ok(p.name + ' is in colour, not a B&W Alamy crop (R>B by >10, warm mud not grey)',
    (st.mean[0] - st.mean[2]) > 10 && st.mean[0] > st.mean[1] && st.mean[1] > st.mean[2],
    'mean RGB ' + st.mean.slice(0, 3).map(v => v.toFixed(1)).join(', '));
});

// --- licensing: tracing fodder only, no Alamy pixel ships --------------------
ok('build script exists and names the Alamy page as tracing fodder',
  fs.existsSync(path.join(ROOT, 'bin', 'build-v58-trenches.py')) &&
  /TRACING FODDER/.test(buildScript) && /no Alamy pixel ships/i.test(buildScript));
ok('build script lists all five Alamy references by image ID',
  ['2M98GG6', 'TXGGH7', '3BTEDHT', 'PBJBXB', 'W2GK7N'].every(id => buildScript.includes(id)));
ok('build script takes its photographic texture ONLY from assets/terrain-aerial.jpg',
  /SRC = os\.path\.join\(ROOT, "assets", "terrain-aerial\.jpg"\)/.test(buildScript) &&
  !/alamy\.com\/comp\/[^"]*\.jpg/.test(buildScript.split('REFS =')[1].split('}')[0].replace(/https:\/\/c8\.alamy\.com\/comp\/[^\s"]+/g, '')));
ok('no Alamy comp preview is stored anywhere in the repo',
  !['kemmel-2M98GG6.jpg', 'ypres-TXGGH7.jpg', 'hindenburg-3BTEDHT.jpg', 'arras-PBJBXB.jpg', 'trenchsys-W2GK7N.jpg']
    .some(fn => fs.existsSync(path.join(ROOT, 'assets', fn)) || fs.existsSync(path.join(ROOT, 'assets', 'sprites', 'v58', fn))));
ok('game file documents the tracing + licensing in the v58Art comment',
  /tracing fodder only — no Alamy pixel ships/.test(html) &&
  /tonally modulated by the traced layout/.test(html));
ok('no vector-drawn shapes in the v58 plates (masks are alpha only; ImageDraw touches L-mode masks, never RGB)',
  /the mask is alpha only/.test(buildScript) &&
  (buildScript.match(/ImageDraw\.Draw\(m\)/g) || []).length === 2 &&
  !/ImageDraw\.Draw\((?!m\))/ .test(buildScript));

// --- wiring: the plates are in the game and drive the map --------------------
ok('v58Art declares all ten plates',
  /var v58Art=\{trenchD:loadImage\('assets\/sprites\/v58\/v58-trench-d\.png'\)/.test(html) &&
  ['trenchE', 'trenchF', 'trenchG', 'trenchH', 'shelltornA', 'shelltornB', 'craterFieldB', 'fieldA', 'nomansland']
    .every(k => new RegExp(k + ":loadImage\\('assets/sprites/v58/").test(html)));
ok('spawnTrenchVarietySystems seeds per-sortie and picks from all nine strip plates + the crater field',
  /function spawnTrenchVarietySystems\(\)\{var rnd=ambRand\(progress\.selected\*2654435761\^0x58ED5801\)/.test(html) &&
  /v58Art\.trenchD,v58Art\.trenchE,v58Art\.trenchF,v58Art\.trenchG,v58Art\.trenchH,v58Art\.shelltornA,v58Art\.shelltornB,v58Art\.fieldA,v58Art\.nomansland/.test(html) &&
  /trenchVarietyFields\.push\(\{im:v58Art\.craterFieldB/.test(html));
ok('updateTrenchVarietySystems scrolls at 92px/s and wraps (same as the v39 system)',
  /function updateTrenchVarietySystems\(dt\)\{if\(!playing\)return;[\s\S]*?t\.y\+=92\*dt/.test(html));
ok('drawTrenchVarietySystems draws the lines and the field (complete + naturalWidth guards)',
  /function drawTrenchVarietySystems\(\)/.test(html) &&
  /noteSpriteDraw\(t\.im\)/.test(html) && /noteSpriteDraw\(f\.im\)/.test(html));
ok('drawTerrain draws the variety plates (after the v39 trenches)',
  /drawTrenchSystems\(\);drawTrenchVarietySystems\(\);drawRiverRoadSystems\(\);/.test(html));
ok('update(dt) runs the variety updater',
  /updateTrenchSystems\(dt\);updateTrenchVarietySystems\(dt\);updateRiverRoadSystems\(dt\);/.test(html));
ok('reset() and softResetForNextSortie() both reset + spawn the variety system',
  (html.match(/trenchVarietyLines=\[\];trenchVarietyFields=\[\];trenchVarietySortie=-1;spawnTrenchVarietySystems\(\);/g) || []).length === 2);

// --- runtime exercises are wired ----------------------------------------------
ok('exerciseV58Trenches + waitForV58Images exist (plate load + draw proof)',
  /function exerciseV58Trenches\(\)/.test(html) && /function waitForV58Images\(\)/.test(html));
ok('exerciseV58TrenchVariety exists (10 plates load + draw, 2 lines + 1 field spawn seeded, distinct, day-one intact)',
  /function exerciseV58TrenchVariety\(\)/.test(html) &&
  /out\.plates===10&&out\.loaded===10&&out\.drawn===10&&out\.lines===2&&out\.fields===1&&out\.seeded&&out\.distinct&&out\.dayOneIntact/.test(html));
ok('AceQA.trenchVariety runtime exercise exists and is wired',
  /trenchVariety:function\(\)\{return exerciseV58TrenchVariety\(\)\}/.test(html));
ok('sprite rendering proof includes v58',
  /var v58=exerciseV58Trenches\(\);/.test(html) && /v48\.pass&&v58\.pass,total/.test(html) && /v48:v48,v58:v58\}\}/.test(html));
ok('campaign playtest report carries the trench-variety check',
  /trenchVariety:null/.test(html) && /await waitForV58Images\(\);/.test(html) &&
  /report\.trenchVariety=AceQA\.trenchVariety\(\);/.test(html) && /report\.trenchVariety\.pass/.test(html));

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
ok('v39 trench system intact (2 strips + 12 craters)', /function spawnTrenchSystems/.test(html) && /function drawTrenchSystems/.test(html));
ok('no Screenshot Studio (zero screenshot references)', !/screenshot/i.test(html));
ok('no HP bars on bosses or enemies (no hpbar / hp-bar)',
  !/hpbar/i.test(html) && !/hp-bar/i.test(html));
ok('one-hit death doctrine intact', /hitPilot/.test(html));

// --- pre-existing warnings (reported, not changed) ---------------------------
note('boss HP does not match standing doctrine (S1 25 -> S32 500) — code: S1 50 -> S32 220');
note('STUN servers still in makePeer — v32 note says they were removed; they are unused for local pairing but still configured');
note('sortie 18 briefing/objective name a Staaken giant but roster[17] is a Zeppelin — pre-existing text/roster drift, reported, not changed');
note('live-fire survival sim pilot rebuilt 2026-11-07 (predictive formation dodging, real wingman buffers, loop/powerup use, escort-first boss targeting) — now beats 4–6/32 sorties across seeds and reports the killer per sortie; a meaningful check, not yet a full certification; Steven\'s iPhone playtest remains the proof for the rest');

console.log('\nv58 static QA: ' + pass + ' passed, ' + fail + ' failed, ' + warn + ' warnings');
if (failures.length) { console.log('FAILURES:'); failures.forEach(f => console.log('  - ' + f)); }
if (warnings.length) { console.log('WARNINGS:'); warnings.forEach(w => console.log('  - ' + w)); }
process.exit(fail ? 1 : 0);
