"""Vaelthorn city plan: data, terrain height function, lot generation, validation, rendering, Luau export.

Coordinates: x east, z south (north = -z, top of the image). Studs, map-relative (city offset is 0,0,0).
Rotation convention (same as the game): rot in degrees, CFrame.Angles(0, rad(rot), 0); the building front is
local -Z, so front direction = (-sin(rot), -cos(rot)). rot 0 faces north, 90 west, 180 south, 270 east.
"""
import math, json, random, sys
from shapely.geometry import Polygon, Point, LineString, box
from shapely.ops import unary_union
from shapely import affinity

SIZE = 800
HALF = SIZE / 2

# ---------------------------------------------------------------- walls and gates
WALL = [(-285, -205), (-205, -300), (-60, -312), (100, -305), (225, -255), (300, -125), (306, 60),
        (278, 190), (215, 272), (60, 308), (-110, 302), (-245, 245), (-302, 115), (-312, -55)]
WALL_POLY = Polygon(WALL)


def rot_for_front(fx, fz):
    """rot (deg) so that local -Z points along (fx, fz)."""
    return round(math.degrees(math.atan2(-fx, -fz))) % 360


def front_of(rot):
    r = math.radians(rot)
    return (-math.sin(r), -math.cos(r))


# Gate: centre on the wall line, `rot` so that the passage runs along local Z (walking through = along front axis)
# and `out` = unit vector pointing out of the city.
GATES = [
    # id, x, z, out(x,z), portal id, target map, arrival
    dict(id="east", x=304, z=0, out=(1, 0), portal="city_meadows", target="meadows"),
    dict(id="north", x=60, z=-307, out=(0, -1), portal="city_duskwood", target="duskwood"),
    dict(id="west", x=-306, z=40, out=(-1, 0), portal="city_ashen", target="ashen"),
    dict(id="south", x=-20, z=305, out=(0, 1), portal="city_frostpeak", target="frostpeak"),
]
for g in GATES:
    # Gate model faces OUT of the city (its local -Z = out), so the portal field sits in the passage.
    g["rot"] = rot_for_front(*g["out"])
    ox, oz = g["out"]
    g["arrive"] = (round(g["x"] - ox * 34), round(g["z"] - oz * 34))  # 34 studs inside, on the gate square
    g["portalPos"] = (g["x"], g["z"])  # the field fills the gate passage

# ---------------------------------------------------------------- terrain features
# Plateaus: flat areas at height y; outside the polygon the height falls off smoothly to 0 over `blend` studs.
# edge: "soft" = grassy slope over `blend` studs; "wall" = sharp step faced by a stone retaining wall;
# "cliff" = sharp rocky step (terrain Rock), used under the castle.
PLATEAUS = [
    dict(id="rynek", poly=[(-58, -78), (98, -78), (98, 48), (-58, 48)], y=4, blend=26, edge="soft"),
    dict(id="upper", poly=[(-294, -208), (-209, -308), (-60, -317), (-22, -255), (-18, -150), (-38, -98),
                           (-120, -84), (-208, -88), (-272, -122), (-308, -128)], y=12, blend=1.5, edge="wall"),
    dict(id="castle", poly=[(-190 + 44 * math.cos(a * math.pi / 8), -216 + 44 * math.sin(a * math.pi / 8))
                            for a in range(16)], y=20, blend=2.5, edge="cliff"),
    dict(id="northeast", poly=[(100, -290), (220, -250), (285, -130), (150, -95), (95, -120)], y=6, blend=40, edge="soft"),
    dict(id="arena", poly=[(132, -222), (248, -222), (248, -98), (132, -98)], y=6, blend=8, edge="soft"),
    dict(id="ratusz", poly=[(34, -114), (78, -114), (78, -76), (34, -76)], y=4, blend=14, edge="soft"),
]
# Ramps: polylines of (x, z, y) with width w. Inside the band (distance to the polyline <= w/2) the terrain height
# is OVERRIDDEN by the polyline height at the nearest point (linear along each segment). y=None means "match the
# terrain at that end" (filled in below). Ramp sides that stand above or cut below the surrounding terrain by more
# than 1.5 studs get stone side walls (embankment / cutting), see RETAINING.
RAMPS = [
    dict(id="schody", name="Wielkie Schody", pts=[(-50, -79, 4.0), (-50, -102, 12.0)], w=16, stairs=True),
    dict(id="zamkowa", name="Ulica Zamkowa", pts=[(-148, -136, 12.0), (-164, -176, 18.5), (-172, -190, 20.0)], w=12),
    dict(id="podgorna", name="Podgórna", pts=[(-232, -28, None), (-246, -112, 12.0)], w=10),
    dict(id="gorna", name="Ulica Górna", pts=[(34, -202, None), (-26, -201, 12.0)], w=10),
]
RIVER = dict(points=[(-400, 150), (-306, 152), (-220, 165), (-120, 178), (0, 182), (110, 172), (200, 160),
                     (290, 150), (400, 140)], width=24, bank=7, bed=-6, water=-1.5)
