--!strict
-- Side quest rules (S27, DESIGN §20). Pure (Lune tests): what an NPC offers, what can be handed in, progress from
-- gameplay events (the same events as the story: QuestLogic.amount), arcs for the journal and the reward choice.
-- The server (SideQuestService), the NPC dialog, the journal and the quest marks (Logic/NpcMarks) all ask here.
-- `quests` is `character.quests` (the save or the replicated client copy; old or partial tables are tolerated).

local Config = require("../Config")
local DevPreset = require("./DevPreset")
local ItemRoll = require("./ItemRoll")
local QuestLogic = require("./QuestLogic")
local Quests = require("../Data/Quests")
local Rng = require("./Rng")
local Types = require("../Types")

type SideQuest = Quests.SideQuest
type SideEntry = Types.SideEntry

export type Reason = "done" | "active" | "level" | "requires" | "limit" | "unknown"

local SideQuests = {}

local function side(quests: any): ({ [string]: any }, { [string]: boolean })
	local s = if type(quests) == "table" then quests.side else nil
	if type(s) ~= "table" then
		return {}, {}
	end
	return (if type(s.active) == "table" then s.active else {}), (if type(s.done) == "table" then s.done else {})
end

function SideQuests.activeOf(quests: any): { [string]: any }
	local active = side(quests)
	return active
end

function SideQuests.isDone(quests: any, id: string): boolean
	local _, done = side(quests)
	return done[id] == true
end

function SideQuests.isActive(quests: any, id: string): boolean
	local active = side(quests)
	return type(active[id]) == "table"
end

function SideQuests.activeCount(quests: any): number
	local n = 0
	for _, entry in side(quests) do
		if type(entry) == "table" then
			n += 1
		end
	end
	return n
end

-- A requirement is a side quest handed in or a story quest already completed.
local function requirementDone(quests: any, id: string): boolean
	if SideQuests.isDone(quests, id) then
		return true
	end
	local index = Quests.Main.indexOf[id]
	local mainDone = if type(quests) == "table" then tonumber(quests.mainDone) or 0 else 0
	return index ~= nil and index <= mainDone
end

function SideQuests.requirementsMet(quests: any, quest: SideQuest): boolean
	local requires: { string } = quest.requires or {}
	for _, id in requires do
		if not requirementDone(quests, id) then
			return false
		end
	end
	return true
end

-- Lowest character level that may take the quest.
function SideQuests.minLevel(quest: SideQuest): number
	return math.max(1, quest.level - Config.SideQuest.levelSlack)
end

-- Whether the character may take the quest now; the reason when not.
function SideQuests.canAccept(quests: any, level: number, quest: SideQuest): (boolean, Reason?)
	if SideQuests.isDone(quests, quest.id) then
		return false, "done"
	end
	if SideQuests.isActive(quests, quest.id) then
		return false, "active"
	end
	if not SideQuests.requirementsMet(quests, quest) then
		return false, "requires"
	end
	if level < SideQuests.minLevel(quest) then
		return false, "level"
	end
	if SideQuests.activeCount(quests) >= Config.SideQuest.maxActive then
		return false, "limit"
	end
	return true, nil
end

local function byLevel(list: { SideQuest }): { SideQuest }
	table.sort(list, function(a, b)
		if a.level ~= b.level then
			return a.level < b.level
		end
		return a.id < b.id
	end)
	return list
end

-- Quests this NPC hands out that the character can take now (the active limit does not hide them: the dialog
-- explains it), lowest level first.
function SideQuests.available(quests: any, level: number, npcId: string): { SideQuest }
	local out = {}
	for _, quest in Quests.Side.list do
		if quest.giver == npcId then
			local ok, reason = SideQuests.canAccept(quests, level, quest)
			if ok or reason == "limit" then
				table.insert(out, quest)
			end
		end
	end
	return byLevel(out)
end

-- Quests this NPC will give a little later (requirements met, level too low).
function SideQuests.later(quests: any, level: number, npcId: string): { SideQuest }
	local out = {}
	for _, quest in Quests.Side.list do
		if quest.giver == npcId then
			local _, reason = SideQuests.canAccept(quests, level, quest)
			if reason == "level" then
				table.insert(out, quest)
			end
		end
	end
	return byLevel(out)
end

function SideQuests.isComplete(entry: any, quest: SideQuest): boolean
	return type(entry) == "table" and QuestLogic.isComplete(entry.progress or {}, quest.objectives)
end

-- Active quests that end at this NPC: ready to hand in, and still in progress.
function SideQuests.atTurnIn(quests: any, npcId: string): ({ SideQuest }, { SideQuest })
	local ready, open = {}, {}
	for id, entry in side(quests) do
		local quest = Quests.Side.get(id)
		if quest and quest.turnIn == npcId and type(entry) == "table" then
			table.insert(if SideQuests.isComplete(entry, quest) then ready else open, quest)
		end
	end
	return byLevel(ready), byLevel(open)
end

function SideQuests.turnInReady(quests: any, npcId: string): { SideQuest }
	local ready = SideQuests.atTurnIn(quests, npcId)
	return ready
end

