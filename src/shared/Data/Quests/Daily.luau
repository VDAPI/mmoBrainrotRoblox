--!strict
-- Daily contracts from the board on the plaza (DESIGN §20): 3 per day picked from these templates with a
-- seed of (userId, character, UTC day); amounts and regions scale with the character level.
-- Rewards: EXP (a share of the level's requirement), gold and a small item.

local Exp = require("../../Logic/Exp")
local Types = require("./Types")

local function region(level: number): number
	return if level <= 20 then 1 elseif level <= 45 then 2 elseif level <= 70 then 3 else 4
end

local templates: { Types.DailyTemplate } = {
	{
		id = "hunt",
		minLevel = 1,
		objective = function(level)
			return { type = "kill", n = 30 + math.floor(level / 4), region = region(level) }
		end,
	},
	{
		id = "elites",
		minLevel = 14,
		objective = function(level)
			return { type = "kill", n = 6, region = region(level), variant = "elite" }
		end,
	},
	{
		id = "herbs",
		minLevel = 1,
		objective = function(_level)
			return { type = "gather", n = 10, category = "herb" }
		end,
	},
	{
		id = "ore",
		minLevel = 1,
		objective = function(_level)
			return { type = "gather", n = 8, category = "ore" }
		end,
	},
	{
		id = "fish",
		minLevel = 1,
		objective = function(_level)
			return { type = "fish", n = 5 }
		end,
	},
	{
		id = "upgrade",
		minLevel = 5,
		objective = function(_level)
			return { type = "upgrade", n = 1, up = 1 }
		end,
	},
	{
		id = "boss",
		minLevel = 18,
		objective = function(_level)
			return { type = "boss", n = 1 }
		end,
	},
	{
		id = "duels",
		minLevel = 10,
		objective = function(_level)
			return { type = "duel", n = 3 }
		end,
	},
}

local byId: { [string]: Types.DailyTemplate } = {}
for _, template in templates do
	byId[template.id] = template
end

-- Reward of one contract for a character level.
local function reward(level: number): Types.Reward
	local blessing = if level >= 35 then 3 elseif level >= 15 then 2 else 1
	local lines = { "warrior", "hunter", "sage", "guardian", "fortune" }
	return {
		exp = math.floor(Exp.expToNext(level) * 0.15),
		gold = 50 + level * 30,
		items = { { id = `blessing_{lines[(level % #lines) + 1]}_{blessing}`, n = 1 }, { id = "essence_dust", n = 3 } },
	}
end

return table.freeze({
	templates = templates,
	byId = byId,
	get = function(id: string): Types.DailyTemplate?
		return byId[id]
	end,
	reward = reward,
	region = region,
	PER_DAY = 3,
})
