# 1918: Ace of Aces — Blender asset RENDER LOG

Procedural low-poly original WWI asset set. Blender 4.5.14, Cycles CPU,
top-down orthographic camera, transparent PNG, 256x256, 32 px/unit,
neutral 3-point lighting (Standard view transform).

Models verified on disk: 20/20 (.blend + .glb each)
Sprites verified on disk: 42/42

## Models (all under 5k tris)

| ID | Tris | .blend | .glb |
|---|---|---|---|
| enemy-triplane | 512 | yes | yes |
| enemy-scout | 500 | yes | yes |
| enemy-fighter | 500 | yes | yes |
| enemy-bomber | 632 | yes | yes |
| enemy-balloon | 448 | yes | yes |
| enemy-aagun | 916 | yes | yes |
| enemy-railwaygun | 592 | yes | yes |
| item-ammo | 168 | yes | yes |
| item-repair | 60 | yes | yes |
| item-bomb | 180 | yes | yes |
| boss-1-red | 512 | yes | yes |
| boss-2-checker | 592 | yes | yes |
| boss-3-stripes | 608 | yes | yes |
| boss-4-tiger | 472 | yes | yes |
| boss-5-jester | 688 | yes | yes |
| boss-6-ghost | 544 | yes | yes |
| boss-7-baron | 508 | yes | yes |
| setpiece-trench | 2740 | yes | yes |
| setpiece-aerodrome | 336 | yes | yes |
| setpiece-farm | 120 | yes | yes |
| setpiece-nomansland | 748 | yes | yes |

**Total: 21 models, 12376 tris**

## Sprites (45)

Aircraft + balloon: 3 frames each (bank-left / level / bank-right).
Guns, items, set pieces: single frame each.

- boss-1-red-bank-left.png
- boss-1-red-bank-right.png
- boss-1-red-level.png
- boss-2-checker-bank-left.png
- boss-2-checker-bank-right.png
- boss-2-checker-level.png
- boss-3-stripes-bank-left.png
- boss-3-stripes-bank-right.png
- boss-3-stripes-level.png
- boss-4-tiger-bank-left.png
- boss-4-tiger-bank-right.png
- boss-4-tiger-level.png
- boss-5-jester-bank-left.png
- boss-5-jester-bank-right.png
- boss-5-jester-level.png
- boss-6-ghost-bank-left.png
- boss-6-ghost-bank-right.png
- boss-6-ghost-level.png
- boss-7-baron-bank-left.png
- boss-7-baron-bank-right.png
- boss-7-baron-level.png
- enemy-aagun.png
- enemy-balloon-bank-left.png
- enemy-balloon-bank-right.png
- enemy-balloon-level.png
- enemy-bomber-bank-left.png
- enemy-bomber-bank-right.png
- enemy-bomber-level.png
- enemy-fighter-bank-left.png
- enemy-fighter-bank-right.png
- enemy-fighter-level.png
- enemy-railwaygun.png
- enemy-scout-bank-left.png
- enemy-scout-bank-right.png
- enemy-scout-level.png
- enemy-triplane-bank-left.png
- enemy-triplane-bank-right.png
- enemy-triplane-level.png
- item-ammo.png
- item-bomb.png
- item-repair.png
- setpiece-aerodrome.png
- setpiece-farm.png
- setpiece-nomansland.png
- setpiece-trench.png

## Notes
- All designs original; national markings limited to simple geometric shapes (discs/bands).
- Boss liveries are fictional and distinct at small sprite size.
- Balloon tether extends below the basket (visible in .glb, hidden top-down).
- Scripts: `blender/build_models.py`, `blender/render_sprites.py`, `blender/test_cycles.py`.
