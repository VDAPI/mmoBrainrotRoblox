--!strict
-- Glacier Heart (90–100, red): elites and one Elite II per kind. Positions match World/Layouts/frostpeak_cave.

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
		id = `glacier_{id}`,
		monster = monster,
		variant = "elite",
		level = { min = minLevel, max = maxLevel },
		position = { x = x, y = 0, z = z },
		radius = 22,
		count = count,
		respawn = { min = 60, max = 90 },
	}
end

local function boss(id: string, monster: string, level: number, x: number, z: number): Types.Spawner
	return {
		id = `glacier_{id}`,
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
	elite("wolves", "iceWolf", 90, 92, -130, -170, 3),
	boss("wolf_alpha", "iceWolf", 94, -100, -205),
	elite("yetis", "yeti", 90, 93, -80, -160, 3),
	boss("yeti_king", "yeti", 95, -130, -210),
	elite("giants", "frostGiant", 91, 94, 60, -150, 3),
	boss("giant_jarl", "frostGiant", 95, 75, -175),
	elite("elementals", "iceElemental", 91, 94, 60, 150, 3),
	boss("elemental_lord", "iceElemental", 95, 75, 175),
	elite("dragonspawn", "dragonspawn", 92, 95, -130, 170, 3),
	boss("dragonspawn_brood", "dragonspawn", 96, -100, 205),
	elite("guardians", "crystalGuardian", 90, 94, -100, 0, 6),
	boss("crystal_warden", "crystalGuardian", 96, -100, 30),
	elite("young_dragons", "youngFrostDragon", 93, 96, 110, 0, 4),
	boss("frost_drake", "youngFrostDragon", 96, 125, 25),
}
