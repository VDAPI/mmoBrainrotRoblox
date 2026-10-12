# Weapon models from the owner's Graphics folder (S52): copies every .glb into assets/Weapons/<item id>.glb (gitignored,
# local only) turned into the Grip frame the game expects (docs/GRAFIKA.md 3.3): +Y = tip / head / front of a crossbow
# / top edge of an off-hand, +X = cutting edge, axe head, back of a bow (towards the target), top of a crossbow, face
# of a shield, clasp of a tome, front of an orb / relic; centred on X and Z, bottom at Y = 0. Only the vertices are
# turned (positions, normals), textures stay as they are. Prints triangle counts, a suggested grip height and the
# handle offset `hold` (WeaponLooks.Asset) per model and draws previews into build/weapons/<type>.png (grip height =
# red line, palm = green ring). Needs Python 3 + numpy + Pillow.
#   py -3 tools/weapons/prepare_glb.py [--src D:/Users/vdapi/Downloads/Graphics] [--dry-run] [--only sword1h]
import argparse
import json
import os
import re
import struct
import sys

import numpy as np

DEFAULT_SRC = "D:/Users/vdapi/Downloads/Graphics"
MAX_TRIS = 20000  # Roblox limit per MeshPart
COMP = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}

# How a type is turned (see the header): "long" / "axe" = longest axis up (the axes' heads were already on +X in the
# owner's files, checked on previews); "bow"; "crossbow"; "flat" = stands as modelled, face (+Z in the file) turned to
# +X; "tome" = stands as modelled; "quiver" = longest axis up.
KIND = {
    "sword1h": "long", "saber1h": "long", "sword2h": "long", "spear2h": "long", "axe1h": "axe", "axe2h": "axe",
    "mace1h": "long", "flail1h": "long", "scepter": "long", "wand": "long", "hammer2h": "long", "staff": "long",
    "runestaff": "long", "holystaff": "long", "shortbow": "bow", "bow": "bow", "longbow": "bow",
    "crossbow": "crossbow", "heavycrossbow": "crossbow", "shield": "flat", "orb": "flat", "relic": "flat",
    "tome": "tome", "quiver": "quiver",
}
# Extra turn about +Y (degrees) for single models whose face or edge the rules above get wrong (checked on previews).
YAW = {
    # Tripo drew the prod of these two in the plane of the stock: turn it to lie across, like the other crossbows.
    "heavycrossbow_5": 90,
    "heavycrossbow_10": 90,
}


# ------------------------------------------------------------------------------------------------ glb io

def load(path):
    data = open(path, "rb").read()
    magic, _, length = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF":
        raise ValueError(f"{path}: not a .glb")
    off, js, binc = 12, None, b""
    while off < length:
        clen, ctype = struct.unpack_from("<II", data, off)
        chunk = data[off + 8: off + 8 + clen]
        if ctype == 0x4E4F534A:
            js = json.loads(chunk)
        elif ctype == 0x004E4942:
            binc = bytearray(chunk)
        off += 8 + clen
    return js, binc


def save(path, js, binc):
    j = json.dumps(js, separators=(",", ":")).encode("utf-8")
    j += b" " * ((4 - len(j) % 4) % 4)
    b = bytes(binc) + b"\0" * ((4 - len(binc) % 4) % 4)
    total = 12 + 8 + len(j) + 8 + len(b)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<II", len(j), 0x4E4F534A) + j)
        f.write(struct.pack("<II", len(b), 0x004E4942) + b)


def _view(js, i):
    a = js["accessors"][i]
    bv = js["bufferViews"][a["bufferView"]]
    dt = np.dtype(COMP[a["componentType"]])
    n = NCOMP[a["type"]]
    stride = bv.get("byteStride") or dt.itemsize * n
    return a, bv.get("byteOffset", 0) + a.get("byteOffset", 0), stride, dt, n


def read(js, binc, i):
    a, start, stride, dt, n = _view(js, i)
    raw = np.frombuffer(bytes(binc), dtype=np.uint8, count=stride * (a["count"] - 1) + dt.itemsize * n, offset=start)
    rows = np.lib.stride_tricks.as_strided(raw, shape=(a["count"], dt.itemsize * n), strides=(stride, 1))
    return rows.copy().view(dt).reshape(a["count"], n).astype(np.float64)


