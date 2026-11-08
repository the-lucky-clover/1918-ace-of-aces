#!/usr/bin/env node
/* v44 headless playtest — runs the game logic in a Node vm with DOM/canvas/
   Image/AudioContext/navigator/localStorage/rAF stubs, then drives the
   in-game QA API (window.AceQA): structural checks, the 32-sortie campaign
   playtest, and the v35 exercises (co-op no-friendly-fire, wingman buffers,
   hold-to-fire, tap-to-move, power cycling).
   Usage: node QA/v44-playtest.js [path-to-html]
   Exit 0 = playtest passes, 1 = a failure. */
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const ROOT = path.resolve(__dirname, '..');
const HTML = process.argv[2] || path.join(ROOT, '1918-ace-of-aces.html');
const html = fs.readFileSync(HTML, 'utf8');
const scriptMatch = html.match(/<script>([\s\S]*)<\/script>/);
if (!scriptMatch) { console.error('no inline <script> found'); process.exit(1); }
const gameJs = scriptMatch[1];

// --- recorded calls ----------------------------------------------------------
const vibrates = [];
const consoleErrors = [];

// --- element stubs -----------------------------------------------------------
function makeClassList() {
  const s = new Set();
  return {
    add: (...c) => c.forEach(x => s.add(x)),
    remove: (...c) => c.forEach(x => s.delete(x)),
    toggle: (c, f) => { if (f === undefined) { s.has(c) ? s.delete(c) : s.add(c); } else if (f) s.add(c); else s.delete(c); return s.has(c); },
    contains: c => s.has(c),
  };
}
function makeStyle() {
  const st = {};
  return new Proxy(st, { get: (t, k) => (k in t ? t[k] : ''), set: (t, k, v) => { t[k] = v; return true; } });
}
function makeElement(id) {
  const el = {
    id: id || '', tagName: 'DIV', hidden: false, disabled: false,
    textContent: '', value: '', placeholder: '',
    style: makeStyle(), classList: makeClassList(),
    dataset: {}, children: [], firstChild: null, lastChild: null,
    className: '',
    width: 800, height: 600,
    addEventListener: () => {}, removeEventListener: () => {},
    appendChild: function (c) {
      this.children.push(c);
      this.firstChild = this.children[0];
      this.lastChild = c;
      c.parentNode = this;
      return c;
    },
    removeChild: function (c) {
      const i = this.children.indexOf(c);
      if (i >= 0) this.children.splice(i, 1);
      this.firstChild = this.children[0] || null;
      this.lastChild = this.children[this.children.length - 1] || null;
      return c;
    },
    setAttribute: () => {}, getAttribute: () => null, removeAttribute: () => {},
    querySelector: function (sel) {
      // '.odo-d' etc: return the first child whose className matches
      const cls = sel && sel[0] === '.' ? sel.slice(1) : null;
      if (cls) { const hit = this.children.find(c => (c.className || '').split(' ').includes(cls)); if (hit) return hit; }
      return makeElement('');
    },
    querySelectorAll: function (sel) {
      const cls = sel && sel[0] === '.' ? sel.slice(1) : null;
      if (cls) return this.children.filter(c => (c.className || '').split(' ').includes(cls));
      return this.children.slice();
    },
    getBoundingClientRect: () => ({ width: 800, height: 600, left: 0, top: 0, right: 800, bottom: 600 }),
    getContext: () => makeCtx(),
    setPointerCapture: () => {}, click: () => {}, focus: () => {}, select: () => {},
    play: () => Promise.resolve(), pause: () => {},
  };
  // innerHTML as a setter: assigning (e.g. el.innerHTML='') clears children,
  // matching real DOM behaviour the game relies on in buildOdometer.
  let _html = '';
  Object.defineProperty(el, 'innerHTML', {
    get: () => _html,
    set: v => {
      _html = String(v);
      el.children = [];
      el.firstChild = null;
      el.lastChild = null;
    },
    configurable: true,
  });
  return el;
}
function makeGradient() { return { addColorStop: () => {} }; }
function makeCtx() {
  const ctx = {
    canvas: null, fillStyle: '', strokeStyle: '', globalAlpha: 1,
    globalCompositeOperation: 'source-over', font: '', textAlign: 'left',
    shadowColor: '', shadowBlur: 0, shadowOffsetX: 0, shadowOffsetY: 0,
    lineWidth: 1, filter: '', imageSmoothingEnabled: true,
    save: () => {}, restore: () => {}, translate: () => {}, rotate: () => {},
    scale: () => {}, transform: () => {}, setTransform: () => {},
    resetTransform: () => {},
    drawImage: () => {}, fillRect: () => {}, clearRect: () => {},
    strokeRect: () => {},
    beginPath: () => {}, moveTo: () => {}, lineTo: () => {}, arc: () => {},
    ellipse: () => {}, fill: () => {}, stroke: () => {}, closePath: () => {},
    quadraticCurveTo: () => {}, bezierCurveTo: () => {}, arcTo: () => {},
    clip: () => {}, setLineDash: () => {}, getLineDash: () => [],
    fillText: () => {}, strokeText: () => {},
    measureText: () => ({ width: 10 }),
    createLinearGradient: () => makeGradient(),
    createRadialGradient: () => makeGradient(),
    createPattern: () => ({}),
    getImageData: () => ({ data: new Uint8ClampedArray(4) }),
    putImageData: () => {},
  };
  return ctx;
}
const elements = {};
function getElement(id) {
  if (!elements[id]) {
    const el = makeElement(id);
    if (id === 'game') { el.tagName = 'CANVAS'; el.getContext = () => makeCtx(); }
    elements[id] = el;
  }
  return elements[id];
}

