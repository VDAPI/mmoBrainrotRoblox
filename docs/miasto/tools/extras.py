"""Derived layers on top of plan.py: gardens (fill empty blocks), street lamps, props, outside scenery."""
import math, random
import plan as P
from free import free_space
from shapely.geometry import Point, Polygon, LineString, box, MultiPolygon
from shapely.ops import unary_union

rng = random.Random(77)

# ---------------------------------------------------------------- gardens
NEAR = [  # (x, z, radius, kind) - first match wins
    (236, 40, 75, "paddock"),          # stable
    (262, -46, 45, "trainingYard"),    # guardhouse
    (-200, 6, 45, "herbs"),            # apothecary
    (-110, -176, 62, "herbs"),         # temple
    (-190, -216, 75, "formal"),        # castle
    (-160, 50, 55, "yard"),            # forge
    (-126, 49, 40, "yard"),
    (-200, 196, 55, "yard"),           # mill
    (170, 110, 50, "yard"),            # granary
    (160, -36, 40, "yard"),            # tavern
]
MIX = {
    "patrician": [("formal", 3), ("orchard", 4), ("herbs", 2), ("vineyard", 2)],
    "craft": [("yard", 5), ("vegetables", 3), ("orchard", 2)],
    "burgher": [("backGarden", 5), ("yard", 2), ("orchard", 3)],
    "cottage": [("vegetables", 5), ("orchard", 3), ("pasture", 1), ("yard", 2)],
}


def pick(mix, r):
    tot = sum(w for _, w in mix)
    v = r.random() * tot
    for k, w in mix:
        v -= w
        if v <= 0:
            return k
    return mix[-1][0]


def kind_for(poly, r):
    c = poly.representative_point()
    # steep ground: wild meadow, no fences
    xs = [c.x] + [x for x, _ in list(poly.exterior.coords)[:12]]
    zs = [c.y] + [z for _, z in list(poly.exterior.coords)[:12]]
    hs = [P.height_at(x, z) for x, z in zip(xs, zs)]
    if max(hs) - min(hs) > 4.5:
        return "meadow"
    for x, z, rad, k in NEAR:
        if math.hypot(c.x - x, c.y - z) < rad:
            return k
    if c.x < -240 and c.y < -110:
        return "vineyard"
    d = P.district_of(c.x, c.y)
    return pick(MIX[d["style"]], r)


def gardens(cell=34, min_area=160):
    fs = free_space()
    out = []
    xs = range(-400, 400, cell)
    for gx in xs:
        for gz in xs:
            cellp = box(gx, gz, gx + cell, gz + cell)
            g = fs.intersection(cellp)
            if g.is_empty:
                continue
            geoms = list(g.geoms) if hasattr(g, "geoms") else [g]
            for piece in geoms:
                if piece.geom_type != "Polygon" or piece.area < min_area:
                    continue
                piece = piece.simplify(1.5, preserve_topology=True).buffer(-0.75, join_style=2)
                if piece.is_empty or piece.geom_type != "Polygon" or piece.area < min_area:
                    continue
                pts = [(round(x, 1), round(z, 1)) for x, z in list(piece.exterior.coords)[:-1]]
                if len(pts) > 14:
                    piece = piece.simplify(3, preserve_topology=True)
                    pts = [(round(x, 1), round(z, 1)) for x, z in list(piece.exterior.coords)[:-1]]
                out.append(dict(poly=pts, area=round(piece.area), seed=rng.randint(1, 99999), _p=piece))
    for i, gd in enumerate(out):
        gd["id"] = f"g{i + 1:03d}"
        gd["kind"] = kind_for(gd["_p"], random.Random(gd["seed"]))
    # at most 2 training yards, keep the two closest to the guardhouse
    ty = sorted([g for g in out if g["kind"] == "trainingYard"],
                key=lambda g: g["_p"].centroid.distance(Point(262, -46)))
    for g in ty[2:]:
        g["kind"] = "orchard"
    return out


GARDENS = gardens()

