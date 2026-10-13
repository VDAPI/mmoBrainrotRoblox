--!strict
-- Weekly contracts from the board on the plaza (S98, docs/DESIGN-15.md §3.1): 3 per week picked from these
-- templates with a seed of (userId, character, week); the week starts on Monday 00:00 UTC (Logic/Time.weekNumber).
-- Bigger than the daily ones (Weekly.reward). Plus one boss contract per week and character (bossContract):
-- defeat the highest boss the character may enter `n` times; only won dungeon runs count (Config.Boss.dailyRuns
-- applies). Outside the quest EXP budget, like the daily contracts (Data/QuestBudget).
-- Texts: weekly.<id>.title.

local Daily = require("./Daily")
local Exp = require("../../Logic/Exp")
local Types = require("./Types")

local region = Daily.region

local templates: { Types.DailyTemplate } = {
	{
		id = "hunt",
		minLevel = 1,
		objective = function(level)
			return { type = "kill", n = 120 + level, region = region(level) }
		end,
	},
	{
		id = "elites",
		minLevel = 14,
		objective = function(level)
			return { type = "kill", n = 20, region = region(level), variant = "elite" }
		end,
	},
	{
		-- Elite II from the first Meadows cave (meadows_hideout, levels 7-12), so 14 like the elites
		id = "elite2",
		minLevel = 14,
		objective = function(level)
			return { type = "kill", n = 3, region = region(level), variant = "elite2" }
		end,
	},
	{
		id = "gather",
		minLevel = 1,
		objective = function(_level)
			return { type = "gather", n = 30 }
		end,
	},
	{
		id = "fish",
		minLevel = 1,
		objective = function(_level)
			return { type = "fish", n = 15 }
		end,
	},
	{
		id = "upgrade",
		minLevel = 10,
		objective = function(_level)
			return { type = "upgrade", n = 3, up = 2 }
		end,
	},
	{
		id = "duels",
		minLevel = 10,
		objective = function(_level)
			return { type = "duel", n = 10 }
		end,
	},
	{
		-- S101: world events (WorldEventService) turn this on
		id = "event",
		minLevel = 1,
		hidden = true,
		objective = function(_level)
			return { type = "event", n = 2 }
		end,
	},
}

local byId: { [string]: Types.DailyTemplate } = {}
for _, template in templates do
	byId[template.id] = template
end

local LINES = { "warrior", "hunter", "sage", "guardian", "fortune" }

-- Reward of one weekly contract for a character level: twice the daily EXP and gold, a blessing one rarity above the
-- daily one (rotating line like Daily.reward) and essences.
local function reward(level: number): Types.Reward
	local blessing = if level >= 35 then 4 elseif level >= 15 then 3 else 2
	local items = {
		{ id = `blessing_{LINES[(level % #LINES) + 1]}_{blessing}`, n = 1 },
		{ id = "essence_dust", n = 10 },
	}
	if level >= 20 then
		table.insert(items, { id = "essence_shard", n = 3 })
	end
	if level >= 45 then
		table.insert(items, { id = "essence_crystal", n = 1 })
	end
	return {
		exp = math.floor(Exp.expToNext(level) * 0.30),
		gold = 2 * (50 + level * 30),
		items = items,
	}
end

-- The week's boss contract: wins needed.
local bossContract = table.freeze({ n = 2 })

-- Reward of the boss contract for a character level (no Legend Cores or dungeon stones: the core flow and the access
-- to bosses stay as tuned in S84-S94).
local function bossReward(level: number): Types.Reward
	local material = if level >= 45
		then { id = "essence_crystal", n = 2 }
		elseif level >= 20 then { id = "essence_shard", n = 4 }
		else { id = "essence_dust", n = 15 }
	return {
		exp = math.floor(Exp.expToNext(level) * 0.5),
		gold = 5 * (50 + level * 30),
		items = {
			{ id = `blessing_fortune_{if level >= 35 then 4 else 3}`, n = 1 },
			material,
		},
	}
end

return table.freeze({
	templates = templates,
	byId = byId,
	get = function(id: string): Types.DailyTemplate?
		return byId[id]
	end,
	reward = reward,
	bossReward = bossReward,
	bossContract = bossContract,
	PER_WEEK = 3,
})
