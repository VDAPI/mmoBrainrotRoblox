--!strict
-- Quest marks over NPCs (S25, DESIGN §20): "available" (!) a story quest to take, "turnIn" (?) a quest ready
-- to hand in, "active" (grey ?) a quest in progress that ends at this NPC. S27: side quests too (Logic/SideQuests);
-- an NPC with several shows the most important mark (turnIn > available > active). One rule for the plates over the
-- NPCs in the world, the world map and the minimap. Daily contracts mark the quest board: "turnIn" when one is
-- done and not collected, "active" while some are still open. Pure (Lune).

local QuestLogic = require("./QuestLogic")
local Quests = require("../Data/Quests")
local SideQuests = require("./SideQuests")

export type Mark = "available" | "turnIn" | "active"

local NpcMarks = {}

NpcMarks.BOARD = "questboard"

-- Marks of every NPC for the character's quest state (`character.quests`) and level.
function NpcMarks.all(quests: any, level: number): { [string]: Mark }
	local marks: { [string]: Mark } = {}
	if type(quests) ~= "table" then
		return marks
	end
	local main = quests.main
	if type(main) == "table" then
		local quest = Quests.Main.get(main.id)
		if quest then
			marks[quest.turnIn] = if QuestLogic.isComplete(main.progress or {}, quest.objectives)
				then "turnIn"
				else "active"
		end
	else
		local nextQuest, ready = QuestLogic.nextMain(tonumber(quests.mainDone) or 0, level)
		if nextQuest and ready then
			marks[nextQuest.giver] = "available"
		end
	end
	-- S27: side quests
	local function put(npcId: string, mark: Mark)
		if NpcMarks.priority(mark) > NpcMarks.priority(marks[npcId]) then
			marks[npcId] = mark
		end
	end
	for id, entry in SideQuests.activeOf(quests) do
		local quest = Quests.Side.get(id)
		if quest and type(entry) == "table" then
			put(quest.turnIn, if SideQuests.isComplete(entry, quest) then "turnIn" else "active")
		end
	end
	for _, quest in Quests.Side.list do
		if marks[quest.giver] ~= "turnIn" and marks[quest.giver] ~= "available" then
			if SideQuests.canAccept(quests, level, quest) then
				put(quest.giver, "available")
			end
		end
	end
	local daily = quests.daily
	if type(daily) == "table" and type(daily.list) == "table" and marks[NpcMarks.BOARD] == nil then
		local open = false
		for _, entry in daily.list do
			if type(entry) == "table" and not entry.claimed and type(entry.objective) == "table" then
				if (tonumber(entry.progress) or 0) >= (tonumber(entry.objective.n) or 1) then
					marks[NpcMarks.BOARD] = "turnIn"
					break
				end
				open = true
			end
		end
		if marks[NpcMarks.BOARD] == nil and open then
			marks[NpcMarks.BOARD] = "active"
		end
	end
	return marks
end

-- Mark of one NPC (nil = nothing to do there).
function NpcMarks.of(npcId: string, quests: any, level: number): Mark?
	return NpcMarks.all(quests, level)[npcId]
end

-- Map priority of a mark (S25: overlapping map icons keep the most important one).
function NpcMarks.priority(mark: Mark?): number
	return if mark == "turnIn" then 3 elseif mark == "available" then 2 elseif mark == "active" then 1 else 0
end

return NpcMarks
