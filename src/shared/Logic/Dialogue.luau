--!strict
-- Answers in quest conversations (S101b, DESIGN-15 §3.5). Pure (Lune tests). A quest may have one page with 2-3
-- answers of the player (`choices`): flavour (another reply of the NPC) or a small effect (`hint`: an extra point for
-- the tracker and the map, `focus`: the tracker leads to another objective first, `item`: a small consumable from
-- Config.Dialogue.gifts). The answer is saved for good in character.quests.said[questId] (remote QuestSay, the server
-- checks canSay); later pages may pick a variant by it (`recall`). The client builds the same page keys (pageOf,
-- pageKey) and reads `focus` / `hint` from the saved answer. Never blocks a quest: there is always an answer without
-- an item, and nothing changes the character's power.

local Config = require("../Config")
local Items = require("../Data/Items")
local Locale = require("../Util/Locale")
local Maps = require("../Data/Maps")
local Npcs = require("../Data/Npcs")
local QuestLogic = require("./QuestLogic")
local Quests = require("../Data/Quests")
local SideQuests = require("./SideQuests")

type ChoicePage = Quests.ChoicePage
type DialogueChoice = Quests.DialogueChoice
type ChoiceEffect = Quests.ChoiceEffect

export type Kind = "main" | "side"

local Dialogue = {}

Dialogue.MIN_OPTIONS = 2
Dialogue.MAX_OPTIONS = 3

-- The page with answers of a quest (story or side; `quest` is either record), or nil.
function Dialogue.choicePage(quest: any): ChoicePage?
	if type(quest) ~= "table" or type(quest.choices) ~= "table" then
		return nil
	end
	return quest.choices
end

-- One answer of the quest's page by id, or nil.
function Dialogue.option(quest: any, choiceId: string?): DialogueChoice?
	local page = Dialogue.choicePage(quest)
	if not page or choiceId == nil then
		return nil
	end
	for _, option in page.options do
		if option.id == choiceId then
			return option
		end
	end
	return nil
end

-- The saved answer of a quest (tolerates a missing or broken `said`).
function Dialogue.saidOf(quests: any, questId: string): string?
	local said = if type(quests) == "table" then quests.said else nil
	if type(said) ~= "table" then
		return nil
	end
	local value = said[questId]
	return if type(value) == "string" then value else nil
end

-- A ChoicePage.page as a page key: 2 -> "p2", "text" / "done" as they are.
function Dialogue.pageName(page: number | string): string
	return if type(page) == "number" then `p{page}` else page
end

-- Pages of a story quest (S102: MainQuest.pages; nil = the single "text" page).
local function mainPages(quest: any): number?
	local pages = if type(quest) == "table" then (quest :: Quests.MainQuest).pages else nil
	return if type(pages) == "number" and pages >= 1 then pages else nil
end

-- The key of the page a conversation shows (in the sense of ChoicePage.page): `mode` of UI/Screens/QuestDialog
-- ("offer" / "active" / "turnIn" / "later" / "elsewhere"), `page` = the offer page number. Story: offer and in
-- progress "text" (S102: the offer of a quest with pages "p<page>"), hand-in "done". Side: offer "p<page>", in progress
-- "progress", hand-in "done".
function Dialogue.pageOf(quest: any, kind: Kind, mode: string, page: number?): string
	if mode == "turnIn" then
		return "done"
	end
	if kind == "main" then
		-- S102: the offer of a story quest with pages shows them; in progress it is the journal line (.text)
		if mainPages(quest) and mode == "offer" then
			return `p{page or 1}`
		end
		return "text"
	end
	if mode == "offer" then
		return `p{page or 1}`
	end
	return "progress"
end

-- Whether the page with answers is shown to this character at this NPC right now (the server's check).
local function pageShown(quests: any, level: number, kind: Kind, quest: any, page: ChoicePage, npcId: string): boolean
	if type(quests) ~= "table" then
		return false
	end
	if kind == "main" then
		local main = quests.main
		local active = type(main) == "table" and main.id == quest.id
		local complete = active and QuestLogic.isComplete(main.progress or {}, quest.objectives)
		if page.page == "done" then
			return active and complete and npcId == quest.turnIn
		end
		if active then
			-- in progress the story's page shows at the turn-in NPC (UI/NpcQuests), only its in-progress page (the
			-- offer pages of a quest with pages are gone by then)
			return not complete
				and npcId == quest.turnIn
				and Dialogue.pageName(page.page) == Dialogue.pageOf(quest, "main", "active")
		end
		if main ~= nil then
			return false
		end
		local nextQuest, ready = QuestLogic.nextMain(tonumber(quests.mainDone) or 0, level)
		return nextQuest ~= nil and nextQuest.id == quest.id and ready and npcId == quest.giver
	end
	local entry = SideQuests.activeOf(quests)[quest.id]
	local active = type(entry) == "table"
	local complete = active and SideQuests.isComplete(entry, quest)
	if page.page == "done" then
		return active and complete and npcId == quest.turnIn
	end
	if npcId ~= quest.giver then
		return false
	end
	if active then
		-- an answer not given at the offer can be given later at the giver while the quest runs
		return not complete
	end
	local ok, reason = SideQuests.canAccept(quests, level, quest)
	return ok or reason == "limit"
