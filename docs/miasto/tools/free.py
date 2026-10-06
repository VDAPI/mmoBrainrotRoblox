import math
import plan as P
from shapely.geometry import Point, Polygon, LineString, box
from shapely.ops import unary_union

def occupied():
    occ = []
    for l in P.LOTS:
        occ.append(P.rect_poly(l["x"], l["z"], l["w"], l["d"], l["rot"]).buffer(2.5))
    for sp in P.SPECIALS:
        if sp["kind"] == "arena":
            o = P.ARENA["half"] + P.ARENA["stands"] + 4
            occ.append(box(sp["x"] - o, sp["z"] - o, sp["x"] + o, sp["z"] + o))
        else:
            occ.append(P.rect_poly(sp["x"], sp["z"], sp["w"], sp["d"], sp["rot"]).buffer(5))
    for st in P.STREETS:
        occ.append(P.street_poly(st, 1.5))
    for sq in P.SQUARES:
        occ.append(Polygon(sq["poly"]).buffer(1))
    for r in P.RAMPS:
        occ.append(LineString([(x, z) for x, z, _ in r["pts"]]).buffer(r["w"] / 2 + 3, cap_style=2))
    for w in P.RETAINING:
        occ.append(LineString([(w["x1"], w["z1"]), (w["x2"], w["z2"])]).buffer(3))
    occ.append(P.RIVER_LINE.buffer(P.RIVER["width"] / 2 + P.RIVER["bank"]))
    for b in P.BRIDGES:
        occ.append(P.rect_poly(b["x"], b["z"], b["w"] + 6, b["len"] + 6, b["rot"]))
    occ.append(P.CEMETERY.buffer(2))
    occ.append(Point(-190, -216).buffer(48))
    for s in P.STALLS:
        occ.append(Point(s["x"], s["z"]).buffer(8))
    occ.append(Point(*P.FOUNTAIN).buffer(14))
    for wx, wz in P.WELLS:
        occ.append(Point(wx, wz).buffer(6))
    for n, (x, z, f) in P.NPCS.items():
        occ.append(Point(x, z).buffer(6))
    occ.append(Point(P.SPAWN[0], P.SPAWN[1]).buffer(10))
    return unary_union(occ)

def free_space():
    inner = P.WALL_POLY.buffer(-9)
    return inner.difference(occupied())

if __name__ == "__main__":
    fs = free_space()
    parts = list(fs.geoms) if fs.geom_type == "MultiPolygon" else [fs]
    parts = [g for g in parts if g.area > 250]
    parts.sort(key=lambda g: -g.area)
    print("free total", round(fs.area), "components>250:", len(parts))
    for g in parts[:40]:
        c = g.representative_point()
        print(f"  area {g.area:6.0f} at ({c.x:5.0f},{c.y:5.0f}) bbox {tuple(round(v) for v in g.bounds)} district {P.district_of(c.x, c.y)['id']}")
