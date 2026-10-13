--!strict
-- Monster kinds of all four regions (DESIGN §15.2). Data only.
-- Names: localization keys "monster.<id>.<variant>" (variant = normal | elite | elite2).
-- Stats: Logic/MonsterStats from level x multipliers below x variant (Data/Combat.variants).
-- Elites and Elite II spawn only in caves (red zones); `elites = false` kinds have no elite variants.
-- S66: every kind names its family (Data/Families) and maybe one of its defence traits

local Families = require("./Families")

export type MonsterDef = {
	id: string,
	region: number, -- 1 meadows, 2 duskwood, 3 ashen, 4 frostpeak
	cave: boolean, -- lives in the region's cave
	levels: { min: number, max: number },
	hpMul: number,
	atkMul: number,
	defMul: number,
	mresMul: number, -- S66: magic resistance multiplier (default 1, independent of defMul)
	dodge: number, -- S66: % dodge against players' basic attacks (default 0, capped by Combat.dodgeCap)
	family: Families.FamilyId, -- S66: monster family (Data/Families)
	defence: Families.DefenceId?, -- S66: defence trait of the family (its values come from Data/Families)
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
	family: Families.FamilyId,
	defence: Families.DefenceId?,
	hpMul: number?,
	atkMul: number?,
	defMul: number?,
	mresMul: number?,
	dodge: number?,
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
	assert(Families.get(o.family), `Monsters: {id} has an unknown family {o.family}`)
	local trait: Families.Defence? = nil
	if o.defence then
		trait = Families.defence(o.family, o.defence)
		assert(trait, `Monsters: {id} names defence {o.defence} outside its family {o.family}`)
		assert(
			o.defMul == nil and o.mresMul == nil and o.dodge == nil,
			`Monsters: {id} sets a multiplier its defence trait already sets`
		)
	end
	table.insert(LIST, {
		id = id,
		region = region,
		cave = cave,
		levels = { min = minLevel, max = maxLevel },
		hpMul = o.hpMul or 1,
		atkMul = o.atkMul or 1,
		defMul = (trait and trait.defMul) or o.defMul or 1,
		mresMul = (trait and trait.mresMul) or o.mresMul or 1,
		dodge = (trait and trait.dodge) or o.dodge or 0,
		family = o.family,
		defence = o.defence,
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
	family = "animal",
	hpMul = 0.6,
	atkMul = 0.5,
	passive = true,
	elites = false,
	moveSpeed = 11,
	size = 0.5,
})
kind("wolf", 1, false, 2, 6, {
	family = "animal",
	speed = 1.15,
	moveSpeed = 14,
	ability = "leap",
})
kind("boar", 1, false, 5, 10, {
	family = "animal",
	hpMul = 1.05,
	defMul = 1.1,
	ability = "charge",
	size = 1.15,
})
kind("bandit", 1, false, 9, 14, {
	family = "humanoid",
	ability = "cleave",
})
kind("goblinScout", 1, true, 13, 18, {
	family = "humanoid",
	speed = 1.1,
	moveSpeed = 14,
	ability = "slam",
	size = 0.8,
})
kind("caveSpider", 1, true, 14, 20, {
	family = "animal",
	hpMul = 0.9,
	speed = 1.2,
	element = "poison",
	ability = "poisonPool",
})
kind("goblinShaman", 1, true, 16, 20, {
	family = "humanoid",
	hpMul = 0.95,
	attack = "ranged",
	damageKind = "magic",
	range = 26,
	ability = "boneNova",
	size = 0.85,
})

-- New kinds after the S17 tests (S19, DESIGN §15.2): more kinds per map, no level gaps.
kind("lynx", 1, false, 3, 7, {
	family = "animal",
	defence = "agile",
	speed = 1.2,
	moveSpeed = 14,
	ability = "leap",
	size = 0.8,
})
kind("swampToad", 1, false, 4, 8, {
	family = "animal",
	hpMul = 1.1,
	atkMul = 0.9,
	element = "poison",
	ability = "poisonPool",
	moveSpeed = 11,
	size = 0.7,
})
kind("carrionCrow", 1, false, 6, 11, {
	family = "animal",
	hpMul = 0.75,
	speed = 1.3,
	attack = "ranged",
	range = 18,
	ability = "wail",
	size = 0.6,
})
kind("koboldMiner", 1, false, 10, 15, {
	family = "humanoid",
	hpMul = 0.95,
	defMul = 1.2,
	ability = "slam",
	size = 0.75,
})
kind("brownBear", 1, false, 16, 20, {
	family = "animal",
	hpMul = 1.4,
	atkMul = 1.1,
	speed = 0.85,
	ability = "slam",
	size = 1.5,
})

-- Region 2: Duskwood (20–45) / Crypt of the Forgotten (35–45)
kind("werewolf", 2, false, 20, 28, {
	family = "beast",
	hpMul = 1.1,
	speed = 1.1,
	moveSpeed = 14,
	ability = "leap",
	size = 1.3,
})
kind("forestWraith", 2, false, 23, 31, {
	family = "undead",
	defence = "warded",
	hpMul = 0.8,
	attack = "ranged",
	damageKind = "magic",
	range = 26,
	element = "ice",
	ability = "frostNova",
})
kind("rotEnt", 2, false, 26, 34, {
	family = "beast",
	hpMul = 1.5,
	defMul = 1.4,
	speed = 0.8,
	moveSpeed = 9,
	element = "poison",
	ability = "slam",
	size = 1.5,
})
kind("darkCultist", 2, false, 29, 37, {
	family = "humanoid",
	attack = "ranged",
	damageKind = "magic",
	range = 28,
	ability = "voidPool",
})
kind("swampTroll", 2, false, 32, 40, {
	family = "humanoid",
	hpMul = 1.6,
	atkMul = 1.1,
	speed = 0.8,
	moveSpeed = 11,
	ability = "slam",
	size = 1.6,
})
kind("skeletonGuard", 2, true, 35, 41, {
	family = "undead",
	defence = "armored",
	ability = "cleave",
})
kind("specter", 2, true, 37, 43, {
	family = "undead",
	defence = "warded",
	hpMul = 0.85,
	attack = "ranged",
	damageKind = "magic",
	range = 24,
	element = "ice",
	ability = "wail",
})
kind("necromancer", 2, true, 39, 45, {
	family = "humanoid",
	hpMul = 0.9,
	attack = "ranged",
	damageKind = "magic",
	range = 28,
	ability = "boneNova",
})

-- New kinds (S19).
kind("blackBear", 2, false, 21, 27, {
	family = "animal",
	hpMul = 1.35,
	speed = 0.9,
	ability = "slam",
	size = 1.5,
})
kind("ghoul", 2, false, 27, 33, {
	family = "undead",
	speed = 1.15,
	element = "poison",
	ability = "leap",
})
kind("bogSerpent", 2, false, 30, 36, {
	family = "animal",
	hpMul = 1.1,
	element = "poison",
	ability = "poisonPool",
	size = 1.1,
})
kind("marshWitch", 2, false, 36, 42, {
	family = "humanoid",
	hpMul = 0.85,
	attack = "ranged",
	damageKind = "magic",
	range = 26,
	element = "poison",
	ability = "voidPool",
})
kind("bloodBat", 2, false, 40, 45, {
	family = "animal",
	defence = "agile",
	hpMul = 0.8,
	speed = 1.35,
	ability = "wail",
	size = 0.7,
})

-- Region 3: Ashen Wastes (45–70) / Deepforge (60–70)
kind("salamander", 3, false, 45, 52, {
	family = "elemental",
	speed = 1.1,
	element = "fire",
	ability = "fireBreath",
	size = 1.1,
})
kind("ashOrc", 3, false, 48, 56, {
	family = "humanoid",
	defence = "armored",
	hpMul = 1.2,
	atkMul = 1.1,
	ability = "cleave",
	size = 1.2,
})
kind("fireGolem", 3, false, 52, 60, {
	family = "elemental",
	defence = "armored",
	hpMul = 1.6,
	speed = 0.75,
	moveSpeed = 9,
	element = "fire",
	ability = "emberNova",
	size = 1.6,
})
kind("desertScorpion", 3, false, 55, 63, {
	family = "animal",
	speed = 1.2,
	element = "poison",
	ability = "poisonPool",
	size = 1.3,
})
kind("wyvern", 3, false, 58, 66, {
	family = "dragon",
	defence = "scaled",
	hpMul = 1.1,
	attack = "ranged",
	range = 22,
	element = "fire",
	ability = "fireBreath",
	size = 1.3,
})
kind("renegadeDwarf", 3, true, 60, 65, {
	family = "humanoid",
	defence = "armored",
	ability = "charge",
	size = 0.85,
})
kind("magmaGolem", 3, true, 62, 68, {
	family = "elemental",
	defence = "armored",
	hpMul = 1.7,
	speed = 0.75,
	moveSpeed = 9,
	element = "fire",
	ability = "slam",
	size = 1.7,
})
kind("flameSmith", 3, true, 64, 70, {
	family = "humanoid",
	atkMul = 1.2,
	element = "fire",
	ability = "emberNova",
	size = 1.1,
})

-- New kinds (S19).
kind("wasteHyena", 3, false, 46, 52, {
	family = "animal",
	speed = 1.2,
	moveSpeed = 14,
	ability = "leap",
	size = 0.95,
})
kind("ashVulture", 3, false, 50, 56, {
	family = "animal",
	hpMul = 0.8,
	speed = 1.25,
	attack = "ranged",
	range = 20,
	ability = "wail",
	size = 0.8,
})
kind("fireImp", 3, false, 55, 61, {
	family = "elemental",
	hpMul = 0.8,
	attack = "ranged",
	damageKind = "magic",
	range = 24,
	element = "fire",
	ability = "emberNova",
	size = 0.7,
})
kind("basilisk", 3, false, 61, 67, {
	family = "beast",
	hpMul = 1.2,
	defMul = 1.3,
	element = "poison",
	ability = "poisonPool",
	size = 0.8,
})
kind("desertMummy", 3, false, 66, 70, {
	family = "undead",
	hpMul = 1.15,
	speed = 0.9,
	ability = "boneNova",
})

-- Region 4: Frostpeak (70–100) / Glacier Heart (90–100)
kind("iceWolf", 4, false, 70, 78, {
	family = "animal",
	speed = 1.15,
	moveSpeed = 14,
	element = "ice",
	ability = "leap",
	size = 1.1,
})
kind("yeti", 4, false, 74, 82, {
	family = "beast",
	hpMul = 1.4,
	atkMul = 1.1,
	ability = "slam",
	size = 1.6,
})
kind("frostGiant", 4, false, 78, 88, {
	family = "humanoid",
	hpMul = 1.8,
	atkMul = 1.2,
	speed = 0.7,
	moveSpeed = 10,
	element = "ice",
	ability = "cleave",
	size = 2,
})
kind("iceElemental", 4, false, 82, 92, {
	family = "elemental",
	attack = "ranged",
	damageKind = "magic",
	range = 28,
	element = "ice",
	ability = "frostNova",
	size = 1.2,
})
kind("dragonspawn", 4, false, 85, 95, {
	family = "dragon",
	defence = "scaled",
	hpMul = 1.2,
	atkMul = 1.15,
	element = "fire",
	ability = "fireBreath",
	size = 1.2,
})
kind("crystalGuardian", 4, true, 90, 96, {
	family = "elemental",
	defence = "armored",
	hpMul = 1.7,
	speed = 0.8,
	moveSpeed = 9,
	ability = "slam",
	size = 1.6,
})
kind("youngFrostDragon", 4, true, 93, 100, {
	family = "dragon",
	defence = "scaled",
	hpMul = 1.5,
	atkMul = 1.25,
	element = "ice",
	ability = "frostBreath",
	size = 1.6,
})

-- New kinds (S19).
kind("snowLeopard", 4, false, 71, 78, {
	family = "animal",
	defence = "agile",
	speed = 1.25,
	moveSpeed = 14,
	ability = "leap",
	size = 0.9,
})
kind("peakHarpy", 4, false, 76, 83, {
	family = "beast",
	defence = "agile",
	hpMul = 0.85,
	speed = 1.2,
	attack = "ranged",
	range = 22,
	element = "lightning",
	ability = "wail",
})
kind("iceMammoth", 4, false, 82, 89, {
	family = "animal",
	hpMul = 1.5,
	atkMul = 1.1,
	speed = 0.8,
	ability = "slam",
	size = 1.9,
})
kind("frozenKnight", 4, false, 88, 95, {
	family = "undead",
	defence = "armored",
	hpMul = 1.15,
	element = "ice",
	ability = "cleave",
	size = 1.1,
})
kind("frostWyrm", 4, false, 95, 100, {
	family = "dragon",
	defence = "scaled",
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
