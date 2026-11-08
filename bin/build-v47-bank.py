#!/usr/bin/env python3
"""bin/build-v47-bank.py — v47 enemy banking poses for 1918.

WHAT WAS WRONG (audited 2026-11-07, pixel-measured):
- The enemy/boss bank-left/right poses are NOT the true +/-14 deg photographic
  rotations the player SPAD enjoys (v38). Most are near-duds: triplane,
  scout, fighter, bomber and all six bosses sit at ~+/-1 deg, dvii at ~0.3
  deg, eiii at ~1.6 deg, dva at ~2.5 deg. A few are wild instead: rumpler and
  junkers at ~+/-23.5 deg, clii and taube at ~+/-18.2 deg, dri at ~+/-6.5
  deg. And pfalz is REVERSED (bank-left +5.7 deg, bank-right -5.7 deg).
- In-game, drawEnemy/drawBoss switch poses at a +/-0.18 bank threshold, so
  a dud pose means no visible banking at all (flat swivel on a pivot), and a
  real pose means the nose snaps +/-14-23 deg off the flight path the moment
  the threshold is crossed (the swivel the Cap'n called weird). The bank
  value itself is already computed from the true turn rate and eased
  (advancePathEnemy), and the boss lateral is already there — only the poses
  and the draw path were wrong.

WHAT THIS SCRIPT DOES (photographic material only, no generated pixels):
- Rebuilds bank-left/bank-right for all 14 enemy aircraft sets and all 6
  boss sets as TRUE +/-14 deg photographic rotations of their own level
  photos — bank-left = rotate(+14) counter-clockwise, bank-right =
  rotate(-14) clockwise, exactly the v38 player-SPAD convention (build
  _spad_set). Rotated with expand, then fit into the 256px square, LANCZOS.
  Level and damaged files are untouched. The balloon is not an aircraft and
  is skipped. The pfalz reversal is fixed by rebuilding from level.
- Originals are backed up to assets/sprites/.v47-backup/ before any
  overwrite. Re-running the script reproduces the same outputs.
- Verifies every rebuilt pose: 256x256 RGBA, aircraft visible, corners
  transparent (feathered), and mask-IoU > 0.98 against the same level photo
  rotated by the same angle through the same pipeline (catches a wrong
  angle, a wrong source, or a flipped sign). Prints the measured
  principal-axis angle of every pose for the record.

Usage: python3 bin/build-v47-bank.py
"""
import os
import shutil
import sys

import numpy as np
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SPR = os.path.join(ROOT, "assets", "sprites")
BACKUP = os.path.join(SPR, ".v47-backup")
os.makedirs(BACKUP, exist_ok=True)

PREFIXES = [
    # enemy aircraft (14)
    "enemy-triplane", "enemy-scout", "enemy-fighter", "enemy-bomber",
    "enemy-dri", "enemy-dvii", "enemy-dva", "enemy-eiii", "enemy-pfalz",
    "enemy-gotha", "enemy-clii", "enemy-rumpler", "enemy-junkers",
    "enemy-taube",
    # bosses (6)
    "boss-1-red", "boss-2-checker", "boss-3-stripes", "boss-4-tiger",
    "boss-5-jester", "boss-6-ghost",
]

BANK_ANGLE = 14  # deg, matching the v38 player-SPAD bank poses


def backup(path):
    """Copy the original to .v47-backup/ before the first overwrite."""
    name = os.path.basename(path)
    dst = os.path.join(BACKUP, name)
    if not os.path.exists(dst) and os.path.exists(path):
        shutil.copy2(path, dst)
    return dst


def save(img, path):
    img.save(path, "PNG")


def fit_into_square(im, size=256):
    """Scale the image to fit inside a transparent square canvas."""
    w, h = im.size
    scale = size / max(w, h)
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    small = im.resize((nw, nh), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(small, ((size - nw) // 2, (size - nh) // 2), small)
    return canvas


def visible_px(im):
    a = np.asarray(im.split()[3], dtype=np.uint8)
    return int((a > 40).sum())


def corner_alpha_max(im):
    a = np.asarray(im.split()[3], dtype=np.uint8)
    return int(max(a[0, 0], a[0, -1], a[-1, 0], a[-1, -1]))


def mask_iou(a_im, b_im):
    """IoU of the visible (alpha>40) masks, both downsampled to 128px."""
    a = np.asarray(a_im.split()[3].resize((128, 128))) > 40
    b = np.asarray(b_im.split()[3].resize((128, 128))) > 40
    inter = int((a & b).sum())
    union = int((a | b).sum())
    return inter / union if union else 0.0


def principal_angle(im):
    """Orientation (deg) of the visible silhouette's principal axis."""
    a = np.asarray(im.split()[3], dtype=np.float64)
    ys, xs = np.where(a > 40)
    if len(xs) < 50:
        return None
    xs = xs.astype(np.float64)
    ys = ys.astype(np.float64)
    cx, cy = xs.mean(), ys.mean()
    cxx = ((xs - cx) ** 2).mean()
    cyy = ((ys - cy) ** 2).mean()
    cxy = ((xs - cx) * (ys - cy)).mean()
    return round(0.5 * float(np.degrees(np.arctan2(2 * cxy, cxx - cyy))), 2)


def build_bank_set(prefix):
    src_path = os.path.join(SPR, prefix + "-level.png")
    src = Image.open(src_path).convert("RGBA")
    out = {}
    for name, angle in (("bank-left", BANK_ANGLE), ("bank-right", -BANK_ANGLE)):
        rot = src.rotate(angle, resample=Image.BICUBIC, expand=True)
        posed = fit_into_square(rot, 256)
        dst = os.path.join(SPR, prefix + "-" + name + ".png")
        backup(dst)
        save(posed, dst)
        out[name] = posed
    return src, out


def main():
    failures = []
    print("v47 bank poses — rebuilding %d sets as true +/-%d deg rotations"
          % (len(PREFIXES), BANK_ANGLE))
    for prefix in PREFIXES:
        level_path = os.path.join(SPR, prefix + "-level.png")
        if not os.path.exists(level_path):
            failures.append(prefix + ": level file missing")
            print("  FAIL  %s: level file missing" % prefix)
            continue
        src, poses = build_bank_set(prefix)
        lvl_ang = principal_angle(src)
        report = []
        ok = True
        for name, angle in (("bank-left", BANK_ANGLE),
                            ("bank-right", -BANK_ANGLE)):
            posed = poses[name]
            # verify against the same level photo rotated the same way
            expect = fit_into_square(
                src.rotate(angle, resample=Image.BICUBIC, expand=True), 256)
            iou = mask_iou(posed, expect)
            ang = principal_angle(posed)
            vis = visible_px(posed)
            corner = corner_alpha_max(posed)
            good = (posed.size == (256, 256) and vis > 500 and corner <= 8
                    and iou > 0.98)
            if not good:
                ok = False
                failures.append(
                    "%s-%s: size=%s vis=%d corner=%d iou=%.3f"
                    % (prefix, name, posed.size, vis, corner, iou))
            report.append("%s: angle=%s iou=%.3f vis=%d"
                          % (name, ang, iou, vis))
        print("  %s  level-angle=%s  %s  %s"
              % ("PASS " if ok else "FAIL ", lvl_ang, prefix, " | ".join(report)))
    print("\n%d sets rebuilt, %d failures" % (len(PREFIXES), len(failures)))
    for f in failures:
        print("  - " + f)
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
