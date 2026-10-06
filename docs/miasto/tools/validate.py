"""Checks the plan the same way the Lune tests in S21 will: overlaps, NPC doors, reachability, slopes."""
import math
from collections import deque
import plan as P
from shapely.geometry import Point, Polygon
from shapely.ops import unary_union
from shapely.geometry import LineString

errors = []

def err(msg):
    errors.append(msg)

# footprints
foot = []
for l in P.LOTS:
    foot.append((l["id"], P.rect_poly(l["x"], l["z"], l["w"], l["d"], l["rot"])))
for sp in P.SPECIALS:
    if sp["kind"] == "arena":
        o = P.ARENA["half"] + P.ARENA["stands"]
        # stands ring only (the sand floor is walkable): approximate the ring as 4 rects, gaps N and S (entrances)
        x, z, h, st = sp["x"], sp["z"], P.ARENA["half"], P.ARENA["stands"]
        for poly in [Polygon([(x - o, z - o), (x - h, z - o), (x - h, z + o), (x - o, z + o)]),
                     Polygon([(x + h, z - o), (x + o, z - o), (x + o, z + o), (x + h, z + o)]),
                     Polygon([(x - h, z - o), (x - 6, z - o), (x - 6, z - h), (x - h, z - h)]),
                     Polygon([(x + 6, z - o), (x + h, z - o), (x + h, z - h), (x + 6, z - h)]),
                     Polygon([(x - h, z + h), (x - 6, z + h), (x - 6, z + o), (x - h, z + o)]),
                     Polygon([(x + 6, z + h), (x + h, z + h), (x + h, z + o), (x + 6, z + o)])]:
            foot.append(("arena_stand", poly))
    else:
        foot.append((sp["id"], P.rect_poly(sp["x"], sp["z"], sp["w"], sp["d"], sp["rot"])))
for s in P.STALLS:
    foot.append((s["id"], P.rect_poly(s["x"], s["z"], 10, 5, s["rot"])))
foot.append(("fountain", Point(*P.FOUNTAIN).buffer(11)))
for i, (wx, wz) in enumerate(P.WELLS):
    foot.append((f"well{i}", Point(wx, wz).buffer(3.5)))

# 1. lots inside walls, no overlaps
inner = P.WALL_POLY.buffer(-8)
for name, poly in foot:
    if not inner.contains(poly) and name != "arena_stand":
        err(f"{name} not inside walls")
for i in range(len(foot)):
    for j in range(i + 1, len(foot)):
        if foot[i][0] == "arena_stand" and foot[j][0] == "arena_stand":
            continue
        a = foot[i][1].intersection(foot[j][1]).area
        if a > 0.5:
            err(f"overlap {foot[i][0]} {foot[j][0]} {a:.1f}")
river = P.RIVER_LINE.buffer(P.RIVER["width"] / 2 + 2)
for name, poly in foot:
    if name in ("mlyn",):
        continue
    if poly.intersects(river):
        err(f"{name} in river")
streets = unary_union([P.street_poly(s) for s in P.STREETS])
for name, poly in foot:
    if name.startswith("stall_") or name == "fountain" or name.startswith("well"):
        continue
    if poly.intersection(streets).area > 1:
        err(f"{name} on a street {poly.intersection(streets).area:.1f}")

# 2. NPC doors
OWNER = P.NPC_AT
specials = {s["id"]: s for s in P.SPECIALS}
stalls = {s["id"]: s for s in P.STALLS}
for npc, (x, z, f) in P.NPCS.items():
    p = Point(x, z)
    for name, poly in foot:
        if poly.contains(p):
            err(f"NPC {npc} inside {name}")
    if npc in OWNER:
        o = OWNER[npc]
        if o in specials:
            dx, dz = P.door_of(specials[o])
            dist = math.hypot(dx - x, dz - z)
            if dist > 16:
                err(f"NPC {npc} {dist:.1f} from door of {o}")
        else:
            s = stalls[o]
            if math.hypot(s["x"] - x, s["z"] - z) > 9:
                err(f"NPC {npc} far from stall")

# 3. reachability grid (2 studs)
CELL = 2
rw_polys = [LineString([(w["x1"], w["z1"]), (w["x2"], w["z2"])]).buffer(1.25, cap_style=2) for w in P.RETAINING]
blocked = unary_union([poly for _, poly in foot] + rw_polys)
water = P.RIVER_LINE.buffer(P.RIVER["width"] / 2 + 1)
bridges = unary_union([P.rect_poly(b["x"], b["z"], b["w"], b["len"], b["rot"]) for b in P.BRIDGES])
cemetery_wall = P.CEMETERY.exterior.buffer(0.8)
nx = int(P.SIZE / CELL)
H = {}
walk = {}
for i in range(nx):
    for j in range(nx):
        x = -P.HALF + (i + 0.5) * CELL
        z = -P.HALF + (j + 0.5) * CELL
        pt = Point(x, z)
        ok = inner.contains(pt) and not blocked.contains(pt)
        if ok and water.contains(pt) and not bridges.contains(pt):
            ok = False
        walk[(i, j)] = ok
        if ok:
            H[(i, j)] = P.height_at(x, z) if not bridges.contains(pt) else max(P.height_at(x, z), 0.8)


