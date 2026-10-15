--!strict
-- Leaderboard definitions (S124, DESIGN-17 §5). Kinds: `ordered` = OrderedDataStore, permanent (level); `sorted` =
-- MemoryStore SortedMap with a TTL, periodic (week, event, season); `list` = one DataStore key with a short list (Hall
-- of Fame, statues). Later sessions add boards here: S125 exp_week / guild, S126/S128 arena_<season>_<bracket>, S129
-- bloodmoon. Board ids are stable: they name the stores (Config.Leaderboard prefixes), so class ids are lower case.
-- Scores come from Logic/Leaderboard.SCORERS (the character only, never the account: tests/paywall.spec).

local Classes = require("./Classes")
local Config = require("../Config")

export type Kind = "ordered" | "sorted" | "list"
export type Filter = "class" | "bracket" | "region"
export type Format = "level" | "int" | "date"
export type ListMode = "first" | "latest"

export type BoardDef = {
	id: string, -- base id; with `parts` the instance id is id .. "_" .. part values joined by "_" (Logic/Leaderboard.instanceId)
	kind: Kind,
	nameKey: string,
	scope: "character" | "guild", -- what an entry key names: "<userId>_<slot>" or "g_<guildId>" (S125)
	score: string?, -- snapshot scorer in Logic/Leaderboard.SCORERS ("level"); nil = fed by a service (Submit / Add)
	class: string?, -- Data/Classes id: only characters of this class
	parts: { string }?, -- instance parts resolved by Logic/Leaderboard.PARTS ("week", "season"; S125+ more)
	ttl: number?, -- sorted: seconds an entry lives
	max: number?, -- list: entries kept
	mode: ListMode?, -- list: keep the first `max` forever / keep the latest `max`
	format: Format, -- how the Rankings window and the town board show the score
	hidden: boolean?, -- not offered by the Rankings window (internal shards, payout bookkeeping)
}

export type TabDef = { id: string, nameKey: string, boards: { string }, filter: Filter?, order: number }
export type PanelDef = { id: string, titleKey: string, kind: "top" | "lists", boards: { string }, n: number }
export type PlinthDef = { board: string, index: number, captionKey: string }
export type Town = { panels: { PanelDef }, plinths: { PlinthDef } }

local HOF_SIZE = 10 -- the first ten characters of each class at the top level (DESIGN-17 §5)

local list: { BoardDef } = {}

local function ordered(id: string, class: string?)
	table.insert(
		list,
		{
			id = id,
			kind = "ordered",
			nameKey = `leaderboard.board.{id}`,
			scope = "character",
			score = "level",
			class = class,
			format = "level",
		} :: BoardDef
	)
end

local function hof(class: string)
	local id = `hof_{string.lower(class)}`
	table.insert(
		list,
		{
			id = id,
			kind = "list",
			nameKey = `leaderboard.board.{id}`,
			scope = "character",
			class = class,
			max = HOF_SIZE,
			mode = "first",
			format = "date",
		} :: BoardDef
	)
end

ordered("level", nil)
local levelBoards = { "level" }
local hofBoards = {}
for _, class in Classes.order do
	ordered(`level_{string.lower(class)}`, class)
	table.insert(levelBoards, `level_{string.lower(class)}`)
end
for _, class in Classes.order do
	hof(class)
	table.insert(hofBoards, `hof_{string.lower(class)}`)
end

local byId: { [string]: BoardDef } = {}
for _, def in list do
	assert(byId[def.id] == nil, `Data/Leaderboards: duplicate board {def.id}`)
	byId[def.id] = def
end

local tabs: { TabDef } = {
	{ id = "level", nameKey = "leaderboard.tab.level", boards = levelBoards, filter = "class", order = 1 },
	{ id = "hof", nameKey = "leaderboard.tab.hof", boards = hofBoards, filter = "class", order = 2 },
}

local plinths: { PlinthDef } = {}
for _, class in Classes.order do
	table.insert(plinths, { board = `hof_{string.lower(class)}`, index = 1, captionKey = "town.fame.plinth" })
end

-- The Hall of Fame by the town hall (Data/Town/fame): the board's panels and the statue plinths in the order of
-- Town.fame.plinths. S128 / S130 append arena and tournament panels and plinths.
local TOWN: Town = {
	panels = {
		{ id = "top", titleKey = "town.fame.top", kind = "top", boards = { "level" }, n = Config.Leaderboard.townTop },
		{ id = "hof", titleKey = "town.fame.hof", kind = "lists", boards = table.clone(hofBoards), n = HOF_SIZE },
	},
	plinths = plinths,
}

local function deepFreeze(value: any): any
	if type(value) == "table" and not table.isfrozen(value) then
		for _, v in value do
			deepFreeze(v)
		end
		table.freeze(value)
	end
	return value
end

local Leaderboards = {
	list = list,
	byId = byId,
	tabs = tabs,
	TOWN = TOWN,
	HOF_SIZE = HOF_SIZE,
	get = function(id: string): BoardDef?
		return byId[id]
	end,
}

deepFreeze(Leaderboards)

return Leaderboards
