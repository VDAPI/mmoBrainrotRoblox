--!strict
-- W29: performance report of every generated map (tools/PerfCells), the numbers behind tests/perf.spec.luau.
--   lune run tools/perf_report.luau            every map: totals, worst 128-stud cell, client parts and lights
--   lune run tools/perf_report.luau <map>      one map, plus its 12 heaviest cells and the parts by Build tag
-- Columns: shell = server parts (streamed), client = shell + detail + fine, light = PointLights, emit = particle
-- emitters the client adds, kit = kit model slots; "worst" = the heaviest 128-stud cell (cx, cz); "parts L/M/H" = the
-- most parts a client holds around one spot at graphics level low / medium / high with the default "World detail"
-- (mid); "on L/M/H" = the most lights shining at once there (light budgets: Config.Graphics.levels[*].lights,
-- Config.RegionLights, Config.CaveLights) and, after "|", what shone before W29 (every free light within the radius).
-- "!" marks a number over its budget in tests/PerfBudgets.luau.

local fs = require("@lune/fs")
local process = require("@lune/process")

local Budgets = require("../tests/PerfBudgets")
local PerfCells = require("./PerfCells")

local only = process.args[1]

local function pad(text: any, width: number): string
	local s = tostring(text)
	return string.rep(" ", math.max(0, width - #s)) .. s
end

local function mark(value: number, cap: number?): string
	return if cap and value > cap then `{value}!` else tostring(value)
end

local function cellText(n: number, cell: PerfCells.Cell, cap: number?): string
	return `{mark(n, cap)}({cell.cx},{cell.cz})`
end

print(table.concat({
	pad("map", 21),
	pad("builds", 6),
	pad("shell", 6),
	pad("client", 6),
	pad("light", 5),
	pad("emit", 4),
	pad("kit", 5),
	pad("worst shell", 13),
	pad("worst client", 15),
	pad("worst light", 12),
	pad("worst emit", 11),
	pad("parts L/M/H", 19),
	"  on L/M/H | before",
}, " "))
for _, entry in PerfCells.maps() do
	if only and entry.id ~= only then
		continue
	end
	local r = PerfCells.report(entry.id)
	local b = Budgets.of(entry.id)
	local t = r.totals
	local w = r.worst
	local parts = {}
	local on = {}
	local before = {}
	for _, q in { "low", "medium", "high" } do
		table.insert(parts, mark(PerfCells.clientParts(r, q, "mid"), if q == "low" then b.lowParts else nil))
		table.insert(on, mark(PerfCells.lightsOn(r, q, "mid"), Budgets.LIGHTS_ON[q]))
		table.insert(before, tostring(PerfCells.lightsBefore(r, "mid")))
	end
	print(table.concat({
		pad(entry.id, 21),
		pad(r.builds, 6),
		pad(mark(t.shell, b.shell), 6),
		pad(t.shell + t.detail + t.fine, 6),
		pad(t.lights, 5),
		pad(t.emitters, 4),
		pad(t.kits, 5),
		pad(cellText(w.shell.shell, w.shell, b.cellShell), 13),
		pad(cellText(w.client.shell + w.client.detail + w.client.fine, w.client, b.cellClient), 15),
		pad(cellText(w.lights.lights, w.lights, b.cellLights), 12),
		pad(cellText(w.emitters.emitters, w.emitters, b.cellEmitters), 11),
		pad(table.concat(parts, "/"), 19),
		`  {table.concat(on, "/")} | {before[1]}`,
	}, " "))
	if only then
		local list = {}
		for _, cell in r.cells do
			table.insert(list, cell)
		end
		table.sort(list, function(a, c)
			return a.shell + a.detail + a.fine > c.shell + c.detail + c.fine
		end)
		print("\nheaviest cells (cx, cz: shell / detail / fine, lights, emitters, kit slots)")
		for i = 1, math.min(12, #list) do
			local c = list[i]
			print(
				`  ({c.cx},{c.cz}): {c.shell} / {c.detail} / {c.fine}, {c.lights} lights, {c.emitters} emitters, {c.kits} kit`
			)
		end
		print("\nby Build tag (parts, lights)")
		local tags = {}
		for tag in r.byTag do
			table.insert(tags, tag)
		end
		table.sort(tags)
		for _, tag in tags do
			print(`  {tag}: {r.byTag[tag].parts}, {r.byTag[tag].lights}`)
		end
	end
end

if not only then
	local camp = PerfCells.invasionCamp(fs.readFile("src/server/World/InvasionCamp.luau"))
	print(`\ninvasion camp (one zone): {camp.parts} parts, {camp.lights} lights, {camp.emitters} emitters`)
end
