# PUBLISH CHECKLIST — 1918 web build (v18+)

The Godot HTML5 export is **staged, not published**. The public link still serves
the old web build until the steps below are done.

## What's staged

- Export: `web-export/` — `index.html`, `index.js`, `index.wasm` (39.5 MB),
  `index.pck` (2.9 MB), audio worklets, icons. Total ~41 MB.
- Preset: `godot/export_presets.cfg` — Web preset, 720x1280 portrait,
  GL Compatibility, **single-threaded** (no COOP/COEP headers needed),
  export path `web-export/index.html`.
- Templates: official Godot 4.7.2 export templates (from GitHub releases;
  downloads.godotengine.org serves an archive redirect for this version).

## At publish time (agent)

1. Re-run the headless export to make sure `web-export/` is current:
   `~/workspace/godot/Godot_v4.7.2-stable_linux.x86_64 --headless --path ~/workspace/1918-godot --export-release "Web"`
2. Verify `index.html` / `index.js` / `index.wasm` / `index.pck` all present.
3. Publish the contents of `web-export/` to the public artifact
   (slug `1918-ace-of-aces`) — **only while Steven is watching chat**;
   he must tap the approval card the instant it appears (standing pattern:
   the card times out otherwise).
4. Smoke-check the live link: title screen loads, FLY starts a sortie.

## What Steven needs to do

- Watch chat during publish and tap the approval card instantly.
- After publish: play the public link once (touch device ideally) and report
  anything that feels off — the v13 skeptic covers headless, not human feel.

## Honest web-platform limitations (v18)

- **Haptics**: `Input.vibrate_handheld()` maps to `navigator.vibrate` — works on
  Android Chrome, silently does nothing on iOS Safari (no Vibration API there).
- **Ads**: test-mode only — no real ads are served; all calls are logged no-ops.
  Real AdMob IDs are still Steven's move (see ADS-SETUP.md).
- **IAP**: test-mode purchase sheet, clearly labeled "NOT A REAL CHARGE".
- **Audio**: browsers require a user gesture before audio starts — the title
  screen tap covers this.
- **Saves**: `user://` maps to IndexedDB — persists normally, may clear in
  private browsing.
- **Renderer**: WebGL2 required (any modern browser); single-threaded build for
  maximum hosting compatibility.
- **Dev tooling in the pack**: the v13 bot/skeptic scripts ship inside the
  `.pck` but only activate with CLI flags — inert in the browser.
