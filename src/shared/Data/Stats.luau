--!strict
-- Derived statistics (DESIGN §4.4): display metadata, caps and formula constants. Data only;
-- the formulas themselves live in Logic/StatCalc.
--
-- Units: "pct" stats are stored in percent points (5 = 5 %). "flat" stats are plain numbers.
-- Item bonuses (S04), blessings (S07) and passives (S05) add to these ids through modifier sources.

export type StatGroup = "offense" | "defense" | "resources" | "other"

export type StatDef = {
	id: string,
	nameKey: string,
	group: StatGroup,
	format: "flat" | "pct",
	decimals: number,
	cap: number?, -- upper limit of the final value
	order: number,
}

local DEFS: { StatDef } = {
	-- Offense
	{ id = "physAtk", group = "offense", format = "flat", decimals = 0 },
	{ id = "magAtk", group = "offense", format = "flat", decimals = 0 },
	{ id = "critChance", group = "offense", format = "pct", decimals = 1, cap = 60 },
	{ id = "critDmg", group = "offense", format = "pct", decimals = 0 },
	{ id = "atkSpeed", group = "offense", format = "flat", decimals = 2, cap = 2.5 },
	{ id = "accuracy", group = "offense", format = "pct", decimals = 1 },
	{ id = "armorPen", group = "offense", format = "flat", decimals = 0 },
	{ id = "lifesteal", group = "offense", format = "pct", decimals = 1, cap = 15 },
	-- Defense
	{ id = "armor", group = "defense", format = "flat", decimals = 0 },
	{ id = "mres", group = "defense", format = "flat", decimals = 0 },
	{ id = "dodge", group = "defense", format = "pct", decimals = 1, cap = 30 },
	{ id = "resFire", group = "defense", format = "pct", decimals = 0, cap = 75 },
	{ id = "resIce", group = "defense", format = "pct", decimals = 0, cap = 75 },
	{ id = "resLightning", group = "defense", format = "pct", decimals = 0, cap = 75 },
	{ id = "resPoison", group = "defense", format = "pct", decimals = 0, cap = 75 },
	-- Resources
	{ id = "maxHp", group = "resources", format = "flat", decimals = 0 },
	{ id = "maxMana", group = "resources", format = "flat", decimals = 0 },
	{ id = "maxEnergy", group = "resources", format = "flat", decimals = 0 },
	{ id = "hpRegen", group = "resources", format = "flat", decimals = 1 },
	{ id = "hpRegenCombat", group = "resources", format = "flat", decimals = 1 },
	{ id = "manaRegen", group = "resources", format = "flat", decimals = 1 },
	{ id = "energyRegen", group = "resources", format = "flat", decimals = 1 },
	-- Other
	{ id = "moveSpeed", group = "other", format = "pct", decimals = 0, cap = 30 },
	{ id = "expBonus", group = "other", format = "pct", decimals = 0 },
	{ id = "dropBonus", group = "other", format = "pct", decimals = 0 },
	{ id = "goldBonus", group = "other", format = "pct", decimals = 0 },
	-- Cheaper potions at shops (guild skill "healer", S12).
	{ id = "potionDiscount", group = "other", format = "pct", decimals = 0, cap = 50 },
} :: any

local byId: { [string]: StatDef } = {}
for index, def in DEFS do
	def.nameKey = `stat.{def.id}`
	def.order = index
	byId[def.id] = def
end

-- Primary stats (allocated with points; also raised by gear/blessings).
local PRIMARY = { "str", "dex", "int", "vit" }

-- Display order of groups in the character window.
local GROUPS: { StatGroup } = { "offense", "defense", "resources", "other" }

-- Formula constants (DESIGN §4.4). L = character level.
local Formula = {
	hpBase = 80,
	hpPerLevel = 20,
	hpPerVit = 12,
	manaBase = 40,
	manaPerLevel = 6,
	manaPerInt = 8,
	energyBase = 100,
	energyPerLevel = 1,
	physPerStat = 0.02, -- weapon dmg x (1 + 0.02 x STR or DEX)
	magPerInt = 0.025,
	armorPerVit = 1,
	armorPerStr = 0.5,
	mresPerInt = 0.5,
	mresPerVit = 0.5,
	critBase = 5,
	critPerDex = 0.05,
	critDmgBase = 150,
	atkSpeedPerDex = 0.002,
	dodgePerDex = 0.03,
	hpRegenPct = 0.5, -- % of max HP per second out of combat
	hpRegenCombatPct = 0.1, -- % of max HP per second in combat
	manaRegenPct = 0.5,
	energyRegenBase = 8,
	walkSpeed = 16,
	-- Used until a weapon is equipped (S04).
	unarmed = { dmg = 4, mdmg = 3, speed = 1.0, ranged = false },
}

return table.freeze({
	list = DEFS,
	byId = byId,
	primary = PRIMARY,
	groups = GROUPS,
	Formula = table.freeze(Formula),
	get = function(id: string): StatDef?
		return byId[id]
	end,
})
