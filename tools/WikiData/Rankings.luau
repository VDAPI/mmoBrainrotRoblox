--!strict
-- rankings.json (S125, DESIGN-17 §5): the one source of the file's shape. The exporter (npm run data) writes a
-- placeholder (`available = false`, the boards with names and empty rows: the page says "ranking in game");
-- tools/rankings_fetch.luau fills the same boards from Roblox Open Cloud in the GitHub workflow (tools/Rankings/Build),
-- never committed. Reads Data/Leaderboards, Data/Classes and the texts only: never Data/Products, a store or the network.
-- No user ids, entry keys, character ids, top-level moments or rewards in shards (Leak.FORBIDDEN_KEYS).

local Classes = require("../../src/shared/Data/Classes")
local Leaderboard = require("../../src/shared/Logic/Leaderboard")
local Leaderboards = require("../../src/shared/Data/Leaderboards")
local Names = require("./Names")
local Schema = require("./Schema")

local S = Schema
local arr, rec = S.arr, S.rec

local Rankings = {}

S.file(
	"rankings",
	rec("RankingsFile", {
		available = "bool", -- false = the exporter's placeholder (the page says "ranking in game")
		updatedAt = "int", -- unix seconds of the fetch, 0 in the placeholder
		boards = arr(rec("RankingBoard", {
			id = "string", -- level, level_<class>, exp_week_<bracket>, guild, hof_<class>
			kind = "string", -- level | week | guild | hof (how the page shows `value`)
			name = "name",
			["class?"] = "string",
			["bracket?"] = "string", -- "1–19"
			["week?"] = "int",
			rows = arr(rec("RankingRow", {
				rank = "int",
				name = "string", -- character or guild name (filtered in game)
				["class?"] = "string",
				["level?"] = "int",
				["guild?"] = "string", -- tag
				["members?"] = "int",
				value = "int", -- level / weekly EXP / guild score (decoded) / the day a Hall of Fame entry was made
			})),
		})),
	})
)

-- A board on the wiki: the id in the file, the board definition and its store instance, the row limit (each row may
-- cost one metadata request in the fetch).
export type WikiBoard = {
	id: string,
	kind: "level" | "week" | "guild" | "hof",
	def: Leaderboards.BoardDef,
	instance: string, -- Data/Leaderboards instance id (the store name without the prefix)
	limit: number,
	class: string?,
	bracket: number?,
	week: number?,
}

Rankings.LIMITS = table.freeze({ level = 100, levelClass = 25, week = 25, guild = 50, hof = 10 })

-- The boards on the wiki in page order for week `week` (Logic/Time.weekNumber of the fetch).
function Rankings.boards(week: number): { WikiBoard }
	local out: { WikiBoard } = {}
	local function add(board: WikiBoard)
		table.insert(out, board)
	end
	local level = Leaderboards.get("level") :: Leaderboards.BoardDef
	add({ id = "level", kind = "level", def = level, instance = "level", limit = Rankings.LIMITS.level })
	for _, class in Classes.order do
		local id = `level_{string.lower(class)}`
		local def = Leaderboards.get(id)
		if def then
			add({ id = id, kind = "level", def = def, instance = id, limit = Rankings.LIMITS.levelClass, class = class })
		end
	end
	local weekDef = Leaderboards.get("exp_week")
	if weekDef then
		for bracket in Leaderboards.WEEK_BRACKETS do
			add({
				id = `exp_week_{bracket}`,
				kind = "week",
				def = weekDef,
				instance = Leaderboard.weekMapName(week, bracket),
				limit = Rankings.LIMITS.week,
				bracket = bracket,
				week = week,
			})
		end
	end
	local guild = Leaderboards.get("guild")
	if guild then
		add({ id = "guild", kind = "guild", def = guild, instance = "guild", limit = Rankings.LIMITS.guild })
	end
	for _, class in Classes.order do
		local id = `hof_{string.lower(class)}`
		local def = Leaderboards.get(id)
		if def then
			add({ id = id, kind = "hof", def = def, instance = id, limit = Rankings.LIMITS.hof, class = class })
		end
	end
	return out
end

-- The header of a board in the file (no rows).
function Rankings.header(board: WikiBoard): { [string]: any }
	return {
		id = board.id,
		kind = board.kind,
		name = Names.of(board.def.nameKey),
		class = board.class,
		bracket = if board.bracket then Leaderboard.bracketLabel(board.bracket) else nil,
		week = board.week,
		rows = {},
	}
end

-- The exporter's placeholder: every board with its name and no rows. Week 0: the page shows no week without data.
function Rankings.build(_ctx: any): any
	local boards = {}
	for _, board in Rankings.boards(0) do
		local header = Rankings.header(board)
		header.week = nil
		table.insert(boards, header)
	end
	return { available = false, updatedAt = 0, boards = boards }
end

return Rankings