def cell_of(x, z):
    return (int((x + P.HALF) / CELL), int((z + P.HALF) / CELL))

start = cell_of(P.SPAWN[0], P.SPAWN[1])
seen = {start}
q = deque([start])
MAX_RISE = 1.9  # per 2 studs (~43 deg) - humanoid walks it; ramps are gentler
while q:
    c = q.popleft()
    for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        n = (c[0] + d[0], c[1] + d[1])
        if n in seen or not walk.get(n):
            continue
        if abs(H[n] - H[c]) > MAX_RISE:
            continue
        seen.add(n)
        q.append(n)
for npc, (x, z, f) in P.NPCS.items():
    if cell_of(x, z) not in seen:
        err(f"NPC {npc} unreachable from spawn")
for g in P.GATES:
    if cell_of(*g["arrive"]) not in seen:
        err(f"gate {g['id']} arrival unreachable")
    # portal sits in the gate passage: the cell 20 studs inward from the gate must be reachable
    ox, oz = g["out"]
    if cell_of(g["x"] - ox * 14, g["z"] - oz * 14) not in seen:
        err(f"gate {g['id']} passage unreachable")
for nm, pt in [("arenaExit", P.ARENA["exit"]), ("duel1", P.ARENA["duel"][0]), ("duel2", P.ARENA["duel"][1])]:
    if cell_of(*pt) not in seen:
        err(f"{nm} unreachable")
for sp in P.SPECIALS:
    if sp["kind"] == "arena":
        continue
    dx, dz = P.door_of(sp)
    if cell_of(dx, dz) not in seen:
        err(f"door of {sp['id']} unreachable")
bad_doors = 0
for l in P.LOTS:
    dx, dz = P.door_of(l)
    if cell_of(dx, dz) not in seen:
        bad_doors += 1
if bad_doors:
    err(f"{bad_doors} house doors unreachable")

# 4. walking surfaces: streets <= 1.0 rise per 2 studs (bridges excluded), ramps <= 1:4 grade, stairs <= 1:2,
#    ramp ends meet the ground (|dy| <= 0.8)
from shapely.geometry import LineString
def worst_step(pts, step=2.0, skip=None):
    ls = LineString(pts)
    n = int(ls.length / step)
    prev, worst = None, (0.0, None)
    for i in range(n + 1):
        q = ls.interpolate(i * step)
        if skip is not None and skip.contains(q):
            prev = None
            continue
        h = P.height_at(q.x, q.y)
        if prev is not None and abs(h - prev) > worst[0]:
            worst = (abs(h - prev), (round(q.x), round(q.y)))
        prev = h
    return worst
bridge_zone = unary_union([P.rect_poly(b["x"], b["z"], b["w"] + 4, b["len"] + 4, b["rot"]) for b in P.BRIDGES])
for st in P.STREETS:
    w_, at = worst_step(st["pts"], skip=bridge_zone)
    if w_ > 1.0:
        err(f"street {st['id']} too steep {w_:.2f}/2st at {at}")
for r in P.RAMPS:
    pts = r["pts"]
    for i in range(len(pts) - 1):
        (ax, az, ay), (bx, bz, by) = pts[i], pts[i + 1]
        grade = abs(by - ay) / math.hypot(bx - ax, bz - az)
        lim = 0.5 if r.get("stairs") else 0.25
        if grade > lim + 1e-6:
            err(f"ramp {r['id']} segment {i} grade {grade:.2f} > {lim}")
    for end, nxt in ((pts[0], pts[1]), (pts[-1], pts[-2])):
        ex, ez, ey = end
        dx, dz = ex - nxt[0], ez - nxt[1]
        L = math.hypot(dx, dz)
        gx, gz = ex + dx / L * (r["w"] / 2 + 1.5), ez + dz / L * (r["w"] / 2 + 1.5)
        g = P.height_at(gx, gz, ramps=False)
        if abs(g - ey) > 0.8:
            err(f"ramp {r['id']} end ({ex},{ez}) y={ey} but ground beyond = {g:.2f}")
for w in P.RETAINING:
    if w["top"] - w["bottom"] > 26:
        err(f"retaining {w['id']} too tall {w['top'] - w['bottom']:.1f}")

# 5. heights at key points
print("heights:")
for npc, (x, z, f) in P.NPCS.items():
    print(f"  {npc:12s} ({x},{z}) y={P.height_at(x, z):.2f}")
for g in P.GATES:
    print(f"  gate {g['id']:6s} ({g['x']},{g['z']}) y={P.height_at(g['x'], g['z']):.2f} arrive {g['arrive']} "
          f"y={P.height_at(*g['arrive']):.2f}")
print(f"  spawn y={P.height_at(P.SPAWN[0], P.SPAWN[1]):.2f}")
print("reachable cells", len(seen), "of walkable", sum(1 for v in walk.values() if v))
print("ERRORS:" if errors else "OK")
for e in errors:
    print("  ", e)
