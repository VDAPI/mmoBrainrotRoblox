"""Tiny z-buffer renderer for TownGen previews: pieces.json (world-space Roblox-like parts) + terrain from plan.py.
python3 render3d.py pieces.json out.png --eye x y z --look x y z [--fov 50] [--size 1400x900] [--terrain x1 z1 x2 z2]
"""
import argparse, json, math
import numpy as np
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("pieces")
ap.add_argument("out")
ap.add_argument("--eye", nargs=3, type=float, default=[60, 60, 120])
ap.add_argument("--look", nargs=3, type=float, default=[20, 8, -10])
ap.add_argument("--fov", type=float, default=50)
ap.add_argument("--size", default="1400x900")
ap.add_argument("--terrain", nargs=4, type=float, default=None)
ap.add_argument("--step", type=float, default=2.0)
ap.add_argument("--detail", type=int, default=1)
ap.add_argument("--fog", type=float, default=150, help="distance where fog starts")
args = ap.parse_args()
W, H = map(int, args.size.split("x"))

MAT_TINT = {"Neon": 1.6, "Glass": 0.8}


def hexrgb(h):
    return np.array([int(h[1:3], 16), int(h[3:5], 16), int(h[5:7], 16)], dtype=float) / 255.0


def box_mesh():
    v = np.array([[x, y, z] for x in (-.5, .5) for y in (-.5, .5) for z in (-.5, .5)])
    idx = lambda x, y, z: (x > 0) * 4 + (y > 0) * 2 + (z > 0)
    quads = [
        [(0, 0, 0), (0, 1, 0), (0, 1, 1), (0, 0, 1)], [(1, 0, 0), (1, 0, 1), (1, 1, 1), (1, 1, 0)],
        [(0, 0, 0), (0, 0, 1), (1, 0, 1), (1, 0, 0)], [(0, 1, 0), (1, 1, 0), (1, 1, 1), (0, 1, 1)],
        [(0, 0, 0), (1, 0, 0), (1, 1, 0), (0, 1, 0)], [(0, 0, 1), (0, 1, 1), (1, 1, 1), (1, 0, 1)],
    ]
    tris = []
    for q in quads:
        ids = [idx(*c) for c in q]
        tris += [(ids[0], ids[1], ids[2]), (ids[0], ids[2], ids[3])]
    return v, np.array(tris)


def wedge_mesh():
    # Roblox WedgePart: full bottom, full back (+Z) face, slope from top-back to bottom-front
    v = np.array([[-.5, -.5, -.5], [.5, -.5, -.5], [-.5, -.5, .5], [.5, -.5, .5], [-.5, .5, .5], [.5, .5, .5]])
    tris = [(0, 2, 3), (0, 3, 1), (2, 4, 5), (2, 5, 3), (0, 1, 5), (0, 5, 4), (0, 4, 2), (1, 3, 5)]
    return v, np.array(tris)


def cyl_mesh(n=12):
    v = [[-.5, 0, 0], [.5, 0, 0]]
    for i in range(n):
        a = 2 * math.pi * i / n
        v.append([-.5, .5 * math.cos(a), .5 * math.sin(a)])
        v.append([.5, .5 * math.cos(a), .5 * math.sin(a)])
    tris = []
    for i in range(n):
        a0, b0 = 2 + 2 * i, 3 + 2 * i
        a1, b1 = 2 + 2 * ((i + 1) % n), 3 + 2 * ((i + 1) % n)
        tris += [(a0, a1, b1), (a0, b1, b0), (0, a1, a0), (1, b0, b1)]
    return np.array(v), np.array(tris)


def ball_mesh(n=10, m=7):
    v = []
    for j in range(m + 1):
        t = math.pi * j / m
        for i in range(n):
            a = 2 * math.pi * i / n
            v.append([.5 * math.sin(t) * math.cos(a), .5 * math.cos(t), .5 * math.sin(t) * math.sin(a)])
    tris = []
    for j in range(m):
        for i in range(n):
            a, b = j * n + i, j * n + (i + 1) % n
            c, d = (j + 1) * n + i, (j + 1) * n + (i + 1) % n
            tris += [(a, b, d), (a, d, c)]
    return np.array(v), np.array(tris)


MESH = {"box": box_mesh(), "wedge": wedge_mesh(), "cyl": cyl_mesh(), "ball": ball_mesh(), "corner": wedge_mesh()}

data = json.load(open(args.pieces))
allv, allc = [], []
for p in data["pieces"]:
    if not args.detail and p["lod"] == "detail":
        continue
    if p.get("t") and p["t"] >= 0.9:
        continue
    mv, mt = MESH[p["s"]]
    R = np.array(p["r"]).reshape(3, 3)
    loc = mv * np.array(p["size"])
    wv = loc @ R.T + np.array(p["p"])
    col = hexrgb(p["c"]) * MAT_TINT.get(p["m"], 1.0)
    for t in mt:
        allv.append(wv[list(t)])
        allc.append((col, p["m"] == "Neon"))