end

-- Whether the character may give answer `choiceId` of `quest` at `npcId` now; the error key when not:
-- quest.say.unknown (no such answer), quest.say.already (answered before), quest.say.notOffered (the page is not
-- shown here now). Givers and turn-in NPCs are never "classVendor" (tests/quest.spec).
function Dialogue.canSay(
	quests: any,
	level: number,
	kind: Kind,
	quest: any,
	choiceId: string,
	npcId: string
): (boolean, string?)
	local page = Dialogue.choicePage(quest)
	if not page or not Dialogue.option(quest, choiceId) then
		return false, "quest.say.unknown"
	end
	if Dialogue.saidOf(quests, quest.id) ~= nil then
		return false, "quest.say.already"
	end
	if not pageShown(quests, level, kind, quest, page, npcId) then
		return false, "quest.say.notOffered"
	end
	return true, nil
end

-- The locale key of page `page` ("p2", "text", "progress", "done") of a quest: the variant picked by an earlier answer
-- (`recall[page] = sourceId`, `said[sourceId] = c` -> quest.<id>.<page>.<c>) when `has` knows it, else the page itself.
function Dialogue.pageKey(quest: any, page: string, quests: any, has: (string) -> boolean): string
	local plain = `quest.{quest.id}.{page}`
	local recall = if type(quest.recall) == "table" then quest.recall else nil
	local source = recall and recall[page]
	if type(source) ~= "string" then
		return plain
	end
	local answer = Dialogue.saidOf(quests, source)
	if not answer then
		return plain
	end
	local key = `{plain}.{answer}`
	return if has(key) then key else plain
end

local function savedEffect(quest: any, quests: any): ChoiceEffect?
	local option = Dialogue.option(quest, Dialogue.saidOf(quests, if type(quest) == "table" then quest.id else ""))
	return if option then option.effect else nil
end

-- The objective the tracker leads to first, by the saved answer (`focus`), or nil.
function Dialogue.focusOf(quest: any, quests: any): number?
	local effect: any = savedEffect(quest, quests)
	return if effect and effect.kind == "focus" then effect.index else nil
end

-- The extra point of the saved answer (`hint`), or nil.
function Dialogue.hintOf(quest: any, quests: any): ChoiceEffect?
	local effect: any = savedEffect(quest, quests)
	return if effect and effect.kind == "hint" then effect else nil
end

-- Validation -----------------------------------------------------------------------------------------------------------

-- Every quest that can carry dialogue fields, with its kind.
function Dialogue.allQuests(): { { kind: Kind, quest: any } }
	local out = {}
	for _, quest in Quests.Main.list do
		table.insert(out, { kind = "main" :: Kind, quest = quest :: any })
	end
	for _, quest in Quests.npcList do
		table.insert(out, { kind = "side" :: Kind, quest = quest :: any })
	end
	return out
end

local function questOf(id: string): (any, Kind?)
	local main = Quests.Main.get(id)
	if main then
		return main, "main"
	end
	local side = Quests.npcQuest(id)
	if side then
		return side, "side"
	end
	return nil, nil
end

-- Page keys a quest has: side p1..pN, progress, done; story text (or p1..pN with pages), done.
function Dialogue.pageKeys(quest: any, kind: Kind): { string }
	local keys: { string } = {}
	local pages = if kind == "side" then quest.pages else mainPages(quest)
	if pages then
		for i = 1, pages do
			table.insert(keys, `p{i}`)
		end
	else
		table.insert(keys, "text")
	end
	if kind == "side" then
		table.insert(keys, "progress")
	end
	table.insert(keys, "done")
	return keys
end

-- Whether `source` comes before (or is) `quest`: the same quest; story: an earlier or the same story quest; side: a
-- quest of the `requires` chain or any story quest.
local function earlier(quest: any, kind: Kind, sourceId: string): boolean
	if sourceId == quest.id then
		return true
	end
	if kind == "main" then
		local a, b = Quests.Main.indexOf[sourceId], Quests.Main.indexOf[quest.id]
		return a ~= nil and b ~= nil and a <= b
	end
	if Quests.Main.get(sourceId) then
		return true
	end
	local seen: { [string]: boolean } = {}
	local stack: { string } = table.clone(quest.requires or {})
	while #stack > 0 do
		local id = table.remove(stack) :: string
		if id == sourceId then
			return true
		end
		if not seen[id] then
			seen[id] = true
			local required = Quests.npcQuest(id)
			for _, more in (if required then required.requires or {} else {}) :: { string } do
				table.insert(stack, more)
			end
		end
	end
	return false
