--!strict
-- What an NPC has for the local character (S27): one list for the NPC dialog and the world map card. Rows in the
-- order of DESIGN §20: to hand in (?), new (!), in progress (…), later (level too low). Story and side quests alike
-- (S98: the scouts' boss quests too, with their category). S99: the hunting contract at the board and the scout of its
-- region (kind "contract", id = contract_<level>).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Contracts = require(ReplicatedStorage.Shared.Logic.Contracts)
local QuestLogic = require(ReplicatedStorage.Shared.Logic.QuestLogic)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local SideQuests = require(ReplicatedStorage.Shared.Logic.SideQuests)

export type Mode = "turnIn" | "offer" | "active" | "later"
-- S98: `kind` is the machinery ("side" = every quest taken at an NPC, boss quests too), `category` the journal tab
-- (Data/Quests.categoryOf).
export type Kind = "main" | "side" | "contract"
export type Row = { kind: Kind, id: string, mode: Mode, level: number, category: Quests.Category }

local NpcQuests = {}

local ORDER: { [Mode]: number } = { turnIn = 1, offer = 2, active = 3, later = 4 }
local KIND_ORDER: { [Kind]: number } = { main = 1, side = 2, contract = 3 }
local MAX_LATER = 2

local function row(kind: Kind, id: string, mode: Mode, level: number): Row
	return {
		kind = kind,
		id = id,
		mode = mode,
		level = level,
		category = Quests.categoryOf(id) or (if kind == "main" then "main" else "side"),
	}
end

function NpcQuests.rows(quests: any, level: number, npcId: string): { Row }
	local rows: { Row } = {}
	if type(quests) ~= "table" then
		return rows
	end
	-- Story
	local main = quests.main
	if type(main) == "table" then
		local quest = Quests.Main.get(main.id)
		if quest and quest.turnIn == npcId then
			local done = QuestLogic.isComplete(main.progress or {}, quest.objectives)
			table.insert(rows, row("main", quest.id, if done then "turnIn" else "active", quest.level))
		end
	else
		local nextQuest, ready = QuestLogic.nextMain(tonumber(quests.mainDone) or 0, level)
		if nextQuest and nextQuest.giver == npcId then
			table.insert(rows, row("main", nextQuest.id, if ready then "offer" else "later", nextQuest.level))
		end
	end
	-- Side quests
	local ready, open = SideQuests.atTurnIn(quests, npcId)
	for _, quest in ready do
		table.insert(rows, row("side", quest.id, "turnIn", quest.level))
	end
	for _, quest in SideQuests.available(quests, level, npcId) do
		table.insert(rows, row("side", quest.id, "offer", quest.level))
	end
	for _, quest in open do
		table.insert(rows, row("side", quest.id, "active", quest.level))
	end
	-- Active quests given here that end elsewhere: the giver still talks about them.
	for id, entry in SideQuests.activeOf(quests) do
		local quest = Quests.npcQuest(id)
		if quest and quest.giver == npcId and quest.turnIn ~= npcId and type(entry) == "table" then
			table.insert(rows, row("side", quest.id, "active", quest.level))
		end
	end
	for i, quest in SideQuests.later(quests, level, npcId) do
		if i > MAX_LATER then
			break
		end
		table.insert(rows, row("side", quest.id, "later", quest.level))
	end
	-- S99: the hunting contract (only at its givers: the board and the scout of its region)
	local state = Contracts.stateOf(quests)
	local active = Contracts.active(state)
	if active then
		if Contracts.isGiver(npcId, active) then
			local mode: Mode = if Contracts.isComplete(state) then "turnIn" else "active"
			table.insert(rows, row("contract", active.id, mode, active.level))
		end
	else
		local nextContract = Contracts.next(state)
		if nextContract and Contracts.isGiver(npcId, nextContract) then
			local mode: Mode = if Contracts.canAccept(state, level) then "offer" else "later"
			table.insert(rows, row("contract", nextContract.id, mode, nextContract.level))
		end
	end
	table.sort(rows, function(a, b)
		if ORDER[a.mode] ~= ORDER[b.mode] then
			return ORDER[a.mode] < ORDER[b.mode]
		end
		if a.kind ~= b.kind then
			return KIND_ORDER[a.kind] < KIND_ORDER[b.kind]
		end
		return a.level < b.level
	end)
	return rows
end

-- Minimum level of a row's quest (for "from level N").
function NpcQuests.minLevel(row: Row): number
	if row.kind == "main" then
		local quest = Quests.Main.get(row.id)
		return if quest then quest.level - Quests.Main.LEVEL_SLACK else 1
	elseif row.kind == "contract" then
		return row.level -- S99: no slack
	end
	local quest = Quests.npcQuest(row.id)
	return if quest then SideQuests.minLevel(quest) else 1
end

return NpcQuests