def write(js, binc, i, values):
    a, start, stride, dt, n = _view(js, i)
    vals = values.astype(dt)
    for k in range(a["count"]):
        o = start + k * stride
        binc[o:o + dt.itemsize * n] = vals[k].tobytes()


def node_matrix(n):
    if "matrix" in n:
        return np.array(n["matrix"], dtype=np.float64).reshape(4, 4).T
    x, y, z, w = n.get("rotation", [0, 0, 0, 1])
    r = np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
        [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
        [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
    ])
    m = np.eye(4)
    m[:3, :3] = r * np.array(n.get("scale", [1, 1, 1]))
    m[:3, 3] = n.get("translation", [0, 0, 0])
    return m


def mesh_nodes(js):
    """[(node index, world matrix)] of nodes with a mesh."""
    out = []

    def walk(ni, parent):
        n = js["nodes"][ni]
        m = parent @ node_matrix(n)
        if "mesh" in n:
            out.append((ni, m))
        for c in n.get("children", []):
            walk(c, m)

    for ni in js["scenes"][js.get("scene", 0)]["nodes"]:
        walk(ni, np.eye(4))
    return out


def geometry(js, binc):
    """World-space vertices of every primitive and the triangle count."""
    pts, tris = [], 0
    for ni, m in mesh_nodes(js):
        for p in js["meshes"][js["nodes"][ni]["mesh"]]["primitives"]:
            pos = read(js, binc, p["attributes"]["POSITION"])
            pts.append(pos @ m[:3, :3].T + m[:3, 3])
            cnt = js["accessors"][p["indices"]]["count"] if "indices" in p else len(pos)
            tris += cnt // 3
    return np.concatenate(pts), tris


# ------------------------------------------------------------------------------------------------ orientation

def _unit(v):
    return v / (np.linalg.norm(v) + 1e-12)


def _pca(p):
    c = p - p.mean(0)
    w, v = np.linalg.eigh(c.T @ c)
    return [v[:, i] for i in np.argsort(w)[::-1]]


def _frame(y, x):
    """Rotation matrix whose rows map the file axes to the Grip frame: canonical = R @ file."""
    y = _unit(y)
    x = _unit(x - np.dot(x, y) * y)
    z = np.cross(x, y)
    return np.array([x, y, z])


def _yaw(deg):
    a = np.radians(deg)
    return np.array([[np.cos(a), 0, np.sin(a)], [0, 1, 0], [-np.sin(a), 0, np.cos(a)]])


def orientation(kind, p):
    """Rotation (3x3, canonical = R @ file) for a model of the given kind."""
    up = np.array([0.0, 1.0, 0.0])
    if kind in ("flat", "tome", "quiver"):
        r = np.eye(3)
        if kind == "quiver":
            a = _pca(p)[0]
            r = _frame(a if a[1] > 0 else -a, np.array([1.0, 0, 0]))
        return _yaw(90) @ r if kind == "flat" else r  # flat: face +Z -> +X
    if kind == "crossbow":
        a1, a2, a3 = _pca(p)
        t = (p - p.mean(0)) @ a1
        spread = lambda sel: np.ptp((p[sel] - p.mean(0)) @ a2) if sel.sum() > 3 else 0
        lo, hi = t < np.percentile(t, 25), t > np.percentile(t, 75)
        if abs(np.dot(a1, up)) > 0.7:  # modelled standing up (as the sketch): front = up, the file's X = top side
            return _frame(up, np.array([1.0, 0, 0]))
        front = a1 if spread(hi) >= spread(lo) else -a1  # the prod (wide) end is the front
        top = a3 if np.dot(a3, up) >= 0 else -a3
        return _frame(front, top)
    a = _pca(p)[0]
    y = a if np.dot(a, up) >= 0 else -a
    if np.degrees(np.arccos(min(1.0, abs(np.dot(y, up))))) < 4:
        y = up
    x0 = np.array([1.0, 0, 0])
    r = _frame(y, x0)
    q = (p - p.mean(0)) @ r.T
    h = q[:, 1]
    if kind == "bow":  # bow plane = widest direction across the length; the riser bulges to the back (+X)
        xz = q[:, [0, 2]]
        _, v = np.linalg.eigh(xz.T @ xz)
        d = v[:, 1]
        ang = np.degrees(np.arctan2(d[1], d[0]))
        r = _yaw(ang) @ r
        q = (p - p.mean(0)) @ r.T
        h = q[:, 1]
        mid = np.abs(h - np.median(h)) < 0.08 * np.ptp(h)
        ends = (h < np.percentile(h, 6)) | (h > np.percentile(h, 94))
        riser = (q[mid, 0].min() + q[mid, 0].max()) / 2
        if riser < np.mean(q[ends, 0]):
            r = _yaw(180) @ r
    return r


