--!strict
-- Monster kinds of all four regions (DESIGN §15.2). Data only.
-- Names: localization keys "monster.<id>.<variant>" (variant = normal | elite | elite2).
-- Stats: Logic/MonsterStats from level x multipliers below x variant (Data/Combat.variants).
-- Elites and Elite II spawn only in caves (red zones); `elites = false` kinds have no elite variants.

export type Shape = "quadruped" | "humanoid" | "spider" | "golem" | "flyer" | "dragon"

export type MonsterDef = {
	id: string,
	region: number, -- 1 meadows, 2 duskwood, 3 ashen, 4 frostpeak
	cave: boolean, -- lives in the region's cave
	levels: { min: number, max: number },
	hpMul: number,
	atkMul: number,
	defMul: number,
	speed: number, -- attack speed multiplier
	moveSpeed: number, -- studs per second while chasing
	attack: "melee" | "ranged",
	damageKind: "phys" | "magic",
	range: number?,
	element: ("fire" | "ice" | "lightning" | "poison")?,
	passive: boolean, -- never attacks first
	elites: boolean,
	ability: string?, -- Elite II special (Data/MonsterAbilities)
	lootTable: string, -- Data/LootTables id (S04)
	shape: Shape,
	size: number, -- model scale before the variant scale
	colors: { primary: string, secondary: string },
	nameKeys: { normal: string, elite: string, elite2: string },
}

type Options = {
	hpMul: number?,
	atkMul: number?,
	defMul: number?,
	speed: number?,
	moveSpeed: number?,
	attack: ("melee" | "ranged")?,
	damageKind: ("phys" | "magic")?,
	range: number?,
	element: ("fire" | "ice" | "lightning" | "poison")?,
	passive: boolean?,
	elites: boolean?,
	ability: string?,
	shape: Shape,
	size: number?,
	colors: { primary: string, secondary: string },
}

local LIST: { MonsterDef } = {}

local function kind(id: string, region: number, cave: boolean, minLevel: number, maxLevel: number, o: Options)
	table.insert(LIST, {
		id = id,
		region = region,
		cave = cave,
		levels = { min = minLevel, max = maxLevel },
		hpMul = o.hpMul or 1,
		atkMul = o.atkMul or 1,
		defMul = o.defMul or 1,
		speed = o.speed or 1,
		moveSpeed = o.moveSpeed or 13,
		attack = o.attack or "melee",
		damageKind = o.damageKind or "phys",
		range = o.range,
		element = o.element,
		passive = o.passive == true,
		elites = o.elites ~= false,
		ability = o.ability,
		lootTable = id,
		shape = o.shape,
		size = o.size or 1,
		colors = o.colors,
		nameKeys = {
			normal = `monster.{id}.normal`,
			elite = `monster.{id}.elite`,
			elite2 = `monster.{id}.elite2`,
		},
	})
end

-- Region 1: Whispering Meadows (1–20) / Mosshollow Cave (12–20)
kind("rabbit", 1, false, 1, 3, {
	hpMul = 0.6,
	atkMul = 0.5,
	passive = true,
	elites = false,
	moveSpeed = 11,
	shape = "quadruped",
	size = 0.5,
	colors = { primary = "#8B6B4A", secondary = "#E8DCC8" },
})
kind("wolf", 1, false, 2, 6, {
	speed = 1.15,
	moveSpeed = 16,
	ability = "leap",
	shape = "quadruped",
	colors = { primary = "#6E6E6E", secondary = "#B9B9B9" },
})
kind("boar", 1, false, 5, 10, {
	hpMul = 1.25,
	defMul = 1.2,
	ability = "charge",
	shape = "quadruped",
	size = 1.15,
	colors = { primary = "#5A3D2B", secondary = "#D9C9A8" },
})
kind("bandit", 1, false, 9, 14, {
	ability = "cleave",
	shape = "humanoid",
	colors = { primary = "#5B4636", secondary = "#2F2F35" },
})
kind("goblinScout", 1, true, 13, 18, {
	speed = 1.1,
	moveSpeed = 15,
	ability = "slam",
	shape = "humanoid",
	size = 0.8,
	colors = { primary = "#5E8C3A", secondary = "#6B4A2B" },
})
kind("caveSpider", 1, true, 14, 20, {
	hpMul = 0.9,
	speed = 1.2,
	element = "poison",
	ability = "poisonPool",
	shape = "spider",
	colors = { primary = "#2B2630", secondary = "#7A2E3A" },
})
kind("goblinShaman", 1, true, 16, 20, {
	hpMul = 0.8,
	attack = "ranged",
	damageKind = "magic",
	range = 26,
	ability = "boneNova",
	shape = "humanoid",
	size = 0.85,
	colors = { primary = "#4F7A34", secondary = "#C9B26B" },
})

