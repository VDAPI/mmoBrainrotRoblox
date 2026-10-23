--!strict
-- Daily contracts from the board on the plaza (DESIGN §20): PER_DAY per day picked from these templates with a
-- seed of (userId, character, UTC day); amounts and the monster levels scale with the character level.
-- S159 (owner 2026-10-20, docs/DESIGN.md §20): 4 a day, one from every group of SLOTS ("combat", "gather"), the rest
-- from any group (weighted; PvP only in the free slots), one free reroll of one contract a day (REROLLS), and the set
-- bonus once every contract of the day is collected: EXP growing with the account's streak of full days
-- (Logic/Dailies), a blessing and a few Dragon Shards (once per account and UTC day, from SHARD_MIN_LEVEL).
-- Rewards of one contract: EXP (a share of the level's requirement), gold and essence dust. Outside the quest EXP
-- budget (Data/QuestBudget); the extras model of tests/Balance (extrasExpPerHour) reads `dayExp`.

local Exp = require("../../Logic/Exp")
local Prey = require("../../Logic/Prey")
local Rng = require("../../Logic/Rng")
local Types = require("./Types")

local function region(level: number): number
	return if level <= 20 then 1 elseif level <= 45 then 2 elseif level <= 70 then 3 else 4
end

-- S159: the lowest monster level a hunt counts: the character's level range (a few levels below and anything above).
local LEVEL_RANGE = 5
local function lvMin(level: number): number
	return math.max(1, level - LEVEL_RANGE)
end

local templates: { Types.DailyTemplate } = {
	{
		id = "hunt",
		minLevel = 1,
		slot = "combat",
		weight = 2,
		objective = function(level)
			return { type = "kill", n = 25 + math.floor(level / 4), lvMin = lvMin(level) }
		end,
	},
	{
		-- owner 2026-10-23: kill N of one monster kind on a hunting ground of the level (Logic/Prey); the kills of the
		-- whole area (22 + L / 5, a bit under the open hunt) scaled by the kind's share, at least 8
		id = "prey",
		minLevel = 1,
		slot = "combat",
		weight = 2,
		objective = function(level, rng)
			return Prey.objective(level, 22 + math.floor(level / 5), 8, rng or Rng.new(level))
		end,
	},
	{
		id = "elites",
		minLevel = 14,
		slot = "combat",
		objective = function(level)
			return { type = "kill", n = 5, variant = "elite", lvMin = lvMin(level) }
		end,
	},
	{
		-- a won dungeon run (DungeonService fires "boss"), Config.Boss.dailyRuns applies
		id = "boss",
		minLevel = 18,
		slot = "combat",
		objective = function(_level)
			return { type = "boss", n = 1 }
		end,
	},
	{
		-- S159: one world event (WorldEventService fires "event" for every rewarded participant)
		id = "event",
		minLevel = 5,
		slot = "combat",
		weight = 0.75,
		objective = function(_level)
			return { type = "event", n = 1 }
		end,
	},
	{
		id = "herbs",
		minLevel = 1,
		slot = "gather",
		objective = function(_level)
			return { type = "gather", n = 10, category = "herb" }
		end,
	},
	{
		id = "ore",
		minLevel = 1,
		slot = "gather",
		objective = function(_level)
			return { type = "gather", n = 8, category = "ore" }
		end,
	},
	{
		id = "fish",
		minLevel = 1,
		slot = "gather",
		objective = function(_level)
			return { type = "fish", n = 5 }
		end,
	},
	{
		id = "upgrade",
		minLevel = 5,
		slot = "craft",
		objective = function(_level)
			return { type = "upgrade", n = 1, up = 1 }
		end,
	},
	{
		-- S159: items taken apart at the blacksmith (the backpack's junk)
		id = "dismantle",
		minLevel = 5,
		slot = "craft",
		objective = function(_level)
			return { type = "dismantle", n = 5 }
		end,
	},
	{
		-- S159: side quests, hunting contracts or story quests handed in
		id = "handin",
		minLevel = 3,
		slot = "social",
		objective = function(_level)
			return { type = "handin", n = 2 }
		end,
	},
	{
		-- duels and arena matches (PvP: only in the free slots, half the weight)
		id = "duels",
		minLevel = 10,
		slot = "social",
		pvp = true,
		weight = 0.5,
		objective = function(_level)
			return { type = "duel", n = 2 }
		end,
	},
}

local byId: { [string]: Types.DailyTemplate } = {}
for _, template in templates do
	byId[template.id] = template
end

local LINES = { "warrior", "hunter", "sage", "guardian", "fortune" }

-- S159: one contract's share of the level's EXP requirement (was 0.15 for 3 a day, S11) and its gold.
local TASK_EXP = 0.09

-- Reward of one contract for a character level.
local function reward(level: number): Types.Reward
	return {
		exp = math.floor(Exp.expToNext(level) * TASK_EXP),
		gold = 40 + level * 20,
		items = { { id = "essence_dust", n = 2 } },
	}
end

-- S159: the set bonus. EXP = expToNext x (base + perDay x streak days, streak capped at STREAK_CAP); shards: `shards`
-- plus `streakShards` from `streakShardsFrom` days of the streak (account, once per UTC day); two blessings one rarity
-- above the old daily one (the three contract blessings of S11 became the bonus).
local BONUS = table.freeze({
	exp = 0.04,
	expPerDay = 0.01,
	shards = 2,
	streakShards = 1,
	streakShardsFrom = 5,
})
local STREAK_CAP = 7

local function bonus(level: number, streak: number): Types.Reward
	local days = math.clamp(streak, 1, STREAK_CAP)
	local blessing = if level >= 35 then 4 elseif level >= 15 then 3 else 2
	return {
		exp = math.floor(Exp.expToNext(level) * (BONUS.exp + BONUS.expPerDay * days)),
		gold = 0,
		items = { { id = `blessing_{LINES[(level % #LINES) + 1]}_{blessing}`, n = 2 } },
		shards = BONUS.shards + (if days >= BONUS.streakShardsFrom then BONUS.streakShards else 0),
	}
end

local PER_DAY = 4

-- S159: EXP of a full day (every contract and the bonus at `streak`) for the extras model.
local function dayExp(level: number, streak: number): number
	return PER_DAY * reward(level).exp + bonus(level, streak).exp
end

return table.freeze({
	templates = templates,
	byId = byId,
	get = function(id: string): Types.DailyTemplate?
		return byId[id]
	end,
	reward = reward,
	bonus = bonus,
	dayExp = dayExp,
	region = region,
	lvMin = lvMin,
	PER_DAY = PER_DAY,
	-- S159: the groups every day draws one contract from first (in this order); the rest come from any group
	SLOTS = table.freeze({ "combat", "gather" }),
	REROLLS = 1, -- free rerolls of one open contract per character and day
	STREAK_CAP = STREAK_CAP,
	BONUS = BONUS,
	SHARD_MIN_LEVEL = 10, -- the set bonus pays shards only from this character level (throwaway characters)
})
