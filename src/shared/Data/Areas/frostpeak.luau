--!strict
-- Frostpeak (70–100): monster areas, roads and cave entrances (S19).

local Types = require("./Types")

local data: Types.MapAreas = {
	map = "frostpeak",
	roads = {
		{
			points = { -790, 0, -480, 20, -200, 0, 0, 0, 260, -40, 500, 0, 720, 0 },
			width = 14,
			material = "Ground",
		},
		{ points = { -790, 160, -480, 20 }, width = 10, material = "Ground" },
		{ points = { -200, 0, -260, -460 }, width = 10, material = "Ground" },
		{ points = { 0, 0, 120, 440 }, width = 10, material = "Ground" },
		{ points = { -260, -460, -300, -720 }, width = 8, material = "Ground" },
		{ points = { 260, -40, 300, -720 }, width = 8, material = "Ground" },
	},
	lakes = {
		{ x = 160, z = 560, r = 30 }, -- ice hole
		{ x = -560, z = 600, r = 22 }, -- second ice hole
		{ x = -100, z = -280, r = 75 }, -- ridges (steep, no groups on top)
		{ x = 120, z = -300, r = 85 },
		{ x = -60, z = 300, r = 75 },
		{ x = 160, z = 320, r = 65 },
	},
	avoid = {
		{ x = -770, z = 0, r = 60 },
		{ x = -770, z = 160, r = 60 },
		{ x = -700, z = 60, r = 40 },
		{ x = -260, z = -300, r = 35 },
		{ x = 40, z = 60, r = 35 },
		{ x = 40, z = 420, r = 35 },
		{ x = 420, z = 40, r = 35 },
		{ x = 690, z = 40, r = 35 },
		{ x = 520, z = -160, r = 35 }, -- temple ruins
		{ x = 600, z = 140, r = 35 },
		{ x = 460, z = 200, r = 35 },
	},
	caves = {
		{ cave = "frostpeak_grotto", x = -300, z = -745, rot = 180 },
		{ cave = "frostpeak_hold", x = 300, z = -745, rot = 180 },
		{ cave = "frostpeak_cave", x = 745, z = 0, rot = 90 },
	},
	areas = {
		{
			id = "frostpeak_valley",
			nameKey = "area.frostpeak_valley",
			lv = { 70, 75 },
			kinds = { "iceWolf", "snowLeopard" },
			rect = { -760, -330, -420, 420 },
			groups = 8,
			arrive = { x = -682, z = 7 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
		},
		{
			id = "frostpeak_slopes",
			nameKey = "area.frostpeak_slopes",
			lv = { 74, 80 },
			kinds = { "yeti", "snowLeopard" },
			rect = { -480, -780, -20, -340 },
			groups = 7,
			arrive = { x = -246, z = -356 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
		},
		{
			id = "frostpeak_harpyrocks",
			nameKey = "area.frostpeak_harpyrocks",
			lv = { 76, 83 },
			kinds = { "peakHarpy", "yeti" },
			rect = { -760, 440, -200, 780 },
			groups = 6,
			arrive = { x = -480, z = 608 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
		},
		{
			id = "frostpeak_pass",
			nameKey = "area.frostpeak_pass",
			lv = { 78, 86 },
			kinds = { "frostGiant", "peakHarpy" },
			rect = { -200, -240, 320, 240 },
			groups = 7,
			arrive = { x = -184, z = 0 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
		},
		{
			id = "frostpeak_lake",
			nameKey = "area.frostpeak_lake",
			lv = { 82, 90 },
			kinds = { "iceElemental", "iceMammoth" },
			rect = { -60, 400, 420, 780 },
			groups = 6,
			arrive = { x = 114, z = 417 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = 160, z = 560 },
		},
		{
			id = "frostpeak_tundra",
			nameKey = "area.frostpeak_tundra",
			lv = { 82, 89 },
			kinds = { "iceMammoth", "frostGiant" },
			rect = { 0, -780, 480, -320 },
			groups = 6,
			arrive = { x = 277, z = -336 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
		},
		{
			id = "frostpeak_temple",
			nameKey = "area.frostpeak_temple",
			lv = { 85, 95 },
			kinds = { "dragonspawn", "frozenKnight" },
			rect = { 400, -300, 780, 320 },
			groups = 7,
			arrive = { x = 417, z = -14 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = 560, z = 0 },
		},
		{
			id = "frostpeak_icewatch",
			nameKey = "area.frostpeak_icewatch",
			lv = { 88, 95 },
			kinds = { "frozenKnight", "iceElemental" },
			rect = { 440, 340, 780, 780 },
			groups = 5,
			arrive = { x = 608, z = 556 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
		},
		{
			id = "frostpeak_wyrmspire",
			nameKey = "area.frostpeak_wyrmspire",
			lv = { 94, 100 },
			kinds = { "frostWyrm", "dragonspawn" },
			rect = { 500, -780, 780, -320 },
			groups = 5,
			arrive = { x = 636, z = -548 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
		},
	},
}

return data
