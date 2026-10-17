--!strict
-- Hunting contract state (S99, S134k; DESIGN-15 §3.3). Pure (Lune); shared by ContractService, the client and the
-- tests. S134k: every contract up to the character's level may be active at once (no limit), a kill counts for every
-- matching active contract (its monster kind on its hunting ground, QuestLogic.amount), "Hand in all" at a giver.
-- character.quests.contract = {
--   done: the highest level up to which EVERY contract is handed in (a prefix),
--   extra: sorted levels > done handed in out of order (compacted: done moves while done + 1 is in extra),
--   active: { { level, progress } } taken and not handed in, one per level, sorted by level,
--   marks: the Hunter's Marks balance (spent at the Huntmaster, Logic/HuntShop),
--   auto: true after the first contract taken at an NPC (a level up then takes the new level's contract by itself),
--   shopWeek: { week, counts } purchases of the Huntmaster's entries with a weekly limit in that week,
-- }
-- Givers (take and hand in): the contract board in the city, the Huntmaster beside it and the scout of the contract's
-- region (giversOf). The contract of level L needs the character at L.

local Npcs = require("../Data/Npcs")
local QuestLogic = require("./QuestLogic")
local Quests = require("../Data/Quests")

type ContractQuest = Quests.ContractQuest

export type Active = { level: number, progress: { number } }
export type ShopWeek = { week: number, counts: { [string]: number } }
export type State = {
	done: number,
	extra: { number },
	active: { Active },
	marks: number,
	auto: boolean,
	shopWeek: ShopWeek,
}
-- An active contract with its save entry.
export type Taken = { contract: ContractQuest, entry: Active }

local Contracts = {}

Contracts.BOARD = "questboard"
Contracts.HUNTMASTER = "huntmaster"

-- A whole non-negative number of `value` (nil for anything else, NaN and infinities included).
local function count(value: any): number?
	local n = tonumber(value)
	if n == nil or n ~= n or n == math.huge or n == -math.huge then
		return nil
	end
	return math.max(0, math.floor(n))
end

-- The state of a character without any contract (also the save template).
function Contracts.empty(): State
	return { done = 0, extra = {}, active = {}, marks = 0, auto = false, shopWeek = { week = 0, counts = {} } }
end

-- A deep copy (the server edits a copy and writes it back whole).
function Contracts.copy(state: State): State
	local active: { Active } = {}
	for _, entry in state.active do
		table.insert(active, { level = entry.level, progress = table.clone(entry.progress) })
	end
	return {
		done = state.done,
		extra = table.clone(state.extra),
		active = active,
		marks = state.marks,
		auto = state.auto,
		shopWeek = { week = state.shopWeek.week, counts = table.clone(state.shopWeek.counts) },
	}
end

-- `done` moved over every level of `extra` that follows it; `extra` sorted without the levels now in the prefix.
local function compact(state: State)
	local set: { [number]: boolean } = {}
	for _, level in state.extra do
		if level > state.done then
			set[level] = true
		end
	end
	while set[state.done + 1] do
		set[state.done + 1] = nil
		state.done += 1
	end
	local list: { number } = {}
	for level in set do
		table.insert(list, level)
	end
	table.sort(list)
	state.extra = list
end

-- The contract state of `character.quests`, safe for nil, broken and pre-S134k saves: unknown levels, duplicates and
-- handed in contracts leave `active`, a progress that is not a list counts as zeros, marks are whole and >= 0. A
-- pre-S134k single active entry ({ level, progress }) reads as a list of one.
function Contracts.stateOf(quests: any): State
	local state = Contracts.empty()
	local branch = if type(quests) == "table" then quests.contract else nil
	if type(branch) ~= "table" then
		return state
	end
	local max = Quests.Contracts.MAX_LEVEL
	state.done = math.min(count(branch.done) or 0, max)
	if type(branch.extra) == "table" then
		for _, value in branch.extra do
			local level = count(value)
			if level and level >= 1 and level <= max then
				table.insert(state.extra, level)
			end
		end
	end
	compact(state)
	local raw = branch.active
	local list: { any } = {}
	if type(raw) == "table" then
		if raw.level ~= nil then
			list = { raw }
		else
			for _, entry in raw do
				table.insert(list, entry)
			end
		end
	end
	local seen: { [number]: boolean } = {}
	for _, entry in list do
		local level = if type(entry) == "table" then count(entry.level) else nil
		local contract = if level then Quests.Contracts.forLevel(level) else nil
		if level and contract and not seen[level] and not Contracts.isDone(state, level) then
			seen[level] = true
			local progress: { number } = {}
			local rawProgress = entry.progress
			for i = 1, #contract.objectives do
				progress[i] = if type(rawProgress) == "table" then count(rawProgress[i]) or 0 else 0
			end
			table.insert(state.active, { level = level, progress = progress })
		end
	end
	table.sort(state.active, function(a, b)
		return a.level < b.level
	end)
	state.marks = count(branch.marks) or 0
	state.auto = branch.auto == true
	local week = branch.shopWeek
	if type(week) == "table" then
		state.shopWeek.week = count(week.week) or 0
		if type(week.counts) == "table" then
			for key, value in week.counts do
				local n = count(value)
				if type(key) == "string" and n and n > 0 then
					state.shopWeek.counts[key] = n
				end
			end
		end
	end
	return state
end

-- Whether the contract of `level` is handed in.
function Contracts.isDone(state: State, level: number): boolean
	return level <= state.done or table.find(state.extra, level) ~= nil
end

-- Contracts handed in (the prefix and the out of order ones).
function Contracts.doneCount(state: State): number
	return state.done + #state.extra
end

-- The active entry of `level` (nil when that contract is not taken).
function Contracts.activeEntry(state: State, level: number): Active?
	for _, entry in state.active do
		if entry.level == level then
			return entry
		end
	end
	return nil
end

-- Every active contract with its entry, by level.
function Contracts.activeList(state: State): { Taken }
	local out: { Taken } = {}
	for _, entry in state.active do
		local contract = Quests.Contracts.forLevel(entry.level)
		if contract then
			table.insert(out, { contract = contract, entry = entry })
		end
	end
	return out
end

-- Whether an active contract has every objective done.
function Contracts.isTakenComplete(taken: Taken): boolean
	return QuestLogic.isComplete(taken.entry.progress, taken.contract.objectives)
end

-- The active contracts ready to hand in, by level.
function Contracts.complete(state: State): { Taken }
	local out: { Taken } = {}
	for _, taken in Contracts.activeList(state) do
		if Contracts.isTakenComplete(taken) then
			table.insert(out, taken)
		end
	end
	return out
end

-- Contracts the character may take now: level <= the character's, not handed in, not active; by level.
function Contracts.eligible(state: State, charLevel: number): { ContractQuest }
	local out: { ContractQuest } = {}
	local top = math.min(math.floor(charLevel), Quests.Contracts.MAX_LEVEL)
	for level = state.done + 1, top do
		if not Contracts.isDone(state, level) and not Contracts.activeEntry(state, level) then
			local contract = Quests.Contracts.forLevel(level)
			if contract then
				table.insert(out, contract)
			end
		end
	end
	return out
end

-- The NPCs that hand out and take back a contract: the board, the Huntmaster (S134k) and the scout of its region.
function Contracts.giversOf(contract: ContractQuest): { string }
	local out = { Contracts.BOARD }
	if Npcs.get(Contracts.HUNTMASTER) then
		table.insert(out, Contracts.HUNTMASTER)
	end
	local scout = `scout_{contract.map}`
	if Npcs.get(scout) then
		table.insert(out, scout)
	end
	return out
end

function Contracts.isGiver(npcId: string, contract: ContractQuest): boolean
	return table.find(Contracts.giversOf(contract), npcId) ~= nil
end

-- Whether `npcId` takes and hands in any contract (the board, the Huntmaster, a region scout).
function Contracts.isAnyGiver(npcId: string): boolean
	if npcId == Contracts.BOARD or npcId == Contracts.HUNTMASTER then
		return true
	end
	for _, contract in Quests.Contracts.list do
		if `scout_{contract.map}` == npcId then
			return true
		end
	end
	return false
end

-- The contracts `npcId` hands out to this character now ("Accept all" there).
function Contracts.acceptable(state: State, charLevel: number, npcId: string): { ContractQuest }
	local out: { ContractQuest } = {}
	for _, contract in Contracts.eligible(state, charLevel) do
		if Contracts.isGiver(npcId, contract) then
			table.insert(out, contract)
		end
	end
	return out
end

-- The finished contracts `npcId` takes back ("Hand in all" there), by level.
function Contracts.ready(state: State, npcId: string): { Taken }
	local out: { Taken } = {}
	for _, taken in Contracts.complete(state) do
		if Contracts.isGiver(npcId, taken.contract) then
			table.insert(out, taken)
		end
	end
	return out
end

-- Whether the character may take a contract at `npcId` now: the contract of `level`, or (nil) any. The reason
-- otherwise: "none" (nothing left: every contract up to the character's level and above is done or taken; for one
-- level: handed in, taken or unknown) | "level" (the next one needs a higher level) | "giver" (not at this NPC).
function Contracts.canAccept(state: State, charLevel: number, npcId: string, level: number?): (boolean, string?)
	if level then
		local contract = Quests.Contracts.forLevel(level)
		if not contract or Contracts.isDone(state, level) or Contracts.activeEntry(state, level) then
			return false, "none"
		end
		if charLevel < contract.level then
			return false, "level"
		end
		if not Contracts.isGiver(npcId, contract) then
			return false, "giver"
		end
		return true, nil
	end
	local eligible = Contracts.eligible(state, charLevel)
	if #eligible == 0 then
		return false, if #Contracts.upcoming(state, charLevel, 1) > 0 then "level" else "none"
	end
	for _, contract in eligible do
		if Contracts.isGiver(npcId, contract) then
			return true, nil
		end
	end
	return false, "giver"
end

-- Contracts up to the character's level still to do: the ones to take and the active ones not finished.
function Contracts.backlog(state: State, charLevel: number): number
	local n = #Contracts.eligible(state, charLevel)
	for _, taken in Contracts.activeList(state) do
		if not Contracts.isTakenComplete(taken) then
			n += 1
		end
	end
	return n
end

-- Up to `count` contracts above the character's level that are not handed in, by level.
function Contracts.upcoming(state: State, charLevel: number, limit: number): { ContractQuest }
	local out: { ContractQuest } = {}
	for level = math.max(state.done, math.floor(charLevel)) + 1, Quests.Contracts.MAX_LEVEL do
		if #out >= limit then
			break
		end
		local contract = Quests.Contracts.forLevel(level)
		if contract and not Contracts.isDone(state, level) and not Contracts.activeEntry(state, level) then
			table.insert(out, contract)
		end
	end
	return out
end

-- Whether every contract is handed in (false while the list is empty).
function Contracts.allDone(state: State): boolean
	local total = #Quests.Contracts.list
	return total > 0 and state.done >= total
end

-- The cosmetics a hand-in of `contracts` gives, `after` being the state after it: each reward's cosmetic, but the
-- title of the last contract (RULES.finalCosmetic) only once every contract is handed in, whichever contract came
-- last (out of order hand-ins). With no contracts: the title of a character that already handed in all 99.
function Contracts.earnedCosmetics(after: State, contracts: { ContractQuest }): { string }
	local final = Quests.Contracts.RULES.finalCosmetic
	local out: { string } = {}
	for _, contract in contracts do
		local id = contract.reward.cosmetic
		if id and id ~= final and not table.find(out, id) then
			table.insert(out, id)
		end
	end
	if final and Contracts.allDone(after) then
		table.insert(out, final)
	end
	return out
end

-- The levels of the active contracts a gameplay event advances (QuestLogic.amount on an unfinished objective: the
-- kill of the contract's kind on its hunting ground), by level.
function Contracts.credit(state: State, kind: string, data: { [string]: any }): { number }
	local out: { number } = {}
	for _, taken in Contracts.activeList(state) do
		for i, objective in taken.contract.objectives do
			if (taken.entry.progress[i] or 0) < objective.n and QuestLogic.amount(objective, kind, data, 0) > 0 then
				table.insert(out, taken.entry.level)
				break
			end
		end
	end
	return out
end

-- A copy with the contracts taken (empty progress; already taken or handed in ones are skipped).
function Contracts.withAccepted(state: State, contracts: { ContractQuest }): State
	local out = Contracts.copy(state)
	for _, contract in contracts do
		if not Contracts.isDone(out, contract.level) and not Contracts.activeEntry(out, contract.level) then
			table.insert(out.active, {
				level = contract.level,
				progress = QuestLogic.emptyProgress(contract.objectives),
			})
		end
	end
	table.sort(out.active, function(a, b)
		return a.level < b.level
	end)
	out.auto = true
	return out
end

-- A copy with the contracts of `levels` handed in (out of `active`, into the prefix or `extra`) and `marks` added.
function Contracts.withHandedIn(state: State, levels: { number }, marks: number): State
	local out = Contracts.copy(state)
	for _, level in levels do
		for i, entry in out.active do
			if entry.level == level then
				table.remove(out.active, i)
				break
			end
		end
		if not Contracts.isDone(out, level) then
			table.insert(out.extra, level)
		end
	end
	compact(out)
	out.marks += math.max(0, math.floor(marks))
	return out
end

-- A copy without the active contract of `level` (abandoned: its progress is lost, it can be taken again).
function Contracts.withAbandoned(state: State, level: number): State
	local out = Contracts.copy(state)
	for i, entry in out.active do
		if entry.level == level then
			table.remove(out.active, i)
			break
		end
	end
	return out
end

-- Hunter's Marks of the contract of `level` (S134k, RULES.marks): base + per10 x floor(L / 10), + milestone on every
-- 10th level. The only source of the number (ContractGen writes it into the reward, the migration's retro marks).
function Contracts.marksFor(level: number): number
	local rules = Quests.Contracts.RULES.marks
	local L = math.floor(level)
	if L < 1 then
		return 0
	end
	return rules.base + rules.per10 * math.floor(L / 10) + (if L % 10 == 0 then rules.milestone else 0)
end

-- The marks of contracts 1..done (the retro marks of the S134k migration; no milestone items).
function Contracts.retroMarks(done: number): number
	local sum = 0
	for level = 1, math.min(math.floor(done), Quests.Contracts.MAX_LEVEL) do
		sum += Contracts.marksFor(level)
	end
	return sum
end

return Contracts
