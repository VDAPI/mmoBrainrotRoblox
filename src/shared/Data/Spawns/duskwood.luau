--!strict
-- Duskwood (20–45, DESIGN §15.2): normal monsters only. Positions match World/Layouts/duskwood.

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
		id = `duskwood_{id}`,
		monster = monster,
		variant = "normal",
		level = { min = minLevel, max = maxLevel },
		position = { x = x, y = 0, z = z },
		radius = radius or 32,
		count = count,
		respawn = { min = 20, max = 40 },
	}
end

return {
	-- West woods: werewolves 20–28
	s("werewolves_1", "werewolf", 20, 23, -560, -200, 7),
	s("werewolves_2", "werewolf", 22, 25, -520, 260, 7),
	s("werewolves_3", "werewolf", 24, 28, -340, -100, 8),
	-- Ruins: wraiths 23–31
	s("wraiths_1", "forestWraith", 23, 27, -80, -340, 7),
	s("wraiths_2", "forestWraith", 26, 31, -160, -470, 8),
	-- Heart: ents 26–34
	s("ents_1", "rotEnt", 26, 30, 160, 300, 6, 40),
	s("ents_2", "rotEnt", 29, 34, 60, 420, 7, 40),
	-- Cultist village 29–37
	s("cultists_1", "darkCultist", 29, 32, 420, -380, 7),
	s("cultists_2", "darkCultist", 31, 35, 550, -520, 9, 40),
	s("cultists_3", "darkCultist", 33, 37, 640, -620, 7),
	-- Swamp: trolls 32–40
	s("trolls_1", "swampTroll", 32, 35, 380, 300, 6, 36),
	s("trolls_2", "swampTroll", 34, 38, 520, 520, 7, 40),
	s("trolls_3", "swampTroll", 36, 40, 680, 680, 6, 36),
}
