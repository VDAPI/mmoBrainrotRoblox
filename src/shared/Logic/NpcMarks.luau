--!strict
-- Quest marks over NPCs (S25, DESIGN §20): "available" (gold !) a quest to take, "turnIn" (?) a quest ready to hand
-- in, "active" (grey ?) a quest in progress that ends at this NPC. S27: side quests too (Logic/SideQuests); an NPC
-- with several shows the most important mark (turnIn > available > availableLow > active). S98 (docs/DESIGN-15.md
-- §3.1): four marks: "availableLow" (grey !) an offer more than Config.Quest.greyGap levels under the character;
-- every quest taken at an NPC (Data/Quests.npcList: side arcs and the boss quests of the scouts). One rule for the
-- plates over the NPCs in the world, the world map and the minimap. The quest board shows "turnIn" when a daily,
-- weekly or boss contract is done and not collected, "active" while some are still open (S99 adds the hunting
-- contracts at the questboard and the scouts). Pure (Lune).

local Config = require("../Config")
local QuestLogic = require("./QuestLogic")
local Quests = require("../Data/Quests")
local SideQuests = require("./SideQuests")

export type Mark = "available" | "availableLow" | "turnIn" | "active"

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
			marks[nextQuest.giver] = if NpcMarks.isLow(nextQuest.level, level) then "availableLow" else "available"
		end
	end
	-- S27: side quests
	local function put(npcId: string, mark: Mark)
		if NpcMarks.priority(mark) > NpcMarks.priority(marks[npcId]) then
			marks[npcId] = mark
		end
	end
	for id, entry in SideQuests.activeOf(quests) do
		local quest = Quests.npcQuest(id)
		if quest and type(entry) == "table" then
			put(quest.turnIn, if SideQuests.isComplete(entry, quest) then "turnIn" else "active")
		end
	end
	-- S98: put() keeps the higher mark, so a grey offer gives way to a gold one
	for _, quest in Quests.npcList do
		if marks[quest.giver] ~= "turnIn" and SideQuests.canAccept(quests, level, quest) then
			put(quest.giver, if NpcMarks.isLow(quest.level, level) then "availableLow" else "available")
		end
	end
	if marks[NpcMarks.BOARD] == nil then
		local ready, open = false, false
		local daily = quests.daily
		if type(daily) == "table" and type(daily.list) == "table" then
			for _, entry in daily.list do
				if type(entry) == "table" and not entry.claimed and type(entry.objective) == "table" then
					if (tonumber(entry.progress) or 0) >= (tonumber(entry.objective.n) or 1) then
						ready = true
					else
						open = true
					end
				end
			end
		end
		-- S98: weekly contracts and the boss contract
		local weeklyReady, weeklyOpen = QuestLogic.weeklyOpen(quests.weekly)
		ready = ready or weeklyReady > 0
		open = open or weeklyOpen > 0
		if ready then
			marks[NpcMarks.BOARD] = "turnIn"
		elseif open then
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
	return if mark == "turnIn"
		then 4
		elseif mark == "available" then 3
		elseif mark == "availableLow" then 2
		elseif mark == "active" then 1
		else 0
end

-- S98: an offer of `questLevel` is "low" (grey !) for a character of `level` more than greyGap levels above it.
function NpcMarks.isLow(questLevel: number, level: number): boolean
	return questLevel < level - Config.Quest.greyGap
end

return NpcMarks