RIVER_LINE = LineString(RIVER["points"])


def smoothstep(t):
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


_plateau_polys = [(p, Polygon(p["poly"])) for p in PLATEAUS]


def value_noise(x, z, seed=7):
    """Smooth deterministic noise from sines, range about 0..1. Same formula in Luau (TownTerrain.noise);
    sin/cos are the only primitives, so Python and Luau agree to ~1e-12."""
    return (0.5 + 0.22 * math.sin(0.9 * x + seed * 1.3) * math.cos(0.8 * z - seed * 0.7)
            + 0.18 * math.sin(0.53 * (x + z) + seed * 2.1) + 0.1 * math.cos(1.7 * x - 1.1 * z + seed))


MOAT = dict(center=13, half=7, bed=-4.5)


def _seg_nearest(px_, pz_, ax, az, bx, bz):
    vx, vz = bx - ax, bz - az
    L2 = vx * vx + vz * vz
    t = 0.0 if L2 == 0 else max(0.0, min(1.0, ((px_ - ax) * vx + (pz_ - az) * vz) / L2))
    nx_, nz_ = ax + vx * t, az + vz * t
    return math.hypot(px_ - nx_, pz_ - nz_), t


def ramp_height(x, z):
    """(height, ramp) if (x, z) is on a ramp band, else (None, None). Nearest ramp wins."""
    best = None
    for r in RAMPS:
        pts = r["pts"]
        for i in range(len(pts) - 1):
            (ax, az, ay), (bx, bz, by) = pts[i], pts[i + 1]
            d, t = _seg_nearest(x, z, ax, az, bx, bz)
            if d <= r["w"] / 2 and (best is None or d < best[0]):
                best = (d, ay + (by - ay) * t, r)
    if best is None:
        return None, None
    return best[1], best[2]


def height_at(x, z, ramps=True):
    p = Point(x, z)
    h = 0.0
    # Outside the walls: rolling fields that rise toward the map edge (scenery only).
    dwall = WALL_POLY.exterior.distance(p)
    inside = WALL_POLY.contains(p)
    if not inside:
        rise = max(0.0, max(abs(x), abs(z)) - 330) * 0.35
        h = max(h, smoothstep(dwall / 30) * (1.5 + 5 * value_noise(x / 70, z / 70) + rise))
    else:
        # gentle unevenness inside the walls (lanes, yards): +-0.8 stud
        h = max(h, 0.8 * value_noise(x / 45, z / 45, 3))
    for pl, poly in _plateau_polys:
        d = poly.exterior.distance(p) if not poly.contains(p) else 0.0
        blend = pl["blend"] if inside else max(pl["blend"], 30)  # outside the walls every plateau edge is soft
        if d <= 0:
            h = max(h, pl["y"])
        elif d < blend:
            h = max(h, pl["y"] * (1 - smoothstep(d / blend)))
    if not inside:
        # wet moat around the walls (water level = river water level)
        m = 1 - smoothstep(abs(dwall - MOAT["center"]) / MOAT["half"])
        h = h + (MOAT["bed"] - h) * m
    if ramps:
        rh, _ = ramp_height(x, z)
        if rh is not None:
            h = rh
    # River carve
    d = RIVER_LINE.distance(p)
    half = RIVER["width"] / 2
    if d < half:
        h = RIVER["bed"] + (RIVER["water"] + 0.5 - RIVER["bed"]) * (d / half) ** 4
    elif d < half + RIVER["bank"]:
        t = smoothstep((d - half) / RIVER["bank"])
        h = min(h, (RIVER["water"] + 0.5) + (h - (RIVER["water"] + 0.5)) * t)
    return h


