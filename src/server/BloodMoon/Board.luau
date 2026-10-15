--!strict
-- Blood Moon region boards (S129, DESIGN-17 §7, §0.4): one MemoryStore SortedMap per occurrence and region,
-- "BloodMoon_<id>_<region>" (Logic/BloodMoon.boardId; Leaderboard/Stores adds Config.Leaderboard.sortedPrefix), entries
-- expire after Config.BloodMoon.ttl. A thin layer over the S124/S125 wrapper Leaderboard/Stores.sorted: the same
-- retries (Market/Retry), the same in-memory fallback chosen once per server (no MemoryStore: "this server only") and
-- no second MemoryStore access. Key = Leaderboard entry key "<userId>_<slot>", score = Logic/BloodMoon.sortKey (more
-- points first, earlier first on a tie), value meta = { n = name, c = class, l = level, g = guild tag?, t }; a write
-- only ever raises an entry (Board.write).
-- Every call may yield: BloodMoonService runs them in task.spawn, never in its step.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared

local BloodMoon = require(Shared.Logic.BloodMoon)
local Config = require(Shared.Config)
local Leaderboard = require(Shared.Logic.Leaderboard)
local Stores = require(script.Parent.Parent.Leaderboard.Stores)

export type Row = {
	key: string,
	rank: number,
	points: number,
	name: string,
	class: string?,
	level: number?,
	guild: string?,
}

local Board = {}

local function boardOf(id: string, region: string): Stores.Board
	return Stores.sorted(BloodMoon.boardId(id, region), Config.BloodMoon.ttl)
end

-- true = the ranking reaches every server (MemoryStore works here); false = this server only.
function Board.isGlobal(): boolean
	return Stores.mode("sorted") == "global"
end

-- Raises the entry `key` of the region board to `sortKey` (written at most every Config.BloodMoon.writeEvery s, plus on
-- leave / at the end). Points only grow within an occurrence, so a lower or equal stored key is kept (UpdateAsync):
-- two writes in flight (a periodic one and the last one on leave) can land in any order. (ok)
function Board.write(id: string, region: string, key: string, sortKey: number, meta: Leaderboard.Meta): boolean
	local score = math.floor(sortKey)
	local ok = boardOf(id, region).update(key, function(old: any?): any?
		if type(old) == "table" and type(old.s) == "number" and old.s >= score then
			return nil
		end
		return { s = score, m = meta }
	end)
	return ok
end

-- The best `n` rows of the region board, whether they came from the global store and whether the read worked
-- (false = the store failed after its retries: the rows are unknown, not an empty board).
function Board.top(id: string, region: string, n: number): ({ Row }, boolean, boolean)
	local ok, entries = boardOf(id, region).top(n)
	local rows: { Row } = {}
	if ok then
		for i, entry in entries do
			local meta = if type(entry.value) == "table" then entry.value else {}
			table.insert(rows, {
				key = entry.key,
				rank = i,
				points = BloodMoon.pointsOf(entry.score),
				name = if type(meta.n) == "string" then meta.n else "?",
				class = if type(meta.c) == "string" then meta.c else nil,
				level = if type(meta.l) == "number" then meta.l else nil,
				guild = if type(meta.g) == "string" then meta.g else nil,
			})
		end
	end
	return rows, Board.isGlobal() and ok, ok
end

return Board
