import json, sys
src, out, x, z, r = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5])
lods = sys.argv[6].split(",") if len(sys.argv) > 6 else ["shell", "detail", "fine"]
d = json.load(open(src))
json.dump({"pieces": [p for p in d["pieces"] if (p["p"][0] - x) ** 2 + (p["p"][2] - z) ** 2 < r * r and p["lod"] in lods]}, open(out, "w"))
