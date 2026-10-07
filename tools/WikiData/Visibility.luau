--!strict
-- Unreleased entities (S34, docs/WIKI.md §1): an entity with `hidden == true` or `wiki == false` in the game data
-- is left out of the wiki together with every reference to it. collect() gathers their ids from the data lists;
-- fromLists() is the pure part (tested on made-up data).

local Blessings = require("../../src/shared/Data/Blessings")
local Bosses = require("../../src/shared/Data/Bosses")
local Cosmetics = require("../../src/shared/Data/Cosmetics")
local Items = require("../../src/shared/Data/Items")
local Maps = require("../../src/shared/Data/Maps")
local Monsters = require("../../src/shared/Data/Monsters")
local Npcs = require("../../src/shared/Data/Npcs")
local Quests = require("../../src/shared/Data/Quests")
local SkillData = require("../../src/shared/Data/Skills")
local Titles = require("../../src/shared/Data/Titles")

local Visibility = {}

local function hidden(entity: any): boolean
	return type(entity) == "table" and (entity.hidden == true or entity.wiki == false)
end

-- Ids of hidden entities in any number of lists / maps of entities with an `id`.
function Visibility.fromLists(lists: { any }): { [string]: boolean }
	local out: { [string]: boolean } = {}
	for _, list in lists do
		for _, entity in list do
			if hidden(entity) and type(entity.id) == "string" then
				out[entity.id] = true
			end
		end
	end
	return out
end

function Visibility.collect(): { [string]: boolean }
	return Visibility.fromLists({
		Items.byId,
		Monsters.list,
		Bosses.list,
		Maps.byId,
		Npcs.list,
		Quests.Main.list,
		Quests.Side.list,
		SkillData.byId,
		Titles.list,
		Blessings.list,
		Cosmetics.list,
	})
end

return Visibility
