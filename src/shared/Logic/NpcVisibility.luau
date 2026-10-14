--!strict
-- S104: NPCs that appear with the story (NpcDef.showFrom = a main quest id). Such an NPC is shown to a character once
-- that quest is active or handed in (Brokk with deadOasis, Ghasha with warcampCages; S105 Halgrim). One rule for the
-- client (the figure, its plate and prompt, the world map, the minimap, the quest marks: Logic/NpcMarks) and the
-- server (QuestService / SideQuestService refuse to talk with a hidden NPC). The server keeps one figure for everyone;
-- hiding it is cosmetic on the client. Pure (Lune tests).

local Npcs = require("../Data/Npcs")
local Quests = require("../Data/Quests")

local NpcVisibility = {}

-- Whether the NPC `def` is shown for a `character.quests` copy (no showFrom = always; an unknown quest id = always,
-- so a typo never hides an NPC for good).
function NpcVisibility.visible(def: Npcs.NpcDef, quests: any): boolean
	local from = def.showFrom
	if from == nil then
		return true
	end
	local index = Quests.Main.indexOf[from]
	if not index then
		return true
	end
	if type(quests) ~= "table" then
		return false
	end
	local done = tonumber(quests.mainDone) or 0
	if index <= done then
		return true
	end
	local main = quests.main
	if type(main) == "table" and type(main.id) == "string" then
		local active = Quests.Main.indexOf[main.id]
		return active ~= nil and index <= active and index <= done + 1
	end
	return false
end

-- Whether the NPC with this id is shown (unknown ids: true, nothing to hide).
function NpcVisibility.visibleId(npcId: string, quests: any): boolean
	local def = Npcs.get(npcId)
	return def == nil or NpcVisibility.visible(def, quests)
end

-- Ids of the NPCs hidden from this character (only NPCs with showFrom can be hidden).
function NpcVisibility.hiddenIds(quests: any): { [string]: boolean }
	local out: { [string]: boolean } = {}
	for _, def in Npcs.list do
		if def.showFrom ~= nil and not NpcVisibility.visible(def, quests) then
			out[def.id] = true
		end
	end
	return out
end

-- Ids of the NPCs shown to this character.
function NpcVisibility.visibleIds(quests: any): { [string]: boolean }
	local out: { [string]: boolean } = {}
	for _, def in Npcs.list do
		if NpcVisibility.visible(def, quests) then
			out[def.id] = true
		end
	end
	return out
end

return table.freeze(NpcVisibility)
