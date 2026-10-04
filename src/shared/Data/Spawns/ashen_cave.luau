--!strict
-- Deepforge (60–70, red): elites and one Elite II per kind. Positions match World/Layouts/ashen_cave.

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
		id = `ashcave_{id}`,
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
		id = `ashcave_{id}`,
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
	elite("salamanders", "salamander", 60, 62, -130, -160, 3),
	boss("salamander_matriarch", "salamander", 64, -100, -195),
	elite("orcs", "ashOrc", 60, 63, -80, -150, 3),
	boss("orc_warlord", "ashOrc", 65, -125, -200),
	elite("golems", "fireGolem", 61, 64, -130, 160, 3),
	boss("golem_colossus", "fireGolem", 66, -100, 195),
	elite("scorpions", "desertScorpion", 62, 65, -80, 150, 3),
	boss("scorpion_queen", "desertScorpion", 66, -125, 200),
	elite("wyverns", "wyvern", 62, 65, -100, 20, 3),
	boss("wyvern_elder", "wyvern", 66, -100, -25),
	elite("dwarves", "renegadeDwarf", 60, 63, 60, -150, 5),
	boss("dwarf_thane", "renegadeDwarf", 65, 75, -175),
	elite("magma_golems", "magmaGolem", 62, 66, 60, 150, 5),
	boss("magma_titan", "magmaGolem", 66, 75, 175),
	elite("flame_smiths", "flameSmith", 64, 68, 110, 0, 4),
	boss("forge_master", "flameSmith", 66, 125, 20),
}
