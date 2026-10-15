--!strict
-- The rankings fetch (S125) without the network and the file system (tests/rankingsfetch.spec): which stores to read
-- for the wiki boards (store names from Config.Leaderboard, like the game builds them), the metadata of the entries,
-- then Build.fromResponses. Without ROBLOX_OPEN_CLOUD_KEY or ROBLOX_UNIVERSE_ID nothing is asked ("skipped": the wiki
-- keeps the placeholder). Returns (status, text): "skipped" + the message, "ok" + the JSON file, "error" + the message
-- (with the HTTP status, never the key).

local Build = require("./Build")
local Config = require("../../src/shared/Config")
local Json = require("../WikiData/Json")
local OpenCloud = require("./OpenCloud")
local Rankings = require("../WikiData/Rankings")
local Time = require("../../src/shared/Logic/Time")

local Main = {}

Main.SKIPPED = "rankings_fetch: no ROBLOX_OPEN_CLOUD_KEY / ROBLOX_UNIVERSE_ID, skipped (the wiki keeps the placeholder)"

export type Deps = OpenCloud.Deps & { now: () -> number }

function Main.run(env: { [string]: string? }, deps: Deps): (string, string)
	local key = env.ROBLOX_OPEN_CLOUD_KEY
	local universe = env.ROBLOX_UNIVERSE_ID
	if not key or key == "" or not universe or universe == "" then
		return "skipped", Main.SKIPPED
	end
	if not string.match(universe, "^%d+$") then
		return "error", "rankings_fetch: ROBLOX_UNIVERSE_ID must be the number of the experience's universe"
	end
	local cfg = Config.Leaderboard
	local now = deps.now()
	local week = Time.weekNumber(now)
	local responses: Build.Responses = { week = week, boards = {}, meta = {} }

	local function fail(what: string, status: number): (string, string)
		return "error", `rankings_fetch: {what} failed (HTTP {status})`
	end

	-- 404 on one board = its store does not exist yet (an empty board); 404 on every board = a wrong universe id or
	-- store prefix (or nothing written yet), an error.
	local asked, missing = 0, 0

	-- One data store entry; 404 = no such entry (nil, not an error).
	local function entry(store: string, entryKey: string): (boolean, number, any?)
		local url = OpenCloud.url("entry", { universe = universe, store = store, entry = entryKey })
		local ok, status, body = OpenCloud.request(url, key :: string, deps)
		if not ok and status == 404 then
			return true, status, nil
		end
		return ok, status, if ok then OpenCloud.entryValue(body) else nil
	end

	for _, board in Rankings.boards(week) do
		if board.def.kind == "ordered" then
			local url = OpenCloud.url(
				"ordered",
				{ universe = universe, store = cfg.orderedPrefix .. board.instance, n = board.limit }
			)
			local ok, status, body = OpenCloud.request(url, key, deps)
			if not ok and status ~= 404 then
				return fail(board.id, status)
			end
			asked += 1
			missing += if ok then 0 else 1
			local entries = if ok then OpenCloud.orderedEntries(body) else {}
			responses.boards[board.id] = { entries = entries }
			for i, e in entries do
				if i > board.limit then
					break
				end
				if responses.meta[e.key] == nil then
					local okMeta, metaStatus, value = entry(cfg.metaStore, e.key)
					if not okMeta then
						return fail(`metadata of {board.id}`, metaStatus)
					end
					responses.meta[e.key] = if type(value) == "table" then value else false
				end
			end
		elseif board.def.kind == "sorted" then
			local url = OpenCloud.url(
				"sorted",
				{ universe = universe, map = cfg.sortedPrefix .. board.instance, n = board.limit }
			)
			local ok, status, body = OpenCloud.request(url, key, deps)
			if not ok and status ~= 404 then
				return fail(board.id, status)
			end
			asked += 1
			missing += if ok then 0 else 1
			responses.boards[board.id] = { items = if ok then OpenCloud.sortedItems(body) else {} }
		else
			local ok, status, value = entry(cfg.listStore, board.instance)
			if not ok then
				return fail(board.id, status)
			end
			local list = if type(value) == "table" and type(value.entries) == "table" then value.entries else {}
			responses.boards[board.id] = { list = list }
		end
	end
	if asked > 0 and missing == asked then
		return fail("every board", 404)
	end
	local built, file = pcall(Build.fromResponses, responses, now)
	if not built then
		return "error", `rankings_fetch: {file}`
	end
	return "ok", Json.file(file)
end

return Main