for _r in RAMPS:
    _r["pts"] = [(x, z, round(height_at(x, z, ramps=False), 1) if y is None else y) for x, z, y in _r["pts"]]


# ---------------------------------------------------------------- streets and squares
# kind: main (Cobblestone), lane (Ground), alley (Ground). Points are polylines.
STREETS = [
    dict(id="kupiecka", name="Ulica Kupiecka", pts=[(98, -6), (200, -4), (304, 0)], w=18, kind="main"),
    dict(id="popielna", name="Ulica Popielna", pts=[(-58, -4), (-150, 22), (-230, 34), (-306, 40)], w=16,
         kind="main"),
    dict(id="lesna", name="Ulica Leśna", pts=[(84, -78), (78, -180), (60, -307)], w=14, kind="main"),
    dict(id="mostowa", name="Ulica Mostowa", pts=[(22, 48), (12, 120), (5, 182), (-8, 250), (-20, 305)], w=16,
         kind="main"),
    dict(id="gorna", name="Ulica Górna", pts=[(78, -202), (34, -202)], w=10, kind="lane"),
    dict(id="gornaGora", name="Ulica Górna", pts=[(-26, -201), (-56, -200)], w=10, kind="lane"),
    dict(id="rycerska", name="Ulica Rycerska", pts=[(-160, -97), (-232, -101), (-246, -112), (-262, -150)], w=10,
         kind="lane"),
    dict(id="katedralna", name="Katedralna", pts=[(-60, -140), (-56, -200), (-74, -244)], w=10, kind="lane"),
    dict(id="kanonicza", name="Kanonicza", pts=[(-205, -150), (-215, -100)], w=8, kind="alley"),
    dict(id="nadrzeczna", name="Nadrzeczna", pts=[(-280, 128), (-200, 136), (-120, 150), (5, 152), (140, 140),
                                                 (282, 126)], w=10, kind="lane"),
    dict(id="rybacka", name="Rybacka", pts=[(-238, 210), (-120, 210), (5, 214), (130, 204), (232, 194)], w=10,
         kind="lane"),
    dict(id="kowalska", name="Kowalska", pts=[(-104, 16), (-110, 150)], w=10, kind="lane"),
    dict(id="stajenna", name="Stajenna", pts=[(205, -4), (205, -92)], w=10, kind="lane"),
    dict(id="spichrzowa", name="Spichrzowa", pts=[(205, -4), (190, 138)], w=10, kind="lane"),
    dict(id="podgorna", name="Podgórna", pts=[(-215, 33), (-232, -28)], w=10, kind="lane"),
    dict(id="dolna", name="Dolna", pts=[(-8, 250), (-150, 252), (-228, 232)], w=10, kind="lane"),
    dict(id="sadowa", name="Sadowa", pts=[(-8, 250), (150, 236)], w=10, kind="lane"),
    dict(id="turniejowa", name="Turniejowa", pts=[(84, -140), (128, -99), (186, -90)], w=10, kind="lane"),
    dict(id="piwna", name="Piwna", pts=[(78, -152), (30, -156), (-6, -156)], w=10, kind="lane"),
    dict(id="mlynska", name="Młyńska", pts=[(-188, 30), (-196, 130)], w=8, kind="alley"),
    dict(id="piekarska", name="Piekarska", pts=[(-58, 30), (-100, 58)], w=8, kind="alley"),
    dict(id="browarna", name="Browarna", pts=[(98, 30), (140, 60), (140, 140)], w=8, kind="alley"),
]
BRIDGES = [
    dict(id="mostKamienny", kind="stone", x=5, z=182, rot=0, len=50, w=18),  # on Mostowa
    dict(id="kladkaKowali", kind="wood", x=-110, z=180, rot=0, len=44, w=8),
    dict(id="mostWschodni", kind="stone", x=140, z=172, rot=0, len=46, w=12),
]
SQUARES = [
    dict(id="rynek", name="Rynek", poly=[(-58, -78), (98, -78), (98, 48), (-58, 48)], mat="Limestone"),
    dict(id="placSwiatynny", name="Plac Świątynny", poly=[(-160, -140), (-40, -140), (-40, -102), (-160, -102)],
         mat="Limestone"),
    dict(id="dziedziniec", name="Dziedziniec Zamkowy",
         poly=[(-190 + 34 * math.cos(a * math.pi / 8), -216 + 34 * math.sin(a * math.pi / 8)) for a in range(16)],
         mat="Cobblestone"),
    dict(id="placWschodni", name="Plac Bramy Wschodniej", poly=[(240, -24), (292, -24), (292, 24), (240, 24)],
         mat="Cobblestone"),
    dict(id="placPolnocny", name="Plac Bramy Północnej", poly=[(38, -296), (84, -296), (84, -256), (38, -256)],
         mat="Cobblestone"),
    dict(id="placZachodni", name="Plac Bramy Zachodniej", poly=[(-296, 18), (-252, 18), (-252, 62), (-296, 62)],
         mat="Cobblestone"),
    dict(id="placPoludniowy", name="Plac Bramy Południowej", poly=[(-42, 254), (6, 254), (6, 294), (-42, 294)],
         mat="Cobblestone"),
]

