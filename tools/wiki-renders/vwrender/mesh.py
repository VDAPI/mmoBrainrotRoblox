"""Unit meshes of the Roblox part shapes and their placement in the world.

Each mesh is (vertices (n, 3), normals (n, 3), triangles (m, 3)) in a unit box -0.5..0.5. Balls and cylinder
sides have smooth normals, flat faces duplicate their vertices. Shapes follow Roblox: "cyl" lies on the X axis,
"wedge" has a full bottom and back (+Z) face with the slope falling to the front (-Z). "corner" (CornerWedgePart)
is drawn as a wedge (approximation, see docs/WIKI.md).
"""
import math

import numpy as np


def _flat(quads_or_tris):
    """Faces as lists of corner points (3 or 4, counter-clockwise from outside) -> flat-shaded mesh."""
    verts, norms, tris = [], [], []
    for face in quads_or_tris:
        pts = np.array(face, dtype=float)
        n = np.cross(pts[1] - pts[0], pts[2] - pts[0])
        n = n / np.linalg.norm(n)
        base = len(verts)
        for p in pts:
            verts.append(p)
            norms.append(n)
        for k in range(1, len(pts) - 1):
            tris.append((base, base + k, base + k + 1))
    return np.array(verts), np.array(norms), np.array(tris)


def box_mesh():
    h = 0.5
    faces = [
        [(h, -h, -h), (h, h, -h), (h, h, h), (h, -h, h)],  # +X
        [(-h, -h, h), (-h, h, h), (-h, h, -h), (-h, -h, -h)],  # -X
        [(-h, h, -h), (-h, h, h), (h, h, h), (h, h, -h)],  # +Y
        [(-h, -h, h), (-h, -h, -h), (h, -h, -h), (h, -h, h)],  # -Y
        [(h, -h, h), (h, h, h), (-h, h, h), (-h, -h, h)],  # +Z
        [(-h, -h, -h), (-h, h, -h), (h, h, -h), (h, -h, -h)],  # -Z
    ]
    return _flat(faces)


def wedge_mesh():
    h = 0.5
    faces = [
        [(-h, -h, h), (-h, -h, -h), (h, -h, -h), (h, -h, h)],  # bottom
        [(h, -h, h), (h, h, h), (-h, h, h), (-h, -h, h)],  # back
        [(-h, -h, -h), (-h, h, h), (h, h, h), (h, -h, -h)],  # slope
        [(h, -h, -h), (h, h, h), (h, -h, h)],  # +X side
        [(-h, -h, h), (-h, h, h), (-h, -h, -h)],  # -X side
    ]
    return _flat(faces)


def cyl_mesh(n=20):
    verts, norms, tris = [], [], []
    ring = [(math.cos(2 * math.pi * i / n), math.sin(2 * math.pi * i / n)) for i in range(n)]
    for c, s in ring:  # side: two rings with radial normals
        verts += [(-0.5, 0.5 * c, 0.5 * s), (0.5, 0.5 * c, 0.5 * s)]
        norms += [(0, c, s), (0, c, s)]
    for i in range(n):
        a0, b0 = 2 * i, 2 * i + 1
        a1, b1 = 2 * ((i + 1) % n), 2 * ((i + 1) % n) + 1
        tris += [(a0, b1, a1), (a0, b0, b1)]
    for x, sign in ((-0.5, -1), (0.5, 1)):  # caps
        centre = len(verts)
        verts.append((x, 0, 0))
        norms.append((sign, 0, 0))
        for c, s in ring:
            verts.append((x, 0.5 * c, 0.5 * s))
            norms.append((sign, 0, 0))
        for i in range(n):
            a, b = centre + 1 + i, centre + 1 + (i + 1) % n
            tris.append((centre, b, a) if sign > 0 else (centre, a, b))
    return np.array(verts, float), np.array(norms, float), np.array(tris)


def ball_mesh(n=24, m=16):
    verts, norms, tris = [], [], []
    for j in range(m + 1):
        t = math.pi * j / m
        for i in range(n):
            a = 2 * math.pi * i / n
            d = (math.sin(t) * math.cos(a), math.cos(t), math.sin(t) * math.sin(a))
            verts.append(tuple(0.5 * c for c in d))
            norms.append(d)
    for j in range(m):
        for i in range(n):
            a, b = j * n + i, j * n + (i + 1) % n
            c, d = (j + 1) * n + i, (j + 1) * n + (i + 1) % n
            if j > 0:
                tris.append((a, b, d))
            if j < m - 1:
                tris.append((a, d, c))
    return np.array(verts, float), np.array(norms, float), np.array(tris)


MESHES = {"box": box_mesh(), "wedge": wedge_mesh(), "corner": wedge_mesh(), "cyl": cyl_mesh(), "ball": ball_mesh()}


def place(piece):
    """World vertices, world normals and triangles of one dumped piece (`s`, `size`, `p`, `r`)."""
    verts, norms, tris = MESHES[piece["s"]]
    size = np.array(piece["size"], float)
    rot = np.array(piece["r"], float).reshape(3, 3)
    wv = (verts * size) @ rot.T + np.array(piece["p"], float)
    # normals of a scaled shape: inverse transpose of the scale
    safe = np.where(np.abs(size) < 1e-6, 1e-6, size)
    wn = (norms / safe) @ rot.T
    wn /= np.maximum(np.linalg.norm(wn, axis=1, keepdims=True), 1e-12)
    return wv, wn, tris
