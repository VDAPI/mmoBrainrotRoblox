--!strict
-- Party buff and enemy debuff categories (S53, ROZWOJ 7.1). Every effect a skill puts on allies and every debuff the
-- party profits from carries one of these ids in SkillEffect.category. Within a category only the strongest effect
-- works; categories add up; own buffs ("own", effects on the caster) always add up, because they are the class
-- balance. The combining rule itself lives in Logic/EffectStack. Data only.

export type Mode = "pct" | "points" | "value" | "any"
export type Side = "ally" | "enemy" | "own"
export type Category = {
	id: string,
	side: Side,
	kind: string?, -- effect kind the category holds; nil = any (own)
	stats: { string }?, -- statBuff only: the stats an effect of this category may change
	mode: Mode, -- pct: statBuff with pct = true; points: flat percentage points; value: the effect's own value (%)
}

local OWN = "own"

local function category(id: string, side: Side, kind: string?, stats: { string }?, mode: Mode): Category
	return table.freeze({
		id = id,
		side = side,
		kind = kind,
		stats = if stats then table.freeze(stats) else nil,
		mode = mode,
	})
end

local list: { Category } = {
	category("allyAttack", "ally", "statBuff", { "physAtk", "magAtk" }, "pct"),
	category("allyHaste", "ally", "statBuff", { "atkSpeed" }, "pct"),
	category("allyCrit", "ally", "statBuff", { "critChance" }, "points"),
	-- moveSpeed already is a percentage of walk speed with base 0, so the category adds points (S53).
	category("allyMove", "ally", "statBuff", { "moveSpeed" }, "points"),
	category("allyGuard", "ally", "damageReduction", nil, "value"),
	category("allyVigor", "ally", "statBuff", { "maxHp", "armor", "mres" }, "pct"),
	category("enemyWeak", "enemy", "vulnerability", nil, "value"),
	category("enemyArmor", "enemy", "armorBreak", nil, "value"),
	category("enemySlow", "enemy", "slow", nil, "value"),
	category("enemyMiss", "enemy", "misfortune", nil, "value"),
	category(OWN, "own", nil, nil, "any"),
}

local byId: { [string]: Category } = {}
for _, entry in list do
	byId[entry.id] = entry
end

-- damageReduction: cap of the total reduction (all categories and own entries, multiplied); enemyMiss and allyMove:
-- cap of their category's share; intercept and interceptPerSecond: the Guardian's intercept (ROZWOJ 7.6).
local caps: { [string]: number } = table.freeze({
	damageReduction = 75,
	enemyMiss = 15,
	allyMove = 30,
	intercept = 30,
	interceptPerSecond = 25,
})

-- ROZWOJ 7.3 (S61): data rules of active party buffs (tests/PartyBuffRules): 10-60 s, radius up to 40 studs when cast,
-- cooldown never shorter than the duration; below rescueBelow s only rescue effects (invuln, guardianAngel, allyGuard,
-- intercept, shield) may go.
local rules = table.freeze({ minDuration = 10, maxDuration = 60, maxRadius = 40, rescueBelow = 10 })

return table.freeze({
	list = table.freeze(list),
	rules = rules,
	byId = table.freeze(byId),
	OWN = OWN,
	caps = caps,
	get = function(id: string?): Category?
		return if id then byId[id] else nil
	end,
})