# ---------------------------------------------------------------- street lamps (main streets + squares)
def lamps():
    occ = []
    for l in P.LOTS:
        occ.append(P.rect_poly(l["x"], l["z"], l["w"], l["d"], l["rot"]).buffer(0.5))
    for sp in P.SPECIALS:
        if sp["kind"] != "arena":
            occ.append(P.rect_poly(sp["x"], sp["z"], sp["w"], sp["d"], sp["rot"]).buffer(1))
    for r in P.RAMPS:
        occ.append(LineString([(x, z) for x, z, _ in r["pts"]]).buffer(r["w"] / 2 + 1))
    occ.append(P.RIVER_LINE.buffer(P.RIVER["width"] / 2 + 3))
    for s in P.STALLS:
        occ.append(Point(s["x"], s["z"]).buffer(7))
    for n, (x, z, f) in P.NPCS.items():
        occ.append(Point(x, z).buffer(4))
    occ.append(Point(P.SPAWN[0], P.SPAWN[1]).buffer(6))
    occ.append(Point(*P.FOUNTAIN).buffer(12))
    for w in P.RETAINING:
        occ.append(LineString([(w["x1"], w["z1"]), (w["x2"], w["z2"])]).buffer(2))
    blocked = unary_union(occ)
    inner = P.WALL_POLY.buffer(-6)
    res = []
    for st in P.STREETS:
        if st["kind"] != "main":
            continue
        line = LineString(st["pts"])
        L = line.length
        k, side = 10.0, 1
        while k < L - 6:
            a = line.interpolate(k)
            b = line.interpolate(min(L, k + 0.5))
            ux, uz = (b.x - a.x) / 0.5, (b.y - a.y) / 0.5
            x, z = a.x - uz * side * (st["w"] / 2 + 1.2), a.y + ux * side * (st["w"] / 2 + 1.2)
            if inner.contains(Point(x, z)) and not blocked.contains(Point(x, z)) and \
                    all(math.hypot(x - q["x"], z - q["z"]) > 14 for q in res):
                res.append(dict(x=round(x, 1), z=round(z, 1), kind="post"))
                side = -side
            k += 26
    for r in P.RAMPS:  # lanterns at the ramp ends, beside the road
        pts = r["pts"]
        for (ax, az, _), (bx, bz, _) in ((pts[0], pts[1]), (pts[-1], pts[-2])):
            L = math.hypot(bx - ax, bz - az)
            ux, uz = (bx - ax) / L, (bz - az) / L
            side = r["w"] / 2 + 1.6
            x, z = ax + ux * 3 - uz * side, az + uz * 3 + ux * side
            if not blocked.contains(Point(x, z)):
                res.append(dict(x=round(x, 1), z=round(z, 1), kind="rampLantern", ramp=r["id"]))
    for sq in P.SQUARES:
        poly = Polygon(sq["poly"])
        for x, z in sq["poly"] if len(sq["poly"]) <= 4 else []:
            c = poly.centroid
            dx, dz = c.x - x, c.y - z
            L = math.hypot(dx, dz)
            px_, pz_ = x + dx / L * 5, z + dz / L * 5
            if not blocked.contains(Point(px_, pz_)) and all(math.hypot(px_ - q["x"], pz_ - q["z"]) > 10 for q in res):
                res.append(dict(x=round(px_, 1), z=round(pz_, 1), kind="post"))
    for i, l in enumerate(res):
        l["id"] = f"l{i + 1:03d}"
    return res


LAMPS = lamps()

# ---------------------------------------------------------------- outside the walls (scenery, not walkable)
ROADS_OUT = []
for g in P.GATES:
    ox, oz = g["out"]
    sx, sz = g["x"] + ox * 6, g["z"] + oz * 6
    ex, ez = g["x"] + ox * 90, g["z"] + oz * 90
    # gentle bend so the road does not look ruled
    mx, mz = (sx + ex) / 2 + oz * 14, (sz + ez) / 2 - ox * 14
    ROADS_OUT.append(dict(gate=g["id"], pts=[(round(sx), round(sz)), (round(mx), round(mz)), (round(ex), round(ez))],
                          w=12, bridge=dict(x=g["x"] + ox * P.MOAT["center"], z=g["z"] + oz * P.MOAT["center"],
                                            rot=g["rot"], len=P.MOAT["half"] * 2 + 8, w=14)))
road_zone = unary_union([LineString(r["pts"]).buffer(r["w"] / 2 + 6) for r in ROADS_OUT])
outer_zone = box(-392, -392, 392, 392).difference(P.WALL_POLY.buffer(P.MOAT["center"] + P.MOAT["half"] + 6))
outer_zone = outer_zone.difference(P.RIVER_LINE.buffer(P.RIVER["width"] / 2 + P.RIVER["bank"] + 4)).difference(road_zone)
FOREST_START = 340  # max(|x|,|z|) beyond this = forest band on the rising hills

WINDMILL = dict(x=330, z=-300, rot=225)
FARMS = [dict(x=345, z=230, rot=200), dict(x=-345, z=-300, rot=40), dict(x=200, z=355, rot=180),
         dict(x=-330, z=330, rot=135)]
WATCHTOWER_RUIN = dict(x=-120, z=-372)


def fields():
    out = []
    fr = random.Random(5)
    crops = ["wheat", "barley", "ploughed", "fallow", "cabbage", "flax"]
    cell = 46
    keep = outer_zone.difference(box(-FOREST_START, -FOREST_START, FOREST_START, FOREST_START).exterior.buffer(0)
                                 if False else Polygon()).intersection(
        box(-FOREST_START, -FOREST_START, FOREST_START, FOREST_START))
    for spec in [WINDMILL] + FARMS:
        keep = keep.difference(Point(spec["x"], spec["z"]).buffer(22))
    for gx in range(-392, 392, cell):
        for gz in range(-392, 392, cell):
            # stagger rows so fields form strips, not a chessboard
            off = (gz // cell) % 2 * cell / 2
            cellp = box(gx + off, gz, gx + off + cell, gz + cell)
            g = keep.intersection(cellp)
            for piece in (list(g.geoms) if hasattr(g, "geoms") else [g]):
                if piece.is_empty or piece.geom_type != "Polygon" or piece.area < 500:
                    continue
                piece = piece.buffer(-1.5, join_style=2).simplify(2)
                if piece.is_empty or piece.geom_type != "Polygon":
                    continue
                out.append(dict(poly=[(round(x), round(z)) for x, z in list(piece.exterior.coords)[:-1]],
                                crop=fr.choice(crops), rows=fr.choice([0, 90]) + fr.randint(-12, 12),
                                seed=fr.randint(1, 99999)))
    for i, f in enumerate(out):
        f["id"] = f"f{i + 1:03d}"
    return out


FIELDS = fields()

if __name__ == "__main__":
    from collections import Counter
    print("gardens", len(GARDENS), Counter(g["kind"] for g in GARDENS), "area", sum(g["area"] for g in GARDENS))
    print("lamps", len(LAMPS), Counter(l["kind"] for l in LAMPS))
    print("fields", len(FIELDS), Counter(f["crop"] for f in FIELDS))
    print("roads out", [(r["gate"], r["pts"]) for r in ROADS_OUT])
