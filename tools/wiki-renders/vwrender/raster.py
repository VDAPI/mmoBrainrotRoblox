"""Z-buffer rasteriser (after docs/miasto/tools/render3d.py) with per-pixel interpolated normals.

`rasterize` writes, for a window of the image, the nearest triangle id, its depth and the interpolated normal.
`limit` (optional depth per pixel of the window) rejects fragments behind it (transparent pass over opaques).
"""
import math

import numpy as np


def rasterize(sx, sy, sz, normals, ids, window, limit=None):
    """sx, sy, sz: (m, 3) screen coords and view depth of triangle corners; normals (m, 3, 3); ids (m,) values
    stored in the id buffer; window (x0, y0, w, h). Returns depth (h, w), normal (h, w, 3), id (h, w; -1 empty)."""
    x0, y0, w, h = window
    zbuf = np.full((h, w), np.inf)
    nbuf = np.zeros((h, w, 3))
    ibuf = np.full((h, w), -1, dtype=np.int32)
    for k in range(len(sx)):
        xs, ys, zs = sx[k], sy[k], sz[k]
        minx = max(x0, math.floor(xs.min()))
        maxx = min(x0 + w - 1, math.ceil(xs.max()))
        miny = max(y0, math.floor(ys.min()))
        maxy = min(y0 + h - 1, math.ceil(ys.max()))
        if minx > maxx or miny > maxy:
            continue
        x0_, x1_, x2_ = xs
        y0_, y1_, y2_ = ys
        den = (y1_ - y2_) * (x0_ - x2_) + (x2_ - x1_) * (y0_ - y2_)
        if abs(den) < 1e-12:
            continue
        gx = np.arange(minx, maxx + 1) + 0.5
        gy = (np.arange(miny, maxy + 1) + 0.5)[:, None]
        a = ((y1_ - y2_) * (gx - x2_) + (x2_ - x1_) * (gy - y2_)) / den
        b = ((y2_ - y0_) * (gx - x2_) + (x0_ - x2_) * (gy - y2_)) / den
        c = 1 - a - b
        inside = (a >= -1e-7) & (b >= -1e-7) & (c >= -1e-7)
        if not inside.any():
            continue
        depth = 1.0 / (a / zs[0] + b / zs[1] + c / zs[2])
        ry, rx = slice(miny - y0, maxy + 1 - y0), slice(minx - x0, maxx + 1 - x0)
        sub = zbuf[ry, rx]
        m = inside & (depth < sub)
        if limit is not None:
            m &= depth < limit[ry, rx]
        if not m.any():
            continue
        sub[m] = depth[m]
        nk = normals[k]
        n = a[..., None] * nk[0] + b[..., None] * nk[1] + c[..., None] * nk[2]
        nbuf[ry, rx][m] = n[m]
        ibuf[ry, rx][m] = ids[k]
    length = np.linalg.norm(nbuf, axis=2, keepdims=True)
    nbuf = nbuf / np.where(length < 1e-12, 1, length)
    return zbuf, nbuf, ibuf
