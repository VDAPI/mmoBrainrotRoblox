--!strict
-- Weapon and off-hand traits (docs/STATY.md 2A, 3): one per base type (Data/Items/Bases "trait"); strength from ItemRoll.trait (rarity baseMul x upgrades). Data only.

local Types = require("../Types")

export type TraitKind = "stat" | "hook" | "effect"

-- S63 (STATY 5): what an "effect" trait does to the target it hits. The grown number stays in TraitDef.value (and
-- reaches CombatService through TraitDef.hook); everything here is fixed.
export type OnHit = {
	effect: "bleed" | "poison" | "armorBreak" | "weaken" | "harass" | "shock",
	line: string?, -- regular line adding chance to the same effect
	linePct: number?, -- % of the hit when only the line procs
	chance: number?, -- fixed % chance; nil: the grown value is the chance (harass, shock) or every hit
	duration: number, -- s, one duration for all stacks
	maxStacks: number?, -- stacks from one player
	slow: number?, -- % move slow
	attackSlow: number?, -- % attack slow
	healCut: number?, -- % less healing and shields on a player (PvP)
	gap: number?, -- shock: s per target
	notBoss: boolean?, -- shock: bosses and Elite II are immune
	delayShare: number?, -- shock: share of the monster's attack interval added after the stun
}

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
	fixedHooks: { [string]: number }?, -- S64: hooks added as is, never scaled (STATY 10: rarity and upgrades raise only the grown value)
	pvp: number, -- multiplier against players (STATY 8): 1 like a line, 0.5 half, 0 none
	live: boolean, -- false: no code yet; ItemRoll.trait returns nil, tooltip and wiki hide it (all live since S65)
	chanceCap: boolean?, -- S65: tooltip clamps {v} to Combat.onHitChanceCap (the grown value is a chance)
	onHit: OnHit?, -- kind "effect" (S63)
	nodeHooks: { string }?, -- S68: passive hooks of path nodes that strengthen it (tooltip details list those nodes)
	capRef: Types.CapRef?, -- S68: cap shown in the tooltip details (enforced elsewhere)
}

-- One live on-hit trait with its effect (no optional field, so callers need no casts).
export type OnHitEntry = { trait: TraitDef, onHit: OnHit }

type Extra = {
	stat: string?,
	hook: string?,
	params: { [string]: number }?,
	fixedHooks: { [string]: number }?,
	pvp: number,
	live: boolean?,
	chanceCap: boolean?,
	onHit: OnHit?,
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
		fixedHooks = if extra.fixedHooks then table.freeze(extra.fixedHooks) else nil,
		pvp = extra.pvp,
		live = extra.live == true,
		chanceCap = extra.chanceCap,
		onHit = if extra.onHit then table.freeze(extra.onHit) else nil,
	}
	table.insert(LIST, def)
	BY_ID[id] = def
end