# terrain grid
if args.terrain:
    import sys, os
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import plan as P
    x1, z1, x2, z2 = args.terrain
    st = args.step
    xs = np.arange(x1, x2 + st, st)
    zs = np.arange(z1, z2 + st, st)
    Hh = np.array([[P.height_at(x, z) for x in xs] for z in zs])
    from shapely.geometry import Point
    streets = __import__("shapely.ops", fromlist=["unary_union"]).unary_union(
        [P.street_poly(s) for s in P.STREETS] + [__import__("shapely.geometry", fromlist=["Polygon"]).Polygon(q["poly"])
                                                 for q in P.SQUARES])
    for j in range(len(zs) - 1):
        for i in range(len(xs) - 1):
            x, z = xs[i] + st / 2, zs[j] + st / 2
            hgt = Hh[j, i]
            if hgt < P.RIVER["water"]:
                col = np.array([0.23, 0.38, 0.52])
                y = P.RIVER["water"]
                quad = [(xs[i], y, zs[j]), (xs[i + 1], y, zs[j]), (xs[i + 1], y, zs[j + 1]), (xs[i], y, zs[j + 1])]
            else:
                col = np.array([0.36, 0.45, 0.26])
                if streets.contains(Point(x, z)):
                    col = np.array([0.5, 0.47, 0.42])
                quad = [(xs[i], Hh[j, i], zs[j]), (xs[i + 1], Hh[j, i + 1], zs[j]), (xs[i + 1], Hh[j + 1, i + 1], zs[j + 1]),
                        (xs[i], Hh[j + 1, i], zs[j + 1])]
            q = np.array(quad)
            allv.append(q[[0, 1, 2]]); allc.append((col, False))
            allv.append(q[[0, 2, 3]]); allc.append((col, False))

tri = np.array(allv)  # (N,3,3)
eye = np.array(args.eye); look = np.array(args.look)
fwd = look - eye; fwd /= np.linalg.norm(fwd)
right = np.cross(fwd, [0, 1, 0]); right /= np.linalg.norm(right)
up = np.cross(right, fwd)
rel = tri - eye
cx = rel @ right; cy = rel @ up; cz = rel @ fwd
f = (H / 2) / math.tan(math.radians(args.fov / 2))
valid = (cz > 0.5).all(axis=1)
sx = W / 2 + f * cx / np.maximum(cz, 0.5)
sy = H / 2 - f * cy / np.maximum(cz, 0.5)
# lighting
n = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
nn = np.linalg.norm(n, axis=1, keepdims=True); nn[nn == 0] = 1
n = n / nn
centre = tri.mean(axis=1)
facing = ((eye - centre) * n).sum(axis=1)
n[facing < 0] *= -1
sun = np.array([-0.45, 0.8, -0.35]); sun /= np.linalg.norm(sun)
lam = np.clip(n @ sun, 0, 1)
img = np.zeros((H, W, 3)); img[:] = [0.62, 0.72, 0.82]
zb = np.full((H, W), np.inf)
for k in np.nonzero(valid)[0]:
    xs_, ys_, zs_ = sx[k], sy[k], cz[k]
    minx, maxx = int(max(0, math.floor(xs_.min()))), int(min(W - 1, math.ceil(xs_.max())))
    miny, maxy = int(max(0, math.floor(ys_.min()))), int(min(H - 1, math.ceil(ys_.max())))
    if minx > maxx or miny > maxy:
        continue
    gx, gy = np.meshgrid(np.arange(minx, maxx + 1) + 0.5, np.arange(miny, maxy + 1) + 0.5)
    x0, x1_, x2_ = xs_; y0, y1_, y2_ = ys_
    den = (y1_ - y2_) * (x0 - x2_) + (x2_ - x1_) * (y0 - y2_)
    if abs(den) < 1e-9:
        continue
    a = ((y1_ - y2_) * (gx - x2_) + (x2_ - x1_) * (gy - y2_)) / den
    b = ((y2_ - y0) * (gx - x2_) + (x0 - x2_) * (gy - y2_)) / den
    c = 1 - a - b
    inside = (a >= -1e-6) & (b >= -1e-6) & (c >= -1e-6)
    if not inside.any():
        continue
    depth = 1.0 / (a / zs_[0] + b / zs_[1] + c / zs_[2])
    sub = zb[miny:maxy + 1, minx:maxx + 1]
    m = inside & (depth < sub)
    if not m.any():
        continue
    sub[m] = depth[m]
    col, neon = allc[k]
    shade = col if neon else col * (0.45 + 0.75 * lam[k])
    fog = np.clip((depth[m] - args.fog) / (args.fog * 3.3), 0, 0.5)[:, None]
    img[miny:maxy + 1, minx:maxx + 1][m] = shade * (1 - fog) + np.array([0.62, 0.72, 0.82]) * fog
Image.fromarray((np.clip(img, 0, 1) * 255).astype(np.uint8)).save(args.out)
print("rendered", len(tri), "triangles")
