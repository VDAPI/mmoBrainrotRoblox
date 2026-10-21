"""Contact sheet from saved Roblox face PNGs: perspective views sampled through the same face convention
(checks seams of the files themselves) plus the unfolded cross."""

import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from sky import FACES, face_dirs  # noqa: E402


def load(folder):
    return {f: np.asarray(Image.open(os.path.join(folder, f + ".png")).convert("RGB"), dtype=np.float32) for f in FACES}


def lookup_tables(n):
    """For every face: its direction grid, used to invert direction -> (face, pixel) by the dominant axis."""
    return {f: face_dirs(f, n) for f in FACES}


def sample(faces, d):
    n = faces["ft"].shape[0]
    out = np.zeros(d.shape[:-1] + (3,), np.float32)
    ax = np.argmax(np.abs(d), axis=-1)
    sgn = np.take_along_axis(d, ax[..., None], -1)[..., 0] > 0
    # face per (axis, sign) in Roblox coords: X+ rt, X- lf, Y+ up, Y- dn, Z+ bk, Z- ft
    names = {(0, True): "rt", (0, False): "lf", (1, True): "up", (1, False): "dn", (2, True): "bk", (2, False): "ft"}
    for (a, s), f in names.items():
        m = (ax == a) & (sgn == s)
        if not m.any():
            continue
        dd = d[m]
        dd = dd / np.abs(dd[:, a : a + 1])
        # find pixel by fitting the face's own grid: corners of the face direction grid give the affine map
        g = face_dirs(f, 2)  # 2x2 grid at +-0.5 of the face
        g = g / np.abs(g[..., a : a + 1])
        o = (g[0, 0] + g[1, 1]) / 2
        cu = (g[0, 1] - g[0, 0]) / 1.0  # one step in columns = 1.0 in face units (cells at +-0.5)
        cv = (g[1, 0] - g[0, 0]) / 1.0
        rel = dd - o
        uu = rel @ cu / (cu @ cu)
        vv = rel @ cv / (cv @ cv)
        col = np.clip(((uu + 1) / 2) * n - 0.5, 0, n - 1)
        row = np.clip(((vv + 1) / 2) * n - 0.5, 0, n - 1)
        c0 = np.floor(col).astype(int)
        r0 = np.floor(row).astype(int)
        c1 = np.minimum(c0 + 1, n - 1)
        r1 = np.minimum(r0 + 1, n - 1)
        fc = (col - c0)[:, None]
        fr = (row - r0)[:, None]
        img = faces[f]
        top = img[r0, c0] * (1 - fc) + img[r0, c1] * fc
        bot = img[r1, c0] * (1 - fc) + img[r1, c1] * fc
        out[m] = top * (1 - fr) + bot * fr
    return out


def persp(faces, yaw, pitch, w=640, h=360, fov=80):
    t = math.tan(math.radians(fov) / 2)
    xs = (np.arange(w) + 0.5) / w * 2 - 1
    ys = 1 - (np.arange(h) + 0.5) / h * 2
    X, Y = np.meshgrid(xs * t, ys * t * h / w)
    d = np.stack([X, Y, -np.ones_like(X)], -1)
    cp, sp = math.cos(math.radians(pitch)), math.sin(math.radians(pitch))
    d = np.stack([d[..., 0], d[..., 1] * cp - d[..., 2] * sp, d[..., 1] * sp + d[..., 2] * cp], -1)
    cy, sy = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    d = np.stack([d[..., 0] * cy + d[..., 2] * sy, d[..., 1], -d[..., 0] * sy + d[..., 2] * cy], -1)
    d /= np.linalg.norm(d, axis=-1, keepdims=True)
    return Image.fromarray(np.clip(sample(faces, d), 0, 255).astype(np.uint8))


def cross(folder, s=160):
    im = Image.new("RGB", (s * 4, s * 3), (40, 40, 40))
    pos = {"up": (1, 0), "lf": (0, 1), "ft": (1, 1), "rt": (2, 1), "bk": (3, 1), "dn": (1, 2)}
    for f, (cx, cy) in pos.items():
        im.paste(Image.open(os.path.join(folder, f + ".png")).convert("RGB").resize((s, s)), (cx * s, cy * s))
    return im


if __name__ == "__main__":
    root = sys.argv[1]
    names = sys.argv[3:]
    rows = []
    for nm in names:
        faces = load(os.path.join(root, nm))
        views = [persp(faces, yaw, pitch) for yaw, pitch in ((0, 8), (90, 8), (180, 8), (270, 8), (45, 50), (0, 89))]
        rows.append((nm, views, cross(os.path.join(root, nm))))
    W = 640 * 3 + 640
    H = 360 * 2
    sheet = Image.new("RGB", (W, H * len(rows)), (20, 20, 20))
    for i, (nm, views, cr) in enumerate(rows):
        for j, v in enumerate(views):
            sheet.paste(v, ((j % 3) * 640, i * H + (j // 3) * 360))
        sheet.paste(cr.resize((640, 480)), (1920, i * H))
        ImageDraw.Draw(sheet).text((1930, i * H + 490), nm, fill=(255, 255, 255))
    sheet.save(sys.argv[2])
