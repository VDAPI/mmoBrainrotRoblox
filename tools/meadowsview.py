"""3D preview of the Whispering Meadows (S26): the export of tools/meadowsview.luau (world-space pieces and the
terrain grid) rendered with the z-buffer of docs/miasto/tools/render3d.py.
python tools/meadowsview.py view.json out.png --eye x y z --look x y z [--fov 50] [--size 1400x900]
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

# terrain grid from the export (tools/meadowsview.luau)
COL = {
    "Grass": (0.36, 0.48, 0.23), "LeafyGrass": (0.20, 0.27, 0.16), "Ground": (0.48, 0.42, 0.31),
    "Mud": (0.25, 0.23, 0.18), "Rock": (0.35, 0.34, 0.31), "Slate": (0.29, 0.28, 0.27), "Sand": (0.76, 0.66, 0.47),
    "Pebble": (0.54, 0.52, 0.48),
}
T = data["terrain"]
st = T["step"]
Hh = np.array(T["heights"], dtype=float)
nz, nx = Hh.shape
for j in range(nz - 1):
    for i in range(nx - 1):
        x0 = T["x1"] + i * st
        z0 = T["z1"] + j * st
        w = T["water"][j][i]
        if w is not False and w is not None:
            col = np.array([0.23, 0.38, 0.52])
            quad = [(x0, w, z0), (x0 + st, w, z0), (x0 + st, w, z0 + st), (x0, w, z0 + st)]
        else:
            col = np.array(COL.get(T["materials"][j][i], (1, 0, 1)))
            quad = [(x0, Hh[j, i], z0), (x0 + st, Hh[j, i + 1], z0), (x0 + st, Hh[j + 1, i + 1], z0 + st),
                    (x0, Hh[j + 1, i], z0 + st)]
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
