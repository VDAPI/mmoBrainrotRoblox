--!strict
-- What an NPC has for the local character (S27): one list for the NPC dialog and the world map card. Rows in the
-- order of DESIGN §20: to hand in (?), new (!), in progress (…), later (level too low). Story and side quests alike.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local QuestLogic = require(ReplicatedStorage.Shared.Logic.QuestLogic)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local SideQuests = require(ReplicatedStorage.Shared.Logic.SideQuests)

export type Mode = "turnIn" | "offer" | "active" | "later"
export type Row = { kind: "main" | "side", id: string, mode: Mode, level: number }

local NpcQuests = {}

local ORDER: { [Mode]: number } = { turnIn = 1, offer = 2, active = 3, later = 4 }
local MAX_LATER = 2

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
			table.insert(
				rows,
				{ kind = "main", id = quest.id, mode = if done then "turnIn" else "active", level = quest.level }
			)
		end
	else
		local nextQuest, ready = QuestLogic.nextMain(tonumber(quests.mainDone) or 0, level)
		if nextQuest and nextQuest.giver == npcId then
			table.insert(
				rows,
				{ kind = "main", id = nextQuest.id, mode = if ready then "offer" else "later", level = nextQuest.level }
			)
		end
	end
	-- Side quests
	local ready, open = SideQuests.atTurnIn(quests, npcId)
	for _, quest in ready do
		table.insert(rows, { kind = "side", id = quest.id, mode = "turnIn", level = quest.level })
	end
	for _, quest in SideQuests.available(quests, level, npcId) do
		table.insert(rows, { kind = "side", id = quest.id, mode = "offer", level = quest.level })
	end
	for _, quest in open do
		table.insert(rows, { kind = "side", id = quest.id, mode = "active", level = quest.level })
	end
	-- Active quests given here that end elsewhere: the giver still talks about them.
	for id, entry in SideQuests.activeOf(quests) do
		local quest = Quests.Side.get(id)
		if quest and quest.giver == npcId and quest.turnIn ~= npcId and type(entry) == "table" then
			table.insert(rows, { kind = "side", id = quest.id, mode = "active", level = quest.level })
		end
	end
	for i, quest in SideQuests.later(quests, level, npcId) do
		if i > MAX_LATER then
			break
		end
		table.insert(rows, { kind = "side", id = quest.id, mode = "later", level = quest.level })
	end
	table.sort(rows, function(a, b)
		if ORDER[a.mode] ~= ORDER[b.mode] then
			return ORDER[a.mode] < ORDER[b.mode]
		end
		if a.kind ~= b.kind then
			return a.kind == "main"
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
	end
	local quest = Quests.Side.get(row.id)
	return if quest then SideQuests.minLevel(quest) else 1
end

return NpcQuests
