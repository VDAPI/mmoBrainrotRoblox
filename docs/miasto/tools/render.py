import math, sys
from PIL import Image, ImageDraw, ImageFont
import plan as P
import extras as E

S = 2.0  # px per stud
W = int(P.SIZE * S)
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
FONTB = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
f_small = ImageFont.truetype(FONT, 13)
f_mid = ImageFont.truetype(FONTB, 15)
f_big = ImageFont.truetype(FONTB, 22)


def px(x, z):
    return ((x + P.HALF) * S, (z + P.HALF) * S)


def poly_px(poly):
    return [px(x, z) for x, z in poly]


def render(path, step=4):
    img = Image.new("RGB", (W, W), (80, 100, 60))
    d = ImageDraw.Draw(img)
    # hillshade + base colour by height
    hs = {}
    n = int(P.SIZE / step)
    for i in range(n + 1):
        for j in range(n + 1):
            x = -P.HALF + i * step
            z = -P.HALF + j * step
            hs[(i, j)] = P.height_at(x, z)
    for i in range(n):
        for j in range(n):
            h = hs[(i, j)]
            dzx = hs[(i + 1, j)] - h
            dzz = hs[(i, j + 1)] - h
            shade = max(0.55, min(1.25, 1.0 - (dzx * 0.6 + dzz * 0.9) / step * 1.6))
            inside = P.WALL_POLY.contains(P.Point(-P.HALF + i * step + 2, -P.HALF + j * step + 2))
            if h < P.RIVER["water"]:
                c = (58, 100, 150)
            elif inside:
                base = (96 + h * 2.2, 118 + h * 1.4, 70 + h * 0.8)
                c = base
            else:
                base = (92 + h * 1.5, 116 + h * 1.0, 64)
                c = base
            c = tuple(int(max(0, min(255, v * shade))) for v in c)
            x0, z0 = px(-P.HALF + i * step, -P.HALF + j * step)
            d.rectangle([x0, z0, x0 + step * S, z0 + step * S], fill=c)
    # outside: fields, roads, farms, windmill
    crop_col = {"wheat": (196, 170, 90), "barley": (170, 160, 96), "ploughed": (110, 84, 60), "fallow": (120, 140, 80),
                "cabbage": (90, 130, 70), "flax": (130, 150, 170)}
    for f in E.FIELDS:
        d.polygon(poly_px(f["poly"]), fill=crop_col[f["crop"]], outline=(70, 90, 50))
    for r in E.ROADS_OUT:
        d.line([px(x, z) for x, z in r["pts"]], fill=(130, 110, 80), width=int(r["w"] * S))
        b = r["bridge"]
        poly = P.rect_poly(b["x"], b["z"], b["w"], b["len"], b["rot"])
        d.polygon(poly_px(list(poly.exterior.coords)), fill=(120, 92, 60), outline=(40, 30, 20))
    for spec in E.FARMS:
        a = px(spec["x"], spec["z"])
        d.rectangle([a[0] - 14, a[1] - 10, a[0] + 14, a[1] + 10], fill=(128, 100, 62), outline=(40, 26, 20))
    a = px(E.WINDMILL["x"], E.WINDMILL["z"])
    d.ellipse([a[0] - 9, a[1] - 9, a[0] + 9, a[1] + 9], fill=(200, 190, 170), outline=(40, 30, 20))
    d.line([(a[0] - 16, a[1] - 16), (a[0] + 16, a[1] + 16)], fill=(60, 40, 30), width=3)
    d.line([(a[0] - 16, a[1] + 16), (a[0] + 16, a[1] - 16)], fill=(60, 40, 30), width=3)
    # forest band marker
    fs = E.FOREST_START
    d.rectangle([*px(-fs, -fs), *px(fs, fs)], outline=(40, 70, 40), width=3)
    # gardens
    gcol = {"orchard": (96, 140, 70), "yard": (150, 128, 96), "backGarden": (120, 150, 90), "vegetables": (110, 120, 60),
            "formal": (70, 120, 80), "paddock": (170, 150, 100), "herbs": (130, 160, 110), "vineyard": (120, 90, 110),
            "trainingYard": (170, 140, 100), "pasture": (140, 170, 100), "meadow": (110, 150, 90)}
    for g in E.GARDENS:
        d.polygon(poly_px(g["poly"]), fill=gcol[g["kind"]], outline=(90, 70, 50))
    # squares
    for sq in P.SQUARES:
        col = (178, 168, 146) if sq["mat"] == "Limestone" else (140, 132, 118)
        d.polygon(poly_px(sq["poly"]), fill=col)
    # streets
    for st in P.STREETS:
        col = {"main": (150, 140, 124), "lane": (138, 118, 88), "alley": (128, 108, 80)}[st["kind"]]
        poly = P.street_poly(st)
        d.polygon(poly_px(list(poly.exterior.coords)), fill=col)
    # ramps and stairs
    from shapely.geometry import LineString as _LS
    for r in P.RAMPS:
        line = _LS([(x, z) for x, z, _ in r["pts"]])
        poly = line.buffer(r["w"] / 2, cap_style=2, join_style=2)
        d.polygon(poly_px(list(poly.exterior.coords)), fill=(160, 150, 132) if not r.get("stairs") else (190, 182, 160))
        if r.get("stairs"):
            L = line.length
            for k in range(1, int(L)):
                q = line.interpolate(k)
                q2 = line.interpolate(min(L, k + 0.01))
                ux, uz = (q2.x - q.x) / 0.01, (q2.y - q.y) / 0.01
                a1 = px(q.x - uz * r["w"] / 2, q.y + ux * r["w"] / 2)
                a2 = px(q.x + uz * r["w"] / 2, q.y - ux * r["w"] / 2)
                d.line([a1, a2], fill=(120, 110, 96), width=1)
        mid = line.interpolate(0.5, normalized=True)
        d.text(px(mid.x, mid.y), r["name"], font=f_small, fill=(255, 255, 255), anchor="mm", stroke_width=2,
               stroke_fill=(60, 50, 40))
    # river water polygon
    water = P.RIVER_LINE.buffer(P.RIVER["width"] / 2 - 1, cap_style=2)
    d.polygon(poly_px(list(water.exterior.coords)), fill=(58, 100, 150))
    # bridges
    for b in P.BRIDGES:
        poly = P.rect_poly(b["x"], b["z"], b["w"], b["len"], b["rot"])
        d.polygon(poly_px(list(poly.exterior.coords)), fill=(150, 140, 124) if b["kind"] == "stone" else (120, 92, 60),
                  outline=(40, 30, 20))
    # cemetery
    d.polygon(poly_px(list(P.CEMETERY.exterior.coords)), fill=(84, 104, 70), outline=(60, 60, 60))
    # lots
    for l in P.LOTS:
        poly = P.rect_poly(l["x"], l["z"], l["w"], l["d"], l["rot"])
        col = {"townhouse": (150, 70, 52), "cottage": (128, 100, 62), "workshopHouse": (110, 80, 60)}[l["kind"]]
        if l["floors"] == 3:
            col = (130, 56, 44)
        d.polygon(poly_px(list(poly.exterior.coords)), fill=col, outline=(40, 26, 20))
        # front marker
        fx, fz = P.front_of(l["rot"])
        a = px(l["x"] + fx * (l["d"] / 2 - 1), l["z"] + fz * (l["d"] / 2 - 1))
        d.ellipse([a[0] - 2, a[1] - 2, a[0] + 2, a[1] + 2], fill=(240, 220, 160))
    # specials
    for sp in P.SPECIALS:
        if sp["kind"] == "arena":
            a = P.ARENA
            o = a["half"] + a["stands"]
            d.rectangle([*px(sp["x"] - o, sp["z"] - o), *px(sp["x"] + o, sp["z"] + o)], fill=(120, 92, 60),
                        outline=(40, 30, 20))
            d.rectangle([*px(sp["x"] - a["half"], sp["z"] - a["half"]), *px(sp["x"] + a["half"], sp["z"] + a["half"])],
                        fill=(200, 176, 128))
        else:
            poly = P.rect_poly(sp["x"], sp["z"], sp["w"], sp["d"], sp["rot"])
            d.polygon(poly_px(list(poly.exterior.coords)), fill=(70, 80, 120), outline=(240, 230, 200))
            fx, fz = P.front_of(sp["rot"])
            a = px(sp["x"] + fx * (sp["d"] / 2 - 1.5), sp["z"] + fz * (sp["d"] / 2 - 1.5))
            d.ellipse([a[0] - 4, a[1] - 4, a[0] + 4, a[1] + 4], fill=(255, 210, 90))
        cx, cz = px(sp["x"], sp["z"])
        d.text((cx, cz), sp["name"], font=f_mid, fill=(255, 255, 255), anchor="mm", stroke_width=3,
               stroke_fill=(0, 0, 0))
    # stalls
    for s in P.STALLS:
        poly = P.rect_poly(s["x"], s["z"], 10, 5, s["rot"])
        d.polygon(poly_px(list(poly.exterior.coords)), fill=(200, 120, 80), outline=(30, 20, 10))
    # fountain & wells
    fx_, fz_ = px(*P.FOUNTAIN)
    d.ellipse([fx_ - 22, fz_ - 22, fx_ + 22, fz_ + 22], fill=(80, 130, 190), outline=(220, 220, 220), width=3)
    for wx, wz in P.WELLS:
        a = px(wx, wz)
        d.ellipse([a[0] - 6, a[1] - 6, a[0] + 6, a[1] + 6], fill=(100, 140, 190), outline=(30, 30, 30))
    # retaining walls
    for w in P.RETAINING:
        col = {"retaining": (60, 58, 56), "cliff": (95, 85, 80), "rampSide": (80, 74, 70)}[w["kind"]]
        d.line([px(w["x1"], w["z1"]), px(w["x2"], w["z2"])], fill=col, width=5 if w["kind"] != "rampSide" else 3)
    # walls
    wp = P.WALL + [P.WALL[0]]
    d.line([px(*p) for p in wp], fill=(70, 66, 62), width=int(7 * S))
    for x, z in P.WALL:
        a = px(x, z)
        d.ellipse([a[0] - 14, a[1] - 14, a[0] + 14, a[1] + 14], fill=(90, 86, 80), outline=(30, 30, 30))
    for g in P.GATES:
        a = px(g["x"], g["z"])
        d.rectangle([a[0] - 22, a[1] - 22, a[0] + 22, a[1] + 22], fill=(110, 90, 160), outline=(255, 255, 255), width=2)
        d.text(a, g["target"], font=f_mid, fill=(255, 255, 255), anchor="mm", stroke_width=3, stroke_fill=(0, 0, 0))
        b = px(*g["arrive"])
        d.ellipse([b[0] - 5, b[1] - 5, b[0] + 5, b[1] + 5], fill=(180, 160, 255))
    for l in E.LAMPS:
        a = px(l["x"], l["z"])
        d.ellipse([a[0] - 3, a[1] - 3, a[0] + 3, a[1] + 3], fill=(255, 200, 80), outline=(0, 0, 0))
    # npcs
    for name, (x, z, f) in P.NPCS.items():
        a = px(x, z)
        d.ellipse([a[0] - 6, a[1] - 6, a[0] + 6, a[1] + 6], fill=(255, 230, 60), outline=(0, 0, 0))
        r = math.radians(f)
        b = (a[0] - math.sin(r) * 14, a[1] - math.cos(r) * 14)
        d.line([a, b], fill=(0, 0, 0), width=3)
        d.text((a[0] + 9, a[1] - 9), name, font=f_small, fill=(255, 255, 180), stroke_width=2, stroke_fill=(0, 0, 0))
    a = px(P.SPAWN[0], P.SPAWN[1])
    d.ellipse([a[0] - 8, a[1] - 8, a[0] + 8, a[1] + 8], fill=(80, 255, 120), outline=(0, 0, 0), width=2)
    d.text((a[0] + 10, a[1] + 4), "SPAWN", font=f_mid, fill=(120, 255, 140), stroke_width=3, stroke_fill=(0, 0, 0))
    # district names
    for dd in P.DISTRICTS:
        poly = P.Polygon(dd["poly"]).intersection(P.WALL_POLY)
        c = poly.representative_point()
    # street names
    for st in P.STREETS:
        if st["kind"] == "main":
            pts = st["pts"]
            i = len(pts) // 2 - 1 if len(pts) > 2 else 0
            mx, mz = (pts[i][0] + pts[i + 1][0]) / 2, (pts[i][1] + pts[i + 1][1]) / 2
            d.text(px(mx, mz), st["name"], font=f_small, fill=(255, 255, 255), anchor="mm", stroke_width=2,
                   stroke_fill=(60, 50, 40))
    # grid
    for v in range(-400, 401, 100):
        d.text(px(v, -395), str(v), font=f_small, fill=(255, 255, 255))
        d.text(px(-398, v), str(v), font=f_small, fill=(255, 255, 255))
    d.text((20, W - 40), "Vaelthorn — plan miasta (N u góry, 1 kratka = 100 st.)", font=f_big, fill=(255, 255, 255),
           stroke_width=3, stroke_fill=(0, 0, 0))
    img.save(path)


if __name__ == "__main__":
    render(sys.argv[1] if len(sys.argv) > 1 else "plan.png")
