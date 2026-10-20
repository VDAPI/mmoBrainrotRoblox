--!strict
-- W28: writes the city street lamps (Logic/TownLamps.place) into the `lamps` block of src/shared/Data/Town/city.luau.
-- Run from the repo root after a change of the city plan (streets, buildings, NPCs, signs, squares, bridges):
--   lune run tools/town_lamps.luau          rewrites the block and prints the count and the darkest street point
--   lune run tools/town_lamps.luau check    exit 1 when the block is out of date (= tests/town.spec)

local fs = require("@lune/fs")
local process = require("@lune/process")

local Town = require("../src/shared/Data/Town")
local TownLamps = require("../src/shared/Logic/TownLamps")

local PATH = "src/shared/Data/Town/city.luau"

local function fmt(v: number): string
	if v == math.floor(v) then
		return tostring(math.floor(v))
	end
	return string.format("%.1f", v)
end

local lamps = TownLamps.place(Town.city)
local lines = { "\tlamps = {" }
for _, l in lamps do
	table.insert(
		lines,
		string.format(
			'\t\t{ id = "%s", kind = "%s", x = %s, z = %s, rot = %s },',
			l.id,
			l.kind,
			fmt(l.x),
			fmt(l.z),
			fmt(l.rot or 0)
		)
	)
end
table.insert(lines, "\t},")
local block = table.concat(lines, "\n")

local source = fs.readFile(PATH)
local s, e = string.find(source, "\n\tlamps = {\n.-\n\t},", 1)
assert(s and e, "city.luau: no lamps block")
local current = string.sub(source, s + 1, e)

local worst = 0
for _, p in TownLamps.samples(Town.city) do
	worst = math.max(worst, TownLamps.nearest(lamps, p[1], p[2]))
end

if process.args[1] == "check" then
	if current ~= block then
		print("city.luau lamps are out of date: lune run tools/town_lamps.luau")
		process.exit(1)
	end
	print(`lamps up to date ({#lamps})`)
	return
end

fs.writeFile(PATH, string.sub(source, 1, s) .. block .. string.sub(source, e + 1))
print(`{#lamps} lamps written, darkest street point {string.format("%.1f", worst)} studs from a lamp`)
