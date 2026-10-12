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
	-- strongest skill entry + strongest item entry (skillId "item"); item part capped by caps[id .. "Item"], total by
	-- caps[id] (owner answer 14)
	split: boolean?,
}

local OWN = "own"

local function category(
	id: string,
	side: Side,
	kind: string?,
	stats: { string }?,
	mode: Mode,
	split: boolean?
): Category
	return table.freeze({
		id = id,
		side = side,
		kind = kind,
		stats = if stats then table.freeze(stats) else nil,
		mode = mode,
		split = split,
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
	category("enemyArmor", "enemy", "armorBreak", nil, "value", true),
	category("enemySlow", "enemy", "slow", nil, "value"),
	category("enemyMiss", "enemy", "misfortune", nil, "value"),
	-- S63: the enemy deals less (Bonebreaker); not enemyWeak, which raises the damage the enemy takes.
	category("enemyDamageDown", "enemy", "weaken", nil, "value", true),
	-- S63: the enemy attacks slower; strongest only (Harrying 20 and the bow's poison 10 give 20).
	category("enemyAttackSlow", "enemy", "attackSlow", nil, "value"),
	category(OWN, "own", nil, nil, "any"),
}

local byId: { [string]: Category } = {}
for _, entry in list do
	byId[entry.id] = entry
end

-- damageReduction: cap of the total reduction (all categories and own entries, multiplied); enemyMiss and allyMove:
-- cap of their category's share; intercept and interceptPerSecond: the Guardian's intercept (ROZWOJ 7.6); <id>Item:
-- cap of the item part of a split category.
local caps: { [string]: number } = table.freeze({
	damageReduction = 75,
	enemyMiss = 15,
	allyMove = 30,
	intercept = 30,
	interceptPerSecond = 25,
	enemyArmor = 50, -- S63: total armour break (skill + item)
	enemyArmorItem = 40, -- S63: armour break from items (Sundering grows with rarity, STATY 10)
	enemyDamageDown = 15, -- S63: total "deals less" (skill + item)
	enemyAttackSlow = 20, -- S63: attack slow
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