def grip_of(kind, item_type, q):
    """Suggested grip height (fraction of the length from the bottom) of a model already in the Grip frame."""
    defaults = {
        "sword1h": 0.12, "saber1h": 0.12, "sword2h": 0.12, "axe1h": 0.15, "axe2h": 0.18, "mace1h": 0.15,
        "flail1h": 0.12, "scepter": 0.18, "wand": 0.2, "hammer2h": 0.15, "spear2h": 0.3, "staff": 0.35,
        "runestaff": 0.35, "holystaff": 0.35, "crossbow": 0.3, "heavycrossbow": 0.3,
    }
    g = defaults.get(item_type, 0.5)
    if item_type in ("sword1h", "saber1h", "sword2h"):
        # The handle is the narrowest run between the pommel and the guard (the widest slice of the lower 45%).
        h = q[:, 1] / max(1e-6, q[:, 1].max())
        r = np.abs(q[:, 0])
        bins = 60
        prof = np.array([r[(h >= i / bins) & (h < (i + 1) / bins)].max() if ((h >= i / bins) & (h < (i + 1) / bins)).any()
                         else 0 for i in range(bins)])
        low = int(bins * 0.45)
        guard = int(np.argmax(prof[:low]))
        if guard > 2:
            handle = prof[1:guard]
            narrow = np.where(handle <= np.min(handle) * 1.6 + 1e-3)[0] + 1
            if len(narrow):
                g = round(min(0.25, max(0.1, float((narrow.min() + narrow.max() + 1) / 2 / bins))), 2)
    return g


HELD_IN_HAND = {"long", "axe", "bow", "crossbow"}  # off-hands sit on their mount centre (`at`), no hold


def hold_of(kind, q, tri, g):
    """Handle centre at the grip height as (x, z) fractions of the length from the box centre line, or None.
    A Roblox MeshPart is centred on its bounds, so the game moves the mesh by this to put the palm on the handle:
    the cross-section of the grip plane is split into pieces (a bow's riser and string, a crossbow's stock) and the
    widest piece is the handle (a string is thin)."""
    if kind not in HELD_IN_HAND:
        return None
    length = max(1e-6, q[:, 1].max())
    y0 = g * length
    v = q[tri]
    pts = []
    for a, b in ((0, 1), (1, 2), (2, 0)):
        pa, pb = v[:, a], v[:, b]
        cross = (pa[:, 1] - y0) * (pb[:, 1] - y0) < 0
        t = (y0 - pa[cross, 1]) / (pb[cross, 1] - pa[cross, 1])
        pts.append(pa[cross][:, [0, 2]] + (pb[cross][:, [0, 2]] - pa[cross][:, [0, 2]]) * t[:, None])
    pts = np.concatenate(pts) if pts else np.zeros((0, 2))
    if len(pts) < 3:
        return None
    # Pieces: points closer than 3% of the length are joined (union-find).
    parent = list(range(len(pts)))

    def root(i):
        while parent[i] != i:
            parent[i] = parent[parent[i]]
            i = parent[i]
        return i

    near = np.linalg.norm(pts[:, None, :] - pts[None, :, :], axis=2) < 0.03 * length
    for i, j in zip(*np.nonzero(np.triu(near, 1))):
        parent[root(i)] = root(j)
    groups = {}
    for i in range(len(pts)):
        groups.setdefault(root(i), []).append(i)
    piece = pts[max(groups.values(), key=lambda g: float(np.linalg.norm(np.ptp(pts[g], axis=0))))]
    centre = (piece.min(0) + piece.max(0)) / 2 / length
    return round(float(centre[0]), 2), round(float(centre[1]), 2)


