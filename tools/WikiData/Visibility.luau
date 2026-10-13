--!strict
-- Unreleased entities (S34, docs/WIKI.md §1): an entity with `hidden == true` or `wiki == false` in the game data
-- is left out of the wiki together with every reference to it. collect() gathers their ids from the data lists;
-- fromLists() is the pure part (tested on made-up data).
-- S57 (ROZWOJ 3.5): a path with `wiki == false` hides its title and its nodes, and a skill whose `path` has no PathDef
-- (or an unpublished one) is hidden too (fromPaths). Path ids themselves never enter the set: ctx.hidden is one id
-- space for every entity and path ids may equal NPC, shop, quest or blessing ids (healer, fortune, guardian).
-- S82: the ids of unpublished paths go to a set of their own (second value of fromPaths, collectPaths ->
-- ctx.hiddenPaths), read only by the skills export.

local Blessings = require("../../src/shared/Data/Blessings")
local Bosses = require("../../src/shared/Data/Bosses")
local Cosmetics = require("../../src/shared/Data/Cosmetics")
local Items = require("../../src/shared/Data/Items")
local Maps = require("../../src/shared/Data/Maps")
local Monsters = require("../../src/shared/Data/Monsters")
local MountData = require("../../src/shared/Data/Mounts")
local Npcs = require("../../src/shared/Data/Npcs")
local PathData = require("../../src/shared/Data/Paths")
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

-- Ids hidden by unpublished paths: their title and nodes, and the skills of unpublished or missing paths. Second
-- value: the ids of the unpublished paths themselves (never in the shared set).
function Visibility.fromPaths(paths: { any }, skills: { [string]: any }): ({ [string]: boolean }, { [string]: boolean })
	local out: { [string]: boolean } = {}
	local hiddenPaths: { [string]: boolean } = {}
	local published: { [string]: boolean } = {}
	for _, path in paths do
		if path.wiki == false then
			hiddenPaths[path.id] = true
			out[path.titleId] = true
			for _, row in path.rows do
				for _, node in row.nodes do
					out[node.id] = true
				end
			end
		else
			published[path.id] = true
		end
	end
	for id, skill in skills do
		if type(skill) == "table" and skill.path ~= nil and not published[skill.path] then
			out[id] = true
		end
	end
	return out, hiddenPaths
end

-- Ids of the unpublished paths of the game (ctx.hiddenPaths).
function Visibility.collectPaths(): { [string]: boolean }
	local _, hiddenPaths = Visibility.fromPaths(PathData.list, SkillData.byId)
	return hiddenPaths
end

function Visibility.collect(): { [string]: boolean }
	local out = Visibility.fromLists({
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
		MountData.list, -- S97
	})
	local fromPaths = Visibility.fromPaths(PathData.list, SkillData.byId)
	for id in fromPaths do
		out[id] = true
	end
	return out
end

return Visibility
