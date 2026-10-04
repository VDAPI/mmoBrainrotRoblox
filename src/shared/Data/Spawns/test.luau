--!strict
-- Spawners on the S02 test strip east of the city (training meadow = yellow, cave of trials = red).
-- Positions are relative to the map offset (Data/Maps). S08 adds per-map spawn files for the real world.

local Types = require("./Types")

local SPAWNS: { Types.Spawner } = {
	-- Training meadow (x 256..600, yellow zone)
	{
		id = "test_rabbits",
		monster = "rabbit",
		variant = "normal",
		level = { min = 1, max = 3 },
		position = { x = 310, y = 0, z = -120 },
		radius = 16,
		count = 4,
		respawn = { min = 20, max = 40 },
	},
	{
		id = "test_wolves",
		monster = "wolf",
		variant = "normal",
		level = { min = 2, max = 6 },
		position = { x = 350, y = 0, z = 115 },
		radius = 14,
		count = 3,
		respawn = { min = 20, max = 40 },
	},
	{
		id = "test_boars",
		monster = "boar",
		variant = "normal",
		level = { min = 5, max = 10 },
		position = { x = 425, y = 0, z = -150 },
		radius = 14,
		count = 3,
		respawn = { min = 25, max = 40 },
	},
	{
		id = "test_bandits",
		monster = "bandit",
		variant = "normal",
		level = { min = 9, max = 14 },
		position = { x = 455, y = 0, z = 165 },
		radius = 12,
		count = 2,
		respawn = { min = 30, max = 40 },
	},
	-- Cave of trials (x 510..600, |z| < 60, red zone): elites only (DESIGN §15.1)
	{
		id = "test_cave_goblins",
		monster = "goblinScout",
		variant = "elite",
		level = { min = 13, max = 16 },
		position = { x = 545, y = 0, z = -30 },
		radius = 8,
		count = 2,
		respawn = { min = 60, max = 90 },
	},
	{
		id = "test_cave_queen",
		monster = "caveSpider",
		variant = "elite2",
		level = { min = 16, max = 16 },
		position = { x = 578, y = 0, z = 20 },
		radius = 4,
		count = 1,
		respawn = { min = 600, max = 1200 }, -- Elite II: 10–20 min
	},
}

return SPAWNS
