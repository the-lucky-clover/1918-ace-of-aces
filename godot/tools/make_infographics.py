#!/usr/bin/env python3
"""v17: sortie infographics for chat delivery — one 1080px PNG per sortie.
Reads sortie_data.gd directly so the cards always match the game.
Output: ~/workspace/1918-ace-of-aces/infographics/sortie-N.png
"""
import re, os, math
from PIL import Image, ImageDraw, ImageFont

GODOT = os.path.expanduser('~/workspace/1918-godot')
SPR = os.path.join(GODOT, 'assets/sprites')
OUT = os.path.expanduser('~/workspace/1918-ace-of-aces/infographics')
os.makedirs(OUT, exist_ok=True)

FB = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'
FR = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
def font(sz, bold=True):
    return ImageFont.truetype(FB if bold else FR, sz)

WEATHER = ["clear", "windy", "rain", "storm", "windy", "clear", "storm"]
BOSS_SPR = ["red", "checker", "stripes", "tiger", "jester", "ghost", "baron"]
WTYPE_SPR = {
    'scout': 'enemy-scout-level.png', 'fighter': 'enemy-fighter-level.png',
    'triplane': 'enemy-triplane-level.png', 'bomber': 'enemy-bomber-level.png',
    'balloon': 'enemy-balloon-level.png', 'fokker_dr1': 'enemy-fokker-dr1-level.png',
    'fokker_d7': 'enemy-fokker-d7-level.png', 'albatros': 'enemy-albatros-level.png',
    'aagun': 'enemy-aagun.png', 'trench': 'setpiece-trench.png',
    'zeppelin': 'zeppelin.png', 'uboat': 'uboat.png', 'subpen': 'subpen.png',
    'ammodepot': 'ammodepot.png', 'train': 'train.png', 'arty': 'arty.png',
    'parked': 'enemy-scout-level.png', 'parked_ger': 'enemy-fokker-d7-level.png',
    'barge': 'barge.png', 'airfield': 'setpiece-aerodrome.png',
    'railwaygun': 'enemy-railwaygun.png',
}
SEC_TEXT = {
    "balloons": "Bust %d observation balloons", "trenches": "Strafe %d trench positions",
    "railgun": "Destroy the railway gun", "bombers": "Down %d bombers",
    "uboats": "Sink %d U-boats before they dive", "pens": "Smash %d submarine pens",
    "zeppelins": "Down %d zeppelins", "depots": "Detonate %d munitions depots",
    "arty": "Silence %d artillery batteries", "parked": "Strafe %d parked aircraft",
    "trucks": "Interdict %d reinforcement trucks", "flak": "Silence %d AA batteries",
    "barges": "Sink %d river supply barges",
}

src = open(os.path.join(GODOT, 'scripts/sortie_data.gd')).read()
names = re.findall(r'"name": "([^"]+)"', src)
themes = re.findall(r'"theme": "([^"]+)"', src)
takeoffs = re.findall(r'"takeoff": "([^"]+)"', src)
bosses = [int(x) for x in re.findall(r'"boss": (\d),', src)]
boss_ats = [float(x) for x in re.findall(r'"boss_at": ([\d.]+),', src)]
arenas = re.findall(r'"boss_arena": "([^"]+)"', src)
boss_names = re.findall(r'^\t"([A-Z ]+)",$', src, re.M)
sec_blocks = re.findall(r'"secondaries": \[(.*?)\],', src, re.S)
wave_blocks = re.findall(r'"waves": \[(.*?)\],\n\t\t"takeoff"', src, re.S)

W, M = 1080, 36
BG = (14, 15, 20)
PANEL = (24, 26, 34)
GOLD = (212, 175, 90)
CREAM = (235, 228, 205)
DIM = (150, 155, 165)
RED = (200, 60, 55)
SKY = (90, 140, 200)

