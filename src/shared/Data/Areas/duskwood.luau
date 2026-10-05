--!strict
-- Duskwood (20–45): monster areas, roads and cave entrances (S19).

local Types = require("./Types")

local data: Types.MapAreas = {
	map = "duskwood",
	roads = {
		{
			points = { -790, 0, -480, 20, -200, -60, 80, 0, 360, -40, 560, 0, 720, 0 },
			width = 12,
			material = "Ground",
		},
		{ points = { -790, 160, -480, 20 }, width = 10, material = "Ground" },
		{ points = { -200, -60, -80, -320 }, width = 10, material = "Ground" },
		{ points = { 360, -40, 500, -480 }, width = 10, material = "Ground" },
		{ points = { 80, 0, 160, 320, 380, 420 }, width = 8, material = "Mud" },
		{ points = { 560, 0, 740, -740 }, width = 10, material = "Ground" },
		{ points = { -480, 20, -420, -400, -420, -720 }, width = 8, material = "Ground" },
		{ points = { -80, -320, 120, -520, 180, -720 }, width = 8, material = "Ground" },
	},
	lakes = {
		{ x = 420, z = 420, r = 50 },
		{ x = 600, z = 560, r = 70 },
		{ x = 640, z = 300, r = 40 },
		{ x = 480, z = 650, r = 35 },
	},
	avoid = {
		{ x = -770, z = 0, r = 60 },
		{ x = -770, z = 160, r = 60 },
		{ x = 740, z = -740, r = 60 },
		{ x = -700, z = 60, r = 40 },
		{ x = -120, z = -200, r = 35 },
		{ x = 60, z = 100, r = 35 },
		{ x = 380, z = -300, r = 35 },
		{ x = 300, z = 150, r = 35 },
		{ x = 690, z = 40, r = 35 },
		{ x = -80, z = -380, r = 45 }, -- ruins
		{ x = 560, z = -560, r = 70 }, -- cultist village
		{ x = 160, z = 300, r = 40 }, -- heart of the forest
		{ x = 600, z = 480, r = 25 }, -- jetty
	},
	caves = {
		{ cave = "duskwood_den", x = -420, z = -745, rot = 180 },
		{ cave = "duskwood_barrow", x = 180, z = -745, rot = 180 },
		{ cave = "duskwood_cave", x = 745, z = 0, rot = 90 },
	},
	areas = {
		{
			id = "duskwood_werethicket",
			nameKey = "area.duskwood_werethicket",
			lv = { 20, 25 },
			kinds = { "werewolf", "blackBear" },
			rect = { -760, -400, -420, 400 },
			groups = 8,
		},
		{
			id = "duskwood_bearhollow",
			nameKey = "area.duskwood_bearhollow",
			lv = { 21, 27 },
			kinds = { "blackBear", "werewolf" },
			rect = { -760, 420, -300, 780 },
			groups = 6,
		},
		{
			id = "duskwood_ruins",
			nameKey = "area.duskwood_ruins",
			lv = { 24, 31 },
			kinds = { "forestWraith", "ghoul" },
			rect = { -400, -780, 60, -150 },
			groups = 7,
			landmark = { x = -80, z = -380 },
		},
		{
			id = "duskwood_heart",
			nameKey = "area.duskwood_heart",
			lv = { 26, 33 },
			kinds = { "rotEnt", "ghoul" },
			rect = { -250, 150, 300, 780 },
			groups = 7,
			landmark = { x = 160, z = 300 },
		},
		{
			id = "duskwood_cultvillage",
			nameKey = "area.duskwood_cultvillage",
			lv = { 29, 37 },
			kinds = { "darkCultist", "bogSerpent" },
			rect = { 300, -780, 780, -300 },
			groups = 7,
			landmark = { x = 560, z = -560 },
		},
		{
			id = "duskwood_crossroads",
			nameKey = "area.duskwood_crossroads",
			lv = { 30, 36 },
			kinds = { "bogSerpent", "darkCultist", "forestWraith" },
			rect = { 80, -300, 500, -80 },
			groups = 5,
		},
		{
			id = "duskwood_swamp",
			nameKey = "area.duskwood_swamp",
			lv = { 32, 40 },
			kinds = { "swampTroll", "bogSerpent", "marshWitch" },
			rect = { 300, 180, 780, 780 },
			groups = 7,
		},
		{
			id = "duskwood_witchmarsh",
			nameKey = "area.duskwood_witchmarsh",
			lv = { 36, 42 },
			kinds = { "marshWitch", "swampTroll" },
			rect = { -200, 40, 300, 160 },
			groups = 4,
		},
		{
			id = "duskwood_bloodcliffs",
			nameKey = "area.duskwood_bloodcliffs",
			lv = { 40, 45 },
			kinds = { "bloodBat", "marshWitch" },
			rect = { 520, -300, 780, 160 },
			groups = 6,
		},
	},
}

return data
