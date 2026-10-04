--!strict
-- Guild balance (DESIGN §19): founding requirements, member limit and the five guild skills (levels 1-5)
-- bought from the guild treasury. Effects per level add to derived stats of every member through the
-- "guild" modifier source; "members" raises the member limit instead.

export type SkillDef = {
	id: string,
	icon: string,
	nameKey: string,
	descKey: string, -- "{value}" = total effect at a level
	stat: string, -- derived stat id, or "members"
	perLevel: number,
	costs: { number }, -- costs[n] = treasury gold to reach level n
}

local MAX_LEVEL = 5

-- Shared cost curve; each skill scales it (EXP and luck are the strongest, so the most expensive).
local BASE_COSTS = { 20000, 50000, 120000, 250000, 500000 }

local function costs(multiplier: number): { number }
	local list = {}
	for i, cost in BASE_COSTS do
		list[i] = math.floor(cost * multiplier)
	end
	return list
end

local SKILLS: { SkillDef } = {
	{ id = "wisdom", icon = "✧", stat = "expBonus", perLevel = 2, costs = costs(1.2) },
	{ id = "fortune", icon = "⛀", stat = "goldBonus", perLevel = 3, costs = costs(1) },
	{ id = "healer", icon = "✚", stat = "potionDiscount", perLevel = 4, costs = costs(0.6) },
	{ id = "expansion", icon = "⚑", stat = "members", perLevel = 5, costs = costs(0.8) },
	{ id = "luck", icon = "☘", stat = "dropBonus", perLevel = 1, costs = costs(1.2) },
} :: any

local byId: { [string]: SkillDef } = {}
for _, skill in SKILLS do
	skill.nameKey = `guild.skill.{skill.id}.name`
	skill.descKey = `guild.skill.{skill.id}.desc`
	byId[skill.id] = skill
end

local Rules = table.freeze({
	createCost = 50000, -- gold
	createLevel = 20,
	baseMembers = 20, -- + expansion (max 45)
	nameMin = 3,
	nameMax = 20,
	tagMin = 2,
	tagMax = 4,
	motdMax = 200,
	inviteSeconds = 60,
	maxDeposit = 1e9, -- per deposit call
})

return table.freeze({
	list = SKILLS,
	byId = byId,
	MAX_LEVEL = MAX_LEVEL,
	Rules = Rules,
	get = function(id: string): SkillDef?
		return byId[id]
	end,
})
