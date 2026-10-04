--!strict
-- Crypt of the Forgotten (35–45, red): elites and one Elite II per kind (forest kinds driven underground plus
-- the crypt's own undead). Positions match World/Layouts/duskwood_cave.

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
		id = `crypt_{id}`,
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
		id = `crypt_{id}`,
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
	elite("werewolves", "werewolf", 35, 37, -130, -160, 3),
	boss("werewolf_alpha", "werewolf", 39, -100, -195),
	elite("wraiths", "forestWraith", 35, 38, -90, -150, 3),
	boss("wraith_lady", "forestWraith", 40, -125, -200),
	elite("ents", "rotEnt", 36, 39, -130, 160, 3),
	boss("ent_elder", "rotEnt", 41, -100, 195),
	elite("trolls", "swampTroll", 37, 40, -90, 150, 3),
	boss("troll_king", "swampTroll", 42, -125, 200),
	elite("cultists", "darkCultist", 37, 40, 40, -170, 5),
	boss("cult_priest", "darkCultist", 42, 55, -195),
	elite("skeletons", "skeletonGuard", 38, 41, 40, 0, 6),
	boss("bone_warden", "skeletonGuard", 43, 60, 20),
	elite("specters", "specter", 39, 43, 40, 170, 5),
	boss("weeping_specter", "specter", 44, 55, 195),
	elite("necromancers", "necromancer", 41, 45, 150, 0, 4),
	boss("arch_necromancer", "necromancer", 45, 165, 20),
}
