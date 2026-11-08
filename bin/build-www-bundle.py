#!/usr/bin/env python3
"""Build the Capacitor wrapper's bundled game (native/www/index.html).

Reproduces the "staged web build" that produced the Oct 30 www/index.html:
the source game (1918-ace-of-aces.html) with its hero assets inlined as
base64 data URIs, while sprite/minimap assets stay as relative paths loaded
from www/assets/ at runtime.

Inlined (the same set the Oct 30 bundle inlined, mapped to v34 references):
  - <style> CSS backgrounds: title-western-front-action.jpg, spad-player.png,
    spad-xiii-period-photo.jpg, title-comic-panels.jpg
  - the `art` object: terrain-aerial.jpg, enemy-scout-level.png,
    spad-player.png, spad-player-2.png, enemy-fighter-level.png,
    v34/v34-zeppelin.png
NOT inlined (left as relative paths, served from www/assets/):
  - <img> tags, all other loadImage() calls (sprites, setpieces, v34 sprites,
    minimaps). Run the www/assets sync (rsync assets/ -> native/www/assets/)
    so those files exist at runtime.
Dropped vs Oct 30: the two THREE.js .glb models (application/octet-stream)
  and the splash-art webp — v34 removed the THREE/GLB path and the splash-art
  img, so there is nothing to inline for them.

Usage: python3 bin/build-www-bundle.py [src-html] [out-html]
Defaults: 1918-ace-of-aces.html -> native/www/index.html
"""
import base64, mimetypes, re, sys, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, '1918-ace-of-aces.html')
OUT = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, 'native', 'www', 'index.html')

# path (as referenced in the HTML) -> file on disk (relative to repo root)
INLINE = {
    'assets/title-western-front-action.jpg': 'assets/title-western-front-action.jpg',
    'assets/spad-player.png': 'assets/spad-player.png',
    'assets/spad-xiii-period-photo.jpg': 'assets/spad-xiii-period-photo.jpg',
    'assets/title-comic-panels.jpg': 'assets/title-comic-panels.jpg',
    'assets/terrain-aerial.jpg': 'assets/terrain-aerial.jpg',
    'assets/sprites/enemy-scout-level.png': 'assets/sprites/enemy-scout-level.png',
    'assets/spad-player-2.png': 'assets/spad-player-2.png',
    'assets/sprites/enemy-fighter-level.png': 'assets/sprites/enemy-fighter-level.png',
    'assets/sprites/v34/v34-zeppelin.png': 'assets/sprites/v34/v34-zeppelin.png',
}

def data_uri(rel):
    with open(os.path.join(ROOT, rel), 'rb') as f:
        raw = f.read()
    mime = mimetypes.guess_type(rel)[0] or 'application/octet-stream'
    return 'data:%s;base64,%s' % (mime, base64.b64encode(raw).decode('ascii'))

def main():
    html = open(SRC, encoding='utf-8').read()
    uris = {p: data_uri(f) for p, f in INLINE.items()}
    inlined = {}

    # 1. CSS url() inside <style> blocks only.
    def style_repl(m):
        block = m.group(0)
        for path, uri in uris.items():
            for q in ("'", '"', ''):
                old = "url(%s%s%s)" % (q, path, q)
                if old in block:
                    block = block.replace(old, "url('%s')" % uri)
                    inlined.setdefault(path, 0)
                    inlined[path] += block.count(uri)  # count after replace (approx)
        return block
    html = re.sub(r'<style[^>]*>.*?</style>', style_repl, html, flags=re.S)

    # 2. loadImage() calls inside the `var art={...}` object only.
    m = re.search(r'var art=\{.*?\}\n', html, flags=re.S)
    if not m:
        raise SystemExit('art object not found in source')
    art = m.group(0)
    art_new = art
    for path, uri in uris.items():
        for q in ("'", '"'):
            old = "loadImage(%s%s%s)" % (q, path, q)
            if old in art_new:
                art_new = art_new.replace(old, "loadImage('%s')" % uri)
    html = html[:m.start()] + art_new + html[m.end():]

    # 3. Safety: no inlined path may remain as a bare reference in <style> or art.
    for path in uris:
        if ("url('%s')" % path) in html or ('url("%s")' % path) in html:
            raise SystemExit('FAILED: %s still referenced as url() (not inlined)' % path)
    m2 = re.search(r'var art=\{.*?\}\n', html, flags=re.S)
    for path in uris:
        if path in m2.group(0):
            raise SystemExit('FAILED: %s still referenced in art object (not inlined)' % path)

    open(OUT, 'w', encoding='utf-8').write(html)
    print('wrote %s (%d bytes)' % (OUT, len(html)))
    print('inlined %d unique assets:' % len(uris))
    for p in sorted(uris):
        print('  %s -> %s (%d base64 chars)' % (p, uris[p][:30], len(uris[p])))

if __name__ == '__main__':
    main()
