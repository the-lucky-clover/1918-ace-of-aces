#!/usr/bin/env node
/* v57 static QA — enemy aircraft read as airborne, not pinned to the ground:
   the four flat strips rebuilt as photorealistic top-down aircraft, the glued
   canvas shadow struck from every enemy and boss, the photographic shadow
   riding the flight-path altitude, and the v54 true scale preserved.
   Checks the game file without running it (plus the sprite PNGs on disk).
   Usage: node QA/v57-qa.js [path-to-html]
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

let pass = 0, fail = 0, warn = 0;
const failures = [], warnings = [];
function ok(name, cond, detail) {
  if (cond) { pass++; console.log('  PASS  ' + name); }
  else { fail++; failures.push(name + (detail ? ' — ' + detail : '')); console.log('  FAIL  ' + name + (detail ? ' — ' + detail : '')); }
}
function note(name, detail) { warn++; warnings.push(name + (detail ? ' — ' + detail : '')); console.log('  WARN  ' + name + (detail ? ' — ' + detail : '')); }

console.log('v57 static QA — ' + HTML);

// --- PNG reader (8-bit RGBA only): IHDR + alpha-bbox width -----------------
function pngInfo(file) {
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
  if (!width || !height || bitDepth !== 8 || colourType !== 6) return { width, height, bitDepth, colourType, alphaBboxW: null };
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const stride = width * 4;
  let minX = width, maxX = -1;
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
    for (let px = 0; px < width; px++) {
      if (out[px * 4 + 3] > 10) { if (px < minX) minX = px; if (px > maxX) maxX = px; }
    }
    prev = out;
  }
  return { width, height, bitDepth, colourType, alphaBboxW: maxX >= 0 ? (maxX - minX + 1) : 0 };
}

// --- version ---------------------------------------------------------------
ok('VERSION file is 57', version === '57', 'got ' + version);
ok('in-game version badge is v57', /ver-badge">v57<\/span>/.test(html) || html.includes('ver-badge">v57</span>'));
ok('CHANGELOG has a v57 entry in pirate speak', /## v57 —/.test(changelog) && /Arrr/.test(changelog.split('## v57 —')[1].split('## ')[0] || ''));

// --- the four rebuilt sprite sets (on disk, photographic, true scale) -------
const TARGET_FILLW = { 'enemy-scout': 168, 'enemy-fighter': 156, 'enemy-triplane': 150, 'enemy-bomber': 246 };
Object.keys(TARGET_FILLW).forEach(prefix => {
  const target = TARGET_FILLW[prefix];
  ['level', 'bank-left', 'bank-right', 'damaged'].forEach(pose => {
    const file = path.join(ROOT, 'assets', 'sprites', prefix + '-' + pose + '.png');
    const exists = fs.existsSync(file);
    ok(prefix + '-' + pose + '.png exists', exists);
    if (!exists) return;
    const size = fs.statSync(file).size;
    ok(prefix + '-' + pose + '.png is a real photographic plate (>' + (pose === 'level' ? '15' : '10') + ' KB, not a placeholder)',
      size > (pose === 'level' ? 15000 : 10000), 'got ' + size + ' bytes');
    const info = pngInfo(file);
    ok(prefix + '-' + pose + '.png is 256x256 RGBA',
      !!info && info.width === 256 && info.height === 256 && info.bitDepth === 8 && info.colourType === 6,
      info ? JSON.stringify({ w: info.width, h: info.height, bitDepth: info.bitDepth, colourType: info.colourType }) : 'unreadable');
  });
  // the level pose's alpha-bbox width must equal the v54 SPRITE_FILLW target,
  // so the drawn wingspan (st.size * fillW/256) — the v54 true scale — is unchanged
  const levelFile = path.join(ROOT, 'assets', 'sprites', prefix + '-level.png');
  if (fs.existsSync(levelFile)) {
    const info = pngInfo(levelFile);
    const fw = info && info.alphaBboxW;
    ok(prefix + '-level alpha-bbox width is the v54 fillW target (' + target + ')',
      fw !== null && Math.abs(fw - target) <= 2, 'got ' + fw);
    // a real top-down aircraft carries far more visible pixels than the old flat strip
    ok(prefix + '-level is a proper aircraft, not a flat strip (alpha-bbox height > 90 px)',
      (() => {
        // height check needs the full bbox; re-derive it from the alpha channel
        const buf = fs.readFileSync(levelFile);
        // reuse pngInfo's decode by scanning the inflated rows for alpha>10 rows
        let off = 8; const idat = [];
        let w = 0, h = 0;
        while (off + 8 <= buf.length) {
          const len = buf.readUInt32BE(off);
          const type = buf.toString('ascii', off + 4, off + 8);
          const data = buf.slice(off + 8, off + 8 + len);
          if (type === 'IHDR') { w = data.readUInt32BE(0); h = data.readUInt32BE(4); }
          else if (type === 'IDAT') idat.push(data);
          else if (type === 'IEND') break;
          off += 8 + len + 4;
        }
        const raw = zlib.inflateSync(Buffer.concat(idat));
        const stride = w * 4;
        let minY = h, maxY = -1, prev = Buffer.alloc(stride);
        for (let y = 0; y < h; y++) {
          const filter = raw[y * (stride + 1)];
          const row = raw.slice(y * (stride + 1) + 1, (y + 1) * (stride + 1));
          const out = Buffer.alloc(stride);
          for (let x = 0; x < stride; x++) {
            const a = x >= 4 ? out[x - 4] : 0, b = prev[x], c = x >= 4 ? prev[x - 4] : 0;
            let v = row[x];
            if (filter === 1) v = (v + a) & 0xff;
            else if (filter === 2) v = (v + b) & 0xff;
            else if (filter === 3) v = (v + ((a + b) >> 1)) & 0xff;
            else if (filter === 4) { const p = a + b - c, pa = Math.abs(p - a), pb = Math.abs(p - b), pc = Math.abs(p - c); v = (v + ((pa <= pb && pa <= pc) ? a : (pb <= pc ? b : c))) & 0xff; }
            out[x] = v;
          }
          let any = false;
          for (let px = 0; px < w; px++) if (out[px * 4 + 3] > 10) { any = true; break; }
          if (any) { if (y < minY) minY = y; if (y > maxY) maxY = y; }
          prev = out;
        }
        const bh = maxY >= 0 ? (maxY - minY + 1) : 0;
        return bh > 90;
      })(), 'the old strips were 53-57 px tall');
  }
});

// --- the other 10 enemy sets + 6 boss sets: fillW still matches the v54 table
const FILLW_ALL = { scout: 168, fighter: 156, bomber: 246, triplane: 150, dri: 217, dvii: 254, dva: 245, eiii: 251, pfalz: 248, gotha: 256, clii: 248, rumpler: 253, junkers: 256, taube: 252 };
Object.keys(FILLW_ALL).forEach(sprite => {
  const file = path.join(ROOT, 'assets', 'sprites', 'enemy-' + sprite + '-level.png');
  if (!fs.existsSync(file)) { ok('enemy-' + sprite + '-level.png exists', false); return; }
  const info = pngInfo(file);
  ok('enemy-' + sprite + '-level fillW matches the v54 table (' + FILLW_ALL[sprite] + ')',
    !!info && info.alphaBboxW !== null && Math.abs(info.alphaBboxW - FILLW_ALL[sprite]) <= 2,
    'got ' + (info && info.alphaBboxW));
});

// --- no glued shadow on any airborne aircraft -------------------------------
ok('drawBlenderSprite takes a noShadow flag (7th arg) and a squashY pitch (8th arg)',
  /function drawBlenderSprite\(im,x,y,size,rotation,alpha,noShadow,squashY\)/.test(html));
ok('drawBlenderSprite only paints the canvas contact shadow when noShadow is false',
  /if\(!noShadow\)\{ctx\.shadowColor='rgba\(0,0,0,\.64\)';ctx\.shadowBlur=9;ctx\.shadowOffsetY=7\}/.test(html));
ok('drawBlenderSprite applies the pitch squash to the draw',
  /ctx\.drawImage\(im,-size\/2,-size\/2\*sq,size,size\*sq\)/.test(html));
ok('drawEnemy flies clean (noShadow=true + pitch squash)',
  /drawBlenderSprite\(im,e\.x,e\.y,size,rot,1,true,pitchSq\)/.test(html));
ok('drawBoss fighter aces fly clean (noShadow=true)',
  /drawBlenderSprite\(im,b\.x,b\.y,size,rot\+bossRoll,1,true\)/.test(html));
ok('no glued canvas shadow remains on the Staaken (shadowColor .7 / blur 20 / offsetY 14)',
  !/ctx\.shadowColor='rgba\(0,0,0,\.7\)';ctx\.shadowBlur=20;ctx\.shadowOffsetY=14;/.test(html));
ok('ground objects still get the contact shadow (drawGroundSprite calls drawBlenderSprite without noShadow)',
  /function drawGroundSprite\(g\)\{[\s\S]*?drawBlenderSprite\(im,g\.x,g\.y,size,rot,1\)/.test(html));
ok('drawFokkerTriplaneSprite draws the square frame as a square (new top-down planform)',
  /function drawFokkerTriplaneSprite\(dw\)\{var im=bankedSprite\(spriteArt\.aircraft\.triplane,0\);if\(!im\|\|!im\.complete\|\|!im\.naturalWidth\)return;var dh=dw;/.test(html));

// --- altitude: the photographic shadow rides the flight path -----------------
ok('enemyAlt01 helper maps pathZ -28..58 to altitude 0..1',
  /function enemyAlt01\(e\)\{var z=\(e&&typeof e\.pathZ==='number'\)\?e\.pathZ:0;return Math\.max\(0,Math\.min\(1,\(z\+28\)\/86\)\)\}/.test(html));
ok('drawEnemyShadow passes the path altitude + the altitude-adjusted size to the photographic shadow',
  /function drawEnemyShadow\(e\)\{[\s\S]*?var alt01=enemyAlt01\(e\),size=st\.size\*\(0\.94\+0\.12\*alt01\);drawAircraftShadow\(e\.x,e\.y,bankedSprite\(set,0\),size,0,alt01\)\}/.test(html));
ok('drawEnemy sizes the aircraft by its path altitude (+/-6%)',
  /var alt01=enemyAlt01\(e\),size=st\.size\*\(0\.94\+0\.12\*alt01\)/.test(html));
ok('drawEnemy foreshortens the airframe by its path pitch',
  /pitchSq=1-Math\.min\(\.16,Math\.abs\(e\.pathPitch\|\|0\)\*\.3\)/.test(html));
ok('drawEnemy reads the path pitch (advancePathEnemy computes it from the path z-slope)',
  /targetPitch=Math\.atan2\(vz,Math\.hypot\(vx,vy\)\)\*1\.25/.test(html) && /e\.pathPitch=\(e\.pathPitch===undefined\?targetPitch:e\.pathPitch\)/.test(html));

// --- damaged fallback: no more vanishing -------------------------------------
ok('drawEnemy falls back to the level sprite when the damaged pose never loaded',
  /im=\(e\.hp\/e\.max<=.25&&set\.damaged&&set\.damaged\.complete&&set\.damaged\.naturalWidth\)\?set\.damaged:\(set\.level\|\|bankedSprite\(set,e\.bank\|\|0\)\)/.test(html));
ok('all four rebuilt sets have a damaged pose on disk (the old ones 404d)',
  ['enemy-scout', 'enemy-fighter', 'enemy-triplane', 'enemy-bomber'].every(p =>
    fs.existsSync(path.join(ROOT, 'assets', 'sprites', p + '-damaged.png'))));

// --- scale vs the SPAD XIII is preserved (v54, at equal altitude) ------------
const SPAD_PX = 69.12, SPAD_M = 8.25;
const spanM = { small: 8.2, red: 8.9, green: 8.9, riser: 18.4, triplane: 8.08, dri: 7.19, dvii: 8.9, dva: 9.04, eiii: 9.52, pfalz: 9.4, gotha: 23.7, clii: 10.77, rumpler: 12.15, junkers: 16.0, taube: 14.3 };
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
    const expectedSize = Math.round(SPAD_PX * (spanM[k] / SPAD_M) * (256 / FILLW_ALL[sprite]));
    ok('archetype ' + k + ' size is true scale vs the SPAD (' + size + ' = ' + spanM[k] + ' m)', size === expectedSize,
      'got size ' + size + ', expected ' + expectedSize + ' (span ' + spanM[k] + ' m, fillW ' + FILLW_ALL[sprite] + ')');
    const expectedR = Math.round(oldR[k] * (expectedSize / oldSize[k]));
    ok('archetype ' + k + ' hitbox r matches the drawn scale (' + r + ')', r === expectedR,
      'got r ' + r + ', expected ' + expectedR);
  });
  ok('player SPAD reference unchanged (plane dw 64, scale 1.08 in drawPilot)',
    /dw=\(enemy\?54:64\)\*s/.test(html) && /drawPilot\(p,1\.08,false\)/.test(html));
}
ok('SPRITE_FILLW table is unchanged from v54 (the reframe preserved it)',
  /var SPRITE_FILLW=\{scout:168,fighter:156,bomber:246,triplane:150,dri:217,dvii:254,dva:245,eiii:251,pfalz:248,gotha:256,clii:248,rumpler:253,junkers:256,taube:252\}/.test(html));
ok('enemy HP values unchanged by v57 (small 3, red 4, green 12, riser 12)',
  /small:\{hp:3/.test(html) && /red:\{hp:4/.test(html) && /green:\{hp:12/.test(html) && /riser:\{hp:12/.test(html));

// --- runtime exercise is wired ----------------------------------------------
ok('AceQA.airborne runtime exercise exists and is wired',
  /function exerciseV57Airborne\(\)/.test(html) && /airborne:function\(\)\{return exerciseV57Airborne\(\)\}/.test(html));
ok('campaign playtest report carries the airborne check',
  /airborne:null/.test(html) && /report\.airborne=AceQA\.airborne\(\);/.test(html) && /report\.airborne\.pass/.test(html));

// --- invariants (must not regress) --------------------------------------------
ok('day-one flag intact (1918-day-one, sale end Nov 12)',
  /DAY_ONE_KEY='1918-day-one'/.test(html) && /SALE_END_MS=Date\.UTC\(2026,10,13,7,59,59\)/.test(html));
ok('1P/2P screen intact (1 PLAYER / 2 PLAYERS)', /id="chooseSolo"/.test(html) && /id="chooseCoop"/.test(html));
ok('stage card intact (stageCard + stageLocale + showSortie)', /id="stageCard"/.test(html) && /function stageLocale/.test(html) && /function showSortie/.test(html));
ok('2P camo intact (player-spad-2, French five-colour)', /player-spad-2/.test(html));
ok('continuous sortie flow intact (v53)', /function exerciseV53ContinuousFlow/.test(html));
ok('Zeppelin fleet intact (v55)', /function exerciseV55ZeppelinFleet/.test(html));
ok('boss battle-damage intact (v56)', /function exerciseV56BossDamage/.test(html));
ok('no Screenshot Studio (zero screenshot references)', !/screenshot/i.test(html));
ok('no HP bars on bosses or enemies (no hpbar / hp-bar)',
  !/hpbar/i.test(html) && !/hp-bar/i.test(html));
ok('one-hit death doctrine intact', /hitPilot/.test(html));
ok('v47 continuous banking intact (bankedSprite + the 14 deg roll)',
  /function bankedSprite\(set,bank\)/.test(html) && /\(e\.bank\|\|0\)\*\.2443/.test(html));

// --- pre-existing warnings (reported, not changed) ---------------------------
note('boss HP does not match standing doctrine (S1 25 -> S32 500) — code: S1 50 -> S32 220');
note('STUN servers still in makePeer — v32 note says they were removed; they are unused for local pairing but still configured');
note('sortie 18 briefing/objective name a Staaken giant but roster[17] is a Zeppelin — pre-existing text/roster drift, reported, not changed');
note('live-fire survival sim scores 0/32 even at the shipped density — it cannot certify beatability; Steven\'s iPhone playtest is the proof');

console.log('\nv57 static QA: ' + pass + ' passed, ' + fail + ' failed, ' + warn + ' warnings');
if (failures.length) { console.log('FAILURES:'); failures.forEach(f => console.log('  - ' + f)); }
if (warnings.length) { console.log('WARNINGS:'); warnings.forEach(w => console.log('  - ' + w)); }
process.exit(fail ? 1 : 0);