def minimap_thumb(theme, tw=300, th=400):
    im = Image.new('RGB', (tw, th), (10, 10, 14))
    d = ImageDraw.Draw(im)
    if theme == 'farmland':
        cols = [(26, 33, 18), (36, 28, 15), (20, 26, 13)]
        for ix in range(4):
            for iy in range(6):
                d.rectangle([ix*tw/4+1, iy*th/6+1, (ix+1)*tw/4-1, (iy+1)*th/6-1],
                            fill=cols[(ix*3+iy) % 3])
        d.line([tw*0.3, 0, tw*0.62, th], fill=(51, 41, 26), width=3)
    elif theme == 'river_interdiction':
        d.rectangle([0, 0, tw, th], fill=(18, 23, 28))
        pts = [(tw*0.5 + math.sin(k*0.85)*tw*0.13, k*th/16) for k in range(17)]
        d.line(pts, fill=(41, 28, 20), width=19)
        d.line(pts, fill=(15, 28, 43), width=14)
        d.line(pts, fill=(115, 140, 165), width=3)
    elif theme == 'zeppelin_sheds':
        d.rectangle([0, 0, tw, th], fill=(28, 31, 18))
        for i in range(3):
            y = th*(0.18 + i*0.22)
            d.rectangle([tw*0.5-52, y, tw*0.5+52, y+40], fill=(51, 49, 38), outline=(115, 110, 87), width=2)
        d.ellipse([tw*0.5-10, th*0.86-10, tw*0.5+10, th*0.86+10], outline=(140, 128, 97), width=2)
    elif theme == 'munitions_depot':
        d.rectangle([0, 0, tw, th], fill=(26, 23, 15))
        for ix in range(4):
            for iy in range(5):
                x, y = tw*0.5-44+ix*24, th*0.16+iy*22
                d.rectangle([x, y, x+18, y+16], fill=(115, 87, 51) if (ix+iy) % 2 == 0 else (97, 71, 41))
    elif theme == 'uboat_base':
        d.rectangle([0, 0, tw, th], fill=(13, 26, 46))
        d.rectangle([0, 0, tw*0.16, th], fill=(77, 66, 43))
        cx = tw*0.55
        d.line([cx-34, th*0.30, cx+6, th*0.30], fill=(107, 107, 112), width=5)
        for i in range(3):
            d.rectangle([cx-26+i*20, th*0.36, cx-10+i*20, th*0.36+10], fill=(77, 77, 82))
    elif theme == 'rail_yard':
        d.rectangle([0, 0, tw, th], fill=(26, 23, 18))
        for i in range(5):
            d.line([tw*(0.30+i*0.10), 0, tw*0.5+(i-2)*8, th], fill=(97, 97, 102), width=2)
        d.rectangle([tw*0.5-40, th*0.42, tw*0.5+40, th*0.42+60], outline=(128, 117, 92), width=2)
    elif theme == 'storm':
        d.rectangle([0, 0, tw, th], fill=(26, 28, 41))
        for i in range(9):
            x = (i*137) % tw; y = (i*89) % th
            d.ellipse([x-12, y-12, x+12, y+12], fill=(41, 43, 61))
        lx = tw*0.68
        d.line([(lx+6 if k % 2 == 0 else lx-6, k*th/6) for k in range(7)], fill=(191, 209, 242), width=2)
    elif theme == 'bluesky':
        d.rectangle([0, 0, tw, th], fill=(77, 122, 184))
        for i in range(7):
            x = (i*173) % tw; y = (i*211) % th
            d.ellipse([x-30, y-12, x+30, y+12], fill=(209, 224, 242))
    # boss entry marker: pulsing red diamond top-center (North)
    mx, my = tw/2, 26
    d.polygon([(mx, my-13), (mx+13, my), (mx, my+13), (mx-13, my)], fill=(220, 60, 55))
    d.polygon([(mx, my-13), (mx+13, my), (mx, my+13), (mx-13, my)], outline=(255, 220, 150), width=2)
    return im

