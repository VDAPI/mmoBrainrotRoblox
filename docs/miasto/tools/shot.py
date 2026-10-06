"""Close-up of one lot (by id) from the front-left at a 3/4 angle.
python3 shot.py h014 out.png [dist] [side]     (needs `lune` on PATH; run from docs/miasto/tools)"""
import sys, math, subprocess, os
import plan as P
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
lid, out = sys.argv[1], sys.argv[2]
dist = float(sys.argv[3]) if len(sys.argv) > 3 else 30
side = float(sys.argv[4]) if len(sys.argv) > 4 else 0.6
lot = next(l for l in P.LOTS if l["id"] == lid)
fx, fz = P.front_of(lot["rot"])
rx, rz = -fz, fx
y = P.height_at(lot["x"], lot["z"])
ex = lot["x"] + fx * dist + rx * dist * side
ez = lot["z"] + fz * dist + rz * dist * side
pad = max(lot["w"], lot["d"]) / 2 + 3
tmp = os.path.join(HERE, "p_shot.json")
subprocess.run(["lune", "run", "tools/dump.luau", tmp, str(lot["x"] - pad), str(lot["z"] - pad),
                str(lot["x"] + pad), str(lot["z"] + pad)], cwd=ROOT, check=True)
subprocess.run(["python3", os.path.join(HERE, "render3d.py"), tmp, out, "--eye", str(ex), str(y + 9), str(ez), "--look",
                str(lot["x"]), str(y + 10), str(lot["z"]), "--fov", "55", "--size", "800x700", "--terrain",
                str(lot["x"] - 40), str(lot["z"] - 40), str(lot["x"] + 40), str(lot["z"] + 40), "--step", "2"], cwd=HERE, check=True)
os.remove(tmp)
