--!strict
-- Weapon and off-hand traits (docs/STATY.md 2A, 3): one per base type (Data/Items/Bases "trait"); strength from ItemRoll.trait (rarity baseMul x upgrades). Data only.

export type TraitKind = "stat" | "hook" | "effect"

export type TraitDef = {
	id: string,
	nameKey: string, -- trait.<id>.name
	lineKey: string, -- trait.<id>.line: {v} = grown value, other placeholders = params
	category: string, -- mechanism; 24 traits, 24 categories (STATY 3)
	kind: TraitKind, -- stat: adds `value` to a Data/Stats id; hook: itemStats.hooks; effect: on-hit effect (S63)
	value: number, -- the number that grows with rarity and upgrades (bold in STATY 3), Common +0
	stat: string?, -- kind "stat": Data/Stats id (flat addition)
	hook: string?, -- kind "hook" / "effect": itemStats.hooks key (provisional until the trait goes live)
	params: { [string]: number }?, -- fixed numbers of the trait (chance %, s, studs); never scaled
	pvp: number, -- multiplier against players (STATY 8): 1 like a line, 0.5 half, 0 none
	live: boolean, -- false: no code yet (S63-S65); ItemRoll.trait returns nil, tooltip and wiki hide it
}

type Extra = {
	stat: string?,
	hook: string?,
	params: { [string]: number }?,
	pvp: number,
	live: boolean?,
}

-- Section icon and colour of the "Trait" block in the tooltip.
local ICON = "◆" -- trait section marker
local COLOR = "#2E6E5E" -- dark sea green: unlike rarity colours and the blue of regular lines

local LIST: { TraitDef } = {}
local BY_ID: { [string]: TraitDef } = {}

local function trait(id: string, kind: TraitKind, category: string, value: number, extra: Extra)
	local def: TraitDef = {
		id = id,
		nameKey = `trait.{id}.name`,
		lineKey = `trait.{id}.line`,
		category = category,
		kind = kind,
		value = value,
		stat = extra.stat,
		hook = extra.hook,
		params = extra.params,
		pvp = extra.pvp,
		live = extra.live == true,
	}
	table.insert(LIST, def)
	BY_ID[id] = def
end

-- Hooks and params of traits that are not live are starting values (STATY 3); the session that makes a trait live may rename its hook or move a constant shared with path nodes to Data/Combat (STATY 13).
trait("swordplay", "hook", "counter", 25, { hook = "counterDamage", params = { chance = 10 }, pvp = 0.5 })
trait("twinCut", "hook", "rhythm", 40, { hook = "traitTwinCut", params = { every = 5, reset = 5 }, pvp = 1 })
trait("reaping", "hook", "killHeal", 1, { hook = "killHeal", pvp = 0 })
trait("bonebreaker", "effect", "weaken", 6, { hook = "traitWeaken", pvp = 0.5 })
trait("beheading", "hook", "execute", 18, { hook = "traitExecute", params = { threshold = 30 }, pvp = 0.5 })
trait("rendingGash", "effect", "bleed", 30, { hook = "traitWound", pvp = 1 })
trait("sundering", "effect", "armorBreak", 5, { hook = "traitArmorBreak", pvp = 1 })
trait(
	"runThrough",
	"hook",
	"pierceBehind",
	25,
	{ hook = "traitRunThrough", params = { width = 4, depth = 4 }, pvp = 1 }
)
trait("parry", "hook", "block", 0.5, { hook = "blockHeal", params = { chance = 5 }, pvp = 0.5 })
trait("harrying", "effect", "harass", 15, { hook = "traitHarass", pvp = 1 })
trait("toxicBarbs", "effect", "poison", 30, { hook = "traitPoison", pvp = 1 })
trait("criticalForce", "stat", "critDamage", 25, { stat = "critDmg", pvp = 1, live = true })
trait("easyPrey", "hook", "controlled", 10, { hook = "controlledDamage", pvp = 0.5 })
trait("bodkinBolt", "stat", "armorPierce", 20, { stat = "pierce", pvp = 1, live = true })
trait("fullDraw", "hook", "nextBasic", 30, { hook = "traitFullDraw", params = { window = 4 }, pvp = 0.5 })
trait("elementalSpark", "hook", "elementProc", 35, { hook = "traitSpark", pvp = 1 })
trait("elementalMight", "hook", "elementPower", 30, { hook = "elementRider", pvp = 1 })
trait("runicSeal", "hook", "standStill", 8, { hook = "traitRuneSeal", params = { still = 1.5, step = 1 }, pvp = 0.5 })
trait("learnedFormulae", "stat", "costReduce", 8, { stat = "costReduce", pvp = 1, live = true })
trait("powerLens", "stat", "skillDamage", 6, { stat = "skillDmg", pvp = 1, live = true })
trait("anointment", "stat", "healPower", 8, { stat = "healPower", pvp = 1, live = true })
trait("savingBlow", "hook", "damageHeal", 4, { hook = "traitSavingBlow", params = { radius = 30 }, pvp = 0.5 })
trait("concussion", "effect", "shock", 6, { hook = "traitShock", pvp = 1 })
trait("prosperity", "stat", "itemFind", 8, { stat = "dropBonus", pvp = 0, live = true })