# ---------------------------------------------------------------- special buildings (hand placed)
# w = frontage (local X), d = depth (local Z); rot: front direction (see header).
SPECIALS = [
    dict(id="hala", kind="marketHall", name="Hala Kupiecka", x=20, z=-14, w=22, d=58, rot=90),
    dict(id="ratusz", kind="townHall", name="Ratusz ze Skarbcem", x=56, z=-94, w=36, d=28, rot=180),
    dict(id="swiatynia", kind="temple", name="Świątynia Światła", x=-110, z=-176, w=34, d=60, rot=180),
    dict(id="donzon", kind="keep", name="Donżon Kasztelana", x=-196, z=-224, w=28, d=28, rot=135),
    dict(id="gildia", kind="guildHall", name="Dom Gildii", x=-172, z=-122, w=30, d=24, rot=270),
    dict(id="kuznia", kind="forge", name="Kuźnia", x=-160, z=50, w=30, d=24, rot=0),
    dict(id="zbrojownia", kind="workshop", name="Zbrojmistrz", x=-126, z=49, w=18, d=20, rot=0),
    dict(id="apteka", kind="apothecary", name="Apteka Alchemika", x=-200, z=6, w=22, d=20, rot=180),
    dict(id="karczma", kind="tavern", name="Karczma Pod Kamiennym Smokiem", x=160, z=-36, w=30, d=26, rot=180),
    dict(id="stajnia", kind="stable", name="Stajnia", x=236, z=40, w=36, d=22, rot=0),
    dict(id="mlyn", kind="watermill", name="Młyn Wodny", x=-200, z=196, w=18, d=16, rot=180),
    dict(id="spichlerz", kind="granary", name="Spichlerz", x=170, z=110, w=24, d=34, rot=270),
    dict(id="arena", kind="arena", name="Ristalle", x=190, z=-160, w=80, d=80, rot=0),
    dict(id="wartownia", kind="guardhouse", name="Wartownia", x=262, z=-46, w=20, d=16, rot=180),
]

# Market stalls on the rynek (front faces north; the vendor stands behind the counter, south).
STALLS = [
    dict(id="stall_merchant", x=6, z=30, rot=0, color="#8E3B2E", npc="merchant"),
    dict(id="stall_backpacker", x=30, z=30, rot=0, color="#3E5A7A", npc="backpacker"),
    dict(id="stall_bread", x=-36, z=30, rot=0, color="#A8843A"),
    dict(id="stall_cloth", x=-15, z=30, rot=0, color="#6B3E6B"),
    dict(id="stall_pottery", x=54, z=30, rot=0, color="#7A5A3A"),
    dict(id="stall_fish", x=76, z=30, rot=0, color="#3E6B5A"),
]

