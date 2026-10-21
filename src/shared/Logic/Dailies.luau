--!strict
-- S159 (owner 2026-10-20, docs/DESIGN.md §20): the daily and weekly sets. Pure rules (Lune tests) for QuestService and
-- the board / journal / tracker: how far a set is, whether its bonus is due, the account's streak of full days
-- (account.dailies) and whether the Dragon Shards of a bonus are still due on this account today / this week.
-- Numbers: Data/Quests/Daily (BONUS, STREAK_CAP, SHARD_MIN_LEVEL) and Data/Quests/Weekly (BONUS).

local Quests = require("../Data/Quests")

local Dailies = {}

-- account.dailies: `streak` full days in a row (a full day = every daily contract and the bonus collected by any
-- character), `last` = the UTC day of the last full day, `shardDay` / `shardWeek` = the day / week whose bonus shards
-- this account already got.
export type State = { streak: number, last: number, shardDay: number, shardWeek: number }

function Dailies.fresh(): State
	return { streak = 0, last = 0, shardDay = 0, shardWeek = 0 }
end

local function int(v: any): number
	return if type(v) == "number" and v == v then math.max(0, math.floor(v)) else 0
end

-- A well-formed state from a saved value (anything else: a fresh one).
function Dailies.sanitize(raw: any): State
	if type(raw) ~= "table" then
		return Dailies.fresh()
	end
	return {
		streak = int(raw.streak),
		last = int(raw.last),
		shardDay = int(raw.shardDay),
		shardWeek = int(raw.shardWeek),
	}
end

-- The streak shown today: it lasts while the last full day is today or yesterday, else it is broken (0).
function Dailies.streakNow(state: State, today: number): number
	if state.last == today or state.last == today - 1 then
		return state.streak
	end
	return 0
end

-- The state after a full day on `today` and the streak its bonus pays: the same day again (another character) keeps
-- the streak, the day after the last one adds a day, a gap starts again at 1.
function Dailies.fullDay(state: State, today: number): (State, number)
	local streak = if state.last == today
		then math.max(1, state.streak)
		elseif state.last == today - 1 then state.streak + 1
		else 1
	local new = table.clone(state)
	new.streak = streak
	new.last = today
	return new, streak
end

-- The streak the bonus of a full day on `today` would pay (the board shows it before the last contract).
function Dailies.nextStreak(state: State, today: number): number
	local _, streak = Dailies.fullDay(state, today)
	return streak
end

-- Whether the daily bonus's shards are due for a character of `level` (once per account and UTC day).
function Dailies.dayShardsDue(state: State, today: number, level: number): boolean
	return level >= Quests.Daily.SHARD_MIN_LEVEL and state.shardDay ~= today
end

-- Whether the weekly bonus's shards are due for a character of `level` (once per account and week).
function Dailies.weekShardsDue(state: State, week: number, level: number): boolean
	return level >= Quests.Daily.SHARD_MIN_LEVEL and state.shardWeek ~= week
end

export type SetProgress = { total: number, complete: number, claimed: number, all: boolean }

-- How far a contract list is: contracts, complete ones (claimed or done), claimed ones, and `all` = every one
-- claimed (a list with no contract is never all).
function Dailies.progress(list: any): SetProgress
	local total, complete, claimed = 0, 0, 0
	if type(list) == "table" then
		for _, entry in list do
			if type(entry) == "table" and type(entry.objective) == "table" then
				total += 1
				if entry.claimed then
					claimed += 1
					complete += 1
				elseif (entry.progress or 0) >= (entry.objective.n or 1) then
					complete += 1
				end
			end
		end
	end
	return { total = total, complete = complete, claimed = claimed, all = total > 0 and claimed == total }
end

-- Whether the set bonus of a period state (character.quests.daily / .weekly) is due now: every contract claimed and
-- the bonus not taken yet.
function Dailies.bonusDue(period: any): boolean
	return type(period) == "table" and period.bonus ~= true and Dailies.progress(period.list).all
end

-- Whether daily contract `index` may be rerolled: on the list, not claimed, not complete, and a free reroll left.
function Dailies.canReroll(daily: any, index: number): (boolean, string?)
	if type(daily) ~= "table" or type(daily.list) ~= "table" then
		return false, "error.badRequest"
	end
	local entry = daily.list[index]
	if type(entry) ~= "table" or entry.claimed then
		return false, "error.badRequest"
	end
	if (daily.swaps or 0) >= Quests.Daily.REROLLS then
		return false, "quest.reroll.used"
	end
	if (entry.progress or 0) >= ((entry.objective or {}).n or 1) then
		return false, "quest.reroll.done"
	end
	return true, nil
end

-- The most Dragon Shards the sets can pay one account in a week (a streak of STREAK_CAP or more every day and the
-- weekly bonus): the documented ceiling of DESIGN §20 and tests/dailies.spec.
function Dailies.weekShardCap(): number
	local total = 0
	for day = 1, 7 do
		total += Quests.Daily.bonus(Quests.Daily.SHARD_MIN_LEVEL, Quests.Daily.STREAK_CAP + day).shards or 0
	end
	return total + (Quests.Weekly.bonus(Quests.Daily.SHARD_MIN_LEVEL).shards or 0)
end

return Dailies
