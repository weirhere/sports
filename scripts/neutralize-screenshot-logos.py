#!/usr/bin/env python3
"""Paint a gray disc over every logo in the App Store screenshot masters.

The Linux stand-in for `-screenshot.neutralLogos YES` (2026-09-29): the
masters in docs/appstore/screenshots/ were shot before that flag existed,
and a reshoot needs the Mac. Each region below is a strip of a master that
holds only logos; every run of rows with ink in it becomes one disc, the
size of the logo it covers, in the gray LogoImage draws in neutral mode.

    python3 scripts/neutralize-screenshot-logos.py   # rewrites in place
"""
from pathlib import Path
from PIL import Image, ImageDraw
import numpy as np

ROOT = Path(__file__).resolve().parent.parent / "docs/appstore/screenshots"
DISC = (200, 200, 204)
S = 1320 / 921  # regions are measured on the 921pt-wide preview

# file: [(x0, y0, x1, y1), ...] in preview coordinates
REGIONS = {
    "01-scores.png": [(48, 480, 118, 1080), (48, 1115, 90, 1150),
                      (48, 1190, 118, 1825), (48, 1955, 118, 2000)],
    "02-game-detail.png": [(115, 275, 215, 368), (705, 285, 805, 360),
                           (46, 995, 90, 1340), (46, 1380, 90, 1565),
                           (46, 1605, 90, 1795)],
    "03-box-score.png": [(115, 275, 215, 368), (705, 285, 805, 360)],
    "04-rankings.png": [(104, 715, 156, 1825), (104, 1955, 156, 2000)],
    "05-teams.png": [(48, 290, 135, 665)],
    "06-team-page.png": [(32, 300, 155, 385), (48, 665, 118, 795)],
    "08-nfl-sunday.png": [(48, 390, 92, 432), (48, 480, 118, 1827),
                          (48, 1955, 118, 2000)],
    "07-widget.png": [(100, 290, 150, 510)],
}

# Logos scrolled under the frosted tab bar blur into colored smudges. They
# can't be disc'd without painting over the bar, so they go gray instead.
# Full-resolution coordinates.
DESATURATE = {
    "01-scores.png": [(40, 2590, 330, 2868)],
    "04-rankings.png": [(130, 2580, 260, 2868)],
    "08-nfl-sunday.png": [(40, 2580, 220, 2868)],
}


def ink_mask(px, bg):
    return np.abs(px.astype(int) - bg).sum(axis=2) > 60


def runs(flags, gap=8):
    out, start, last = [], None, None
    for i, f in enumerate(flags):
        if f:
            if start is None:
                start = i
            last = i
        elif start is not None and i - last > gap:
            out.append((start, last))
            start = None
    if start is not None:
        out.append((start, last))
    return out


def neutralize(path, regions):
    img = Image.open(path).convert("RGB")
    arr = np.array(img)
    draw = ImageDraw.Draw(img)
    for x0, y0, x1, y1 in regions:
        x0, y0, x1, y1 = (round(v * S) for v in (x0, y0, x1, y1))
        crop = arr[y0:y1, x0:x1]
        for r0, r1 in runs(ink_mask(crop, crop[:, 0:1].astype(int)).any(axis=1)):
            rows = crop[r0:r1 + 1]
            cols = np.where(ink_mask(rows, rows[:, 0:1].astype(int)).any(axis=0))[0]
            if r1 - r0 < 6 or len(cols) == 0:
                continue  # a separator line, not a logo
            cx = x0 + (cols[0] + cols[-1]) / 2
            cy = y0 + (r0 + r1) / 2
            r = max(r1 - r0, cols[-1] - cols[0]) / 2 + 3
            # cover the whole mark, then draw the disc on top
            bg = tuple(int(v) for v in crop[r0, 0])
            draw.rectangle([x0 + cols[0] - 2, y0 + r0 - 2,
                            x0 + cols[-1] + 2, y0 + r1 + 2], fill=bg)
            draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=DISC)
    for box in DESATURATE.get(path.name, []):
        img.paste(img.crop(box).convert("L").convert("RGB"), box[:2])
    img.save(path)


if __name__ == "__main__":
    for name, regions in REGIONS.items():
        neutralize(ROOT / name, regions)
        print("neutralized", name)
