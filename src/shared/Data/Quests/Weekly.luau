--!strict
-- Weekly contracts from the board on the plaza (S98, docs/DESIGN-15.md §3.1): 3 per week picked from these
-- templates with a seed of (userId, character, week); the week starts on Monday 00:00 UTC (Logic/Time.weekNumber).
-- Bigger than the daily ones (Weekly.reward). Plus one boss contract per week and character (bossContract):
-- defeat the highest boss the character may enter `n` times; only won dungeon runs count (Config.Boss.dailyRuns
-- applies). Outside the quest EXP budget, like the daily contracts (Data/QuestBudget).
-- S159 (owner 2026-10-20): the hunts count monsters in the character's level range (Daily.lvMin), a hand-in template,
-- and the set bonus once the PER_WEEK contracts are collected (`bonus`: EXP, gold, essence and Dragon Shards, the shards
-- once per account and week from Daily.SHARD_MIN_LEVEL; the boss contract is apart from the set).
-- Texts: weekly.<id>.title.

local Daily = require("./Daily")
local Exp = require("../../Logic/Exp")
local Prey = require("../../Logic/Prey")
local Rng = require("../../Logic/Rng")
local Types = require("./Types")

local region = Daily.region

local templates: { Types.DailyTemplate } = {
	{
		id = "hunt",
		minLevel = 1,
		objective = function(level)
			return { type = "kill", n = 120 + level, lvMin = Daily.lvMin(level) }
		end,
	},
	{
		-- owner 2026-10-23: the weekly prey (Logic/Prey): kill N of one monster kind, the area's kills 90 + L scaled by
		-- the kind's share, at least 30
		id = "prey",
		minLevel = 1,
		objective = function(level, rng)
			return Prey.objective(level, 90 + level, 30, rng or Rng.new(level))
		end,
	},
	{
		id = "elites",
		minLevel = 14,
		objective = function(level)
			return { type = "kill", n = 20, variant = "elite", lvMin = Daily.lvMin(level) }
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
		-- S159: side quests, hunting contracts or story quests handed in
		id = "handin",
		minLevel = 3,
		objective = function(_level)
			return { type = "handin", n = 8 }
		end,
	},
	{
		-- S101: world events (WorldEventService fires QuestEvents "event")
		id = "event",
		minLevel = 1,
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

-- Reward of one weekly contract for a character level: a quarter of the level's EXP (S159, was 0.30), the old daily
-- gold x2, a blessing (rotating line like Daily.bonus) and essences.
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
		exp = math.floor(Exp.expToNext(level) * 0.25),
		gold = 2 * (50 + level * 30),
		items = items,
	}
end

-- S159: the set bonus once every weekly contract is collected: EXP, essence and shards (once per account and week).
local BONUS = table.freeze({ exp = 0.20, shards = 8 })
local function bonus(level: number): Types.Reward
	local items =
		{ { id = if level >= 45 then "essence_shard" else "essence_dust", n = if level >= 45 then 3 else 10 } }
	return {
		exp = math.floor(Exp.expToNext(level) * BONUS.exp),
		gold = 0, -- the extras' gold stays within T-EC3 (tests/Balance FULL_INCOME.extras)
		items = items,
		shards = BONUS.shards,
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
	bonus = bonus,
	BONUS = BONUS,
	PER_WEEK = 3,
})