# ------------------------------------------------------------------------------------------------ apply

def turned(js, binc, rot):
    """New (js, binc) with every vertex in the Grip frame: X and Z centred, bottom at Y = 0, nodes without transforms."""
    js = json.loads(json.dumps(js))
    binc = bytearray(binc)
    pts = []
    done = set()
    for ni, m in mesh_nodes(js):
        for p in js["meshes"][js["nodes"][ni]["mesh"]]["primitives"]:
            pos = read(js, binc, p["attributes"]["POSITION"])
            pts.append((pos @ m[:3, :3].T + m[:3, 3]) @ rot.T)
    allp = np.concatenate(pts)
    lo, hi = allp.min(0), allp.max(0)
    shift = -np.array([(lo[0] + hi[0]) / 2, lo[1], (lo[2] + hi[2]) / 2])
    for ni, m in mesh_nodes(js):
        lin = rot @ m[:3, :3]
        nrm_m = np.linalg.inv(lin).T
        for p in js["meshes"][js["nodes"][ni]["mesh"]]["primitives"]:
            ai = p["attributes"]["POSITION"]
            if ai not in done:
                pos = read(js, binc, ai)
                new = pos @ lin.T + (rot @ m[:3, 3]) + shift
                write(js, binc, ai, new)
                js["accessors"][ai]["min"] = [float(v) for v in new.min(0).astype(np.float32)]
                js["accessors"][ai]["max"] = [float(v) for v in new.max(0).astype(np.float32)]
                done.add(ai)
            for name in ("NORMAL", "TANGENT"):
                ai = p["attributes"].get(name)
                if ai is None or ai in done:
                    continue
                v = read(js, binc, ai)
                xyz = v[:, :3] @ nrm_m.T if name == "NORMAL" else v[:, :3] @ lin.T
                xyz /= np.linalg.norm(xyz, axis=1, keepdims=True) + 1e-12
                v[:, :3] = xyz
                write(js, binc, ai, v)
                done.add(ai)
    for n in js["nodes"]:
        for k in ("matrix", "translation", "rotation", "scale"):
            n.pop(k, None)
    return js, binc


