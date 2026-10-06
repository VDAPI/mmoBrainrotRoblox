"""Render every special building from its front-left. python3 spshots.py pieces.json outdir [ids]"""
import json, math, os, subprocess, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import plan as P
src, outdir = sys.argv[1], sys.argv[2]
only = sys.argv[3].split(",") if len(sys.argv) > 3 else None
os.makedirs(outdir, exist_ok=True)
data = json.load(open(src))
for sp in P.SPECIALS:
    if only and sp["id"] not in only:
        continue
    x, z, r = sp["x"], sp["z"], math.radians(sp["rot"])
    fx, fz = -math.sin(r), -math.cos(r)
    size = max(sp["w"], sp["d"])
    if sp["kind"] == "arena":
        size = 108
    if sp["id"] == "donzon":
        size = 100
    dist = size * 1.25 + 20
    # front-left three-quarter view
    lx, lz = fz, -fx
    ex, ez = x + fx * dist + lx * dist * 0.6, z + fz * dist + lz * dist * 0.6
    y = P.height_at(x, z)
    sub = {"pieces": [p for p in data["pieces"] if (p["p"][0] - x) ** 2 + (p["p"][2] - z) ** 2 < (size * 0.9 + 15) ** 2]}
    tmp = os.path.join(outdir, sp["id"] + ".json")
    json.dump(sub, open(tmp, "w"))
    t = size * 0.75 + 10
    cmd = ["python3", os.path.join(os.path.dirname(os.path.abspath(__file__)), "render3d.py"), tmp, os.path.join(outdir, sp["id"] + ".png"),
           "--eye", str(ex), str(y + size * 0.45 + 8), str(ez), "--look", str(x), str(y + size * 0.15), str(z),
           "--fov", "50", "--size", "900x620", "--terrain", str(x - t), str(z - t), str(x + t), str(z + t), "--step", "3"]
    subprocess.run(cmd, cwd=os.path.dirname(os.path.abspath(__file__)), check=True)
    os.remove(tmp)
    print(sp["id"])
