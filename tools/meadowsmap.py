"""Top-down preview of the Whispering Meadows (S26) from tools/meadowsdump.luau, without Studio.

    lune run tools/meadowsdump.luau m.json 8 builds
    python tools/meadowsmap.py m.json out.png [--overlay] [--zoom x1 z1 x2 z2] [--scale 1]

Hill-shaded terrain in the material colours of WorldBuilder, water, and (with --overlay) roads, streams, monster
areas, groups, sites, NPC spots, quest anchors, crossings and building footprints.
"""
import json
import math
import sys

import numpy as np
from PIL import Image, ImageDraw

COLORS = {
    "Grass": (92, 122, 58),
    "LeafyGrass": (52, 69, 42),
    "Ground": (122, 106, 78),
    "Mud": (63, 58, 46),
    "Rock": (90, 86, 80),
    "Slate": (74, 71, 68),
    "Sand": (194, 168, 120),
    "Pebble": (138, 132, 122),
    "Water": (58, 111, 168),
}


def main():
    args = sys.argv[1:]
    src, out = args[0], args[1]
    overlay = "--overlay" in args
    zoom = None
    if "--zoom" in args:
        i = args.index("--zoom")
        zoom = [float(v) for v in args[i + 1 : i + 5]]
    scale = 1.0
    if "--scale" in args:
        scale = float(args[args.index("--scale") + 1])
    d = json.load(open(src, encoding="utf-8"))
    half, step = d["half"], d["step"]
    h = np.array(d["heights"], dtype=float)
    n = h.shape[0]
    # hillshade (light from the north-west)
    gy, gx = np.gradient(h, step)
    lx, ly, lz = -0.6, -0.6, 0.55
    norm = np.sqrt(gx * gx + gy * gy + 1)
    shade = (-gx * lx - gy * ly + lz) / norm
    shade = np.clip(shade / 0.55 * 0.75 + 0.25, 0.25, 1.25)
    img = np.zeros((n, n, 3))
    for zi in range(n):
        for xi in range(n):
            w = d["water"][zi][xi]
            if w is not False and w is not None:
                depth = max(0.0, w - h[zi, xi])
                base = np.array(COLORS["Water"]) * (1 - min(depth, 6) / 14)
                img[zi, xi] = base
            else:
                img[zi, xi] = np.array(COLORS.get(d["materials"][zi][xi], (255, 0, 255))) * shade[zi, xi]
    # contour lines every 4 studs
    lev = np.floor(h / 4)
    edge = (lev != np.roll(lev, 1, 0)) | (lev != np.roll(lev, 1, 1))
    img[edge] *= 0.82
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
    px = 2.0 * scale
    size = int(n * px)
    im = im.resize((size, size), Image.NEAREST)
    dr = ImageDraw.Draw(im)

    def P(x, z):
        return ((x + half) / step * px, (z + half) / step * px)

    if overlay:
        for a in d["areas"]:
            r = a["rect"]
            dr.rectangle([P(r[0], r[1]), P(r[2], r[3])], outline=(255, 255, 255))
            dr.text(P(r[0] + 4, r[1] + 4), a["id"].replace("meadows_", ""), fill=(255, 255, 255))
        for road in d["roads"]:
            p = road["points"]
            dr.line([P(p[i], p[i + 1]) for i in range(0, len(p), 2)], fill=(240, 220, 160), width=1)
        for s in d["streams"]:
            p = s["points"]
            dr.line([P(p[i], p[i + 1]) for i in range(0, len(p), 2)], fill=(120, 200, 255), width=1)
        for g in d["groups"]:
            x, z = P(g[0], g[1])
            dr.ellipse([x - 3, z - 3, x + 3, z + 3], outline=(255, 60, 60))
        for c in d["avoid"]:
            x, z = P(c["x"], c["z"])
            r = c["r"] / step * px
            dr.ellipse([x - r, z - r, x + r, z + r], outline=(255, 160, 0))
        for name, s in d["sites"].items():
            x, z = P(s["x"], s["z"])
            dr.rectangle([x - 2, z - 2, x + 2, z + 2], fill=(255, 255, 0))
            dr.text((x + 4, z - 6), name, fill=(255, 255, 0))
        for name, s in d["npcSpots"].items():
            x, z = P(s["x"], s["z"])
            dr.ellipse([x - 3, z - 3, x + 3, z + 3], fill=(0, 255, 120))
            dr.text((x + 4, z + 2), "npc:" + name, fill=(0, 255, 120))
        for a in d["anchors"]:
            x, z = P(a["x"], a["z"])
            dr.rectangle([x - 1, z - 1, x + 1, z + 1], fill=(255, 0, 255))
        for c in d["crossings"]:
            x, z = P(c["x"], c["z"])
            col = {"stone": (220, 220, 220), "wood": (160, 100, 50), "ford": (80, 220, 255)}[c["kind"]]
            dr.ellipse([x - 5, z - 5, x + 5, z + 5], outline=col, width=2)
        for c in d["caves"]:
            x, z = P(c["x"], c["z"])
            dr.polygon([(x, z - 6), (x - 6, z + 5), (x + 6, z + 5)], outline=(255, 80, 80))
        for b in d.get("builds", []):
            x, z = P(b["x"], b["z"])
            dr.rectangle([x - 1, z - 1, x + 1, z + 1], outline=(255, 255, 255))
    if "--pieces" in args:
        for p in d.get("pieces", []):
            x, z = P(p[0], p[1])
            r = max(0.6, p[2] / step * px)
            c = p[3]
            col = (int(c[1:3], 16), int(c[3:5], 16), int(c[5:7], 16))
            if p[4]:
                dr.ellipse([x - r, z - r, x + r, z + r], fill=col, outline=(0, 0, 0))
            else:
                dr.ellipse([x - r, z - r, x + r, z + r], fill=col)
    if zoom:
        x1, z1 = P(zoom[0], zoom[1])
        x2, z2 = P(zoom[2], zoom[3])
        im = im.crop((int(x1), int(z1), int(x2), int(z2)))
    im.save(out)
    print(f"{out}: {im.size[0]}x{im.size[1]}, heights {h.min():.1f}..{h.max():.1f}")


if __name__ == "__main__":
    main()
