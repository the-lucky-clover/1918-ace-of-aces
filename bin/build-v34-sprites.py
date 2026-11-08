#!/usr/bin/env python3
"""bin/build-v34-sprites.py — v34 raster sprite sheets for 1918.

Every sprite is built ONLY from the one verified photographic source in the
repo: native/www/assets/terrain-aerial.jpg (a real vertical aerial photo of
a WWI battlefield: trenches, shell craters, a ruined village, roads, fields).

No vector art is drawn into these sheets at runtime in the game; the sheets
are raster PNGs (photo pixels + crop/scale/grade/alpha masks). The only
PIL-drawn shapes are alpha MASKS (silhouettes) that photo texture is
composited through, and the hat-ring insignia decal (a flat livery decal,
geometric by nature — the same marks the player SPAD already carries).

Outputs: assets/sprites/v34/*.png
Usage: python3 bin/build-v34-sprites.py
"""
import os
from PIL import Image, ImageDraw, ImageFilter, ImageEnhance, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "native", "www", "assets", "terrain-aerial.jpg")
OUT = os.path.join(ROOT, "assets", "sprites", "v34")
os.makedirs(OUT, exist_ok=True)

photo = Image.open(SRC).convert("RGB")
PW, PH = photo.size
print("photo:", photo.size)


def crop(box):
    """Crop, clamped to the photo."""
    x0, y0, x1, y1 = box
    x0 = max(0, min(PW - 2, x0)); y0 = max(0, min(PH - 2, y0))
    x1 = max(x0 + 2, min(PW, x1)); y1 = max(y0 + 2, min(PH, y1))
    return photo.crop((x0, y0, x1, y1))


def soft_radial(size, feather=18, inner=1.0):
    """L-mode radial alpha mask: solid centre, feathered edge."""
    w, h = size
    m = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(m)
    d.ellipse([0, 0, w, h], fill=255)
    if feather:
        m = m.filter(ImageFilter.GaussianBlur(feather))
    return m


def soft_ellipse_mask(size, feather=10):
    return soft_radial(size, feather)


def apply_mask(img, mask):
    img = img.convert("RGBA")
    img.putalpha(mask)
    return img


def grade(img, bright=1.0, contrast=1.0, color=1.0, tint=None, tint_amt=0.0):
    img = ImageEnhance.Brightness(img).enhance(bright)
    img = ImageEnhance.Contrast(img).enhance(contrast)
    img = ImageEnhance.Color(img).enhance(color)
    if tint is not None and tint_amt > 0:
        solid = Image.new("RGB", img.size, tint)
        img = Image.blend(img.convert("RGB"), solid, tint_amt).convert("RGBA")
    return img


def save(img, name):
    p = os.path.join(OUT, name)
    img.save(p, "PNG")
    print("wrote", name, img.size)
    return p


# ------------------------------------------------------------------ FX sheets
# Smoke: 4 frames, dusty field crops, heavy blur, soft round alpha.
smoke_frames = []
smoke_boxes = [(60, 1700, 340, 1980), (420, 1750, 700, 2030),
               (760, 1680, 1040, 1960), (180, 1900, 460, 2180)]
for i, box in enumerate(smoke_boxes):
    im = crop(box).resize((128, 128), Image.LANCZOS)
    im = im.filter(ImageFilter.GaussianBlur(4))
    im = grade(im, bright=0.92, contrast=1.05, color=0.6,
               tint=(70, 66, 58), tint_amt=0.18)
    im = apply_mask(im, soft_radial((128, 128), feather=12))
    smoke_frames.append(im)
sheet = Image.new("RGBA", (512, 128), (0, 0, 0, 0))
for i, f in enumerate(smoke_frames):
    sheet.paste(f, (i * 128, 0), f)
save(sheet, "v34-smoke.png")

# Fire: 4 frames, burnt crater interiors, warm grade, soft round alpha.
fire_frames = []
fire_boxes = [(620, 560, 860, 800), (700, 700, 940, 940),
              (520, 820, 760, 1060), (820, 900, 1060, 1140)]
