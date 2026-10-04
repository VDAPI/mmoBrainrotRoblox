--!strict
-- Mosshollow Cave (12–20, red, DESIGN §15.1–15.2): elites and one Elite II per kind.

local Types = require("./Types")

local function elite(
	id: string,
	monster: string,
	minLevel: number,
	maxLevel: number,
	x: number,
	z: number,
	count: number
): Types.Spawner
	return {
		id = `mcave_{id}`,
		monster = monster,
		variant = "elite",
		level = { min = minLevel, max = maxLevel },
		position = { x = x, y = 0, z = z },
		radius = 24,
		count = count,
		respawn = { min = 60, max = 90 },
	}
end

local function boss(id: string, monster: string, level: number, x: number, z: number): Types.Spawner
	return {
		id = `mcave_{id}`,
		monster = monster,
		variant = "elite2",
		level = { min = level, max = level },
		position = { x = x, y = 0, z = z },
		radius = 4,
		count = 1,
		respawn = { min = 600, max = 1200 }, -- Elite II: 10–20 min
	}
end

return {
	elite("wolves", "wolf", 12, 14, -150, -140, 4),
	boss("wolf_alpha", "wolf", 15, -160, -165),
	elite("boars", "boar", 13, 15, -150, 140, 4),
	boss("boar_tusker", "boar", 16, -160, 165),
	elite("bandits", "bandit", 14, 16, 130, -160, 4),
	boss("bandit_ruben", "bandit", 17, 145, -185),
	elite("goblins_1", "goblinScout", 14, 16, -60, -30, 5),
	elite("goblins_2", "goblinScout", 15, 17, 0, 30, 5),
	boss("goblin_butcher", "goblinScout", 18, -30, 50),
	elite("spiders", "caveSpider", 15, 18, -30, -230, 6),
	boss("spider_queen", "caveSpider", 19, -30, -260),
	elite("shamans", "goblinShaman", 17, 20, 90, 215, 5),
	boss("bone_seer", "goblinShaman", 20, 100, 240),
}
