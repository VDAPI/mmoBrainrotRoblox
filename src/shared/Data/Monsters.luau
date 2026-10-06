--!strict
-- Monster kinds of all four regions (DESIGN §15.2). Data only.
-- Names: localization keys "monster.<id>.<variant>" (variant = normal | elite | elite2).
-- Stats: Logic/MonsterStats from level x multipliers below x variant (Data/Combat.variants).
-- Elites and Elite II spawn only in caves (red zones); `elites = false` kinds have no elite variants.

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
	size: number, -- model scale before the variant scale (looks: Data/MonsterLooks, S24)
	aura: string?, -- bosses: aura colour (Data/Bosses look.aura)
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
	size: number?,
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
		size = o.size or 1,
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
	size = 0.5,
})
kind("wolf", 1, false, 2, 6, {
	speed = 1.15,
	moveSpeed = 14,
	ability = "leap",
})
kind("boar", 1, false, 5, 10, {
	hpMul = 1.25,
	defMul = 1.2,
	ability = "charge",
	size = 1.15,
})
kind("bandit", 1, false, 9, 14, {
	ability = "cleave",
})
kind("goblinScout", 1, true, 13, 18, {
	speed = 1.1,
	moveSpeed = 14,
	ability = "slam",
	size = 0.8,
})
kind("caveSpider", 1, true, 14, 20, {
	hpMul = 0.9,
	speed = 1.2,
	element = "poison",
	ability = "poisonPool",
})
kind("goblinShaman", 1, true, 16, 20, {
	hpMul = 0.8,
	attack = "ranged",
	damageKind = "magic",
	range = 26,
	ability = "boneNova",
	size = 0.85,
})

-- New kinds after the S17 tests (S19, DESIGN §15.2): more kinds per map, no level gaps.
kind("lynx", 1, false, 3, 7, {
	speed = 1.2,
	moveSpeed = 14,
	ability = "leap",
	size = 0.8,
})
kind("swampToad", 1, false, 4, 8, {
	hpMul = 1.1,
	atkMul = 0.9,
	element = "poison",
	ability = "poisonPool",
	moveSpeed = 11,
	size = 0.7,
})
kind("carrionCrow", 1, false, 6, 11, {
	hpMul = 0.75,
	speed = 1.3,
	attack = "ranged",
	range = 18,
	ability = "wail",
	size = 0.6,
})
kind("koboldMiner", 1, false, 10, 15, {
	hpMul = 0.95,
	defMul = 1.2,
	ability = "slam",
	size = 0.75,
})
kind("brownBear", 1, false, 16, 20, {
	hpMul = 1.4,
	atkMul = 1.1,
	speed = 0.85,
	ability = "slam",
	size = 1.5,
})

-- Region 2: Duskwood (20–45) / Crypt of the Forgotten (35–45)
kind("werewolf", 2, false, 20, 28, {
	hpMul = 1.1,
	speed = 1.1,
	moveSpeed = 14,
	ability = "leap",
	size = 1.3,
})
kind("forestWraith", 2, false, 23, 31, {
	hpMul = 0.8,
	attack = "ranged",
	damageKind = "magic",
	range = 26,
	element = "ice",
	ability = "frostNova",
})
kind("rotEnt", 2, false, 26, 34, {
	hpMul = 1.5,
	defMul = 1.4,
	speed = 0.8,
	moveSpeed = 9,
	element = "poison",
	ability = "slam",
	size = 1.5,
})
kind("darkCultist", 2, false, 29, 37, {
	attack = "ranged",
	damageKind = "magic",
	range = 28,
	ability = "voidPool",
})
kind("swampTroll", 2, false, 32, 40, {
	hpMul = 1.6,
	atkMul = 1.1,
	speed = 0.8,
	moveSpeed = 11,
	ability = "slam",
	size = 1.6,
})
kind("skeletonGuard", 2, true, 35, 41, {
	defMul = 1.4,
	ability = "cleave",
})
kind("specter", 2, true, 37, 43, {
	hpMul = 0.85,
	attack = "ranged",
	damageKind = "magic",
	range = 24,
	element = "ice",
	ability = "wail",
})
kind("necromancer", 2, true, 39, 45, {
	hpMul = 0.9,
	attack = "ranged",
	damageKind = "magic",
	range = 28,
	ability = "boneNova",
})

-- New kinds (S19).
kind("blackBear", 2, false, 21, 27, {
	hpMul = 1.35,
	speed = 0.9,
	ability = "slam",
	size = 1.5,
})
kind("ghoul", 2, false, 27, 33, {
	speed = 1.15,
	element = "poison",
	ability = "leap",
})
kind("bogSerpent", 2, false, 30, 36, {
	hpMul = 1.1,
	element = "poison",
	ability = "poisonPool",
	size = 1.1,
})
kind("marshWitch", 2, false, 36, 42, {
	hpMul = 0.85,
	attack = "ranged",
	damageKind = "magic",
	range = 26,
	element = "poison",
	ability = "voidPool",
})
kind("bloodBat", 2, false, 40, 45, {
	hpMul = 0.8,
	speed = 1.35,
	ability = "wail",
	size = 0.7,
})