// --- Image stub (loads instantly, plausible natural size) -------------------
class ImageStub {
  constructor() {
    this._src = ''; this.complete = false; this.naturalWidth = 0; this.naturalHeight = 0;
    this.onload = null; this.onerror = null; this.__spriteKey = '';
    this._listeners = {};
  }
  set src(v) {
    this._src = v;
    // v34 fx sheets are 512x128 (4 frames); everything else is a square sprite
    const isSheet = /v34-(smoke|fire|flak|flash|crater|scorch|ring|rain|fog|gas|snow|tracer)\.png$/.test(v);
    this.naturalWidth = isSheet ? 512 : 256;
    this.naturalHeight = isSheet ? 128 : 160;
    this.complete = true;
    if (typeof this.onload === 'function') setTimeout(() => this.onload(), 0);
    (this._listeners.load || []).forEach(f => setTimeout(() => f(), 0));
  }
  get src() { return this._src; }
  addEventListener(t, f) { (this._listeners[t] = this._listeners[t] || []).push(f); }
  removeEventListener(t, f) { const l = this._listeners[t]; if (l) { const i = l.indexOf(f); if (i >= 0) l.splice(i, 1); } }
}

// --- AudioContext stub -------------------------------------------------------
class AudioParamStub {
  constructor() { this.value = 0; }
  setValueAtTime() {} linearRampToValueAtTime() {} exponentialRampToValueAtTime() {} setTargetAtTime() {}
}
class AudioNodeStub {
  constructor() {
    this.gain = new AudioParamStub(); this.frequency = new AudioParamStub();
    this.detune = new AudioParamStub(); this.Q = new AudioParamStub(); this.threshold = new AudioParamStub();
  }
  connect() { return this; } disconnect() {} start() {} stop() {}
}
class AudioContextStub {
  constructor() {
    this.currentTime = 0; this.state = 'running'; this.sampleRate = 44100;
    this.destination = new AudioNodeStub();
  }
  createOscillator() { return new AudioNodeStub(); }
  createGain() { return new AudioNodeStub(); }
  createBuffer(ch, len) { return { getChannelData: () => new Float32Array(len) }; }
  createBufferSource() { return new AudioNodeStub(); }
  createDynamicsCompressor() { return new AudioNodeStub(); }
  createBiquadFilter() { return new AudioNodeStub(); }
  resume() { return Promise.resolve(); }
  suspend() { return Promise.resolve(); }
}

