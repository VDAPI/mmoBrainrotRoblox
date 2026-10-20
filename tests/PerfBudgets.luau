--!strict
-- W29: part, light and emitter budgets of every generated map (tests/perf.spec.luau, tools/perf_report.luau). Taken
-- from the W29 numbers (tools/PerfCells) plus about 10% headroom: a map session that needs more raises the number here
-- on purpose, with a line in docs/wyglad/SESJE-W.md saying why.
--   shell        server parts of the whole map (streamed to the clients)
--   cellShell    server parts in the heaviest 128-stud cell
--   cellClient   shell + detail + fine parts in the heaviest 128-stud cell
--   cellLights   PointLights in the heaviest cell
--   cellEmitters particle emitters the client adds in the heaviest cell (TownFxController)
--   lowParts     the most parts a phone holds around one spot at graphics level low, "World detail" mid
-- LIGHTS_ON: the most lights shining at once around one spot at each graphics level (W29 light budget + region
-- and cave LOD), on every map.

export type Budget = {
	shell: number,
	cellShell: number,
	cellClient: number,
	cellLights: number,
	cellEmitters: number,
	lowParts: number,
}

local PerfBudgets = {}

PerfBudgets.LIGHTS_ON = { low = 16, medium = 40, high = 76 }

-- The Invasion camp (server/World/InvasionCamp) of one zone.
PerfBudgets.INVASION_CAMP = { parts = 95, lights = 8, emitters = 10 }

local MAPS: { [string]: Budget } = {
	["city"] = {
		shell = 6300,
		cellShell = 300,
		cellClient = 3650,
		cellLights = 40,
		cellEmitters = 20,
		lowParts = 15100,
	},
	["ashen"] = { shell = 1070, cellShell = 40, cellClient = 400, cellLights = 12, cellEmitters = 70, lowParts = 1080 },
	["ashen_cave"] = {
		shell = 90,
		cellShell = 12,
		cellClient = 120,
		cellLights = 14,
		cellEmitters = 22,
		lowParts = 520,
	},
	["ashen_lair"] = { shell = 10, cellShell = 10, cellClient = 80, cellLights = 10, cellEmitters = 30, lowParts = 170 },
	["ashen_mine"] = {
		shell = 20,
		cellShell = 10,
		cellClient = 180,
		cellLights = 10,
		cellEmitters = 10,
		lowParts = 630,
	},
	["dungeon_ashen"] = {
		shell = 20,
		cellShell = 10,
		cellClient = 90,
		cellLights = 20,
		cellEmitters = 50,
		lowParts = 270,
	},
	["dungeon_duskwood"] = {
		shell = 31,
		cellShell = 13,
		cellClient = 60,
		cellLights = 10,
		cellEmitters = 13,
		lowParts = 130,
	},
	["dungeon_frostpeak"] = {
		shell = 22,
		cellShell = 11,
		cellClient = 80,
		cellLights = 10,
		cellEmitters = 10,
		lowParts = 140,
	},
	["dungeon_meadows"] = {
		shell = 23,
		cellShell = 13,
		cellClient = 180,
		cellLights = 11,
		cellEmitters = 11,
		lowParts = 420,
	},
	["duskwood"] = {
		shell = 2490,
		cellShell = 60,
		cellClient = 770,
		cellLights = 10,
		cellEmitters = 20,
		lowParts = 4070,
	},
	["duskwood_barrow"] = {
		shell = 23,
		cellShell = 10,
		cellClient = 390,
		cellLights = 10,
		cellEmitters = 20,
		lowParts = 970,
	},
	["duskwood_cave"] = {
		shell = 50,
		cellShell = 20,
		cellClient = 530,
		cellLights = 10,
		cellEmitters = 20,
		lowParts = 1250,
	},
	["duskwood_den"] = {
		shell = 14,
		cellShell = 10,
		cellClient = 90,
		cellLights = 10,
		cellEmitters = 5,
		lowParts = 230,
	},
	["frostpeak"] = {
		shell = 1230,
		cellShell = 50,
		cellClient = 380,
		cellLights = 11,
		cellEmitters = 10,
		lowParts = 2260,
	},
	["frostpeak_cave"] = {
		shell = 20,
		cellShell = 10,
		cellClient = 60,
		cellLights = 10,
		cellEmitters = 10,
		lowParts = 230,
	},
	["frostpeak_grotto"] = {
		shell = 10,
		cellShell = 10,
		cellClient = 60,
		cellLights = 10,
		cellEmitters = 10,
		lowParts = 160,
	},
	["frostpeak_hold"] = {
		shell = 50,
		cellShell = 20,
		cellClient = 60,
		cellLights = 10,
		cellEmitters = 12,
		lowParts = 200,
	},
	["meadows"] = {
		shell = 2450,
		cellShell = 100,
		cellClient = 580,
		cellLights = 10,
		cellEmitters = 10,
		lowParts = 3130,
	},
	["meadows_burrow"] = {
		shell = 50,
		cellShell = 20,
		cellClient = 60,
		cellLights = 10,
		cellEmitters = 10,
		lowParts = 240,
	},
	["meadows_cave"] = {
		shell = 60,
		cellShell = 20,
		cellClient = 60,
		cellLights = 11,
		cellEmitters = 11,
		lowParts = 290,
	},
	["meadows_hideout"] = {
		shell = 50,
		cellShell = 20,
		cellClient = 50,
		cellLights = 10,
		cellEmitters = 11,
		lowParts = 160,
	},
	["arena_pit:arena"] = {
		shell = 70,
		cellShell = 22,
		cellClient = 120,
		cellLights = 10,
		cellEmitters = 10,
		lowParts = 410,
	},
	["arena_pit:tournament"] = {
		shell = 260,
		cellShell = 50,
		cellClient = 290,
		cellLights = 20,
		cellEmitters = 20,
		lowParts = 1610,
	},
}

-- The budget of a map id of tools/PerfCells.maps().
function PerfBudgets.of(id: string): Budget
	return MAPS[id]
end

function PerfBudgets.ids(): { string }
	local list = {}
	for id in MAPS do
		table.insert(list, id)
	end
	table.sort(list)
	return list
end

return PerfBudgets