-- Region 3: Ashen Wastes (45–70) / Deepforge (60–70)
kind("salamander", 3, false, 45, 52, {
	speed = 1.1,
	element = "fire",
	ability = "fireBreath",
	size = 1.1,
})
kind("ashOrc", 3, false, 48, 56, {
	hpMul = 1.2,
	atkMul = 1.1,
	ability = "cleave",
	size = 1.2,
})
kind("fireGolem", 3, false, 52, 60, {
	hpMul = 1.6,
	defMul = 1.5,
	speed = 0.75,
	moveSpeed = 9,
	element = "fire",
	ability = "emberNova",
	size = 1.6,
})
kind("desertScorpion", 3, false, 55, 63, {
	speed = 1.2,
	element = "poison",
	ability = "poisonPool",
	size = 1.3,
})
kind("wyvern", 3, false, 58, 66, {
	hpMul = 1.1,
	attack = "ranged",
	range = 22,
	element = "fire",
	ability = "fireBreath",
	size = 1.3,
})
kind("renegadeDwarf", 3, true, 60, 65, {
	defMul = 1.5,
	ability = "charge",
	size = 0.85,
})
kind("magmaGolem", 3, true, 62, 68, {
	hpMul = 1.7,
	defMul = 1.4,
	speed = 0.75,
	moveSpeed = 9,
	element = "fire",
	ability = "slam",
	size = 1.7,
})
kind("flameSmith", 3, true, 64, 70, {
	atkMul = 1.2,
	element = "fire",
	ability = "emberNova",
	size = 1.1,
})

-- New kinds (S19).
kind("wasteHyena", 3, false, 46, 52, {
	speed = 1.2,
	moveSpeed = 14,
	ability = "leap",
	size = 0.95,
})
kind("ashVulture", 3, false, 50, 56, {
	hpMul = 0.8,
	speed = 1.25,
	attack = "ranged",
	range = 20,
	ability = "wail",
	size = 0.8,
})
kind("fireImp", 3, false, 55, 61, {
	hpMul = 0.8,
	attack = "ranged",
	damageKind = "magic",
	range = 24,
	element = "fire",
	ability = "emberNova",
	size = 0.7,
})
kind("basilisk", 3, false, 61, 67, {
	hpMul = 1.2,
	defMul = 1.3,
	element = "poison",
	ability = "poisonPool",
	size = 0.8,
})
kind("desertMummy", 3, false, 66, 70, {
	hpMul = 1.15,
	speed = 0.9,
	ability = "boneNova",
})

-- Region 4: Frostpeak (70–100) / Glacier Heart (90–100)
kind("iceWolf", 4, false, 70, 78, {
	speed = 1.15,
	moveSpeed = 14,
	element = "ice",
	ability = "leap",
	size = 1.1,
})
kind("yeti", 4, false, 74, 82, {
	hpMul = 1.4,
	atkMul = 1.1,
	ability = "slam",
	size = 1.6,
})
kind("frostGiant", 4, false, 78, 88, {
	hpMul = 1.8,
	atkMul = 1.2,
	speed = 0.7,
	moveSpeed = 10,
	element = "ice",
	ability = "cleave",
	size = 2,
})
kind("iceElemental", 4, false, 82, 92, {
	attack = "ranged",
	damageKind = "magic",
	range = 28,
	element = "ice",
	ability = "frostNova",
	size = 1.2,
})
kind("dragonspawn", 4, false, 85, 95, {
	hpMul = 1.2,
	atkMul = 1.15,
	element = "fire",
	ability = "fireBreath",
	size = 1.2,
})
kind("crystalGuardian", 4, true, 90, 96, {
	hpMul = 1.7,
	defMul = 1.8,
	speed = 0.8,
	moveSpeed = 9,
	ability = "slam",
	size = 1.6,
})
kind("youngFrostDragon", 4, true, 93, 100, {
	hpMul = 1.5,
	atkMul = 1.25,
	element = "ice",
	ability = "frostBreath",
	size = 1.6,
})

-- New kinds (S19).
kind("snowLeopard", 4, false, 71, 78, {
	speed = 1.25,
	moveSpeed = 14,
	ability = "leap",
	size = 0.9,
})
kind("peakHarpy", 4, false, 76, 83, {
	hpMul = 0.85,
	speed = 1.2,
	attack = "ranged",
	range = 22,
	element = "lightning",
	ability = "wail",
})
kind("iceMammoth", 4, false, 82, 89, {
	hpMul = 1.5,
	atkMul = 1.1,
	speed = 0.8,
	ability = "slam",
	size = 1.9,
})
kind("frozenKnight", 4, false, 88, 95, {
	hpMul = 1.15,
	defMul = 1.4,
	element = "ice",
	ability = "cleave",
	size = 1.1,
})
kind("frostWyrm", 4, false, 95, 100, {
	hpMul = 1.3,
	element = "ice",
	ability = "frostBreath",
	size = 1.1,
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
