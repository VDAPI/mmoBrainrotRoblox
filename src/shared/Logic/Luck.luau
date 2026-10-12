--!strict
-- Group luck (docs/ROZWOJ.md 6, S60). Pure. Every field is capped (Data/Luck) and the best value in the group counts:
-- a second Fortune priest adds nothing. Monsters: items, blessings and guild (dropBonus, best in the group) share one
-- cap with Fortune's item chance; gold and Elite II are Fortune only. Bosses: Fortune only (dropBonus ignored).
-- No luck in PvP (options.pvp).

local LuckData = require("../Data/Luck")

export type Totals = { [string]: number } -- raw fields from Paths.luck (before caps)
export type Member = { name: string, dropBonus: number?, luck: Totals? }
export type MonsterLuck = {
	itemBonus: number, -- % for Loot Modifiers.dropBonus: min(monsterItemCap, personal + fortune)
	personal: number, -- best dropBonus in the group
	fortune: number, -- best monsterItem in the group (capped)
	gold: number, -- % added to every credited player's goldBonus
	elite2Mul: number, -- multiplier of the Legendary weight of Elite II
	from: string?, -- name of the member whose Fortune counted
}
export type BossLuck = { legendaryMul: number, upgrade: number, extra: number, from: string? } -- chances 0..1
export type Options = { pvp: boolean? }

local Luck = {}

Luck.NONE_MONSTER = table.freeze({
	itemBonus = 0,
	personal = 0,
	fortune = 0,
	gold = 0,
	elite2Mul = 1,
}) :: MonsterLuck

Luck.NONE_BOSS = table.freeze({ legendaryMul = 1, upgrade = 0, extra = 0 }) :: BossLuck

function Luck.capped(field: string, value: number?): number
	local def = LuckData.fields[field]
	if not def then
		return 0
	end
	return math.clamp(value or 0, 0, def.cap)
end

-- The highest capped value of `field` and its owner (ties: the first member; 0 has no owner).
function Luck.best(members: { Member }, field: string): (number, string?)
	local best, from = 0, nil
	for _, member in members do
		local value = Luck.capped(field, member.luck and member.luck[field])
		if value > best then
			best, from = value, member.name
		end
	end
	return best, from
end

function Luck.monster(members: { Member }, options: Options?): MonsterLuck
	if options and options.pvp == true then
		return Luck.NONE_MONSTER
	end
	local personal = 0
	for _, member in members do
		personal = math.max(personal, member.dropBonus or 0)
	end
	local fortune, fromItem = Luck.best(members, "monsterItem")
	local gold, fromGold = Luck.best(members, "gold")
	local elite2, fromElite = Luck.best(members, "elite2")
	return {
		itemBonus = math.min(LuckData.monsterItemCap, personal + fortune),
		personal = personal,
		fortune = fortune,
		gold = gold,
		elite2Mul = 1 + elite2 / 100,
		from = fromItem or fromGold or fromElite,
	}
end

function Luck.boss(members: { Member }, options: Options?): BossLuck
	if options and options.pvp == true then
		return Luck.NONE_BOSS
	end
	local legendary, fromLeg = Luck.best(members, "bossLegendary")
	local upgrade, fromUp = Luck.best(members, "bossUpgrade")
	local extra, fromExtra = Luck.best(members, "bossExtra")
	return {
		legendaryMul = 1 + legendary / 100,
		upgrade = upgrade / 100,
		extra = extra / 100,
		from = fromLeg or fromUp or fromExtra,
	}
end

function Luck.isNeutral(luck: BossLuck?): boolean
	return luck == nil or (luck.legendaryMul <= 1 and luck.upgrade == 0 and luck.extra == 0)
end

return Luck
