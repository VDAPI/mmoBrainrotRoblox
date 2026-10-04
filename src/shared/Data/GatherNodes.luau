--!strict
-- Gathering nodes (DESIGN §12): ore veins (pickaxe, 2.5 s, respawn 90 s), herb bushes (no tool, 1.5 s,
-- respawn 60 s) and fishing spots (rod, minigame — see Data/Fish). Respawn is per server.

export type LootEntry = { id: string, min: number, max: number, chance: number }

export type Category = "ore" | "herb" | "fishing"

export type NodeKind = {
	id: string,
	category: Category,
	tool: string?, -- item id required in the backpack
	time: number, -- hold time (s); fishing uses the minigame instead
	respawn: number, -- seconds hidden after gathering
	loot: { LootEntry },
	level: number, -- region level, for map placement (S08)
	look: { shape: "rock" | "bush" | "water", color: string, accent: string },
	nameKey: string,
	spot: string?, -- fishing: Data/Fish spot id
}

local kinds: { [string]: NodeKind } = {}
local list: { NodeKind } = {}

local function add(kind: NodeKind)
	kinds[kind.id] = kind
	table.insert(list, kind)
end

local ORES = {
	{ ore = "copper", level = 1, color = "#B87333" },
	{ ore = "iron", level = 20, color = "#8E8E93" },
	{ ore = "silver", level = 45, color = "#D8D8E0" },
	{ ore = "mithril", level = 70, color = "#7FD4E8" },
	{ ore = "adamantite", level = 90, color = "#5A3F7A" },
}
for _, ore in ORES do
	add({
		id = `vein_{ore.ore}`,
		category = "ore",
		tool = "pickaxe",
		time = 2.5,
		respawn = 90,
		loot = {
			{ id = `ore_{ore.ore}`, min = 1, max = 2, chance = 1 },
			{ id = "essence_dust", min = 1, max = 1, chance = 0.1 },
		},
		level = ore.level,
		look = { shape = "rock", color = "#6B6660", accent = ore.color },
		nameKey = `gather.vein_{ore.ore}`,
	})
end

local HERBS = {
	{ herb = "meadowsweet", level = 1, color = "#E8E4B0" },
	{ herb = "nightshade", level = 20, color = "#6B4A9A" },
	{ herb = "moonpetal", level = 30, color = "#E8E8FF" },
	{ herb = "firebloom", level = 45, color = "#FF7A1A" },
	{ herb = "frostleaf", level = 70, color = "#9FE0FF" },
}
for _, herb in HERBS do
	add({
		id = `bush_{herb.herb}`,
		category = "herb",
		tool = nil,
		time = 1.5,
		respawn = 60,
		loot = { { id = `herb_{herb.herb}`, min = 1, max = 2, chance = 1 } },
		level = herb.level,
		look = { shape = "bush", color = "#3F6B35", accent = herb.color },
		nameKey = `gather.bush_{herb.herb}`,
	})
end

-- Fishing spots: the catch is rolled from Data/Fish by spot id.
local SPOTS = {
	{ spot = "meadows", level = 1 },
	{ spot = "duskwood", level = 25 },
	{ spot = "ashen", level = 50 },
	{ spot = "frostpeak", level = 75 },
}
for _, spot in SPOTS do
	add({
		id = `fishing_{spot.spot}`,
		category = "fishing",
		tool = "fishing_rod",
		time = 0,
		respawn = 0,
		loot = {},
		level = spot.level,
		look = { shape = "water", color = "#2F6FA3", accent = "#9FD0F0" },
		nameKey = `gather.fishing_{spot.spot}`,
		spot = spot.spot,
	})
end

-- S07 test placement on the training meadow east of the city (map-relative x/z). S08 places nodes from
-- the map layouts with the same kinds.
export type Placement = { kind: string, map: string, x: number, z: number }
local TEST_PLACEMENTS: { Placement } = {
	{ kind = "vein_copper", map = "city", x = 300, z = 150 },
	{ kind = "vein_copper", map = "city", x = 320, z = 175 },
	{ kind = "vein_iron", map = "city", x = 345, z = 150 },
	{ kind = "vein_silver", map = "city", x = 370, z = 170 },
	{ kind = "bush_meadowsweet", map = "city", x = 290, z = -150 },
	{ kind = "bush_meadowsweet", map = "city", x = 310, z = -170 },
	{ kind = "bush_nightshade", map = "city", x = 335, z = -150 },
	{ kind = "bush_moonpetal", map = "city", x = 360, z = -170 },
	{ kind = "fishing_meadows", map = "city", x = 420, z = 200 },
}

return table.freeze({
	kinds = kinds,
	list = list,
	testPlacements = TEST_PLACEMENTS,
	get = function(id: string): NodeKind?
		return kinds[id]
	end,
	-- Interaction range (studs) and how far the player may move while gathering.
	RANGE = 10,
	MOVE_LIMIT = 3,
})
