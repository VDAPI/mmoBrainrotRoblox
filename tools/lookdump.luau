--!strict
-- Dumps generated monster looks (Logic/Anatomy) as world-space pieces (logic in tools/WikiLooks.luau):
--   lune run tools/lookdump.luau out.json <ids...|region:N|bosses|pets> [variant]
--     S24 preview for docs/miasto/tools/render3d.py: looks stand in a row along X, facing -Z, on a ground plate.
--   lune run tools/lookdump.luau --wiki tools/wiki-renders/out/looks.json
--     S38: every wiki render (monsters with elite variants, bosses, pets) for tools/wiki-renders/render.py.

local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")

local Json = require("./WikiData/Json")
local WikiLooks = require("./WikiLooks")

local args = process.args

if args[1] == "--wiki" then
	local out = args[2] or "tools/wiki-renders/out/looks.json"
	local entries = WikiLooks.entries()
	local dir = string.match(out, "^(.*)[/\\][^/\\]+$")
	if dir and dir ~= "" and not fs.isDir(dir) then
		fs.writeDir(dir)
	end
	fs.writeFile(out, Json.file({ version = WikiLooks.VERSION, looks = entries }))
	print(`lookdump: {#entries} looks -> {out}`)
	return
end

local out = args[1] or "looks.json"
local rest = {}
for i = 2, #args do
	table.insert(rest, args[i])
end
local pieces, labels, width = WikiLooks.legacy(rest)
fs.writeFile(out, `\{"pieces": {serde.encode("json", pieces)}\}`)
print(table.concat(labels, " "), "width", width)
