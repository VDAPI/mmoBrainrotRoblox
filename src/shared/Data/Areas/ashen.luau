--!strict
-- Ashen Wastes (45–70): monster areas, roads and cave entrances (S19).

local Types = require("./Types")

local data: Types.MapAreas = {
	map = "ashen",
	roads = {
		{
			points = { -790, 0, -480, 0, -240, -60, 0, -60, 260, -20, 520, 0, 720, 0 },
			width = 14,
			material = "Pavement",
		},
		{ points = { -790, 160, -480, 0 }, width = 10, material = "Pavement" },
		{ points = { -240, -60, -200, -420 }, width = 10, material = "Pavement" },
		{ points = { 260, -20, 420, 360 }, width = 10, material = "Sand" },
		{ points = { 520, 0, 620, -440, 740, -740 }, width = 10, material = "Pavement" },
		{ points = { -200, -420, -460, -560, -560, -720 }, width = 8, material = "Pavement" },
		{ points = { 620, -440, 420, -600, 420, -720 }, width = 8, material = "Pavement" },
	},
	lakes = {
		{ x = -60, z = 120, r = 40 },
		{ x = 120, z = 40, r = 55 },
		{ x = 60, z = 260, r = 35 },
		{ x = -180, z = 300, r = 30 },
		{ x = 260, z = 180, r = 30 },
		{ x = -560, z = 600, r = 70 },
		{ x = -680, z = 300, r = 26 },
	},
	avoid = {
		{ x = -770, z = 0, r = 60 },
		{ x = -770, z = 160, r = 60 },
		{ x = 740, z = -740, r = 60 },
		{ x = -700, z = 60, r = 40 },
		{ x = -240, z = -300, r = 35 },
		{ x = -100, z = -20, r = 35 },
		{ x = 300, z = 260, r = 35 },
		{ x = 480, z = -200, r = 35 },
		{ x = 690, z = 40, r = 35 },
		{ x = -260, z = -540, r = 40 }, -- warcamp fire
		{ x = -520, z = 420, r = 35 }, -- ruins
		{ x = 200, z = 640, r = 35 }, -- ruins
	},
	caves = {
		{ cave = "ashen_mine", x = -560, z = -745, rot = 180 },
		{ cave = "ashen_lair", x = 420, z = -745, rot = 180 },
		{ cave = "ashen_cave", x = 745, z = 0, rot = 90 },
	},
	areas = {
		{
			id = "ashen_flats",
			nameKey = "area.ashen_flats",
			lv = { 45, 50 },
			kinds = { "salamander", "wasteHyena" },
			rect = { -760, -330, -420, 420 },
			groups = 8,
			arrive = { x = -680, z = 0 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
		},
		{
			id = "ashen_oasis",
			nameKey = "area.ashen_oasis",
			lv = { 46, 52 },
			kinds = { "wasteHyena", "ashVulture" },
			rect = { -760, 440, -300, 780 },
			groups = 6,
			arrive = { x = -488, z = 632 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = -560, z = 600 },
		},
		{
			id = "ashen_warcamp",
			nameKey = "area.ashen_warcamp",
			lv = { 48, 56 },
			kinds = { "ashOrc", "ashVulture" },
			rect = { -460, -780, -20, -340 },
			groups = 7,
			arrive = { x = -207, z = -356 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = -260, z = -540 },
		},
		{
			id = "ashen_golemfields",
			nameKey = "area.ashen_golemfields",
			lv = { 52, 60 },
			kinds = { "fireGolem", "fireImp" },
			rect = { -260, -40, 330, 420 },
			groups = 7,
			arrive = { x = 324, z = 131 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
		},
		{
			id = "ashen_burntruins",
			nameKey = "area.ashen_burntruins",
			lv = { 55, 61 },
			kinds = { "fireImp", "desertScorpion" },
			rect = { -280, 440, 280, 780 },
			groups = 6,
			arrive = { x = 0, z = 608 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
			landmark = { x = 200, z = 640 },
		},
		{
			id = "ashen_dunes",
			nameKey = "area.ashen_dunes",
			lv = { 55, 63 },
			kinds = { "desertScorpion", "desertMummy" },
			rect = { 330, 300, 780, 780 },
			groups = 7,
			arrive = { x = 401, z = 316 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
		},
		{
			id = "ashen_crags",
			nameKey = "area.ashen_crags",
			lv = { 58, 66 },
			kinds = { "wyvern", "basilisk" },
			rect = { 300, -780, 780, -300 },
			groups = 6,
			arrive = { x = 592, z = -317 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
		},
		{
			id = "ashen_ashroad",
			nameKey = "area.ashen_ashroad",
			lv = { 61, 67 },
			kinds = { "basilisk", "wyvern" },
			rect = { 0, -300, 500, -80 },
			groups = 4,
			arrive = { x = 248, z = -188 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
		},
		{
			id = "ashen_tombs",
			nameKey = "area.ashen_tombs",
			lv = { 66, 70 },
			kinds = { "desertMummy", "basilisk" },
			rect = { 340, 40, 780, 280 },
			groups = 5,
			arrive = { x = 346, z = 185 }, -- S22: portal / map stone arrival (Logic/AreaArrival)
		},
	},
}

return data
