--!strict
-- The wiki rankings fetch (S125, tools/rankings_fetch.luau): the file built from Open Cloud answers (schema, decoded
-- scores, no user ids or keys), the skip without the key and the retries after 429. Mock answers only: no network.

local serde = require("@lune/serde")

local Answers = require("./fixtures/rankings/answers")
local Build = require("../tools/Rankings/Build")
local Json = require("../tools/WikiData/Json")
local Leak = require("../tools/WikiData/Leak")
local Main = require("../tools/Rankings/Main")
local OpenCloud = require("../tools/Rankings/OpenCloud")
local Schema = require("../tools/WikiData/Schema")
local T = require("./Test")
local Time = require("../src/shared/Logic/Time")

local NOW = 1791763200 + 7200
local WEEK = Time.weekNumber(NOW)

local function responses(): Build.Responses
	local meta = {}
	for key, answer in Answers.meta do
		meta[key] = answer.value
	end
	return {
		week = WEEK,
		boards = {
			level = { entries = OpenCloud.orderedEntries(Answers.ordered.level) },
			guild = { entries = OpenCloud.orderedEntries(Answers.ordered.guild) },
			exp_week_3 = { items = OpenCloud.sortedItems(Answers.sorted3) },
			hof_mage = { list = Answers.hofMage.value.entries },
		},
		meta = meta,
	}
end

local function board(file: any, id: string): any
	for _, b in file.boards do
		if b.id == id then
			return b
		end
	end
	error(`no board {id}`)
end

-- A mock Open Cloud: answers by the kind of address, counts the calls.
local function mockDeps(): (OpenCloud.Deps & { now: () -> number }, { calls: number, waits: { number } })
	local seen = { calls = 0, waits = {} }
	local deps = {
		send = function(url: string, _key: string): OpenCloud.Response
			seen.calls += 1
			local body: any = nil
			if string.find(url, "ordered-data-stores", 1, true) then
				if string.find(url, "Vaelthorn_LB_v1_level/", 1, true) then
					body = Answers.ordered.level
				elseif string.find(url, "Vaelthorn_LB_v1_guild/", 1, true) then
					body = Answers.ordered.guild
				else
					body = { orderedDataStoreEntries = {} }
				end
			elseif string.find(url, "sorted-maps", 1, true) then
				body = if string.find(url, `exp_week_{WEEK}_3`, 1, true)
					then Answers.sorted3
					else { memoryStoreSortedMapItems = {} }
			elseif string.find(url, "Vaelthorn_LBMeta_v1", 1, true) then
				local key = string.match(url, "/entries/([^/?]+)$") or ""
				local answer = Answers.meta[key]
				if not answer then
					return { status = 404, body = "" }
				end
				body = answer
			elseif string.find(url, "Vaelthorn_LBLists_v1", 1, true) then
				if string.find(url, "/entries/hof_mage", 1, true) then
					body = Answers.hofMage
				else
					return { status = 404, body = "" }
				end
			end
			return { status = 200, body = Json.encode(body or {}) }
		end,
		wait = function(seconds: number)
			table.insert(seen.waits, seconds)
		end,
		decode = function(text: string): any
			return serde.decode("json", text)
		end,
		now = function(): number
			return NOW
		end,
	}
	return deps, seen
end

