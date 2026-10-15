--!strict
-- rankings.json from the raw Open Cloud answers (S125), pure (tests/rankingsfetch.spec). The boards and their limits come
-- from tools/WikiData/Rankings, the scores are decoded like the game does it (Logic/Leaderboard), the metadata is joined
-- by entry key and a row without metadata is dropped (never a bare key with a user id). The result is checked against
-- the exporter schema and the leak scan; any problem is an error, so no file is written.
--
-- responses = {
--   week = <Logic/Time.weekNumber of the fetch>,
--   boards = { [wiki board id] = { entries = { { key, value: number } } } (level, guild: ordered data stores)
--                                | { items = { { key, value = { s, m, cid } } } } (weekly sorted maps)
--                                | { list = { ListEntry } } (Hall of Fame) },
--   meta = { [entry key] = Logic/Leaderboard.Meta },
-- }

local Json = require("../WikiData/Json")
local Leak = require("../WikiData/Leak")
local Leaderboard = require("../../src/shared/Logic/Leaderboard")
local Rankings = require("../WikiData/Rankings")
local Schema = require("../WikiData/Schema")

local Build = {}

export type Responses = {
	week: number,
	boards: { [string]: { entries: { any }?, items: { any }?, list: { any }? } },
	meta: { [string]: any },
}

local function text(v: any): string?
	return if type(v) == "string" and v ~= "" then v else nil
end

local function int(v: any): number?
	local n = tonumber(v)
	return if n and n == n and n ~= math.huge and n ~= -math.huge then math.floor(n) else nil
end

-- Metadata usable on the wiki: a name, not the "deleted" marker.
local function usable(meta: any): boolean
	return type(meta) == "table" and meta.d ~= true and text(meta.n) ~= nil
end

local function rowsOf(board: Rankings.WikiBoard, data: any, meta: { [string]: any }): { any }
	local rows = {}
	local function add(row: { [string]: any })
		if #rows < board.limit then
			row.rank = #rows + 1
			table.insert(rows, row)
		end
	end
	if board.kind == "level" or board.kind == "guild" then
		for _, e in if type(data.entries) == "table" then data.entries else {} do
			local m = meta[e.key]
			local value = int(e.value)
			if not usable(m) or not value then
				continue
			end
			if board.kind == "level" then
				local level = Leaderboard.decodeLevel(value)
				add({ name = m.n, class = text(m.c), guild = text(m.g), level = level, value = level })
			else
				add({ name = m.n, guild = text(m.g), members = int(m.m), value = Leaderboard.decodeGuild(value) })
			end
		end
	elseif board.kind == "week" then
		local items = {}
		for _, item in if type(data.items) == "table" then data.items else {} do
			local v = item.value
			if type(v) == "table" and int(v.s) and usable(v.m) then
				table.insert(items, { key = item.key, s = int(v.s) :: number, m = v.m })
			end
		end
		table.sort(items, function(a, b)
			if a.s ~= b.s then
				return a.s > b.s
			end
			return a.key < b.key
		end)
		for _, item in items do
			local m = item.m
			add({ name = m.n, class = text(m.c), guild = text(m.g), level = int(m.l), value = item.s })
		end
	elseif board.kind == "hof" then
		for _, e in if type(data.list) == "table" then data.list else {} do
			local at = int(e.at)
			if text(e.n) and at then
				-- the day of the entry, not the second
				add({ name = e.n, class = text(e.c), value = at - at % 86400 })
			end
		end
	end
	return rows
end

-- The rankings file of the answers, checked (schema, leak scan); errors on any problem.
function Build.fromResponses(responses: Responses, now: number): any
	local file = { available = true, updatedAt = math.floor(now), boards = {} }
	for _, board in Rankings.boards(responses.week) do
		local header = Rankings.header(board)
		header.rows = rowsOf(board, responses.boards[board.id] or {}, responses.meta or {})
		table.insert(file.boards, header)
	end
	local errors = Schema.check(file, Schema.files.rankings, "rankings")
	if #errors > 0 then
		error("rankings: the file does not match the schema:\n  " .. table.concat(errors, "\n  "), 0)
	end
	local leaks = Leak.scanKeys({ ["wiki/src/data/rankings.json"] = Json.file(file) })
	if #leaks > 0 then
		error("rankings: forbidden keys:\n  " .. table.concat(leaks, "\n  "), 0)
	end
	return file
end

return Build