for si in range(7):
    name = names[si]; theme = themes[si]; boss = bosses[si]
    secs = re.findall(r'\{"id": "(\w+)", "target": (\d+)\}', sec_blocks[si])
    wtypes = []
    for wt in re.findall(r'"type": "(\w+)"', wave_blocks[si]):
        if wt in WTYPE_SPR and wt not in wtypes and wt not in ('gasstrike',):
            wtypes.append(wt)
    wtypes = wtypes[:6]

    H = 1140
    im = Image.new('RGB', (W, H), BG)
    d = ImageDraw.Draw(im)
    y = M
    # header
    d.rectangle([M, y, W-M, y+96], fill=PANEL)
    d.text((M+20, y+14), 'SORTIE %d' % (si+1), font=font(30), fill=GOLD)
    d.text((M+20, y+52), name.split('—', 1)[1].strip() if '—' in name else name,
           font=font(26), fill=CREAM)
    wb = '  %s  ' % WEATHER[si].upper()
    fwb = font(24)
    bb = d.textbbox((0, 0), wb, font=fwb)
    bx = W-M-(bb[2]-bb[0])-20
    d.rectangle([bx, y+26, bx+(bb[2]-bb[0]), y+26+(bb[3]-bb[1])+16], fill=(46, 60, 80))
    d.text((bx+10, y+32), wb.strip(), font=fwb, fill=(170, 200, 235))
    d.text((bx-150, y+66), 'TAKEOFF ' + takeoffs[si], font=font(18, False), fill=DIM)
    y += 120
    # sprite strip
    d.text((M, y), 'SPRITE SHEET', font=font(22), fill=GOLD); y += 34
    strip = [('player-spad.png', 'YOU')]
    for wt in wtypes:
        strip.append((WTYPE_SPR[wt], wt.replace('_', ' ').upper()))
    strip.append(('boss-%d-%s-level.png' % (boss+1, BOSS_SPR[boss]), 'BOSS'))
    x = M
    for fn, label in strip:
        p = os.path.join(SPR, fn)
        try:
            sp = Image.open(p).convert('RGBA').resize((104, 104))
        except Exception:
            sp = Image.new('RGBA', (104, 104), (60, 60, 60, 255))
        im.paste(sp, (x, y), sp)
        d.text((x, y+108), label[:12], font=font(13, False), fill=DIM)
        x += 118
    y += 150
    # objectives
    d.text((M, y), 'MISSION OBJECTIVES', font=font(22), fill=GOLD); y += 34
    d.rectangle([M, y, W-M, y+150], fill=PANEL)
    oy = y + 14
    d.text((M+18, oy), 'PRIMARY — Defeat %s' % boss_names[boss], font=font(20), fill=(255, 150, 140)); oy += 34
    for sid, tgt in secs:
        tmpl = SEC_TEXT.get(sid, sid)
        txt = tmpl % int(tgt) if '%d' in tmpl else tmpl
        d.text((M+18, oy), '• %s' % txt, font=font(18, False), fill=CREAM); oy += 28
    y += 170
    # boss entry card
    d.text((M, y), 'BOSS ENTRY', font=font(22), fill=GOLD); y += 34
    d.rectangle([M, y, W-M, y+440], fill=PANEL)
    thumb = minimap_thumb(theme).resize((280, 380))
    im.paste(thumb, (M+18, y+30))
    d.text((M+18, y+414), 'MINIMAP — spawn marked N', font=font(14, False), fill=DIM)
    tx = M+330
    d.text((tx, y+30), boss_names[boss], font=font(30), fill=(255, 150, 140))
    d.text((tx, y+74), 'INBOUND in ~%ds of wheels-up' % int(boss_ats[si]), font=font(20), fill=CREAM)
    d.text((tx, y+108), 'ENTRY — top-center (North)', font=font(20), fill=CREAM)
    arena = arenas[si]
    ab = '  BLUE-SKY ARENA  ' if arena == 'bluesky' else '  TERRAIN DUEL  '
    fba = font(22)
    abb = d.textbbox((0, 0), ab, font=fba)
    acol = SKY if arena == 'bluesky' else (110, 90, 60)
    d.rectangle([tx, y+150, tx+(abb[2]-abb[0]), y+150+(abb[3]-abb[1])+16], fill=acol)
    d.text((tx+10, y+156), ab.strip(), font=fba, fill=(10, 12, 16) if arena == 'bluesky' else CREAM)
    note = ('The duel climbs above the terrain into a seamless'
            if arena == 'bluesky' else 'The duel stays over the terrain —') 
    note2 = ('cyclical blue sky. No ground, just clouds.' if arena == 'bluesky'
             else 'watch the ground war below you.')
    d.text((tx, y+210), note, font=font(17, False), fill=DIM)
    d.text((tx, y+234), note2, font=font(17, False), fill=DIM)
    d.text((tx, y+280), 'TAUNTS: period-flavored, no ceremony.', font=font(16, False), fill=DIM)
    d.text((tx, y+304), 'Respect the fallen. Celebrate the win.', font=font(16, False), fill=GOLD)
    y += 470
    # footer
    d.text((M, H-50), '1918 — v17 sortie briefing cards', font=font(16, False), fill=DIM)
    d.text((W-M-260, H-50), 'procedural · original · honest', font=font(16, False), fill=DIM)
    out = os.path.join(OUT, 'sortie-%d.png' % (si+1))
    im.save(out)
    print('wrote', out)
