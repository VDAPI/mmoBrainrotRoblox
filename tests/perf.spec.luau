--!strict
-- W29: part, light and emitter budgets of every generated map (tools/PerfCells, tests/PerfBudgets) and what each
-- graphics level cuts (Logic/GraphicsLevel).
local fs = require("@lune/fs")

local Config = require("../src/shared/Config")
local GraphicsLevel = require("../src/shared/Logic/GraphicsLevel")
local PerfBudgets = require("./PerfBudgets")
local PerfCells = require("../tools/PerfCells")
local T = require("./Test")

local reports: { [string]: PerfCells.Report } = {}
local function report(id: string): PerfCells.Report
	local r = reports[id]
	if not r then
		r = PerfCells.report(id)
		reports[id] = r
	end
	return r :: PerfCells.Report
end

T.describe("Map budgets per 128-stud cell (W29)", function()
	T.it("every generated map has a budget and every budget a map", function()
		local seen: { [string]: boolean } = {}
		for _, entry in PerfCells.maps() do
			seen[entry.id] = true
			if not PerfBudgets.of(entry.id) then
				error(`no budget for {entry.id} in tests/PerfBudgets.luau (lune run tools/perf_report.luau)`)
			end
		end
		for _, id in PerfBudgets.ids() do
			if not seen[id] then
				error(`budget for {id}, which is not a generated map`)
			end
		end
	end)

	T.it("keeps every map within its parts, lights and emitters", function()
		local over = {}
		for _, entry in PerfCells.maps() do
			local r = report(entry.id)
			local b = PerfBudgets.of(entry.id)
			local w = r.worst
			local checks = {
				{ "shell", r.totals.shell, b.shell },
				{ "cellShell", w.shell.shell, b.cellShell },
				{ "cellClient", w.client.shell + w.client.detail + w.client.fine, b.cellClient },
				{ "cellLights", w.lights.lights, b.cellLights },
				{ "cellEmitters", w.emitters.emitters, b.cellEmitters },
				{ "lowParts", PerfCells.clientParts(r, "low", "mid"), b.lowParts },
			}
			for _, c in checks do
				if (c[2] :: number) > (c[3] :: number) then
					table.insert(over, `{entry.id}.{c[1]} {c[2]} > {c[3]}`)
				end
			end
		end
		if #over > 0 then
			error(`over budget (tools/perf_report.luau): {table.concat(over, ", ")}`)
		end
	end)

	T.it("keeps the lights shining at once within the budget of each graphics level", function()
		for _, entry in PerfCells.maps() do
			local r = report(entry.id)
			for _, q in { "low", "medium", "high" } do
				for _, decor in { "low", "mid", "high" } do
					local on = PerfCells.lightsOn(r, q, decor)
					if on > (PerfBudgets.LIGHTS_ON :: any)[q] then
						error(`{entry.id} at {q} / {decor}: {on} lights on > {(PerfBudgets.LIGHTS_ON :: any)[q]}`)
					end
				end
			end
		end
	end)

	T.it("the city at night lit far fewer lamps before the light budget than a phone lights now", function()
		local r = report("city")
		T.expect(PerfCells.lightsBefore(r, "mid") > 100).toBe(true)
		T.expect(PerfCells.lightsOn(r, "low", "mid") <= 16).toBe(true)
	end)

	T.it("low quality holds fewer parts than medium and high on every big map", function()
		for _, id in { "city", "meadows", "duskwood", "ashen", "frostpeak" } do
			local r = report(id)
			local low = PerfCells.clientParts(r, "low", "mid")
			local high = PerfCells.clientParts(r, "high", "mid")
			if not (low < high) then
				error(`{id}: low {low} >= high {high}`)
			end
		end
		-- the forest of Duskwood is mostly filler trees: low keeps well under 60% of what high builds
		local r = report("duskwood")
		T.expect(PerfCells.clientParts(r, "low", "mid") < PerfCells.clientParts(r, "high", "mid") * 0.6).toBe(true)
	end)

	T.it("an Invasion camp stays within its budget", function()
		local camp = PerfCells.invasionCamp(fs.readFile("src/server/World/InvasionCamp.luau"))
		T.expect(camp.parts > 0).toBe(true)
		T.expect(camp.parts <= PerfBudgets.INVASION_CAMP.parts).toBe(true)
		T.expect(camp.lights <= PerfBudgets.INVASION_CAMP.lights).toBe(true)
		T.expect(camp.emitters <= PerfBudgets.INVASION_CAMP.emitters).toBe(true)
	end)
end)

