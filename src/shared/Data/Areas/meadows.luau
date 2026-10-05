--!strict
-- Whispering Meadows (1–20): monster areas, roads and cave entrances (S19). The layout draws the roads
-- from here; Logic/AreaSpawns places the monster groups.

local Types = require("./Types")

local data: Types.MapAreas = {
	map = "meadows",
	roads = {
		{
			points = { -790, 0, -420, 0, -120, 80, 120, 260, 300, 380, 520, 300, 700, 340 },
			width = 14,
			material = "Ground",
		},
		{ points = { -120, 80, -80, -260, 60, -520 }, width = 10, material = "Ground" },
		{ points = { 300, 380, 420, 120, 560, -200, 640, -480, 720, -700 }, width = 12, material = "Ground" },
		{ points = { 300, 380, 160, 560, 60, 700 }, width = 10, material = "Ground" },
		{ points = { 640, -480, 460, -620, 420, -720 }, width = 10, material = "Ground" },
	},
	lakes = { { x = -470, z = 450, r = 95 }, { x = -60, z = 560, r = 34 } },
	avoid = {
		{ x = -770, z = 0, r = 70 }, -- city portal
		{ x = 730, z = -720, r = 60 }, -- Duskwood portal
		{ x = -700, z = 30, r = 40 },
		{ x = -150, z = -300, r = 35 },
		{ x = 120, z = 300, r = 35 },
		{ x = 470, z = -180, r = 35 },
		{ x = 660, z = 380, r = 35 },
		{ x = -640, z = -180, r = 50 }, -- farm
		{ x = 300, z = 440, r = 50 }, -- bandit camp
		{ x = 650, z = -390, r = 45 }, -- goblin camp
		{ x = -150, z = -380, r = 35 }, -- ruins
		{ x = -470, z = 345, r = 25 }, -- jetty
	},
	caves = {
		{ cave = "meadows_hideout", x = 60, z = 735, rot = 0 },
		{ cave = "meadows_burrow", x = 420, z = -745, rot = 180 },
		{ cave = "meadows_cave", x = 745, z = 330, rot = 90 },
	},
	areas = {
		{
			id = "meadows_rabbitfields",
			nameKey = "area.meadows_rabbitfields",
			lv = { 1, 4 },
			kinds = { "rabbit", "wolf" },
			rect = { -760, -330, -480, 330 },
			groups = 7,
		},
		{
			id = "meadows_wolfhills",
			nameKey = "area.meadows_wolfhills",
			lv = { 3, 7 },
			kinds = { "wolf", "lynx" },
			rect = { -470, -330, -200, 330 },
			groups = 7,
		},
		{
			id = "meadows_toadmire",
			nameKey = "area.meadows_toadmire",
			lv = { 4, 8 },
			kinds = { "swampToad", "lynx" },
			rect = { -760, 360, -200, 780 },
			groups = 6,
			landmark = { x = -470, z = 450 },
		},
		{
			id = "meadows_oldforest",
			nameKey = "area.meadows_oldforest",
			lv = { 6, 11 },
			kinds = { "boar", "carrionCrow" },
			rect = { -320, -780, 220, -360 },
			groups = 7,
			landmark = { x = -150, z = -380 },
		},
		{
			id = "meadows_crowfield",
			nameKey = "area.meadows_crowfield",
			lv = { 8, 12 },
			kinds = { "carrionCrow", "boar", "bandit" },
			rect = { -180, -330, 260, 40 },
			groups = 5,
		},
		{
			id = "meadows_banditroad",
			nameKey = "area.meadows_banditroad",
			lv = { 9, 14 },
			kinds = { "bandit", "koboldMiner" },
			rect = { -150, 120, 450, 780 },
			groups = 8,
			landmark = { x = 300, z = 440 },
		},
		{
			id = "meadows_diggings",
			nameKey = "area.meadows_diggings",
			lv = { 11, 15 },
			kinds = { "koboldMiner", "goblinScout" },
			rect = { 260, -330, 780, 60 },
			groups = 6,
		},
		{
			id = "meadows_goblincamp",
			nameKey = "area.meadows_goblincamp",
			lv = { 13, 18 },
			kinds = { "goblinScout", "koboldMiner" },
			rect = { 420, -780, 780, -340 },
			groups = 6,
			landmark = { x = 650, z = -390 },
		},
		{
			id = "meadows_bearridge",
			nameKey = "area.meadows_bearridge",
			lv = { 16, 20 },
			kinds = { "brownBear", "goblinScout" },
			rect = { 480, 100, 780, 780 },
			groups = 6,
		},
	},
}

return data
