--!strict
-- Hunting contract queue (S99, DESIGN-15 §3.3). Pure (Lune); shared by ContractService, the client and the tests.
-- character.quests.contract = { done, active? }: `done` = the highest contract level handed in (= the number handed
-- in, they go in order), `active` = { level = done + 1, progress } while one is taken. One active at a time; the next
-- is always Quests.Contracts.forLevel(done + 1) and needs the character at its level (no slack). Taken and handed in
-- at the contract board in the city or at the scout of the contract's region (giversOf).

local Npcs = require("../Data/Npcs")
local QuestLogic = require("./QuestLogic")
local Quests = require("../Data/Quests")

type ContractQuest = Quests.ContractQuest

export type Active = { level: number, progress: { number } } -- S98 save shape (quests.contract.active)
export type State = { done: number, active: Active? }

local Contracts = {}

Contracts.BOARD = "questboard"

-- The contract state of `character.quests` (safe for nil / broken saves: { done = 0 }). An active entry whose level
-- is not done + 1 or without a progress list counts as none.
function Contracts.stateOf(quests: any): State
	local branch = if type(quests) == "table" then quests.contract else nil
	if type(branch) ~= "table" then
		return { done = 0 }
	end
	local done = math.clamp(math.floor(tonumber(branch.done) or 0), 0, Quests.Contracts.MAX_LEVEL)
	local active = branch.active
	if type(active) == "table" and active.level == done + 1 and type(active.progress) == "table" then
		return { done = done, active = { level = active.level, progress = active.progress } }
	end
	return { done = done }
end

-- The next contract to take (nil while one is active or after the last one).
function Contracts.next(state: State): ContractQuest?
	if state.active then
		return nil
	end
	return Quests.Contracts.forLevel(state.done + 1)
end

-- The active contract and its entry (nil, nil when none).
function Contracts.active(state: State): (ContractQuest?, Active?)
	local entry = state.active
	if not entry then
		return nil, nil
	end
	local contract = Quests.Contracts.forLevel(entry.level)
	if not contract then
		return nil, nil
	end
	return contract, entry
end

-- Whether the active contract has every objective done (false without one).
function Contracts.isComplete(state: State): boolean
	local contract, entry = Contracts.active(state)
	if not contract or not entry then
		return false
	end
	return QuestLogic.isComplete(entry.progress, contract.objectives)
end

-- Whether the next contract can be taken now; the reason otherwise: "active" | "none" | "level".
function Contracts.canAccept(state: State, level: number): (boolean, string?)
	if state.active then
		return false, "active"
	end
	local contract = Quests.Contracts.forLevel(state.done + 1)
	if not contract then
		return false, "none"
	end
	if level < contract.level then
		return false, "level"
	end
	return true, nil
end

-- The NPCs that hand out and take back a contract: the board and the scout of its region (when it exists).
function Contracts.giversOf(contract: ContractQuest): { string }
	local out = { Contracts.BOARD }
	local scout = `scout_{contract.map}`
	if Npcs.get(scout) then
		table.insert(out, scout)
	end
	return out
end

function Contracts.isGiver(npcId: string, contract: ContractQuest): boolean
	return table.find(Contracts.giversOf(contract), npcId) ~= nil
end

-- Contracts with a level up to the character's level that are not handed in (the active one included).
function Contracts.backlog(state: State, level: number): number
	local top = math.min(math.floor(level), #Quests.Contracts.list)
	return math.max(0, top - state.done)
end

-- Up to `count` contracts after the active one (or after the next to take).
function Contracts.upcoming(state: State, count: number): { ContractQuest }
	local out: { ContractQuest } = {}
	local from = state.done + 2
	for level = from, from + count - 1 do
		local contract = Quests.Contracts.forLevel(level)
		if not contract then
			break
		end
		table.insert(out, contract)
	end
	return out
end

-- Whether every contract is handed in (false while the list is empty).
function Contracts.allDone(state: State): boolean
	local total = #Quests.Contracts.list
	return total > 0 and state.done >= total
end

return Contracts