-- All 24 traits are live since S65; numbers are starting values for S84 / S88.
-- S64: the fixed chance of Swordplay and Parry is both the text placeholder {chance} and a fixed hook.
local SWORDPLAY_CHANCE = 10
local PARRY_CHANCE = 5
trait("swordplay", "hook", "counter", 25, {
	hook = "counterDamage",
	params = { chance = SWORDPLAY_CHANCE },
	fixedHooks = { riposte = SWORDPLAY_CHANCE },
	pvp = 0.5,
	live = true,
})
-- every: the n-th basic attack strikes again; reset: s without a basic attack that restart the count
trait(
	"twinCut",
	"hook",
	"rhythm",
	40,
	{ hook = "traitTwinCut", params = { every = 5, reset = 5 }, pvp = 1, live = true }
)
trait("reaping", "hook", "killHeal", 1, { hook = "killHeal", pvp = 0, live = true })
trait("bonebreaker", "effect", "weaken", 6, {
	hook = "traitWeaken",
	pvp = 0.5,
	live = true,
	onHit = { effect = "weaken", duration = 4 },
})
-- threshold is text only; the code reads Combat.lowHpFraction (items.spec keeps them equal)
trait(
	"beheading",
	"hook",
	"execute",
	18,
	{ hook = "traitExecute", params = { threshold = 30 }, pvp = 0.5, live = true }
)
trait("rendingGash", "effect", "bleed", 30, {
	hook = "traitWound",
	pvp = 1,
	live = true,
	onHit = {
		effect = "bleed",
		line = "woundChance",
		linePct = 20,
		chance = 15,
		duration = 4,
		maxStacks = 3,
		healCut = 20,
	},
})
trait("sundering", "effect", "armorBreak", 5, {
	hook = "traitArmorBreak",
	pvp = 1,
	live = true,
	onHit = { effect = "armorBreak", duration = 6, maxStacks = 5 },
})
trait(
	"runThrough",
	"hook",
	"pierceBehind",
	25,
	-- width x depth studs of the band behind the target's back edge
	{ hook = "traitRunThrough", params = { width = 4, depth = 4 }, pvp = 1, live = true }
)
trait("parry", "hook", "block", 0.5, {
	hook = "blockHeal",
	params = { chance = PARRY_CHANCE },
	fixedHooks = { block = PARRY_CHANCE },
	pvp = 0.5,
	live = true,
})
trait("harrying", "effect", "harass", 15, {
	hook = "traitHarass",
	chanceCap = true,
	pvp = 1,
	live = true,
	onHit = { effect = "harass", duration = 2, slow = 20, attackSlow = 20 },
})
trait("toxicBarbs", "effect", "poison", 30, {
	hook = "traitPoison",
	pvp = 1,
	live = true,
	onHit = {
		effect = "poison",
		line = "poisonChance",
		linePct = 20,
		chance = 15,
		duration = 5,
		maxStacks = 3,
		attackSlow = 10,
	},
})
trait("criticalForce", "stat", "critDamage", 25, { stat = "critDmg", pvp = 1, live = true })
trait("easyPrey", "hook", "controlled", 10, { hook = "controlledDamage", pvp = 0.5, live = true })
trait("bodkinBolt", "stat", "armorPierce", 20, { stat = "pierce", pvp = 1, live = true })
-- window: s the drawn shot waits for the next basic attack (x main weapon speed)
trait("fullDraw", "hook", "nextBasic", 30, { hook = "traitFullDraw", params = { window = 4 }, pvp = 0.5, live = true })
-- Grown value = chance %, capped by Combat.onHitChanceCap; params: Logic/Traits.ElementSpec of the Spark.
trait("elementalSpark", "hook", "elementProc", 35, {
	hook = "traitSpark",
	params = {
		burnPct = 30,
		burnDuration = 2,
		slowPct = 20,
		slowDuration = 2,
		arcPct = 40,
		sameTargetPct = 20,
		arcRadius = 10,
	},
	-- fixed: Frostbite % with an ice weapon, replaces SkillData.FROSTBITE when higher (today the same 6; S88 may
	-- raise it on its own, STATY 14)
	fixedHooks = { frostbite = 6 },
	chanceCap = true,
	pvp = 1,
	live = true,
})
trait("elementalMight", "hook", "elementPower", 30, {
	hook = "elementRider",
	-- fixed: Frostbite % with an ice weapon (instead of 6); riderSameTarget: a skill arc with no second enemy hits
	-- the same target for arcPct x elementRider %
	fixedHooks = { frostbite = 10, riderSameTarget = 1 },
	pvp = 1,
	live = true,
})
-- still: s without moving before the seal glows; step: studs a move may take without breaking it
trait(
	"runicSeal",
	"hook",
	"standStill",
	8,
	{ hook = "traitRuneSeal", params = { still = 1.5, step = 1 }, pvp = 0.5, live = true }
)
trait("learnedFormulae", "stat", "costReduce", 8, { stat = "costReduce", pvp = 1, live = true })
trait("powerLens", "stat", "skillDamage", 6, { stat = "skillDmg", pvp = 1, live = true })
trait("anointment", "stat", "healPower", 8, { stat = "healPower", pvp = 1, live = true })
-- radius: studs to the most wounded ally
trait(
	"savingBlow",
	"hook",
	"damageHeal",
	4,
	{ hook = "traitSavingBlow", params = { radius = 30 }, pvp = 0.5, live = true }
)
trait("concussion", "effect", "shock", 6, {
	hook = "traitShock",
	chanceCap = true,
	pvp = 1,
	live = true,
	onHit = { effect = "shock", duration = 0.5, gap = 8, notBoss = true, delayShare = 0.5 },
})
trait("prosperity", "stat", "itemFind", 8, { stat = "dropBonus", pvp = 0, live = true })

local MATCH = 3 -- STATY 2B: a line that suits the type's trait rolls 3x as often; 0 = never on this type