local MATCH = 3 -- STATY 2B: a line that suits the type's trait rolls 3x as often; 0 = never on this type

-- Pool weights per base type (STATY 3, last column); lines not listed weigh 1. S63/S64 add woundChance,
-- poisonChance, dotPower, meleeGuard and blockChance (1).
local AFFINITY: { [string]: { [string]: number } } = {
	sword1h = { critChance = MATCH, accuracy = MATCH, basicDmg = MATCH },
	saber1h = { atkSpeed = MATCH, basicDmg = MATCH, lifesteal = MATCH },
	axe1h = { lifesteal = MATCH, atkSpeed = MATCH },
	mace1h = { skillDmg = MATCH, critChance = MATCH },
	sword2h = { critChance = MATCH, critDmg = MATCH, skillDmg = MATCH },
	axe2h = { lifesteal = MATCH },
	hammer2h = { skillDmg = MATCH, pierce = MATCH, critDmg = MATCH },
	spear2h = { basicDmg = MATCH, atkSpeed = MATCH, pierce = MATCH },
	shield = { critResist = MATCH, hpPct = MATCH },
	shortbow = { atkSpeed = MATCH, basicDmg = MATCH, accuracy = MATCH },
	bow = { atkSpeed = MATCH },
	longbow = { critChance = MATCH, critDmg = MATCH, skillDmg = MATCH },
	crossbow = { skillDmg = MATCH },
	heavycrossbow = { pierce = MATCH, critChance = MATCH, skillDmg = MATCH },
	quiver = { atkSpeed = MATCH, basicDmg = MATCH },
	wand = { basicDmg = MATCH, atkSpeed = MATCH, critChance = MATCH },
	staff = { skillDmg = MATCH, magAtk = MATCH },
	runestaff = { skillDmg = MATCH, critDmg = MATCH, magicPierce = MATCH },
	tome = { costReduce = MATCH, manaRegen = MATCH, mana = MATCH },
	orb = { skillDmg = MATCH, critDmg = MATCH, magicPierce = MATCH },
	scepter = { healPower = MATCH, magAtk = MATCH, critChance = MATCH },
	holystaff = { healPower = MATCH, magAtk = MATCH, skillDmg = MATCH },
	flail1h = { magicPierce = MATCH, skillDmg = MATCH, critChance = MATCH },
	relic = { healPower = MATCH, costReduce = MATCH, manaRegen = MATCH },
}

local CLASS_AFFINITY: { [string]: { [string]: { [string]: number } } } = {
	mace1h = { Warrior = { lifesteal = MATCH }, Cleric = { healPower = MATCH } }, -- shared base (STATY 3)
}

local function get(id: string?): TraitDef?
	return if id then BY_ID[id] else nil
end

-- Pool weight of `lineId` on `baseType`: the class entry first (when the class is known), then the type, else 1.
local function weight(baseType: string, lineId: string, classId: string?): number
	if classId then
		local byClass = CLASS_AFFINITY[baseType]
		local entry = byClass and byClass[classId]
		if entry and entry[lineId] ~= nil then
			return entry[lineId]
		end
	end
	local byType = AFFINITY[baseType]
	if byType and byType[lineId] ~= nil then
		return byType[lineId]
	end
	return 1
end

return table.freeze({
	list = LIST,
	byId = BY_ID,
	affinity = AFFINITY,
	classAffinity = CLASS_AFFINITY,
	ICON = ICON,
	COLOR = COLOR,
	get = get,
	weight = weight,
})