-- Region 2: Duskwood (20–45) / Crypt of the Forgotten (35–45)
kind("werewolf", 2, false, 20, 28, {
	hpMul = 1.1,
	speed = 1.1,
	moveSpeed = 16,
	ability = "leap",
	shape = "humanoid",
	size = 1.3,
	colors = { primary = "#4A3B30", secondary = "#8E7E6A" },
})
kind("forestWraith", 2, false, 23, 31, {
	hpMul = 0.8,
	attack = "ranged",
	damageKind = "magic",
	range = 26,
	element = "ice",
	ability = "frostNova",
	shape = "flyer",
	colors = { primary = "#9FB6C9", secondary = "#E4F0F7" },
})
kind("rotEnt", 2, false, 26, 34, {
	hpMul = 1.5,
	defMul = 1.4,
	speed = 0.8,
	moveSpeed = 9,
	element = "poison",
	ability = "slam",
	shape = "golem",
	size = 1.5,
	colors = { primary = "#4B3A26", secondary = "#5F7D3A" },
})
kind("darkCultist", 2, false, 29, 37, {
	attack = "ranged",
	damageKind = "magic",
	range = 28,
	ability = "voidPool",
	shape = "humanoid",
	colors = { primary = "#2A1F33", secondary = "#7A3FA0" },
})
kind("swampTroll", 2, false, 32, 40, {
	hpMul = 1.6,
	atkMul = 1.1,
	speed = 0.8,
	moveSpeed = 11,
	ability = "slam",
	shape = "golem",
	size = 1.6,
	colors = { primary = "#4D5E3A", secondary = "#2E3A24" },
})
kind("skeletonGuard", 2, true, 35, 41, {
	defMul = 1.4,
	ability = "cleave",
	shape = "humanoid",
	colors = { primary = "#D8D2C2", secondary = "#5A5A60" },
})
kind("specter", 2, true, 37, 43, {
	hpMul = 0.85,
	attack = "ranged",
	damageKind = "magic",
	range = 24,
	element = "ice",
	ability = "wail",
	shape = "flyer",
	colors = { primary = "#6E8FA8", secondary = "#C9E3F2" },
})
kind("necromancer", 2, true, 39, 45, {
	hpMul = 0.9,
	attack = "ranged",
	damageKind = "magic",
	range = 28,
	ability = "boneNova",
	shape = "humanoid",
	colors = { primary = "#1F1F24", secondary = "#5FA06B" },
})