-- NPCs with a quest the character can take now (Wacław's gossip, S27), nearest level first; `except` skipped.
function SideQuests.giversWithWork(quests: any, level: number, except: string?): { string }
	local best: { [string]: number } = {}
	for _, quest in Quests.Side.list do
		if quest.giver ~= except and SideQuests.canAccept(quests, level, quest) then
			local d = math.abs(quest.level - level)
			if best[quest.giver] == nil or d < best[quest.giver] then
				best[quest.giver] = d
			end
		end
	end
	local out = {}
	for npc in best do
		table.insert(out, npc)
	end
	table.sort(out, function(a, b)
		if best[a] ~= best[b] then
			return best[a] < best[b]
		end
		return a < b
	end)
	return out
end

-- Done / total quests of an arc.
function SideQuests.arcProgress(quests: any, arc: string): (number, number)
	local list: { SideQuest } = Quests.Side.byArc[arc] or {}
	local done = 0
	for _, quest in list do
		if SideQuests.isDone(quests, quest.id) then
			done += 1
		end
	end
	return done, #list
end

-- A fresh save entry for an accepted quest.
function SideQuests.newEntry(quest: SideQuest): SideEntry
	return { progress = QuestLogic.emptyProgress(quest.objectives), used = {} }
end

-- Applies a gameplay event to an active entry in place: progress, and for `use` the anchor joins `used`. Returns
-- the changed objective indices.
function SideQuests.advance(
	entry: SideEntry,
	quest: SideQuest,
	kind: string,
	data: { [string]: any },
	rng: Rng.Rng
): { number }
	local event = data
	if kind == "talk" or kind == "use" then
		event = table.clone(data)
		event.turnIn = quest.turnIn
		event.used = entry.used
	end
	local changed = QuestLogic.advance(entry.progress, quest.objectives, kind, event, rng)
	if kind == "use" and #changed > 0 and type(data.anchor) == "string" then
		table.insert(entry.used, data.anchor)
	end
	return changed
end

-- The `use` objective of an active quest that still needs this anchor (index), or nil.
function SideQuests.pendingUse(entry: any, quest: SideQuest, anchor: string): number?
	if type(entry) ~= "table" then
		return nil
	end
	local used: { string } = entry.used or {}
	if table.find(used, anchor) then
		return nil
	end
	for i, objective in quest.objectives do
		if
			objective.type == "use"
			and QuestLogic.usesAnchor(objective, anchor)
			and ((entry.progress or {})[i] or 0) < objective.n
		then
			return i
		end
	end
	return nil
end

-- Every anchor the character may use now: anchor id -> { quest, objective index }.
function SideQuests.usableAnchors(quests: any): { [string]: { quest: string, index: number } }
	local out = {}
	for id, entry in side(quests) do
		local quest = Quests.Side.get(id)
		if quest and type(entry) == "table" then
			for i, objective in quest.objectives do
				if objective.type == "use" and ((entry.progress or {})[i] or 0) < objective.n then
					local anchors: { string } = objective.anchors or { objective.anchor :: string }
					for _, anchor in anchors do
						if not table.find(entry.used or {}, anchor) and out[anchor] == nil then
							out[anchor] = { quest = id, index = i }
						end
					end
				end
			end
		end
	end
	return out
end

-- Anchors whose "done" look the client shows: used by an active quest or by any handed-in quest.
function SideQuests.doneAnchors(quests: any): { [string]: string }
	local out: { [string]: string } = {}
	local active, done = side(quests)
	for id, entry in active do
		local quest = Quests.Side.get(id)
		if quest and type(entry) == "table" then
			for _, anchor in entry.used or {} do
				for _, objective in quest.objectives do
					if objective.type == "use" and objective.fx and QuestLogic.usesAnchor(objective, anchor) then
						out[anchor] = objective.fx
					end
				end
			end
		end
	end
	for id in done do
		local quest = Quests.Side.get(id)
		if quest then
			for _, objective in quest.objectives do
				if objective.type == "use" and objective.fx then
					local anchors: { string } = objective.anchors or { objective.anchor :: string }
					for _, anchor in anchors do
						out[anchor] = objective.fx
					end
				end
			end
		end
	end
	return out
end

-- Item ids offered as the reward choice for a class at a level: the class weapon and armour pieces of the
-- highest generated tier <= level (DevPreset), `count` of them, the weapon always first. `rng` picks the pieces.
function SideQuests.choiceIds(class: string, level: number, count: number, rng: Rng.Rng): { string }
	local weapon: string? = nil
	local armour: { string } = {}
	for _, entry in DevPreset.pick(class, level) do
		if entry.slot == "weapon" then
			weapon = entry.id
		elseif entry.slot == "helmet" or entry.slot == "armor" or entry.slot == "gloves" or entry.slot == "boots" then
			table.insert(armour, entry.id)
		end
	end
	local out: { string } = {}
	if weapon then
		table.insert(out, weapon)
	end
	while #out < count and #armour > 0 do
		table.insert(out, table.remove(armour, rng:int(1, #armour)) :: string)
	end
	return out
end

-- Rolled reward items for a finished quest (class items, item level = quest level).
function SideQuests.rollChoice(
	quest: SideQuest,
	class: string,
	rng: Rng.Rng,
	newUid: () -> string
): { Types.ItemInstance }
	local kind = quest.reward.choice
	if not kind then
		return {}
	end
	local rarity = Config.SideQuest.choiceRarity[kind] or 2
	local out = {}
	for _, id in SideQuests.choiceIds(class, quest.level, Config.SideQuest.choiceCount, rng) do
		table.insert(out, ItemRoll.rollItem(id, quest.level, rarity, rng, newUid()))
	end
	return out
end

-- Which objective a tracker / guide should point at: the first unfinished one (or nil when complete).
function SideQuests.currentObjective(entry: any, quest: SideQuest): number?
	for i, objective in quest.objectives do
		if ((if type(entry) == "table" then entry.progress or {} else {})[i] or 0) < objective.n then
			return i
		end
	end
	return nil
end

return SideQuests
