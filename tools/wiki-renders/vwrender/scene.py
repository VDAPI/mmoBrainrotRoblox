"""One look -> premultiplied float image: shadow, opaque pass, transparent pass (far to near), Neon glow."""
import numpy as np

from . import frame, post, shade
from .mesh import place
from .raster import rasterize

SKIP_T = 0.9
HOVER_GAP = 0.8  # studs at scale 1 between a flier and its shadow


def mix_hex(a, b, t):
    """Color3:Lerp on hex colours (LookBuild.tint)."""
    ca, cb = shade.hex_rgb(a), shade.hex_rgb(b)
    c = np.round((ca + (cb - ca) * t) * 255).astype(int)
    return "#%02X%02X%02X" % tuple(c)


def tinted(pieces, phase):
    """Pieces coloured like LookBuild.tint for a boss phase: Neon -> glow, others towards tint by amount."""
    out = []
    for p in pieces:
        q = dict(p)
        if p["m"] == "Neon" and phase.get("glow"):
            q["c"] = phase["glow"]
        elif p["m"] != "Neon":
            q["c"] = mix_hex(p["c"], phase["tint"], phase["amount"])
        out.append(q)
    return out


def rim_color(entry):
    if entry["kind"] == "boss":
        return entry.get("aura") or "#D64A3E"
    return shade.RANK_RIM.get(entry["variant"], shade.RANK_RIM["normal"])


def _gather(pieces, warn):
    """Visible pieces as triangle arrays: world corners, corner normals, piece index per triangle."""
    tri_v, tri_n, tri_p, info = [], [], [], []
    for p in pieces:
        material = shade.material_of(p["m"], warn)
        t = p.get("t") or 0.0
        if material == "Glass" and t == 0:
            t = shade.GLASS_TRANSPARENCY
        if t >= SKIP_T:
            continue
        wv, wn, tris = place(p)
        idx = len(info)
        info.append({"color": p["c"], "material": material, "t": t})
        tri_v.append(wv[tris])
        tri_n.append(wn[tris])
        tri_p.append(np.full(len(tris), idx))
    return np.concatenate(tri_v), np.concatenate(tri_n), np.concatenate(tri_p), info


def render(entry, size, override=None, pieces=None, warn=None):
    """Premultiplied RGBA float image (size, size, 4) of a dumped look."""
    tri_v, tri_n, tri_p, info = _gather(pieces if pieces is not None else entry["pieces"], warn)
    if entry.get("hovers"):
        # fliers float HOVER studs up in the game; the render keeps a smaller gap so the figure stays big
        lift = float(tri_v[..., 1].min()) - HOVER_GAP * entry.get("scale", 1.0)
        if lift > 0:
            tri_v = tri_v - np.array([0.0, lift, 0.0])
    points = tri_v.reshape(-1, 3)
    centre, radii = frame.shadow_ellipse(points)
    # fliers: frame the body and the shadow centre only (a wide shadow far below would shrink them)
    ground = (np.array([[centre[0], 0.0, centre[1]]]) if entry.get("hovers")
              else frame.ellipse_points(centre, radii))
    cam = frame.fit(np.concatenate([points, ground]), size, override)

    albedo = shade.to_linear(np.array([shade.hex_rgb(i["color"]) for i in info]))
    neon = np.array([i["material"] == "Neon" for i in info])
    spec = np.array([shade.MATERIALS[i["material"]][0] for i in info])
    shininess = np.array([shade.MATERIALS[i["material"]][1] for i in info], float)
    trans = np.array([i["t"] for i in info])
    rim = rim_color(entry)

    flat = tri_v.reshape(-1, 3)
    sx, sy, sz = cam.project(flat)
    sx, sy, sz = sx.reshape(-1, 3), sy.reshape(-1, 3), sz.reshape(-1, 3)

    img = np.zeros((size, size, 4))
    img[..., 3] = post.shadow(cam, centre, radii, entry.get("hovers", False))

    def colours(normal, ids):
        lin = shade.shade(normal, albedo[ids], neon[ids], spec[ids], shininess[ids], cam, rim)
        return shade.to_srgb(lin)

    # opaque pass
    opaque = trans[tri_p] == 0
    oz, on, oi = rasterize(sx[opaque], sy[opaque], sz[opaque], tri_n[opaque], tri_p[opaque], (0, 0, size, size))
    hit = oi >= 0
    img[hit, :3] = colours(on[hit], oi[hit])
    img[hit, 3] = 1.0
    neon_mask = np.zeros((size, size))
    neon_rgb = np.zeros((size, size, 3))
    nm = hit & neon[np.maximum(oi, 0)]
    neon_mask[nm] = 1.0
    neon_rgb[nm] = img[nm, :3]

    # transparent pass: pieces far to near, each blended over (src * (1 - t) + dst * t)
    order = []
    for idx in np.unique(tri_p[~opaque]):
        sel = tri_p == idx
        order.append((-float(sz[sel].mean()), idx, sel))
    order.sort(key=lambda o: (o[0], o[1]))
    for _, idx, sel in order:
        x0 = int(max(0, np.floor(sx[sel].min())))
        x1 = int(min(size - 1, np.ceil(sx[sel].max())))
        y0 = int(max(0, np.floor(sy[sel].min())))
        y1 = int(min(size - 1, np.ceil(sy[sel].max())))
        if x0 > x1 or y0 > y1:
            continue
        win = (x0, y0, x1 - x0 + 1, y1 - y0 + 1)
        _, tn, ti = rasterize(sx[sel], sy[sel], sz[sel], tri_n[sel], tri_p[sel], win, oz[y0:y1 + 1, x0:x1 + 1])
        h = ti >= 0
        if not h.any():
            continue
        a = 1.0 - trans[idx]
        region = img[y0:y1 + 1, x0:x1 + 1]
        region[h, :3] = colours(tn[h], ti[h]) * a + region[h, :3] * (1 - a)
        region[h, 3] = a + region[h, 3] * (1 - a)
        if neon[idx]:
            neon_mask[y0:y1 + 1, x0:x1 + 1][h] = np.maximum(neon_mask[y0:y1 + 1, x0:x1 + 1][h], a)
            neon_rgb[y0:y1 + 1, x0:x1 + 1][h] = region[h, :3] / np.maximum(region[h, 3:4], 1e-6)

    return post.glow(img, neon_rgb, neon_mask)
