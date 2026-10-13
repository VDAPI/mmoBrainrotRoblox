--!strict
-- Story progress (S102, docs/FABULA.md §2.1). Pure (Lune tests). Until S101b the save counted the story as a number
-- (quests.mainDone = how many first quests of Main.list were handed in), so a quest inserted in the middle of the list
-- would shift everyone. Since S102 the save also keeps quests.mainLast = the id of the last story quest handed in, and
-- mainDone is recomputed from it (or from the active quest) on every load (AccountSchema.migrate -> apply): story
-- sessions insert quests (S103-S105) without a migration. Quests inserted before the player's place count as handed
-- in, without rewards.

local Quests = require("../Data/Quests")

export type Entry = { id: string }

local StoryProgress = {}

-- The 32 story quests in their order before S102 (save data counted mainDone in this order). Never change it:
-- migration 8 maps old saves through it. Later insertions need no new list (mainLast keeps the place).
-- stylua: ignore
StoryProgress.LEGACY_ORDER = table.freeze({
	"arrival", "healer", "smith", "portal", "firstHunt", "gearUp", "wolves", "wolfFangs", "boars", "herbs",
	"banditRoad", "banditOrders", "goblinCamp", "mosshollow", "grimrok", "toDuskwood", "werewolves", "ruins",
	"ents", "cult", "swamp", "crypt", "morvane", "ashen", "orcs", "golems", "deepforge", "azgor",
	"frostpeak", "giants", "glacier", "vaelgrath",
})

local LEGACY_SET: { [string]: boolean } = {}
for _, id in StoryProgress.LEGACY_ORDER do
	LEGACY_SET[id] = true
end

local function listOf(list: { Entry }?): { Entry }
	return list or (Quests.Main.list :: any)
end

-- id -> index of a story list (the data's own indexOf for the real list).
local function indexOf(list: { Entry }?): { [string]: number }
	if list == nil then
		return Quests.Main.indexOf
	end
	local out: { [string]: number } = {}
	for i, entry in list do
		out[entry.id] = i
	end
	return out
end

-- Story quests of `list` that are not in LEGACY_ORDER, in list order (the insertions of S102 and later; computed from
-- the data, nobody keeps it by hand).
function StoryProgress.inserted(list: { Entry }?): { string }
	local out: { string } = {}
	for _, entry in listOf(list) do
		if not LEGACY_SET[entry.id] then
			table.insert(out, entry.id)
		end
	end
	return out
end

-- The quest id an old save's mainDone stood for (the last one handed in), nil for 0 or garbage.
function StoryProgress.legacyId(mainDone: any): string?
	local n = math.clamp(math.floor(tonumber(mainDone) or 0), 0, #StoryProgress.LEGACY_ORDER)
	return StoryProgress.LEGACY_ORDER[n]
end

-- The right mainDone and mainLast of a `quests` branch (nothing is written): the active quest, else the last quest
-- handed in, else the number itself (a new character: 0).
function StoryProgress.sync(quests: any, list: { Entry }?): (number, string?)
	local entries = listOf(list)
	local index = indexOf(list)
	local done: number
	local main = if type(quests) == "table" then quests.main else nil
	local last = if type(quests) == "table" then quests.mainLast else nil
	if type(main) == "table" and type(main.id) == "string" and index[main.id] then
		-- quests inserted before the active one count as handed in (no rewards)
		done = index[main.id] - 1
	elseif type(last) == "string" and index[last] then
		done = index[last]
	else
		local raw = if type(quests) == "table" then quests.mainDone else nil
		done = math.clamp(math.floor(tonumber(raw) or 0), 0, #entries)
	end
	local entry = entries[done]
	return done, if entry then entry.id else nil
end

-- Writes the result of `sync` into the branch in place. An active quest with an unknown id is dropped first (a quest
-- withdrawn from the data never blocks the story). Idempotent.
function StoryProgress.apply(quests: any, list: { Entry }?)
	if type(quests) ~= "table" then
		return
	end
	local main = quests.main
	if main ~= nil and (type(main) ~= "table" or type(main.id) ~= "string" or indexOf(list)[main.id] == nil) then
		quests.main = nil
	end
	local done, last = StoryProgress.sync(quests, list)
	quests.mainDone = done
	quests.mainLast = last
end

-- Whether a story quest is handed in (the shared rule of side-quest requirements, anchors and the journal).
function StoryProgress.isDone(quests: any, questId: string): boolean
	local index = Quests.Main.indexOf[questId]
	local done = if type(quests) == "table" then tonumber(quests.mainDone) or 0 else 0
	return index ~= nil and index <= done
end

return StoryProgress