-- Region 3: Ashen Wastes (45–70) / Deepforge (60–70)
kind("salamander", 3, false, 45, 52, {
	speed = 1.1,
	element = "fire",
	ability = "fireBreath",
	shape = "quadruped",
	size = 1.1,
	colors = { primary = "#B5462B", secondary = "#F0A030" },
})
kind("ashOrc", 3, false, 48, 56, {
	hpMul = 1.2,
	atkMul = 1.1,
	ability = "cleave",
	shape = "humanoid",
	size = 1.2,
	colors = { primary = "#5C5A55", secondary = "#8A3A2A" },
})
kind("fireGolem", 3, false, 52, 60, {
	hpMul = 1.6,
	defMul = 1.5,
	speed = 0.75,
	moveSpeed = 9,
	element = "fire",
	ability = "emberNova",
	shape = "golem",
	size = 1.6,
	colors = { primary = "#3A2A22", secondary = "#FF7A1A" },
})
kind("desertScorpion", 3, false, 55, 63, {
	speed = 1.2,
	element = "poison",
	ability = "poisonPool",
	shape = "spider",
	size = 1.3,
	colors = { primary = "#C29A5B", secondary = "#6B4A2B" },
})
kind("wyvern", 3, false, 58, 66, {
	hpMul = 1.1,
	attack = "ranged",
	range = 22,
	element = "fire",
	ability = "fireBreath",
	shape = "dragon",
	size = 1.3,
	colors = { primary = "#6B2E25", secondary = "#C97B3A" },
})
kind("renegadeDwarf", 3, true, 60, 65, {
	defMul = 1.5,
	ability = "charge",
	shape = "humanoid",
	size = 0.85,
	colors = { primary = "#6A4A32", secondary = "#9A9AA2" },
})
kind("magmaGolem", 3, true, 62, 68, {
	hpMul = 1.7,
	defMul = 1.4,
	speed = 0.75,
	moveSpeed = 9,
	element = "fire",
	ability = "slam",
	shape = "golem",
	size = 1.7,
	colors = { primary = "#2B1F1A", secondary = "#FF5A1A" },
})
kind("flameSmith", 3, true, 64, 70, {
	atkMul = 1.2,
	element = "fire",
	ability = "emberNova",
	shape = "humanoid",
	size = 1.1,
	colors = { primary = "#4A3A30", secondary = "#FF9A3A" },
})

-- Region 4: Frostpeak (70–100) / Glacier Heart (90–100)
kind("iceWolf", 4, false, 70, 78, {
	speed = 1.15,
	moveSpeed = 17,
	element = "ice",
	ability = "leap",
	shape = "quadruped",
	size = 1.1,
	colors = { primary = "#C8DDEB", secondary = "#7FA7C9" },
})
kind("yeti", 4, false, 74, 82, {
	hpMul = 1.4,
	atkMul = 1.1,
	ability = "slam",
	shape = "humanoid",
	size = 1.6,
	colors = { primary = "#EEF3F7", secondary = "#8FA3B3" },
})
kind("frostGiant", 4, false, 78, 88, {
	hpMul = 1.8,
	atkMul = 1.2,
	speed = 0.7,
	moveSpeed = 10,
	element = "ice",
	ability = "cleave",
	shape = "golem",
	size = 2,
	colors = { primary = "#7FA7C9", secondary = "#3A5A7A" },
})
kind("iceElemental", 4, false, 82, 92, {
	attack = "ranged",
	damageKind = "magic",
	range = 28,
	element = "ice",
	ability = "frostNova",
	shape = "flyer",
	size = 1.2,
	colors = { primary = "#9FE0FF", secondary = "#FFFFFF" },
})
kind("dragonspawn", 4, false, 85, 95, {
	hpMul = 1.2,
	atkMul = 1.15,
	element = "fire",
	ability = "fireBreath",
	shape = "dragon",
	size = 1.2,
	colors = { primary = "#3A4A6B", secondary = "#C9A45C" },
})
kind("crystalGuardian", 4, true, 90, 96, {
	hpMul = 1.7,
	defMul = 1.8,
	speed = 0.8,
	moveSpeed = 9,
	ability = "slam",
	shape = "golem",
	size = 1.6,
	colors = { primary = "#7FD4E8", secondary = "#E8FBFF" },
})
kind("youngFrostDragon", 4, true, 93, 100, {
	hpMul = 1.5,
	atkMul = 1.25,
	element = "ice",
	ability = "frostBreath",
	shape = "dragon",
	size = 1.6,
	colors = { primary = "#A8D8F0", secondary = "#3A6A9A" },
})

local byId: { [string]: MonsterDef } = {}
for _, def in LIST do
	assert(byId[def.id] == nil, `Monsters: duplicate id {def.id}`)
	byId[def.id] = def
end

return table.freeze({
	list = LIST,
	byId = byId,
	get = function(id: string): MonsterDef?
		return byId[id]
	end,
	variants = { "normal", "elite", "elite2" },
})
