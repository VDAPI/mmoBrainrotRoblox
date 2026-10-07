# Renders every icon on a 192 px canvas (32 px margin) and reports pixels outside the 128 px cell.
import json, os, subprocess, sys
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))


def check(icons, outdir):
    outdir = os.path.abspath(outdir)
    os.makedirs(outdir, exist_ok=True)
    html = ['<html><body style="margin:0;background:transparent">']
    per = 5
    for i, ic in enumerate(icons):
        svg = ic.full_svg(f"f{i}").replace('width="128" height="128" viewBox="0 0 128 128"',
                                            'width="192" height="192" viewBox="-32 -32 192 192"')
        x, y = (i % per) * 192, (i // per) * 192
        html.append(f'<div style="position:absolute;left:{x}px;top:{y}px;width:192px;height:192px">{svg}</div>')
    html.append("</body></html>")
    hp = os.path.join(outdir, "fit.html")
    open(hp, "w").write("".join(html))
    rows = (len(icons) + per - 1) // per
    js = f"""const {{ chromium }} = require('playwright');
(async () => {{ const b = await chromium.launch(); const p = await b.newPage({{ viewport: {{ width: {per * 192}, height: {rows * 192} }} }});
await p.goto(require('url').pathToFileURL({json.dumps(hp)}).href); await p.screenshot({{ path: {json.dumps(os.path.join(outdir, 'fit.png'))}, omitBackground: true }}); await b.close(); }})();"""
    open(os.path.join(outdir, "fit.js"), "w").write(js)
    env = dict(os.environ)
    env["NODE_PATH"] = subprocess.check_output("npm root -g", shell=True).decode().strip()
    subprocess.check_call(["node", os.path.join(outdir, "fit.js")], env=env)
    img = Image.open(os.path.join(outdir, "fit.png")).convert("RGBA")
    a = img.split()[3]
    bad = []
    for i, ic in enumerate(icons):
        x0, y0 = (i % per) * 192, (i // per) * 192
        cell = a.crop((x0, y0, x0 + 192, y0 + 192))
        px = cell.load()
        out = 0
        minx, miny, maxx, maxy = 999, 999, -1, -1
        for yy in range(192):
            for xx in range(192):
                if px[xx, yy] > 40:
                    minx, miny, maxx, maxy = min(minx, xx), min(miny, yy), max(maxx, xx), max(maxy, yy)
                    if not (32 <= xx < 160 and 32 <= yy < 160):
                        out += 1
        bbox = (minx - 32, miny - 32, maxx - 32, maxy - 32)
        if out:
            bad.append((ic.key, out, bbox))
        else:
            # report how much margin is left
            pass
    return bad