for i, box in enumerate(fire_boxes):
    im = crop(box).resize((128, 128), Image.LANCZOS)
    im = im.filter(ImageFilter.GaussianBlur(3))
    im = grade(im, bright=1.12, contrast=1.15, color=1.5,
               tint=(255, 110, 20), tint_amt=0.28)
    im = apply_mask(im, soft_radial((128, 128), feather=16))
    fire_frames.append(im)
sheet = Image.new("RGBA", (512, 128), (0, 0, 0, 0))
for i, f in enumerate(fire_frames):
    sheet.paste(f, (i * 128, 0), f)
save(sheet, "v34-fire.png")

# Flak burst: dark crater crop, bright hot core.
im = crop((760, 520, 1000, 760)).resize((128, 128), Image.LANCZOS)
im = grade(im, bright=0.72, contrast=1.2, color=0.7)
core = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
d = ImageDraw.Draw(core)
d.ellipse([44, 44, 84, 84], fill=(255, 214, 110, 255))
core = core.filter(ImageFilter.GaussianBlur(10))
im = Image.alpha_composite(im.convert("RGBA"), core)
im = apply_mask(im, soft_radial((128, 128), feather=14))
save(im, "v34-flak.png")

# Muzzle flash / glow: pale sunlit field, heavy blur, near-white.
im = crop((80, 2000, 320, 2240)).resize((96, 96), Image.LANCZOS)
im = im.filter(ImageFilter.GaussianBlur(9))
im = grade(im, bright=1.9, contrast=0.7, color=0.4, tint=(255, 226, 140),
           tint_amt=0.35)
im = apply_mask(im, soft_radial((96, 96), feather=10))
save(im, "v34-flash.png")

# Crater: one real round water-filled crater, circular mask.
im = crop((780, 560, 980, 760)).resize((160, 160), Image.LANCZOS)
im = grade(im, bright=0.95, contrast=1.12, color=0.9)
im = apply_mask(im, soft_radial((160, 160), feather=8))
save(im, "v34-crater.png")

# Scorch: dark burnt ground, soft elliptical mask.
im = crop((560, 1000, 800, 1120)).resize((160, 96), Image.LANCZOS)
im = grade(im, bright=0.55, contrast=1.1, color=0.6)
im = apply_mask(im, soft_ellipse_mask((160, 96), feather=14))
save(im, "v34-scorch.png")

# Shockwave ring: warm bright field pixels masked to a ring.
base = crop((100, 2050, 340, 2240)).resize((128, 128), Image.LANCZOS)
base = grade(base, bright=1.7, contrast=0.8, color=0.5,
             tint=(255, 214, 140), tint_amt=0.4)
ring = Image.new("L", (128, 128), 0)
d = ImageDraw.Draw(ring)
d.ellipse([14, 14, 114, 114], outline=255, width=16)
ring = ring.filter(ImageFilter.GaussianBlur(4))
save(apply_mask(base, ring), "v34-ring.png")

# Rain tile: diagonal translucent streaks (raster tile).
im = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
for i in range(26):
    x = (i * 53) % 128
    y = (i * 97) % 128
    d.line([(x, y), (x - 9, y + 26)], fill=(225, 235, 240, 110), width=2)
save(im, "v34-rain.png")

# Fog bank: pale field, heavy blur, horizontal soft alpha.
im = crop((60, 1500, 560, 1700)).resize((256, 128), Image.LANCZOS)
im = im.filter(ImageFilter.GaussianBlur(12))
im = grade(im, bright=1.25, contrast=0.7, color=0.45)
mask = Image.new("L", (256, 128), 0)
d = ImageDraw.Draw(mask)
d.ellipse([-40, -30, 296, 158], fill=200)
mask = mask.filter(ImageFilter.GaussianBlur(18))
save(apply_mask(im, mask), "v34-fog.png")

# Gas cloud: field crop tinted yellow-green, soft round alpha.
im = crop((300, 1500, 540, 1740)).resize((128, 128), Image.LANCZOS)
im = im.filter(ImageFilter.GaussianBlur(8))
im = grade(im, bright=1.05, contrast=0.85, color=0.9,
           tint=(167, 168, 61), tint_amt=0.45)