# NPC spots (x, z, facing). Facing: 0 north, 90 west, 180 south, 270 east.
NPCS = {
    "captain": (-36, 10, 90),          # by the spawn on the west side of the rynek, faces the spawn... see below
    "questboard": (28, -68, 180),       # notice board at the town hall steps
    "banker": (56, -72, 180),           # town hall door (treasury)
    "auctioneer": (-16, -14, 90),       # west end of the market hall
    "merchant": (6, 36, 0),             # behind the stall counter
    "backpacker": (30, 36, 0),
    "healer": (-120, -134, 180),        # temple steps
    "teacher": (-100, -134, 180),
    "guildmaster": (-150, -122, 270),   # guild hall door
    "blacksmith": (-160, 32, 0),        # forge yard
    "weaponsmith": (-126, 33, 0),       # workshop counter
    "alchemist": (-200, 22, 180),       # apothecary door
    "guard1": (270, -16, 270),
    "guard2": (270, 16, 270),
}
# Which building or stall an NPC belongs to (the NPC stands within 16 studs of its door, 9 of a stall).
NPC_AT = {"banker": "ratusz", "auctioneer": "hala", "healer": "swiatynia", "teacher": "swiatynia",
          "guildmaster": "gildia", "blacksmith": "kuznia", "weaponsmith": "zbrojownia", "alchemist": "apteka",
          "merchant": "stall_merchant", "backpacker": "stall_backpacker"}
SPAWN = (-30, -4, 270)  # x, z, facing east toward the market hall
CAPTAIN_FIX = True
if CAPTAIN_FIX:
    NPCS["captain"] = (-40, 6, 270)

ARENA = dict(x=190, z=-160, half=40, stands=14, exit=(190, -88), duel=((165, -160), (215, -160)))
SELECT_CAMERA = dict(eye=(150, 70, 120), look=(-20, 10, -80))

FOUNTAIN = (-30, -40)
WELLS = [(-128, 96), (150, 220), (120, -120), (-60, 230)]

# ---------------------------------------------------------------- districts (for lot styles)
DISTRICTS = [
    dict(id="upper", name="Górne Miasto", poly=PLATEAUS[1]["poly"], style="patrician"),
    dict(id="craft", name="Dzielnica Rzemieślnicza", poly=[(-306, -40), (-60, -40), (-60, 160), (-306, 160)],
         style="craft"),
    dict(id="market", name="Śródmieście", poly=[(-60, -90), (120, -90), (120, 80), (-60, 80)], style="burgher"),
    dict(id="east", name="Dzielnica Kupiecka", poly=[(120, -100), (306, -100), (306, 150), (120, 150)],
         style="burgher"),
    dict(id="north", name="Przedmieście Leśne", poly=[(-20, -310), (130, -310), (130, -90), (-20, -90)],
         style="burgher"),
    dict(id="lower", name="Dolne Miasto", poly=[(-306, 160), (306, 160), (306, 310), (-306, 310)], style="cottage"),
    dict(id="ne", name="Ristalle", poly=[(130, -310), (306, -310), (306, -100), (130, -100)], style="cottage"),
]
_district_polys = [(d, Polygon(d["poly"])) for d in DISTRICTS]


def district_of(x, z):
    p = Point(x, z)
    for d, poly in _district_polys:
        if poly.contains(p):
            return d
    return DISTRICTS[3]


# ---------------------------------------------------------------- footprint helpers
def rect_poly(x, z, w, d, rot):
    """Footprint polygon: w along local X, d along local Z, rotated by rot (deg, game convention)."""
    r = math.radians(rot)
    c, s = math.cos(r), math.sin(r)
    pts = []
    for lx, lz in [(-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2)]:
        # RotY(theta): x' = x cos + z sin ; z' = -x sin + z cos
        pts.append((x + lx * c + lz * s, z - lx * s + lz * c))
    return Polygon(pts)


