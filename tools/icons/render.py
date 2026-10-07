# Renders icons into 1024x1024 atlases (128 px cells) and builds the index + previews.
import json, os, subprocess, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
CELL, GRID = 128, 8


def cells_of(icons):
    cells = []
    for ic in icons:
        for layer in ic.layers():
            cells.append((ic, layer))
    return cells


def render(icons, outdir, prefix="atlas"):
    outdir = os.path.abspath(outdir)
    os.makedirs(outdir, exist_ok=True)
    cells = cells_of(icons)
    pages = [cells[i:i + GRID * GRID] for i in range(0, len(cells), GRID * GRID)]
    args = []
    index = {}
    for pi, page in enumerate(pages):
        html = ['<html><head><meta charset="utf-8"><style>html,body{margin:0;background:transparent}'
                '.c{position:absolute;width:128px;height:128px;overflow:hidden}</style></head><body>']
        for ci, (ic, layer) in enumerate(page):
            x, y = (ci % GRID) * CELL, (ci // GRID) * CELL
            html.append(f'<div class="c" style="left:{x}px;top:{y}px">{ic.layer_svg(layer, f"p{pi}c{ci}")}</div>')
            index.setdefault(ic.key, {"layers": [], "accent": ic.accent})
            index[ic.key]["layers"].append({"sheet": pi + 1, "x": x, "y": y, "layer": layer})
        html.append("</body></html>")
        hp = os.path.join(outdir, f"{prefix}_{pi + 1}.html")
        open(hp, "w").write("".join(html))
        args += [hp, os.path.join(outdir, f"{prefix}_{pi + 1}.png")]
    env = dict(os.environ)
    env["NODE_PATH"] = subprocess.check_output("npm root -g", shell=True).decode().strip()
    subprocess.check_call(["node", os.path.join(HERE, "atlas.js"), *args], env=env)
    for i in range(0, len(args), 2):
        os.remove(args[i])
    return index, len(pages)


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def tinted(img, color):
    if color is None:
        return img
    r, g, b = hexrgb(color)
    px = img.split()
    R = px[0].point(lambda v: v * r // 255)
    G = px[1].point(lambda v: v * g // 255)
    B = px[2].point(lambda v: v * b // 255)
    return Image.merge("RGBA", (R, G, B, px[3]))


def compose(index, sheets, key, tier=None, accent=None):
    out = Image.new("RGBA", (CELL, CELL), (0, 0, 0, 0))
    for L in index[key]["layers"]:
        img = sheets[L["sheet"]].crop((L["x"], L["y"], L["x"] + CELL, L["y"] + CELL))
        if L["layer"] == "m":
            img = tinted(img, tier)
        elif L["layer"] == "a":
            img = tinted(img, accent or index[key].get("accent") or "#ffffff")
        out = Image.alpha_composite(out, img)
    return out
