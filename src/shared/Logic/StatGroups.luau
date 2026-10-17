--!strict
-- S134g (F1): the fixed groups of an item's statistics block, in order; inside a group the order of `keys` (StatCalc
-- stat or hook ids after Data/Bonuses: a line reads as its `stat` or `hook`, hp / mana / energy as maxHp / maxMana /
-- maxEnergy) and `prefixes` (lines with a parameter). Not balance numbers (CLAUDE.md): only the reading order.
-- S134j: its own module (was inside Logic/TooltipModel) so Logic/Reroll orders its preview the same way without a
-- require cycle; TooltipModel.STAT_GROUPS / TooltipModel.groupOf are these.

local Bonuses = require("../Data/Bonuses")
local ItemRoll = require("./ItemRoll")

local StatGroups = {}

-- Stat aliases of the base keys and lines (hp / mana / energy read as the derived maxima).
StatGroups.ALIASES = table.freeze({ hp = "maxHp", mana = "maxMana", energy = "maxEnergy" }) :: { [string]: string }

-- Every published line of Data/Bonuses has a group (tooltip.spec); anything else goes last.
StatGroups.LIST = table.freeze({
	{ id = "attributes", keys = { "str", "dex", "int", "vit" }, prefixes = {} },
	{
		id = "attack",
		keys = {
			"physAtk",
			"magAtk",
			"critChance",
			"critDmg",
			"atkSpeed",
			"pierce",
			"magicPierce",
			"accuracy",
			"skillDmg",
			"basicDmg",
			"lifesteal",
			"woundChance",
			"poisonChance",
			"dotPower",
		},
		prefixes = { "vs_" },
	},
	{
		id = "defence",
		keys = {
			"maxHp",
			"armor",
			"mres",
			"resFire",
			"resIce",
			"resLightning",
			"resPoison",
			"block",
			"dodge",
			"critResist",
			"meleeGuard",
			"rangedGuard",
		},
		prefixes = { "res_" },
	},
	{
		id = "resources",
		keys = {
			"maxMana",
			"maxEnergy",
			"hpRegen",
			"manaRegen",
			"energyRegen",
			"resourceOnHit",
			"costReduce",
			"healPower",
			"moveSpeed",
			"dropBonus",
			"expBonus",
			"goldBonus",
		},
		prefixes = {},
	},
})

-- The StatCalc stat or hook a line id or base key reads as (aliases applied).
function StatGroups.readKey(key: string): string
	local aliases = StatGroups.ALIASES
	local bonus = Bonuses.get(key)
	if bonus then
		local read = if bonus.replacedBy then Bonuses.get(bonus.replacedBy) or bonus else bonus
		local id = read.hook or read.stat or key
		return aliases[id] or id
	end
	local id = ItemRoll.baseKey(key)
	return aliases[id] or id
end

-- (group index, place in the group) of a line id or base key; nil when no group lists it.
function StatGroups.groupOf(key: string): (number?, number?)
	local read = StatGroups.readKey(key)
	for index, group in StatGroups.LIST do
		local at = table.find(group.keys, read)
		if at then
			return index, at
		end
		for p, prefix in group.prefixes do
			if string.sub(read, 1, #prefix) == prefix then
				return index, #group.keys + p
			end
		end
	end
	return nil, nil
end

-- A sort key of `key` (group, then place; ungrouped keys after every group).
function StatGroups.rank(key: string): number
	local group, place = StatGroups.groupOf(key)
	return (group or #StatGroups.LIST + 1) * 1000 + (place or 0)
end

return StatGroups