def street_poly(st, extra=0.0):
    return LineString(st["pts"]).buffer(st["w"] / 2 + extra, cap_style=2, join_style=2)


def door_of(b):
    fx, fz = front_of(b["rot"])
    return (b["x"] + fx * (b["d"] / 2 + 1.5), b["z"] + fz * (b["d"] / 2 + 1.5))


# ---------------------------------------------------------------- lot generation along streets
def generate_lots(seed=2026):
    rng = random.Random(seed)
    blockers = []
    for st in STREETS:
        blockers.append(street_poly(st, 1.5))
    for sq in SQUARES:
        blockers.append(Polygon(sq["poly"]).buffer(1.5))
    for sp in SPECIALS:
        extra = 4
        if sp["kind"] == "arena":
            poly = box(sp["x"] - ARENA["half"] - ARENA["stands"] - 4, sp["z"] - ARENA["half"] - ARENA["stands"] - 4,
                       sp["x"] + ARENA["half"] + ARENA["stands"] + 4, sp["z"] + ARENA["half"] + ARENA["stands"] + 4)
        else:
            poly = rect_poly(sp["x"], sp["z"], sp["w"], sp["d"], sp["rot"]).buffer(extra)
        blockers.append(poly)
    for s in STALLS:
        blockers.append(Point(s["x"], s["z"]).buffer(9))
    blockers.append(RIVER_LINE.buffer(RIVER["width"] / 2 + RIVER["bank"] + 3))
    for b in BRIDGES:
        blockers.append(rect_poly(b["x"], b["z"], b["w"] + 6, b["len"] + 6, b["rot"]))
    for r in RAMPS:
        blockers.append(LineString([(x, z) for x, z, _ in r["pts"]]).buffer(r["w"] / 2 + 4, cap_style=2))
    for pl in PLATEAUS:
        if pl["edge"] != "soft":
            blockers.append(Polygon(pl["poly"]).exterior.buffer(4))
    blockers.append(Point(*FOUNTAIN).buffer(16))
    for wx, wz in WELLS:
        blockers.append(Point(wx, wz).buffer(7))
    for n, (x, z, f) in NPCS.items():
        blockers.append(Point(x, z).buffer(5))
    blockers.append(Point(SPAWN[0], SPAWN[1]).buffer(8))
    # castle hill: no ordinary houses on the castle plateau slope
    blockers.append(Point(-190, -216).buffer(56))
    # cemetery behind the temple
    CEMETERY = Polygon([(-150, -280), (-60, -285), (-40, -250), (-60, -212), (-148, -212)])
    blockers.append(CEMETERY)
    inner = WALL_POLY.buffer(-16)
    blocked = unary_union(blockers)
    blocked_sq = blocked
    lots = []
    placed = []
    # Frontage lines: every street (both sides) and the edges of the squares (outer side only, facing in).
    lines = []
    for st in STREETS:
        if st["id"] in ("zamkowa", "podzamcze"):
            continue
        for i in range(len(st["pts"]) - 1):
            lines.append(dict(a=st["pts"][i], b=st["pts"][i + 1], half=st["w"] / 2, sides=(-1, 1), street=st["id"],
                              main=st["kind"] == "main"))
    for sq in SQUARES:
        if sq["id"] not in ("rynek", "placWschodni", "placPolnocny", "placZachodni", "placPoludniowy"):
            continue
        poly = Polygon(sq["poly"])
        pts = sq["poly"] + [sq["poly"][0]]
        for i in range(len(pts) - 1):
            (ax, az), (bx, bz) = pts[i], pts[i + 1]
            ln = math.hypot(bx - ax, bz - az)
            ux, uz = (bx - ax) / ln, (bz - az) / ln
            mx, mz = (ax + bx) / 2, (az + bz) / 2
            outside = 1 if not poly.contains(Point(mx - uz * 3, mz + ux * 3)) else -1
            lines.append(dict(a=(ax, az), b=(bx, bz), half=0.0, sides=(outside,), street=sq["id"], main=True,
                              square=True))
    for ln_ in lines:
        (ax, az), (bx, bz) = ln_["a"], ln_["b"]
        seg_len = math.hypot(bx - ax, bz - az)
        ux, uz = (bx - ax) / seg_len, (bz - az) / seg_len
        for side in ln_["sides"]:
            nx, nz = -uz * side, ux * side  # normal pointing to this side
            t = 2.0
            while t < seg_len - 6:
                dist = district_of(ax + ux * t + nx * 20, az + uz * t + nz * 20)
                style = dist["style"]
                if ln_.get("square"):
                    style = "burgher" if style != "patrician" else style
                if style == "cottage":
                    w = rng.choice([12, 13, 14, 15, 16])
                    d = rng.choice([12, 13, 14, 15])
                elif style == "craft":
                    w = rng.choice([13, 14, 15, 16, 18])
                    d = rng.choice([15, 16, 18])
                elif style == "patrician":
                    w = rng.choice([15, 16, 18, 20])
                    d = rng.choice([18, 20, 22])
                else:
                    w = rng.choice([12, 13, 14, 15, 16, 17])
                    d = rng.choice([16, 17, 18, 20])
                if t + w > seg_len - 2:
                    break
                off = ln_["half"] + 2.0 + d / 2
                cx = ax + ux * (t + w / 2) + nx * off
                cz = az + uz * (t + w / 2) + nz * off
                rot = rot_for_front(-nx, -nz)
                cx, cz = round(cx, 1), round(cz, 1)
                poly = rect_poly(cx, cz, w, d, rot)
                ok = inner.contains(poly) and not poly.intersects(blocked if not ln_.get("square") else blocked_sq)
                if ok:
                    for q in placed:
                        if poly.intersection(q).area > 0.05:
                            ok = False
                            break
                if ok:
                    hs = [height_at(px, pz) for px, pz in list(poly.exterior.coords)[:4]] + [height_at(cx, cz)]
                    if max(hs) - min(hs) > (7.0 if style == "patrician" else 5.0):
                        ok = False
                if ok:
                    placed.append(poly)
                    if ln_.get("square"):
                        floors = rng.choice([3, 3, 3, 2])
                    elif style == "burgher":
                        floors = rng.choice([2, 2, 3, 3, 3]) if ln_["main"] else rng.choice([2, 2, 3])
                    elif style == "patrician":
                        floors = rng.choice([2, 3, 3])
                    elif style == "craft":
                        floors = rng.choice([1, 2, 2])
                    else:
                        floors = rng.choice([1, 1, 2])
                    kind = {"burgher": "townhouse", "patrician": "townhouse", "craft": "workshopHouse",
                            "cottage": "cottage"}[style]
                    lots.append(dict(id=f"h{len(lots) + 1:03d}", kind=kind, style=style, x=round(cx, 1),
                                     z=round(cz, 1), w=w, d=d, rot=rot, floors=floors,
                                     seed=rng.randint(1, 99999), street=ln_["street"],
                                     arcade=bool(ln_.get("square")) and ln_["street"] == "rynek"
                                     and rng.random() < 0.5))
                    t += w + (0 if style in ("burgher", "patrician") else rng.choice([0, 2, 4, 6]))
                else:
                    t += 3
    return lots, CEMETERY


