--!strict
-- Quests (DESIGN §20): the main story, the daily contracts and (S27) the side quests; S98 (docs/DESIGN-15.md §3.1):
-- categories, boss quests ("Slayer", given by the scouts), weekly contracts and the skeleton of the hunting contracts
-- (filled by S99).

local Types = require("@self/Types")

export type Objective = Types.Objective
export type Reward = Types.Reward
export type MainQuest = Types.MainQuest
export type DailyTemplate = Types.DailyTemplate
export type SideQuest = Types.SideQuest
export type Category = Types.Category
export type ContractQuest = Types.ContractQuest

local Main = require("@self/Main")
local Daily = require("@self/Daily")
local Side = require("@self/Side")
local Boss = require("@self/Boss")
local Weekly = require("@self/Weekly")
local Contracts = require("@self/Contracts")

-- Journal tab order (the stable arc of S96 is in the "side" tab like every arc).
local CATEGORIES: { Category } = { "main", "side", "contract", "boss", "daily", "weekly" }

-- S98: every quest taken at an NPC and kept in character.quests.side (side arcs incl. the S96 stable arc, boss
-- quests), keyed by id.
local npcList: { SideQuest } = {}
for _, quest in Side.list do
	table.insert(npcList, quest)
end
for _, quest in Boss.list do
	table.insert(npcList, quest)
end

local function npcQuest(id: string): SideQuest?
	return Side.byId[id] or Boss.byId[id]
end

-- The category of a quest id (main, side, boss, contract); nil for an unknown id.
local function categoryOf(id: string): Category?
	local main = Main.byId[id]
	if main then
		return main.category or "main"
	end
	local quest = npcQuest(id)
	if quest then
		return quest.category or "side"
	end
	if Contracts.byId[id] then
		return "contract"
	end
	return nil
end

return table.freeze({
	Main = Main,
	Daily = Daily,
	Side = Side,
	Boss = Boss,
	Weekly = Weekly,
	Contracts = Contracts,
	CATEGORIES = table.freeze(CATEGORIES),
	npcList = table.freeze(npcList),
	npcQuest = npcQuest,
	categoryOf = categoryOf,
})
