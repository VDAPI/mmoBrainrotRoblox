--!strict
-- Ashen Wastes (45–70, DESIGN §15.2): normal monsters only. Positions match World/Layouts/ashen.

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
		id = `ashen_{id}`,
		monster = monster,
		variant = "normal",
		level = { min = minLevel, max = maxLevel },
		position = { x = x, y = 0, z = z },
		radius = radius or 34,
		count = count,
		respawn = { min = 20, max = 40 },
	}
end

return {
	s("salamanders_1", "salamander", 45, 48, -560, -160, 7),
	s("salamanders_2", "salamander", 47, 52, -480, 240, 8),
	s("orcs_1", "ashOrc", 48, 52, -300, -440, 8, 40),
	s("orcs_2", "ashOrc", 51, 56, -160, -600, 8, 40),
	s("golems_1", "fireGolem", 52, 56, -40, 200, 6, 40),
	s("golems_2", "fireGolem", 55, 60, 200, 100, 7, 40),
	s("scorpions_1", "desertScorpion", 55, 59, 400, 440, 7, 40),
	s("scorpions_2", "desertScorpion", 58, 63, 600, 620, 7, 40),
	s("wyverns_1", "wyvern", 58, 62, 460, -520, 6, 40),
	s("wyverns_2", "wyvern", 61, 66, 660, -660, 6, 40),
}
