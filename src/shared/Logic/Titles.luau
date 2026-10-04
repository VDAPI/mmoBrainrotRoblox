--!strict
-- Which titles a character has unlocked (pure; DESIGN §4, S16).

local TitleData = require("../Data/Titles")

local Titles = {}

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

function Titles.isUnlocked(character: any, id: string): boolean
	local def = TitleData.get(id)
	return def ~= nil and progress(character, def.req.kind) >= def.req.value
end

-- Unlocked title ids in display order.
function Titles.unlocked(character: any): { string }
	local result = {}
	for _, def in TitleData.list do
		if progress(character, def.req.kind) >= def.req.value then
			table.insert(result, def.id)
		end
	end
	return result
end

-- The title to show: the chosen one while it is still unlocked, otherwise none.
function Titles.shown(character: any): string?
	local chosen = character.title
	if type(chosen) == "string" and Titles.isUnlocked(character, chosen) then
		return chosen
	end
	return nil
end

return Titles