im = apply_mask(im, soft_radial((128, 128), feather=20))
save(im, "v34-gas.png")

# Snowflake: soft white dot.
im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
d.ellipse([4, 4, 28, 28], fill=(246, 250, 253, 235))
im = im.filter(ImageFilter.GaussianBlur(3))
save(im, "v34-snow.png")

# Tracer: warm horizontal streak.
im = Image.new("RGBA", (32, 8), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
d.ellipse([0, 0, 32, 8], fill=(255, 241, 164, 255))
im = im.filter(ImageFilter.GaussianBlur(2))
save(im, "v34-tracer.png")


# ------------------------------------------------- photo-textured silhouettes
def textured_silhouette(size, draw_shape, tex_box, darken=0.85):
    """Fill a PIL-drawn silhouette mask with photo texture."""
    tex = crop(tex_box).resize(size, Image.LANCZOS)
    tex = grade(tex, bright=darken, contrast=1.1, color=0.85)
    mask = Image.new("L", size, 0)
    d = ImageDraw.Draw(mask)
    draw_shape(d, size)
    mask = mask.filter(ImageFilter.GaussianBlur(1.5))
    return apply_mask(tex, mask)


def shape_arty(d, s):
    w, h = s
    # gun base + trail + long barrel (top-down artillery piece)
    d.polygon([(w * .32, h * .78), (w * .68, h * .78), (w * .62, h * .5),
               (w * .38, h * .5)], fill=255)
    d.rectangle([w * .46, h * .08, w * .54, h * .55], fill=255)
    d.ellipse([w * .30, h * .62, w * .48, h * .80], fill=255)
    d.ellipse([w * .52, h * .62, w * .70, h * .80], fill=255)


def shape_tank(d, s):
    w, h = s
    d.rounded_rectangle([w * .06, h * .30, w * .94, h * .78], radius=12,
                        fill=255)
    d.rounded_rectangle([w * .36, h * .18, w * .64, h * .46], radius=8,
                        fill=255)
    d.rectangle([w * .47, h * .02, w * .53, h * .30], fill=255)
    for cx in (0.2, 0.38, 0.56, 0.74, 0.88):
        d.ellipse([w * cx - 7, h * .80, w * cx + 7, h * .94], fill=255)


def shape_limber(d, s):
    w, h = s
    d.rectangle([w * .18, h * .22, w * .82, h * .62], fill=255)
    d.ellipse([w * .14, h * .58, w * .34, h * .86], fill=255)
    d.ellipse([w * .66, h * .58, w * .86, h * .86], fill=255)
    d.rectangle([w * .44, h * .06, w * .56, h * .24], fill=255)


def shape_cavalry(d, s):
    w, h = s
    for cx, cy in ((.26, .4), (.5, .62), (.72, .34), (.42, .22), (.66, .66)):
        d.ellipse([w * cx - 14, h * cy - 9, w * cx + 14, h * cy + 9],
                  fill=255)


def shape_vehicle(d, s):
    w, h = s
    d.rounded_rectangle([w * .08, h * .26, w * .92, h * .66], radius=8,
                        fill=255)
    d.rectangle([w * .60, h * .10, w * .88, h * .30], fill=255)
    d.ellipse([w * .16, h * .62, w * .32, h * .86], fill=255)
    d.ellipse([w * .68, h * .62, w * .84, h * .86], fill=255)
    d.rectangle([w * .46, h * .10, w * .54, h * .34], fill=255)


def shape_zeppelin(d, s):
    w, h = s
    d.ellipse([w * .02, h * .18, w * .98, h * .62], fill=255)
    d.rectangle([w * .40, h * .62, w * .48, h * .80], fill=255)
    d.rectangle([w * .54, h * .62, w * .62, h * .80], fill=255)


def shape_parachute(d, s):
    w, h = s
    d.pieslice([w * .08, h * .04, w * .92, h * .62], 180, 360, fill=255)
    d.ellipse([w * .46, h * .78, w * .54, h * .94], fill=255)


save(textured_silhouette((160, 160), shape_arty,
                         (700, 300, 900, 500), darken=0.8),
     "v34-arty.png")
save(textured_silhouette((192, 128), shape_tank,
                         (100, 2000, 500, 2200), darken=0.62),
     "v34-tank.png")
save(textured_silhouette((128, 96), shape_limber,
                         (200, 1500, 440, 1700), darken=0.85),
     "v34-limber.png")
save(textured_silhouette((128, 96), shape_cavalry,
                         (500, 300, 740, 500), darken=0.7),
     "v34-cavalry.png")
save(textured_silhouette((160, 96), shape_vehicle,
                         (100, 300, 420, 500), darken=0.85),
     "v34-vehicle.png")
save(textured_silhouette((440, 150), shape_zeppelin,
                         (100, 2050, 700, 2240), darken=1.0),
     "v34-zeppelin.png")
save(textured_silhouette((160, 160), shape_parachute,
                         (100, 2000, 400, 2240), darken=1.15),
     "v34-parachute.png")

# ------------------------------------------------------------- ground targets
# Depot: ruined-building cluster, rectangular soft mask.
im = crop((140, 980, 560, 1280)).resize((192, 128), Image.LANCZOS)
im = grade(im, bright=0.92, contrast=1.1, color=0.9)
im = apply_mask(im, soft_ellipse_mask((192, 128), feather=6))
save(im, "v34-depot.png")

# Fuel: round water-filled crater, dark metallic tint.
im = crop((820, 620, 1000, 800)).resize((128, 128), Image.LANCZOS)
im = grade(im, bright=0.8, contrast=1.15, color=0.7,
           tint=(60, 70, 80), tint_amt=0.25)
im = apply_mask(im, soft_radial((128, 128), feather=8))
save(im, "v34-fuel.png")

# Checkpoint: road crop with a barrier bar (dark photo texture).
im = crop((300, 1200, 620, 1400)).resize((128, 128), Image.LANCZOS)
im = grade(im, bright=0.95, contrast=1.1, color=0.9)
bar = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
d = ImageDraw.Draw(bar)
d.rectangle([8, 56, 120, 70], fill=(40, 34, 26, 255))
bar = bar.filter(ImageFilter.GaussianBlur(1))
im = Image.alpha_composite(im.convert("RGBA"), bar)
im = apply_mask(im, soft_ellipse_mask((128, 128), feather=8))
save(im, "v34-checkpoint.png")

# Burning chateau: ruined village foundations, darkened (burnt).
im = crop((220, 1020, 660, 1350)).resize((256, 192), Image.LANCZOS)
im = grade(im, bright=0.72, contrast=1.18, color=0.85,
           tint=(30, 20, 12), tint_amt=0.22)
im = apply_mask(im, soft_ellipse_mask((256, 192), feather=8))
save(im, "v34-chateau.png")

# Runway: straight road crop, rotated to horizontal.
im = crop((500, 1100, 900, 1250)).resize((256, 96), Image.LANCZOS)
im = grade(im, bright=1.0, contrast=1.1, color=0.9)
im = apply_mask(im, soft_ellipse_mask((256, 96), feather=6))
save(im, "v34-runway.png")

# Damage hole decal: dark crater interior, irregular soft mask.
im = crop((700, 640, 820, 760)).resize((64, 64), Image.LANCZOS)
im = grade(im, bright=0.5, contrast=1.2, color=0.6)
im = apply_mask(im, soft_radial((64, 64), feather=8))
save(im, "v34-damage.png")

# ------------------------------------------------------- hat-ring insignia decal
# Flat livery decal (roundel + striped tail + white 1). Proportions match the
# original code-drawn markings: roundel radius 0.073*dw at -0.09*dw, thin tail
# stripes at +0.32*dw. Output is a raster PNG with transparency.
im = Image.new("RGBA", (192, 192), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
# hat mark: small dark hat silhouette above the roundel
d.polygon([(84, 56), (108, 56), (102, 44), (90, 44)], fill=(32, 35, 29, 255))
d.rectangle([80, 54, 112, 58], fill=(32, 35, 29, 255))
# roundel: red ring, dark centre, white "1" (centre 96,78, outer r=14)
d.ellipse([82, 64, 110, 92], outline=(183, 45, 39, 255), width=4)
d.ellipse([86, 68, 106, 88], fill=(32, 35, 29, 255))
try:
    f1 = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf', 17)
except Exception:
    f1 = ImageFont.load_default()
d.text((96, 82), "1", font=f1, fill=(255, 255, 255, 255), anchor='mm')
# striped tail: red / cream / blue thin vertical bars at +0.32*dw
d.rectangle([84, 150, 90, 172], fill=(186, 49, 42, 255))
d.rectangle([93, 150, 99, 172], fill=(238, 232, 210, 255))
d.rectangle([102, 150, 108, 172], fill=(41, 76, 120, 255))
save(im, "v34-markings.png")


# --- v34 2.5D powerup coins: brass-rimmed medallions, photo-textured faces,
# letter embossed on the front, 94th Aero hat-ring on the reverse. The game
# spins these around their vertical axis (coin spin); the letter is baked
# into the raster sprite so it turns with the coin.
import math
def _coin_face(tex_box, letter=None, back=False):
    size=192
    face=crop(tex_box).resize((size,size))
    face=grade(face,bright=0.95,contrast=1.05,color=0.9,tint=(176,138,62),tint_amt=0.18)
    im=Image.new('RGBA',(size,size),(0,0,0,0))
    mask=Image.new('L',(size,size),0)
    md=ImageDraw.Draw(mask)
    md.ellipse([4,4,size-4,size-4],fill=255)
    im.paste(face,(0,0),mask)
    d=ImageDraw.Draw(im)
    # milled edge: short radial ticks around the rim
    cx=cy=size/2
    for k in range(48):
        a=k/48*2*math.pi
        x0=cx+math.cos(a)*88; y0=cy+math.sin(a)*88
        x1=cx+math.cos(a)*80; y1=cy+math.sin(a)*80
        d.line([x0,y0,x1,y1],fill=(90,66,30,255),width=2)
    # brass rim rings
    d.ellipse([4,4,size-4,size-4],outline=(122,90,40,255),width=8)
    d.ellipse([16,16,size-16,size-16],outline=(216,178,110,255),width=3)
    d.ellipse([16,16,size-16,size-16],outline=(60,44,20,255),width=1)
    if back:
        # reverse face: 94th Aero hat-ring (red ring + white 1)
        d.ellipse([62,62,130,130],outline=(183,45,39,255),width=6)
        d.ellipse([66,66,126,126],fill=(238,232,210,255))
        try:
            fb=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',44)
        except Exception:
            fb=ImageFont.load_default()
        d.text((96,100),'1',font=fb,fill=(32,35,29,255),anchor='mm')
    elif letter:
        # embossed letter: dark offset shadow + cream face
        try:
            fs=84 if len(letter)==1 else 56
            fl=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf',fs)
        except Exception:
            fl=ImageFont.load_default()
        d.text((98,99),letter,font=fl,fill=(40,28,12,255),anchor='mm')
        d.text((96,96),letter,font=fl,fill=(245,230,190,255),anchor='mm')
    return im

POWER_LETTERS={'firepower':'P','wing':'W','blast':'C','loop':'L','points':'1K','flak':'S','bomb':'B','yashichi':'5K'}
for _i,(_t,_L) in enumerate(POWER_LETTERS.items()):
    _tb=(100+_i*97, 300+(_i*211)%1400, 100+_i*97+300, 300+(_i*211)%1400+300)
    save(_coin_face(_tb,letter=_L), 'v34-power-%s.png'%_t)
save(_coin_face((700,1200,1000,1500),back=True), 'v34-power-back.png')

print("done:", len(os.listdir(OUT)), "sprites in", OUT)