end

local function validatePage(quest: any, kind: Kind, problems: { string })
	local function bad(text: string)
		table.insert(problems, `{quest.id}: {text}`)
	end
	local page = quest.choices
	if type(page) ~= "table" or type(page.options) ~= "table" then
		bad("choices without options")
		return
	end
	local count = #page.options
	if count < Dialogue.MIN_OPTIONS or count > Dialogue.MAX_OPTIONS then
		bad(`{count} options (2-3)`)
	end
	local where = page.page
	local pages = if kind == "side" then quest.pages else mainPages(quest)
	if type(where) == "number" then
		if not pages or where ~= math.floor(where) or where < 1 or where > pages then
			bad(`page {where} is not an offer page`)
		end
	elseif where == "text" then
		if kind ~= "main" or pages ~= nil then
			bad(`"text" only on a story quest without pages`)
		end
	elseif where ~= "done" then
		bad(`unknown page {tostring(where)}`)
	end
	local ids: { [string]: boolean } = {}
	local items = 0
	for _, option in page.options do
		local id = option.id
		if type(id) ~= "string" or not string.match(id, "^[a-zA-Z]+$") then
			bad(`bad answer id {tostring(id)}`)
		elseif ids[id] then
			bad(`answer {id} twice`)
		end
		if type(id) == "string" then
			ids[id] = true
		end
		local effect: any = option.effect
		if effect ~= nil then
			if where == "done" and effect.kind ~= "item" then
				bad(`{effect.kind} on the hand-in page (only item)`)
			end
			if effect.kind == "item" then
				items += 1
				local limit = Config.Dialogue.gifts[effect.id]
				if not limit then
					bad(`item {tostring(effect.id)} is not in Config.Dialogue.gifts`)
				elseif not Items.get(effect.id) then
					bad(`unknown item {effect.id}`)
				elseif type(effect.n) ~= "number" or effect.n < 1 or effect.n > limit then
					bad(`item {effect.id} x{tostring(effect.n)} (1..{limit})`)
				end
			elseif effect.kind == "hint" then
				if not Maps.get(effect.map or "") then
					bad(`hint on unknown map {tostring(effect.map)}`)
				end
				if type(effect.x) ~= "number" or type(effect.z) ~= "number" then
					bad("hint without x / z")
				end
				if not (Locale.has(effect.place or "", "pl") and Locale.has(effect.place or "", "en")) then
					bad(`hint place {tostring(effect.place)} has no text`)
				end
			elseif effect.kind == "focus" then
				local index = effect.index
				if type(index) ~= "number" or index ~= math.floor(index) or index < 1 or index > #quest.objectives then
					bad(`focus {tostring(index)} out of the objectives`)
				end
			else
				bad(`unknown effect {tostring(effect.kind)}`)
			end
		end
	end
	if items > 1 then
		bad(`{items} item answers (at most one)`)
	end
end

local function validateRecall(quest: any, kind: Kind, problems: { string })
	local keys = Dialogue.pageKeys(quest, kind)
	for page, sourceId in quest.recall do
		if type(page) ~= "string" or not table.find(keys, page) then
			table.insert(problems, `{quest.id}: recall on unknown page {tostring(page)}`)
		end
		local source = if type(sourceId) == "string" then questOf(sourceId) else nil
		if not source then
			table.insert(problems, `{quest.id}: recall from unknown quest {tostring(sourceId)}`)
		elseif type(source.choices) ~= "table" then
			table.insert(problems, `{quest.id}: recall from {sourceId} without choices`)
		elseif not earlier(quest, kind, sourceId) then
			table.insert(problems, `{quest.id}: recall from {sourceId}, which does not come earlier`)
		end
	end
end

-- Problems of the dialogue data ("<questId>: <problem>"); empty = fine. `list` defaults to every quest.
function Dialogue.validate(list: { { kind: Kind, quest: any } }?): { string }
	local problems: { string } = {}
	local items: { { kind: Kind, quest: any } } = if list then list else Dialogue.allQuests()
	for _, item in items do
		local quest = item.quest
		if quest.choices ~= nil then
			validatePage(quest, item.kind, problems)
		end
		if quest.recall ~= nil then
			if type(quest.recall) ~= "table" then
				table.insert(problems, `{quest.id}: recall is not a table`)
			else
				validateRecall(quest, item.kind, problems)
			end
		end
		if (quest.choices ~= nil or quest.recall ~= nil) and not Npcs.get(quest.giver) then
			table.insert(problems, `{quest.id}: unknown giver {quest.giver}`)
		end
	end
	return problems
end

return Dialogue