// --- vm context --------------------------------------------------------------
const store = {};
// Seeded RNG (mulberry32) so the bullet-hell survival sim is reproducible.
// Override with QA_SEED=<int> to re-run under a different random stream.
const QA_SEED = Number(process.env.QA_SEED || 191843) >>> 0;
function mulberry32(a) {
  return function () {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
const seededMath = Object.create(Math);
seededMath.random = mulberry32(QA_SEED);
console.log('QA seed: ' + QA_SEED + ' (override with QA_SEED=<int>)');
const sandbox = {
  console: { ...console, error: (...a) => { consoleErrors.push(a.join(' ')); } },
  setTimeout, clearTimeout, setInterval, clearInterval,
  performance, Date, JSON, Math: seededMath, Promise, URLSearchParams,
  requestAnimationFrame: cb => setTimeout(() => cb(performance.now()), 16),
  cancelAnimationFrame: id => clearTimeout(id),
  devicePixelRatio: 1,
  navigator: {
    vibrate: p => { vibrates.push(p); return true; },
    getGamepads: () => [], userAgent: 'node-qa', maxTouchPoints: 0,
    mediaDevices: undefined, bluetooth: undefined,
  },
  localStorage: {
    getItem: k => (k in store ? store[k] : null),
    setItem: (k, v) => { store[k] = String(v); },
    removeItem: k => { delete store[k]; },
  },
  location: { hash: '', href: 'http://localhost/', search: '' },
  matchMedia: () => ({ matches: false, addEventListener: () => {}, removeEventListener: () => {} }),
  Image: ImageStub,
  AudioContext: AudioContextStub,
  webkitAudioContext: AudioContextStub,
  addEventListener: () => {}, removeEventListener: () => {},
  document: {
    getElementById: id => getElement(id),
    createElement: tag => makeElement(tag),
    querySelector: () => makeElement(''),
    querySelectorAll: () => [],
    addEventListener: () => {}, removeEventListener: () => {},
    documentElement: makeElement('html'),
    body: makeElement('body'),
    // the game ships an inline <style> block, so styleSheets is non-empty in
    // a real browser; mirror that so the first-load animation check is fair.
    styleSheets: [{}],
    title: '1918',
  },
  URL: { createObjectURL: () => 'blob:qa', revokeObjectURL: () => {} },
  Blob: class {},
};
sandbox.window = sandbox;
sandbox.globalThis = sandbox;
vm.createContext(sandbox);

console.log('v44 headless playtest — loading game (' + gameJs.length + ' chars)');
let loadError = null;
try {
  vm.runInContext(gameJs, sandbox, { filename: '1918-ace-of-aces.html' });
} catch (e) {
  loadError = e;
  console.error('LOAD ERROR:', e && e.stack || e);
}
if (loadError) process.exit(1);
if (!sandbox.window.AceQA) { console.error('window.AceQA not exposed after load'); process.exit(1); }

(async () => {
  const AceQA = sandbox.window.AceQA;
  let failures = 0;
  const check = (name, cond, detail) => {
    if (cond) console.log('  PASS  ' + name);
    else { failures++; console.log('  FAIL  ' + name + (detail ? ' — ' + detail : '')); }
  };

  // --- structural checks (in-game) -------------------------------------------
  console.log('\n-- structural (AceQA.runAlphaOmega) --');
  let alpha = null;
  try {
    alpha = await AceQA.runAlphaOmega();
    console.log('  structural pass:', alpha.pass, '| checks:', alpha.total);
    (alpha.checks || []).forEach(c => { if (!c.pass) console.log('    FAIL check:', c.name); });
    check('structural checks pass', alpha.pass === true, JSON.stringify((alpha.checks || []).filter(c => !c.pass).map(c => c.name)));
  } catch (e) {
    failures++;
    console.log('  FAIL  runAlphaOmega threw: ' + (e && e.message));
  }

  // --- full campaign playtest ------------------------------------------------
  console.log('\n-- campaign playtest (AceQA.runCampaignPlaytest) --');
  let report = null;
  try {
    report = await AceQA.runCampaignPlaytest();
  } catch (e) {
    failures++;
    console.log('  FAIL  runCampaignPlaytest threw: ' + (e && e.stack || e));
  }
  if (report) {
    console.log('  overall pass:', report.pass);
    if (report.error) console.log('  error:', report.error);
    console.log('  frames:', report.frames && report.frames.fps + ' fps', '| inputMs:', report.inputMs);
    console.log('  sorties:', (report.sorties || []).length, '| beatable:', (report.sorties || []).filter(s => s.beatable).length);
    const badSorties = (report.sorties || []).filter(s => !s.beatable);
    badSorties.forEach(s => console.log('    unbeatable sortie:', JSON.stringify(s)));
    console.log('  sprites pass:', report.sprites && report.sprites.pass, '| v34:', JSON.stringify(report.sprites && report.sprites.v34), '| v36:', JSON.stringify(report.sprites && report.sprites.v36), '| v37:', JSON.stringify(report.sprites && report.sprites.v37), '| v38:', JSON.stringify(report.sprites && report.sprites.v38), '| v39:', JSON.stringify(report.sprites && report.sprites.v39), '| v40:', JSON.stringify(report.sprites && report.sprites.v40));
    console.log('  trenches + craters:', JSON.stringify(report.trenches));
    console.log('  rivers + roads + buildings:', JSON.stringify(report.rivers));
    console.log('  frontline (checkpoints/POW/towers/sirens/arty/MG/booms/beams/flares):', JSON.stringify(report.frontline));
    console.log('  bombers (zeppelin x7 + staaken x2 spawn, draw, die in the v37 explosion):', JSON.stringify(report.bombers));
    console.log('  bullet hell (live-fire survival, no invulnerability):', JSON.stringify({ pass: report.bulletHell && report.bulletHell.pass, maxBullets: report.bulletHell && report.bulletHell.maxBullets, maxBulletsStage: report.bulletHell && report.bulletHell.maxBulletsStage, wingmenLost: report.bulletHell && report.bulletHell.wingmenLost, beatable: (report.bulletHell && report.bulletHell.sorties || []).filter(x => x.beatable).length + '/32' }));
    (report.bulletHell && report.bulletHell.sorties || []).filter(x => !x.beatable).forEach(x => console.log('    bullet-hell unbeatable sortie:', JSON.stringify(x)));
    (report.bulletHell && report.bulletHell.sorties || []).filter(x => !x.beatable).slice(0, 6).forEach(x => console.log('    deaths S' + x.stage + ':', JSON.stringify(x.deaths)));
    (report.bulletHell && report.bulletHell.sorties || []).filter(x => !x.beatable).slice(0, 6).forEach(x => console.log('    hits S' + x.stage + ' (cause/t/pilot-or-wingman-id/wingmen-left):', JSON.stringify(x.hits)));
    (report.bulletHell && report.bulletHell.sorties || []).filter(x => x.maxBullets >= 30).forEach(x => console.log('    bullet-hell peak S' + x.stage + ': ' + x.maxBullets + ' live bullets, ' + x.seconds + 's, fuel left ' + x.fuelLeft + ', wingmen lost ' + x.wingmenLost));
    console.log('  ambient overlays:', JSON.stringify(report.ambient));
    console.log('  explosions:', JSON.stringify(report.explosions));
    console.log('  deathRetry pass:', report.deathRetry && report.deathRetry.pass);
    console.log('  co-op no-friendly-fire:', JSON.stringify(report.coop));
    console.log('  wingman buffer (one-hit death):', JSON.stringify(report.wingmanBuffer));
    console.log('  hold-to-fire:', JSON.stringify(report.holdFire));
    console.log('  tap-to-move:', JSON.stringify(report.tapMove));
    console.log('  power cycle:', JSON.stringify(report.powerCycle));
    check('campaign playtest passes', report.pass === true, report.error || '');
    check('all 32 sorties beatable', (report.sorties || []).length === 32 && badSorties.length === 0);
    check('v34 sprites drawn', !!(report.sprites && report.sprites.v34 && report.sprites.v34.pass), JSON.stringify(report.sprites && report.sprites.v34 && report.sprites.v34.missing));
    check('v36 overlay plates drawn', !!(report.sprites && report.sprites.v36 && report.sprites.v36.pass), JSON.stringify(report.sprites && report.sprites.v36 && report.sprites.v36.missing));
    check('ambient overlays spawn and cap (fires 2-5, clouds 1-2, smoke <= 38)', !!(report.ambient && report.ambient.pass), JSON.stringify(report.ambient));
    check('v37 explosion frames drawn', !!(report.sprites && report.sprites.v37 && report.sprites.v37.pass), JSON.stringify(report.sprites && report.sprites.v37 && report.sprites.v37.missing));
    check('v38 aircraft sprites + chateau drawn', !!(report.sprites && report.sprites.v38 && report.sprites.v38.pass), JSON.stringify(report.sprites && report.sprites.v38 && report.sprites.v38.missing));
    check('v39 trench + crater plates drawn', !!(report.sprites && report.sprites.v39 && report.sprites.v39.pass), JSON.stringify(report.sprites && report.sprites.v39 && report.sprites.v39.missing));
    check('trenches + craters spawn and cap (2 strips, 12 craters: 2 fields + 10 singles)', !!(report.trenches && report.trenches.pass), JSON.stringify(report.trenches));
    check('v40 river/road/bridge/building plates drawn', !!(report.sprites && report.sprites.v40 && report.sprites.v40.pass), JSON.stringify(report.sprites && report.sprites.v40 && report.sprites.v40.missing));
    check('rivers + roads + buildings spawn and cap (4 lines: 2 rivers + 2 roads; 9 spots: 1 bridge + 8 buildings)', !!(report.rivers && report.rivers.pass), JSON.stringify(report.rivers));
    check('frontline spawns and caps (9 spots: 2 checkpoints + 2 POW camps + 2 towers + 3 sirens; volleys/MG/booms fire; 2 searchlights + flares at night only)', !!(report.frontline && report.frontline.pass), JSON.stringify(report.frontline));
    check('bombers: 7 zeppelin + 2 staaken bosses spawn, draw their plates, and die in the v37 explosion', !!(report.bombers && report.bombers.pass), JSON.stringify(report.bombers));
    check('bullet hell: all 32 sorties beatable under live fire (no invulnerability)', !!(report.bulletHell && report.bulletHell.pass) && (report.bulletHell.sorties || []).length === 32 && (report.bulletHell.sorties || []).every(x => x.beatable), JSON.stringify((report.bulletHell && report.bulletHell.sorties || []).filter(x => !x.beatable)));
    check('bullet hell: density past the 1942 reference (max live bullets > 20)', !!(report.bulletHell && report.bulletHell.maxBullets > 20), 'maxBullets=' + (report.bulletHell && report.bulletHell.maxBullets));
    check('bullet hell: cap respected (max live bullets <= 30)', !!(report.bulletHell && report.bulletHell.maxBullets <= 30), 'maxBullets=' + (report.bulletHell && report.bulletHell.maxBullets));
    check('bullet hell: every sortie killed its boss (bossKilled)', !!(report.bulletHell && (report.bulletHell.sorties || []).every(x => x.bossKilled)), JSON.stringify((report.bulletHell && report.bulletHell.sorties || []).filter(x => !x.bossKilled).map(x => x.stage)));
    check('explosions spawn, size, expire, cap (AceQA.explosions)', !!(report.explosions && report.explosions.pass), JSON.stringify(report.explosions));
    check('co-op no friendly fire', !!(report.coop && report.coop.pass), JSON.stringify(report.coop));
    check('one-hit death with wingman buffers', !!(report.wingmanBuffer && report.wingmanBuffer.pass), JSON.stringify(report.wingmanBuffer));
    check('hold-to-fire (release stops firing)', !!(report.holdFire && report.holdFire.pass), JSON.stringify(report.holdFire));
    check('tap-and-hold movement', !!(report.tapMove && report.tapMove.pass), JSON.stringify(report.tapMove));
    check('power-ups cycle when shot', !!(report.powerCycle && report.powerCycle.pass), JSON.stringify(report.powerCycle));
  }

  // --- individual v35 exercises (direct) ---------------------------------------
  console.log('\n-- direct v40 exercises --');
  try {
    const nf = AceQA.noFriendlyFire();
    check('AceQA.noFriendlyFire()', nf.pass === true, JSON.stringify(nf));
    const wb = AceQA.wingmanBuffer();
    check('AceQA.wingmanBuffer()', wb.pass === true, JSON.stringify(wb));
    const hf = AceQA.holdFire();
    check('AceQA.holdFire()', hf.pass === true, JSON.stringify(hf));
    const tm = AceQA.tapMove();
    check('AceQA.tapMove()', tm.pass === true, JSON.stringify(tm));
    const pc = AceQA.powerCycle();
    check('AceQA.powerCycle()', pc.pass === true, JSON.stringify(pc));
    const am = AceQA.ambient();
    check('AceQA.ambient()', am.pass === true, JSON.stringify(am));
    const ex = AceQA.explosions();
    check('AceQA.explosions()', ex.pass === true, JSON.stringify(ex));
    const tr = AceQA.trenches();
    check('AceQA.trenches()', tr.pass === true, JSON.stringify(tr));
    const rv = AceQA.rivers();
    check('AceQA.rivers()', rv.pass === true, JSON.stringify(rv));
    const fl = AceQA.frontline();
    check('AceQA.frontline()', fl.pass === true, JSON.stringify(fl));
    const bm = AceQA.bombers();
    check('AceQA.bombers()', bm.pass === true, JSON.stringify(bm));
    const bh = AceQA.bulletHell();
    check('AceQA.bulletHell() (all 32 beatable under fire, max ' + bh.maxBullets + ' live bullets at S' + bh.maxBulletsStage + ')', bh.pass === true && bh.sorties.length === 32 && bh.sorties.every(x => x.beatable), JSON.stringify(bh.sorties.filter(x => !x.beatable)));
    const sz = AceQA.spawnZeppelin();
    check('AceQA.spawnZeppelin() spawns a zeppelin boss', sz.boss && sz.boss.kind === 'zeppelin', JSON.stringify(sz.boss));
    const ss = AceQA.spawnStaaken();
    check('AceQA.spawnStaaken() spawns the Staaken R.VI boss', ss.boss && ss.boss.kind === 'staaken' && ss.boss.stage === 28, JSON.stringify(ss.boss));
  } catch (e) {
    failures++;
    console.log('  FAIL  direct exercise threw: ' + (e && e.stack || e));
  }

  // --- haptics (checked last: buzz() is muted during the campaign playtest,
  // so vibrates only accumulate once the direct exercises run unmuted) --------
  console.log('\n-- haptics --');
  console.log('  navigator.vibrate calls recorded:', vibrates.length);
  check('haptics fired (buzz wired to hits/deaths)', vibrates.length > 0);

  if (consoleErrors.length) {
    console.log('\nconsole errors during run (' + consoleErrors.length + '):');
    consoleErrors.slice(0, 5).forEach(e => console.log('  - ' + e));
  }
  console.log('\nv44 headless playtest: ' + (failures ? failures + ' FAILURES' : 'ALL GREEN'));
  process.exit(failures ? 1 : 0);
})().catch(e => { console.error('playtest driver error:', e && e.stack || e); process.exit(1); });
