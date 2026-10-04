--!strict
-- Frostpeak (70–100, DESIGN §15.2): normal monsters only. Positions match World/Layouts/frostpeak.

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
		id = `frostpeak_{id}`,
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
	s("wolves_1", "iceWolf", 70, 74, -560, -160, 8),
	s("wolves_2", "iceWolf", 73, 78, -500, 300, 8),
	s("yetis_1", "yeti", 74, 78, -260, -420, 7, 40),
	s("yetis_2", "yeti", 77, 82, -120, -620, 7, 40),
	s("giants_1", "frostGiant", 78, 83, 40, -120, 6, 40),
	s("giants_2", "frostGiant", 82, 88, 120, 120, 6, 40),
	s("elementals_1", "iceElemental", 82, 87, 40, 500, 7, 40),
	s("elementals_2", "iceElemental", 86, 92, 300, 620, 7, 40),
	s("dragonspawn_1", "dragonspawn", 85, 90, 520, -120, 6, 40),
	s("dragonspawn_2", "dragonspawn", 89, 95, 620, 240, 6, 40),
}