T.describe("Graphics levels (W29, Logic/GraphicsLevel)", function()
	T.it("low cuts every cost below medium and high", function()
		local low, medium, high = GraphicsLevel.get("low"), GraphicsLevel.get("medium"), GraphicsLevel.get("high")
		T.expect(low.particles <= 1 / 3 + 1e-9).toBe(true)
		T.expect(low.shadows).toBe(false)
		T.expect(low.bloom).toBe(0)
		T.expect(low.sunRays).toBe(false)
		T.expect(low.farBlur).toBe(false)
		T.expect(low.motion).toBe(false)
		T.expect(low.decor < medium.decor and medium.decor <= high.decor).toBe(true)
		T.expect(low.fill < 1 and low.under < medium.under).toBe(true)
		T.expect((low.lights :: number) <= 12).toBe(true)
		T.expect((low.lights :: number) < (medium.lights :: number)).toBe(true)
		T.expect(low.chevrons < high.chevrons).toBe(true)
		T.expect(low.plateEvery > high.plateEvery).toBe(true)
		T.expect(low.fxRadius < high.fxRadius).toBe(true)
		T.expect(GraphicsLevel.get("nonsense")).toBe(GraphicsLevel.get(Config.Graphics.default))
	end)

	T.it("low quality caps World detail at low, other levels keep the setting", function()
		T.expect(GraphicsLevel.detail("low", "high")).toBe("low")
		T.expect(GraphicsLevel.detail("low", nil)).toBe("low")
		T.expect(GraphicsLevel.detail("medium", "high")).toBe("high")
		T.expect(GraphicsLevel.detail("high", nil)).toBe("mid")
		T.expect(GraphicsLevel.detail("high", "low")).toBe("low")
	end)

	T.it("keeps a subset of the decorations: the first tries of the same layout", function()
		T.expect(GraphicsLevel.decorTries("high", 44)).toBe(44)
		T.expect(GraphicsLevel.decorTries("low", 44)).toBe(22)
		T.expect(GraphicsLevel.decorTries("medium", 30) < 30).toBe(true)
	end)

	T.it("thins filler trees and undergrowth by position, never server slots", function()
		local trees, unders, n = 0, 0, 2000
		for i = 1, n do
			local x, z = (i * 37.3) % 1600 - 800, (i * 91.7) % 1600 - 800
			if GraphicsLevel.keepSlot("low", "tree:oak", "detail", x, z) then
				trees += 1
			end
			if GraphicsLevel.keepSlot("low", "under:fern", "detail", x, z) then
				unders += 1
			end
			T.expect(GraphicsLevel.keepSlot("low", "tree:oak", "shell", x, z)).toBe(true)
			T.expect(GraphicsLevel.keepSlot("high", "under:fern", "detail", x, z)).toBe(true)
			T.expect(GraphicsLevel.keepSlot("low", "landmark:tower", "detail", x, z)).toBe(true)
			-- the same answer on every machine
			T.expect(GraphicsLevel.keepSlot("low", "tree:oak", "detail", x, z))
				.toBe(GraphicsLevel.keepSlot("low", "tree:pine", "detail", x, z))
		end
		local low = GraphicsLevel.get("low")
		T.expect(math.abs(trees / n - low.fill) < 0.06).toBe(true)
		T.expect(math.abs(unders / n - low.under) < 0.06).toBe(true)
	end)

	T.it("lights the nearest few, and a light already on wins a near tie", function()
		local list = { { d = 50 }, { d = 10 }, { d = 30 }, { d = 31, on = true }, { d = 90 } }
		local keep = GraphicsLevel.nearest(list, 2, 10)
		T.expect(keep[2]).toBe(true)
		T.expect(keep[4]).toBe(true)
		T.expect(keep[3]).toBe(nil)
		local all = GraphicsLevel.nearest(list, nil, 10)
		for i in list do
			T.expect(all[i]).toBe(true)
		end
		T.expect(next(GraphicsLevel.nearest(list, 0, 10))).toBe(nil)
	end)
end)
