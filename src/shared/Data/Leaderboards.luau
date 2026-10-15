--!strict
-- Leaderboard definitions (S124, DESIGN-17 §5). Kinds: `ordered` = OrderedDataStore, permanent (level); `sorted` =
-- MemoryStore SortedMap with a TTL, periodic (week, event, season); `list` = one DataStore key with a short list (Hall
-- of Fame, statues). Later sessions add boards here: S125 exp_week / guild (with the weekly brackets, rewards and EXP
-- sources), S126 arena_<season>_<bracket> (S128 arena3_...), S129
-- bloodmoon. Board ids are stable: they name the stores (Config.Leaderboard prefixes), so class ids are lower case.
-- Scores come from Logic/Leaderboard.SCORERS (the character only, never the account: tests/paywall.spec).

local Classes = require("./Classes")
local Config = require("../Config")

export type Kind = "ordered" | "sorted" | "list"
export type Filter = "class" | "bracket" | "region" | "arenaBracket" -- S126: the arena brackets (Data/Arena.BRACKETS)
export type Format = "level" | "int" | "date" | "guild" | "rating" -- S125: "guild" = Logic/Leaderboard.decodeGuild; S126 arena rating
export type ListMode = "first" | "latest"

export type BoardDef = {
	id: string, -- base id; with `parts` the instance id is id .. "_" .. part values joined by "_" (Logic/Leaderboard.instanceId)
	kind: Kind,
	nameKey: string,
	scope: "character" | "guild", -- what an entry key names: "<userId>_<slot>" or "g_<guildId>" (S125)
	score: string?, -- snapshot scorer in Logic/Leaderboard.SCORERS ("level"); nil = fed by a service (Submit / Add)
	class: string?, -- Data/Classes id: only characters of this class
	parts: { string }?, -- instance parts resolved by Logic/Leaderboard.PARTS ("week", "season"; S125 "bracket", S126 "arenaBracket")
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

-- S125 (DESIGN-17 §5): weekly EXP. One MemoryStore SortedMap per (week, bracket), TTL Config.Leaderboard.weekTtl.
-- The bracket is the character's level at its last write. Top 3 of every bracket get WEEK_REWARDS by mail after the
-- week ends (one server pays, guarded by the "paid_<week>" lock). Week = Logic/Time.weekNumber (Monday 00:00 UTC, S98).
local WEEK_BRACKETS: { { number } } = { { 1, 19 }, { 20, 44 }, { 45, 69 }, { 70, 100 } }

-- Rewards per place (index 1..3): Dragon Shards and the timed title (Data/Titles, req.kind "timed"). Gameplay rewards,
-- never sold (tests/paywall.spec).
local WEEK_REWARDS = {
	shards = { 100, 50, 25 },
	title = "weekly_diligent",
	titleDays = 7, -- counted from the start of the next week (Logic/Leaderboard.payoutPlan)
}

-- EXP sources that count for the week (LevelService.GiveExp `source`). An allowlist: anything else (admin commands,
-- unknown sources) never reaches a ranking (DESIGN-17 §0.2). Adding a source is a deliberate change with a test.
local WEEK_SOURCES: { [string]: boolean } = {
	monster = true,
	boss = true,
	quest = true,
	contract = true,
	worldEvent = true,
}

do
	-- the brackets cover 1..Config.MaxLevel without gaps or overlaps
	local nextLevel = 1
	for i, b in WEEK_BRACKETS do
		assert(b[1] == nextLevel and b[2] >= b[1], `Data/Leaderboards: WEEK_BRACKETS[{i}] must start at {nextLevel}`)
		nextLevel = b[2] + 1
	end
	assert(nextLevel == Config.MaxLevel + 1, "Data/Leaderboards: WEEK_BRACKETS must end at Config.MaxLevel")
end

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

-- S125: weekly EXP, fed by LeaderboardService from LevelService.ExpGained (no scorer); instance id
-- exp_week_<week>_<bracket> (Logic/Leaderboard.weekMapName).
table.insert(
	list,
	{
		id = "exp_week",
		kind = "sorted",
		nameKey = "leaderboard.board.exp_week",
		scope = "character",
		parts = { "week", "bracket" },
		ttl = Config.Leaderboard.weekTtl,
		format = "int",
	} :: BoardDef
)
-- S125: guilds, the sum of the levels of the Config.Leaderboard.guildTop highest members (GuildService through
-- LeaderboardService.SubmitGuild); entry key "g_<guildId>".
table.insert(
	list,
	{
		id = "guild",
		kind = "ordered",
		nameKey = "leaderboard.board.guild",
		scope = "guild",
		format = "guild",
	} :: BoardDef
)

-- S126 (DESIGN-17 §6): the ranked arena, one board per season and arena bracket ("arena_202611_40_59"), score =
-- the 1v1 rating, fed by ArenaService through Submit (no scorer). Ordered (no TTL): S128 reads closed seasons.
table.insert(
	list,
	{
		id = "arena",
		kind = "ordered",
		nameKey = "leaderboard.board.arena",
		scope = "character",
		parts = { "season", "arenaBracket" },
		format = "rating",
	} :: BoardDef
)
-- S128 (DESIGN-17 §6): the 3v3 arena, the same shape ("arena3_202611_40_59"), score = the 3v3 rating (rating3).
table.insert(
	list,
	{
		id = "arena3",
		kind = "ordered",
		nameKey = "leaderboard.board.arena3",
		scope = "character",
		parts = { "season", "arenaBracket" },
		format = "rating",
	} :: BoardDef
)

local byId: { [string]: BoardDef } = {}
for _, def in list do
	assert(byId[def.id] == nil, `Data/Leaderboards: duplicate board {def.id}`)
	byId[def.id] = def
end

local tabs: { TabDef } = {
	{ id = "level", nameKey = "leaderboard.tab.level", boards = levelBoards, filter = "class", order = 1 },
	{ id = "hof", nameKey = "leaderboard.tab.hof", boards = hofBoards, filter = "class", order = 2 },
	{ id = "week", nameKey = "leaderboard.tab.week", boards = { "exp_week" }, filter = "bracket", order = 3 },
	{ id = "guild", nameKey = "leaderboard.tab.guild", boards = { "guild" }, order = 4 },
	-- S126: this season's arena board of an arena bracket
	{ id = "arena", nameKey = "leaderboard.tab.arena", boards = { "arena" }, filter = "arenaBracket", order = 5 },
	-- S128: this season's 3v3 arena board of an arena bracket
	{ id = "arena3", nameKey = "leaderboard.tab.arena3", boards = { "arena3" }, filter = "arenaBracket", order = 6 },
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
	WEEK_BRACKETS = WEEK_BRACKETS,
	WEEK_REWARDS = WEEK_REWARDS,
	WEEK_SOURCES = WEEK_SOURCES,
	get = function(id: string): BoardDef?
		return byId[id]
	end,
}

deepFreeze(Leaderboards)

return Leaderboards
