--!strict
-- Whispering Meadows (1–20, DESIGN §15.2): normal monsters only (elites live in the cave). Positions are
-- map-relative and match World/Layouts/meadows.

local Types = require("./Types")

local function s(
	id: string,
	monster: string,
	minLevel: number,
	maxLevel: number,
	x: number,
	z: number,
	count: number,
	radius: number?
): Types.Spawner
	return {
		id = `meadows_{id}`,
		monster = monster,
		variant = "normal",
		level = { min = minLevel, max = maxLevel },
		position = { x = x, y = 0, z = z },
		radius = radius or 30,
		count = count,
		respawn = { min = 20, max = 40 },
	}
end

return {
	-- Fields 1–6
	s("rabbits_1", "rabbit", 1, 3, -620, 120, 8),
	s("rabbits_2", "rabbit", 1, 3, -520, -60, 7),
	s("rabbits_3", "rabbit", 1, 3, -680, 300, 6),
	s("wolves_1", "wolf", 2, 4, -420, 160, 6),
	s("wolves_2", "wolf", 3, 5, -380, -200, 6),
	s("wolves_3", "wolf", 4, 6, -300, 320, 7),
	-- Forest 5–10
	s("boars_1", "boar", 5, 7, -220, -420, 7),
	s("boars_2", "boar", 6, 9, 20, -460, 7),
	s("boars_3", "boar", 7, 10, -40, -640, 8),
	s("wolves_forest", "wolf", 5, 6, 120, -180, 6),
	-- Trade road 9–14
	s("bandits_1", "bandit", 9, 11, 180, 300, 6),
	s("bandits_2", "bandit", 10, 13, 300, 440, 8, 36),
	s("bandits_3", "bandit", 12, 14, 480, 260, 6),
	-- Goblin camp 13–18
	s("goblins_1", "goblinScout", 13, 15, 480, -200, 7),
	s("goblins_2", "goblinScout", 14, 17, 640, -390, 9, 40),
	s("goblins_3", "goblinScout", 15, 18, 600, -620, 7),
}