LOTS, CEMETERY = generate_lots()

if __name__ == "__main__":
    print("lots", len(LOTS))
    from collections import Counter
    print(Counter(l["kind"] for l in LOTS))
    print(Counter(l["floors"] for l in LOTS))


# ---------------------------------------------------------------- retaining walls (derived, exported as data)
def _merge_samples(samples, kind, max_len=24.0):
    """samples: list of (x, z, top, bottom, parapet) along a line at ~2 stud spacing, None = gap."""
    segs = []
    run = []

    def flush():
        if len(run) >= 2:
            # split into pieces of <= max_len
            i = 0
            while i < len(run) - 1:
                j = i
                while j + 1 < len(run) and math.hypot(run[j + 1][0] - run[i][0], run[j + 1][1] - run[i][1]) <= max_len:
                    j += 1
                if j == i:
                    j = i + 1
                part = run[i:j + 1]
                segs.append(dict(kind=kind, x1=round(part[0][0], 1), z1=round(part[0][1], 1), x2=round(part[-1][0], 1),
                                 z2=round(part[-1][1], 1), top=round(max(s[2] for s in part), 1),
                                 bottom=round(min(s[3] for s in part), 1), parapet=any(s[4] for s in part)))
                i = j
        run.clear()

    for s_ in samples:
        if s_ is None:
            flush()
        else:
            run.append(s_)
    flush()
    return segs