T.describe("Rankings fetch (S125)", function()
	T.it("builds a file that matches the schema with decoded scores", function()
		local file = Build.fromResponses(responses(), NOW)
		T.expect(#Schema.check(file, Schema.files.rankings, "rankings")).toBe(0)
		T.expect(file.available).toBe(true)
		T.expect(file.updatedAt).toBe(NOW)
		local level = board(file, "level")
		T.expect(#level.rows).toBe(2)
		T.expect(level.rows[1])
			.toEqual({ rank = 1, name = "Aria", class = "Mage", guild = "ORD", level = 100, value = 100 })
		T.expect(level.rows[2]).toEqual({ rank = 2, name = "Borin", class = "Warrior", level = 63, value = 63 })
		local guild = board(file, "guild")
		T.expect(guild.rows[1]).toEqual({ rank = 1, name = "Order", guild = "ORD", members = 12, value = 300 })
		local week = board(file, "exp_week_3")
		T.expect(week.week).toBe(WEEK)
		T.expect(week.bracket).toBe("45–69")
		T.expect(#week.rows).toBe(2)
		T.expect({ week.rows[1].name, week.rows[1].value, week.rows[1].rank }).toEqual({ "Cyra", 7000, 1 })
		T.expect({ week.rows[2].name, week.rows[2].value, week.rows[2].rank }).toEqual({ "Borin", 5400, 2 })
		local hof = board(file, "hof_mage")
		T.expect(hof.rows[1]).toEqual({ rank = 1, name = "Aria", class = "Mage", value = 1791763200 })
		T.expect(#board(file, "level_hunter").rows).toBe(0)
		T.expect(board(file, "level").name.pl ~= nil).toBe(true)
	end)

	T.it("drops rows without metadata and never writes ids or keys", function()
		local file = Build.fromResponses(responses(), NOW)
		local text = Json.file(file)
		T.expect(#Leak.scanKeys({ ["wiki/src/data/rankings.json"] = text })).toBe(0)
		for _, word in { '"userId"', '"charId"', '"cid"', '"key"', '"u"', '"shards"', '"productId"', '"robux"' } do
			T.expect({ word, string.find(text, word, 1, true) == nil }).toEqual({ word, true })
		end
		for _, key in { "111_1", "222_2", "333_1", "555_1", "g_abc" } do
			T.expect({ key, string.find(text, key, 1, true) == nil }).toEqual({ key, true })
		end
	end)

	T.it("skips without the key or the universe and asks nothing", function()
		local deps, seen = mockDeps()
		for _, env in
			{
				{},
				{ ROBLOX_OPEN_CLOUD_KEY = "secret" },
				{ ROBLOX_UNIVERSE_ID = "123" },
				{ ROBLOX_OPEN_CLOUD_KEY = "", ROBLOX_UNIVERSE_ID = "123" },
			} :: { { [string]: string } }
		do
			local status, text = Main.run(env, deps)
			T.expect(status).toBe("skipped")
			T.expect(text).toBe(Main.SKIPPED)
		end
		T.expect(seen.calls).toBe(0)
	end)

	T.it("fetches every board through the mock and never prints the key", function()
		local deps, seen = mockDeps()
		local status, text = Main.run({ ROBLOX_OPEN_CLOUD_KEY = "secret-key", ROBLOX_UNIVERSE_ID = "123" }, deps)
		T.expect(status).toBe("ok")
		T.expect(seen.calls > 10).toBe(true)
		T.expect(string.find(text, "secret-key", 1, true)).toBeNil()
		T.expect(string.find(text, '"Cyra"', 1, true) ~= nil).toBe(true)
		local failing = table.clone(deps)
		failing.send = function(_url: string, _key: string): OpenCloud.Response
			return { status = 403, body = "" }
		end
		local bad, message = Main.run({ ROBLOX_OPEN_CLOUD_KEY = "secret-key", ROBLOX_UNIVERSE_ID = "123" }, failing)
		T.expect(bad).toBe("error")
		T.expect(string.find(message, "403", 1, true) ~= nil).toBe(true)
		T.expect(string.find(message, "secret-key", 1, true)).toBeNil()
		-- 404 on every board (wrong universe id or prefix) is an error, 404 on one board is an empty board
		local missing = table.clone(deps)
		missing.send = function(_url: string, _key: string): OpenCloud.Response
			return { status = 404, body = "" }
		end
		local none, why = Main.run({ ROBLOX_OPEN_CLOUD_KEY = "secret-key", ROBLOX_UNIVERSE_ID = "123" }, missing)
		T.expect(none).toBe("error")
		T.expect(string.find(why, "404", 1, true) ~= nil).toBe(true)
		local some = table.clone(deps)
		some.send = function(url: string, k: string): OpenCloud.Response
			if string.find(url, "Vaelthorn_LB_v1_level_hunter/", 1, true) then
				return { status = 404, body = "" }
			end
			return deps.send(url, k)
		end
		T.expect((Main.run({ ROBLOX_OPEN_CLOUD_KEY = "secret-key", ROBLOX_UNIVERSE_ID = "123" }, some))).toBe("ok")
	end)

	T.it("retries after 429 and 5xx with the injected wait", function()
		local answers = { 429, 429, 200 }
		local calls = 0
		local waits = {}
		local deps: OpenCloud.Deps = {
			send = function(_url: string, _key: string): OpenCloud.Response
				calls += 1
				local status = answers[calls] or 200
				return { status = status, body = if status == 200 then '{"value": 7}' else "" }
			end,
			wait = function(seconds: number)
				table.insert(waits, seconds)
			end,
			decode = function(text: string): any
				return serde.decode("json", text)
			end,
		}
		local ok, status, body = OpenCloud.request("https://example.invalid/x", "k", deps)
		T.expect({ ok, status, OpenCloud.entryValue(body) }).toEqual({ true, 200, 7 })
		T.expect(calls).toBe(3)
		T.expect(waits).toEqual({ OpenCloud.PAUSE, 1, OpenCloud.PAUSE, 2, OpenCloud.PAUSE })
		calls = 0
		answers = { 503, 503, 503, 503, 503 }
		waits = {}
		local okFail, statusFail = OpenCloud.request("https://example.invalid/x", "k", deps)
		T.expect({ okFail, statusFail, calls }).toEqual({ false, 503, 4 })
		calls = 0
		answers = { 404 }
		T.expect({ OpenCloud.request("https://example.invalid/x", "k", deps) }).toEqual({ false, 404 })
		T.expect(calls).toBe(1)
		T.expect(OpenCloud.url("entry", { universe = 1, store = "a b", entry = "x/y" }))
			.toBe("https://apis.roblox.com/cloud/v2/universes/1/data-stores/a%20b/scopes/global/entries/x%2Fy")
	end)
end)

return nil
