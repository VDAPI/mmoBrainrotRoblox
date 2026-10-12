--!strict
-- Which titles a character has unlocked (pure; DESIGN §4, S16).
-- S59 (ROZWOJ 3.2): path titles (req.kind "mainPath") are unlocked while the active set's main path is their path;
-- character.title nil = never chose (the main path title shows), Titles.NONE = the player hid the title. Every
-- function takes an optional title list (tests); default Data/Titles.

local TitleData = require("../Data/Titles")

type TitleDef = TitleData.TitleDef

local Titles = {}

Titles.NONE = TitleData.NONE

-- Progress of a character towards a requirement kind.
local function progress(character: any, kind: string): number
	if kind == "level" then
		return character.level or 0
	elseif kind == "mainDone" then
		return if character.quests then character.quests.mainDone or 0 else 0
	elseif kind == "pvpKills" then
		return if character.pvp then character.pvp.kills or 0 else 0
	elseif kind == "duelsWon" then
		return if character.pvp then character.pvp.duelsWon or 0 else 0
	end
	return 0
end

local function mainPathOf(character: any): string?
	local state = character.path
	return if type(state) == "table" and type(state.main) == "string" then state.main else nil
end

local function meets(character: any, req: TitleData.Requirement): boolean
	if req.kind == "mainPath" then
		return mainPathOf(character) == req.path
	end
	return progress(character, req.kind) >= (req :: any).value
end

local function find(id: string, list: { TitleDef }?): TitleDef?
	if list == nil then
		return TitleData.get(id)
	end
	for _, def in list do
		if def.id == id then
			return def
		end
	end
	return nil
end

function Titles.isUnlocked(character: any, id: string, list: { TitleDef }?): boolean
	local def = find(id, list)
	return def ~= nil and meets(character, def.req)
end

-- Unlocked title ids in display order.
function Titles.unlocked(character: any, list: { TitleDef }?): { string }
	local result = {}
	for _, def in list or TitleData.list do
		if meets(character, def.req) then
			table.insert(result, def.id)
		end
	end
	return result
end

-- The title of the character's main path (nil without a main path or without its title).
function Titles.pathTitle(character: any, list: { TitleDef }?): string?
	local main = mainPathOf(character)
	if main == nil then
		return nil
	end
	for _, def in list or TitleData.list do
		local req = def.req
		if req.kind == "mainPath" and req.path == main then
			return def.id
		end
	end
	return nil
end

-- The title to show: none when hidden, the chosen one while it is still unlocked, otherwise the main path title.
function Titles.shown(character: any, list: { TitleDef }?): string?
	local chosen = character.title
	if chosen == Titles.NONE then
		return nil
	end
	if type(chosen) == "string" and Titles.isUnlocked(character, chosen, list) then
		return chosen
	end
	return Titles.pathTitle(character, list)
end

return Titles
