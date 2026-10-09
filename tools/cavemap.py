"""Top-down preview and vertical sections of a cave on the engine (S48) from tools/cavedump.luau.

    lune run tools/cavedump.luau meadows_cave c.json 4
    python tools/cavemap.py c.json out.png [--overlay] [--scale 2] [--section x1 z1 x2 z2]

Floor shaded by height (rock black, water blue, lava orange, sky holes pale), with --overlay rooms and their cores, spawners
with radii, ore nodes, portals, dressing footprints, life points and lights. --section draws the floor, ceiling and
liquid along a line (and a 5-stud figure for scale) under the map.
"""
import json
import sys

import numpy as np
from PIL import Image, ImageDraw

MAT = {
    "Rock": (90, 86, 80),
    "Slate": (74, 71, 68),
    "Ground": (122, 106, 78),
    "Mud": (63, 58, 46),
    "Salt": (138, 132, 122),
    "LeafyGrass": (52, 69, 42),
    "Basalt": (47, 43, 48),
    "Sandstone": (110, 47, 42),
    "Glacier": (168, 216, 240),
    "Ice": (201, 232, 247),
    "Snow": (238, 243, 247),
}


def main():
    a = sys.argv[1:]
    src, out = a[0], a[1]
    overlay = "--overlay" in a
    scale = float(a[a.index("--scale") + 1]) if "--scale" in a else 2.0
    section = [float(v) for v in a[a.index("--section") + 1 : a.index("--section") + 5]] if "--section" in a else None
    d = json.load(open(src, encoding="utf-8"))
    half, step = d["half"], d["step"]
    fl = d["floor"]
    nz, nx = len(fl), len(fl[0])
    img = np.zeros((nz, nx, 3), dtype=float)
    for k in range(nz):
        for i in range(nx):
            f = fl[k][i]
            if f is False:
                img[k, i] = (12, 12, 14)
                continue
            base = np.array(MAT.get(d["material"][k][i], (150, 150, 150)), dtype=float)
            shade = 0.75 + 0.03 * f
            # slope shading
            fx = fl[k][min(i + 1, nx - 1)]
            fz = fl[min(k + 1, nz - 1)][i]
            if fx is not False and fz is not False:
                shade += 0.08 * ((fx - f) - (fz - f))
            col = base * max(0.35, min(1.6, shade))
            if d["liquid"][k][i] is not False:
                # S50: lava (its surface is CrackedLava) orange, water blue
                lava = d["material"][k][i] == "CrackedLava"
                col = np.array((235, 95, 30) if lava else (50, 100, 150), dtype=float)
            if d["ceiling"][k][i] is not False and d["ceiling"][k][i] > 900:
                col = col * 0.6 + np.array((200, 210, 230)) * 0.4
            img[k, i] = col
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8)).resize(
        (int(nx * scale), int(nz * scale)), Image.NEAREST
    )
    dr = ImageDraw.Draw(im)
    px = lambda x: (x + half) / step * scale
    if overlay:
        for r in d["rooms"]:
            cx, cz = px(r["x"]), px(r["z"])
            rr = r["r"] / step * scale
            dr.ellipse([cx - rr, cz - rr, cx + rr, cz + rr], outline=(200, 200, 90))
            if r["core"] > 0:
                c = r["core"] / step * scale
                dr.ellipse([cx - c, cz - c, cx + c, cz + c], outline=(90, 200, 90))
            dr.text((cx - 10, cz - 6), f'{r["i"]} {r["role"]}', fill=(255, 255, 255))
        for b in d["builds"]:
            cx, cz = px(b["x"]), px(b["z"])
            rr = max(2, b["r"] / step * scale)
            dr.ellipse([cx - rr, cz - rr, cx + rr, cz + rr], outline=(180, 120, 255))
        for s in d["spawners"]:
            cx, cz = px(s["x"]), px(s["z"])
            rr = s["r"] / step * scale
            color = (255, 60, 60) if s["v"] == "normal" else (255, 160, 0) if s["v"] == "elite" else (255, 0, 255)
            dr.ellipse([cx - rr, cz - rr, cx + rr, cz + rr], outline=color, width=2)
        for n in d["nodes"]:
            cx, cz = px(n["x"]), px(n["z"])
            dr.rectangle([cx - 3, cz - 3, cx + 3, cz + 3], fill=(230, 200, 60))
        for l in d["lights"]:
            cx, cz = px(l["x"]), px(l["z"])
            dr.ellipse([cx - 2, cz - 2, cx + 2, cz + 2], fill=(255, 240, 160))
        for l in d["life"]:
            cx, cz = px(l["x"]), px(l["z"])
            dr.point([cx, cz], fill=(120, 255, 255))
        for p in d["portals"]:
            cx, cz = px(p["x"]), px(p["z"])
            dr.rectangle([cx - 4, cz - 4, cx + 4, cz + 4], outline=(80, 200, 255), width=2)
    if section:
        x1, z1, x2, z2 = section
        dr.line([px(x1), px(z1), px(x2), px(z2)], fill=(255, 255, 255), width=1)
        H = 240
        W = im.width
        sec = Image.new("RGB", (W, H), (12, 12, 14))
        sd = ImageDraw.Draw(sec)
        n = 400
        ys = lambda y: H - 30 - (y + 24) * 3
        for j in range(n):
            t = j / (n - 1)
            x, z = x1 + (x2 - x1) * t, z1 + (z2 - z1) * t
            i, k = int((x + half) / step), int((z + half) / step)
            if 0 <= i < nx and 0 <= k < nz and fl[k][i] is not False:
                f, c = fl[k][i], min(d["ceiling"][k][i], 60)
                xx = t * W
                sd.line([xx, ys(f), xx, ys(c)], fill=(60, 60, 70))
                sd.point([xx, ys(f)], fill=(220, 200, 150))
                sd.point([xx, ys(c)], fill=(160, 160, 180))
                if d["liquid"][k][i] is not False:
                    sd.point([xx, ys(d["liquid"][k][i])], fill=(80, 140, 220))
        sd.line([10, ys(0), 10, ys(5)], fill=(255, 80, 80), width=3)
        both = Image.new("RGB", (W, im.height + H))
        both.paste(im, (0, 0))
        both.paste(sec, (0, im.height))
        im = both
    im.save(out)
    print(f"{out}: {im.width}x{im.height}")


if __name__ == "__main__":
    main()