def preview(models, path):
    """Front (X right, Y up) and side (Z right, Y up) views of models in the Grip frame, red line = grip."""
    from PIL import Image, ImageDraw
    S = 200
    rows = []
    for name, q, tri, g, hold in models:
        row = Image.new("RGB", (2 * S + 10, S + 16), (28, 30, 38))
        d = ImageDraw.Draw(row)
        d.text((4, 2), f"{name}  grip {g}" + (f"  hold {hold[0]}, {hold[1]}" if hold else ""), fill=(255, 255, 255))
        lo, hi = q.min(0), q.max(0)
        sc = (S - 24) / max(hi - lo)
        for k, (ax, depth) in enumerate(((0, 2), (2, 0))):
            ox = k * (S + 10)
            v = q[tri]
            nrm = np.cross(v[:, 1] - v[:, 0], v[:, 2] - v[:, 0])
            nrm /= np.linalg.norm(nrm, axis=1, keepdims=True) + 1e-12
            shade = np.abs(nrm @ _unit(np.array([0.4, 0.8, 0.45])))
            order = np.argsort(v[:, :, depth].mean(1))
            cx = (lo[ax] + hi[ax]) / 2
            for i in order:
                pts = [(ox + S / 2 + (pp[ax] - cx) * sc, 16 + S - 12 - (pp[1] - lo[1]) * sc) for pp in v[i]]
                gcol = int(60 + 180 * shade[i])
                d.polygon(pts, fill=(gcol, gcol, int(gcol * 0.9)))
            gy = 16 + S - 12 - g * (hi[1] - lo[1]) * sc
            d.line((ox, gy, ox + S, gy), fill=(230, 60, 50), width=1)
            if hold:  # the palm (handle centre) on the grip line
                hx = ox + S / 2 + (hold[k] * (hi[1] - lo[1]) - cx) * sc
                d.ellipse((hx - 3, gy - 3, hx + 3, gy + 3), outline=(60, 220, 90), width=2)
            d.text((ox + 4, 18), "X>" if k == 0 else "Z>", fill=(255, 200, 0))
        rows.append(row)
    if not rows:
        return
    sheet = Image.new("RGB", (rows[0].width * 3, ((len(rows) + 2) // 3) * rows[0].height), (0, 0, 0))
    for i, r in enumerate(rows):
        sheet.paste(r, ((i % 3) * r.width, (i // 3) * r.height))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    sheet.save(path)


def sources(src):
    """[(item id, item type, path)] of the models in the Graphics folder."""
    out = []
    base = os.path.join(src, "modele_3d", "bronie")
    for kind in sorted(os.listdir(base)):
        mdir = os.path.join(base, kind, "model")
        if not os.path.isdir(mdir):
            continue
        for name in sorted(os.listdir(mdir), key=lambda n: [int(t) if t.isdigit() else t for t in re.split(r"(\d+)", n)]):
            if name.endswith(".glb"):
                item = name[:-4]
                item_type = "axe1h" if kind == "unique_grimrok_cleaver" else kind
                out.append((item, item_type, os.path.join(mdir, name)))
    return out


def main():
    ap = argparse.ArgumentParser(description="Kopiuje modele broni (.glb) do assets/Weapons w osiach Gripa (S52).")
    ap.add_argument("--src", default=DEFAULT_SRC)
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--only", help="tylko ten typ (np. sword1h)")
    a = ap.parse_args()
    root = os.getcwd()
    out_dir = os.path.join(root, "assets", "Weapons")
    if not os.path.isdir(out_dir):
        sys.exit("Uruchom z katalogu repozytorium.")
    by_type = {}
    bad = []
    for item, item_type, path in sources(a.src):
        if a.only and item_type != a.only:
            continue
        js, binc = load(path)
        pts, tris = geometry(js, binc)
        rot = _yaw(YAW.get(item, 0)) @ orientation(KIND[item_type], pts)
        js2, binc2 = turned(js, binc, rot)
        q, _ = geometry(js2, binc2)
        g = grip_of(KIND[item_type], item_type, q)
        if tris > MAX_TRIS:
            bad.append(f"{item}: {tris} trójkątów (limit Roblox {MAX_TRIS})")
        tri_idx = []
        off = 0
        for ni, _ in mesh_nodes(js2):
            for p in js2["meshes"][js2["nodes"][ni]["mesh"]]["primitives"]:
                idx = read(js2, binc2, p["indices"]).astype(int).reshape(-1, 3) if "indices" in p else None
                n = js2["accessors"][p["attributes"]["POSITION"]]["count"]
                tri_idx.append((idx if idx is not None else np.arange(n).reshape(-1, 3)) + off)
                off += n
        tri_all = np.concatenate(tri_idx)
        hold = hold_of(KIND[item_type], q, tri_all, g)
        size = q.max(0) - q.min(0)
        held = f"  hold {{ {hold[0]}, {hold[1]} }}" if hold and (hold[0] or hold[1]) else ""
        print(f"{item:28s} {tris:6d} tris  size {size[0]:.2f} x {size[1]:.2f} x {size[2]:.2f}  grip {g}{held}")
        by_type.setdefault(item_type, []).append((item, q, tri_all, g, hold))
        # Studio names the imported Model / MeshPart after the file, scene or node: all of them are the item id.
        for n in js2["nodes"]:
            n["name"] = item
        for m in js2.get("meshes", []):
            m["name"] = item
        for sc in js2.get("scenes", []):
            sc["name"] = item
        if not a.dry_run:
            save(os.path.join(out_dir, f"{item}.glb"), js2, binc2)
    for item_type, models in by_type.items():
        preview(models, os.path.join(root, "build", "weapons", f"{item_type}.png"))
    print(f"Modele: {sum(len(m) for m in by_type.values())}, podglądy: build/weapons/<typ>.png")
    if bad:
        sys.exit("Za dużo trójkątów:\n" + "\n".join(bad))


if __name__ == "__main__":
    main()