-- Pool weights per base type (STATY 3, last column); lines not listed weigh 1. blockChance on a shield weighs 1.
local AFFINITY: { [string]: { [string]: number } } = {
	sword1h = { critChance = MATCH, accuracy = MATCH, basicDmg = MATCH },
	saber1h = { atkSpeed = MATCH, basicDmg = MATCH, lifesteal = MATCH },
	axe1h = { lifesteal = MATCH, atkSpeed = MATCH, woundChance = MATCH },
	mace1h = { skillDmg = MATCH, critChance = MATCH },
	sword2h = { critChance = MATCH, critDmg = MATCH, skillDmg = MATCH },
	axe2h = { lifesteal = MATCH, woundChance = MATCH, dotPower = MATCH },
	hammer2h = { skillDmg = MATCH, pierce = MATCH, critDmg = MATCH },
	spear2h = { basicDmg = MATCH, atkSpeed = MATCH, pierce = MATCH },
	shield = { critResist = MATCH, hpPct = MATCH, meleeGuard = MATCH },
	shortbow = { atkSpeed = MATCH, basicDmg = MATCH, accuracy = MATCH },
	bow = { atkSpeed = MATCH, poisonChance = MATCH, dotPower = MATCH },
	longbow = { critChance = MATCH, critDmg = MATCH, skillDmg = MATCH },
	crossbow = { skillDmg = MATCH, poisonChance = MATCH, dotPower = MATCH },
	heavycrossbow = { pierce = MATCH, critChance = MATCH, skillDmg = MATCH },
	quiver = { atkSpeed = MATCH, basicDmg = MATCH, poisonChance = MATCH },
	wand = { basicDmg = MATCH, atkSpeed = MATCH, critChance = MATCH },
	staff = { skillDmg = MATCH, magAtk = MATCH, dotPower = MATCH },
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

-- S68 (STATY 3): path node hooks that strengthen a trait and the cap it lives under. A class session that adds a
-- node strengthening a trait through a hook not listed here adds the hook to the list.
local function capOf(source: "stat" | "combat" | "category" | "luck", key: string): Types.CapRef
	return table.freeze({ source = source, key = key })
end
local DETAILS: { [string]: { nodeHooks: { string }?, capRef: Types.CapRef? } } = {
	swordplay = { nodeHooks = { "riposte" }, capRef = capOf("combat", "riposteCap") },
	parry = { nodeHooks = { "block" }, capRef = capOf("combat", "blockCap") },
	beheading = { nodeHooks = { "executioner" }, capRef = capOf("combat", "executionerCap") },
	rendingGash = { nodeHooks = { "bleedDamage" }, capRef = capOf("combat", "onHitChanceCap") },
	toxicBarbs = {
		nodeHooks = { "poisonDamage", "poisonSlow", "poisonSpread" },
		capRef = capOf("combat", "onHitChanceCap"),
	},
	easyPrey = { nodeHooks = { "trapRootDuration", "poisonSlow" } },
	elementalSpark = { nodeHooks = { "elementRider" }, capRef = capOf("combat", "onHitChanceCap") },
	elementalMight = { nodeHooks = { "elementRider" } },
	sundering = { capRef = capOf("category", "enemyArmorItem") },
	bonebreaker = { capRef = capOf("category", "enemyDamageDown") },
	harrying = { capRef = capOf("category", "enemyAttackSlow") },
	bodkinBolt = { capRef = capOf("stat", "pierce") },
	learnedFormulae = { capRef = capOf("stat", "costReduce") },
	savingBlow = { capRef = capOf("stat", "lifesteal") }, -- healing yourself counts towards the lifesteal cap
	prosperity = { capRef = capOf("luck", "monsterItemCap") },
}
for id, detail in DETAILS do
	local def = BY_ID[id]
	assert(def, `ItemTraits: details of unknown trait {id}`)
	def.nodeHooks = if detail.nodeHooks then table.freeze(detail.nodeHooks) else nil
	def.capRef = detail.capRef
end

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

-- S63: live on-hit traits in a fixed order (it fixes the sequence of rolls in CombatService): bleed, poison, armour
-- break, weaken, harass, shock.
local ON_HIT_ORDER = { "bleed", "poison", "armorBreak", "weaken", "harass", "shock" }
local ON_HIT_LIST: { OnHitEntry } = {}
for _, effect in ON_HIT_ORDER do
	for _, def in LIST do
		local onHit = def.onHit
		if def.live and onHit and onHit.effect == effect then
			table.insert(ON_HIT_LIST, table.freeze({ trait = def, onHit = onHit }))
		end
	end
end

-- S64: trait multiplier against players by hook (hooks of traits are unique), so the code never writes 0.5.
local PVP_BY_HOOK: { [string]: number } = {}
for _, def in LIST do
	if def.hook then
		PVP_BY_HOOK[def.hook] = def.pvp
	end
end
table.freeze(PVP_BY_HOOK)

return table.freeze({
	list = LIST,
	pvpByHook = PVP_BY_HOOK,
	onHitList = table.freeze(ON_HIT_LIST),
	byId = BY_ID,
	affinity = AFFINITY,
	classAffinity = CLASS_AFFINITY,
	ICON = ICON,
	COLOR = COLOR,
	get = get,
	weight = weight,
})
