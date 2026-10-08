"""Writes the arrival points computed by tools/arrivals.luau into Data/Areas/<map>.luau (S26).

    python tools/arrivals_apply.py

Run after changing areas, roads, water or a map's terrain: tests/areaarrival.spec requires the stored `arrive`
points to match Logic/AreaArrival. Prints the areas whose point changed.
"""
import re
import subprocess

out = subprocess.run(["lune", "run", "tools/arrivals.luau"], capture_output=True, text=True, check=True).stdout
values = {}
for line in out.splitlines():
    m = re.match(r"(\w+) (\w+)\s+\{ x = (-?\d+), z = (-?\d+) \}", line)
    if m:
        values[(m.group(1), m.group(2))] = (m.group(3), m.group(4))
    if "changed" in line:
        print(line)
for map_id in sorted({k[0] for k in values}):
    path = f"src/shared/Data/Areas/{map_id}.luau"
    text = open(path, encoding="utf-8").read()
    lines, current = [], None
    for line in text.split("\n"):
        m = re.search(r'id = "(\w+)"', line)
        if m:
            current = m.group(1)
        if "arrive = {" in line and current and (map_id, current) in values:
            x, z = values[(map_id, current)]
            line = re.sub(r"arrive = \{ x = -?\d+, z = -?\d+ \}", f"arrive = {{ x = {x}, z = {z} }}", line)
        lines.append(line)
    # newline="\n": keep LF line endings on Windows too
    open(path, "w", encoding="utf-8", newline="\n").write("\n".join(lines))