def compute_retaining():
    walls = []
    city_inner = WALL_POLY.buffer(-5)
    for pl, poly in _plateau_polys:
        if pl["edge"] == "soft":
            continue
        pts = pl["poly"] + [pl["poly"][0]]
        for i in range(len(pts) - 1):
            (ax, az), (bx, bz) = pts[i], pts[i + 1]
            L = math.hypot(bx - ax, bz - az)
            ux, uz = (bx - ax) / L, (bz - az) / L
            nx_, nz_ = -uz, ux
            mx, mz = (ax + bx) / 2, (az + bz) / 2
            if poly.contains(Point(mx + nx_ * 2, mz + nz_ * 2)):
                nx_, nz_ = -nx_, -nz_
            n = max(2, int(L / 2))
            samples = []
            for k in range(n + 1):
                t = k / n * L
                px_, pz_ = ax + ux * t, az + uz * t
                ox, oz = px_ + nx_ * 3, pz_ + nz_ * 3
                if not city_inner.contains(Point(ox, oz)):
                    samples.append(None)
                    continue
                on_ramp = any(ramp_height(px_ + nx_ * o, pz_ + nz_ * o)[0] is not None for o in (-2, 0, 2, 4))
                if on_ramp:
                    samples.append(None)
                    continue
                h_out = min(height_at(ox, oz), height_at(px_ + nx_ * 1.5, pz_ + nz_ * 1.5))
                drop = pl["y"] - h_out
                if drop > 1.5:
                    # wall centre line sits 1.25 outside the plateau edge (thickness 2.5)
                    samples.append((px_ + nx_ * 1.25, pz_ + nz_ * 1.25, pl["y"] + (2.5 if drop > 4 else 0.3),
                                    h_out - 2, drop > 4))
                else:
                    samples.append(None)
            walls += _merge_samples(samples, "retaining" if pl["edge"] == "wall" else "cliff")
    for r in RAMPS:
        pts = r["pts"]
        for i in range(len(pts) - 1):
            (ax, az, ay), (bx, bz, by) = pts[i], pts[i + 1]
            L = math.hypot(bx - ax, bz - az)
            ux, uz = (bx - ax) / L, (bz - az) / L
            for side in (-1, 1):
                nx_, nz_ = -uz * side, ux * side
                n = max(2, int(L / 2))
                samples = []
                for k in range(n + 1):
                    t = k / n * L
                    cx, cz = ax + ux * t, az + uz * t
                    y = ay + (by - ay) * (t / L)
                    ox, oz = cx + nx_ * (r["w"] / 2 + 3), cz + nz_ * (r["w"] / 2 + 3)
                    if ramp_height(ox, oz)[0] is not None:
                        samples.append(None)
                        continue
                    h_o = height_at(ox, oz)
                    sx, sz = cx + nx_ * (r["w"] / 2 + 1.25), cz + nz_ * (r["w"] / 2 + 1.25)
                    if y - h_o > 1.2:  # embankment: wall from the low ground up to a balustrade above the road
                        samples.append((sx, sz, y + 2.2, h_o - 2, True))
                    elif h_o - y > 1.2:  # cutting: wall holds back the higher ground
                        samples.append((sx, sz, h_o + (2.5 if h_o - y > 4 else 0.3), y - 1, h_o - y > 4))
                    else:
                        samples.append(None)
                walls += _merge_samples(samples, "rampSide")
    for i, w in enumerate(walls):
        w["id"] = f"rw{i + 1:03d}"
    return walls


RETAINING = compute_retaining()
