--!strict
-- Rankings on the wiki (S125, docs/WIKI.md "Rankingi"): `lune run tools/rankings_fetch.luau` from the repository root.
-- Reads the top of the leaderboards through Roblox Open Cloud and writes wiki/src/data/rankings.json (the workflows
-- .github/workflows/rankings.yml and wiki.yml run it before the build; the result is never committed: the commit keeps
-- the exporter's placeholder). Needs ROBLOX_OPEN_CLOUD_KEY (secret) and ROBLOX_UNIVERSE_ID; without them it prints why
-- and exits 0. An API or network error exits 1 with the HTTP status (the key is never printed).

local fs = require("@lune/fs")
local net = require("@lune/net")
local process = require("@lune/process")
local serde = require("@lune/serde")
local task = require("@lune/task")

local Main = require("./Rankings/Main")

local OUT = "wiki/src/data/rankings.json"

if not fs.isDir("src/shared") or not fs.isDir("wiki/src/data") then
	print("rankings_fetch: run it from the repository root")
	process.exit(2)
end

local status, output = Main.run(process.env, {
	send = function(url: string, key: string)
		local ok, response = pcall(net.request, {
			url = url,
			method = "GET",
			headers = { ["x-api-key"] = key, ["accept"] = "application/json" },
		})
		if not ok then
			return { status = 0, body = "" }
		end
		return { status = response.statusCode, body = response.body }
	end,
	wait = function(seconds: number)
		task.wait(seconds)
	end,
	decode = function(text: string): any
		return serde.decode("json", text)
	end,
	now = function(): number
		return os.time()
	end,
})

if status == "skipped" then
	print(output)
	process.exit(0)
elseif status == "ok" then
	fs.writeFile(OUT, output)
	print(`rankings_fetch: wrote {OUT} ({#output} bytes)`)
	process.exit(0)
end
print(output)
process.exit(1)
