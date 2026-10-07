--!strict
-- Wiki map SVGs (S37). Run from the repository root:
--   lune run tools/wikimap.luau [--out wiki/public/img/maps] [--only meadows,world] [--check]
-- Writes <name>.svg for the world, the city, the regions and the caves and prints a table (file, bytes, elements).
-- --check writes nothing and exits 1 when a file differs. Logic: tools/WikiMaps (tests/wikimap.spec.luau).

local fs = require("@lune/fs")
local process = require("@lune/process")

if not fs.isDir("src/shared") or not fs.isDir("tools/WikiMaps") then
	print("wikimap: uruchom z katalogu repozytorium (run it from the repository root)")
	process.exit(2)
end

local WikiMap = require("./WikiMaps")

local args = process.args
local outDir = WikiMap.OUT_DIR
local only: { string }? = nil
local check = false
local i = 1
while i <= #args do
	local a = args[i]
	if a == "--out" then
		outDir = args[i + 1]
		i += 1
	elseif a == "--only" then
		only = {}
		for name in string.gmatch(args[i + 1] or "", "[^,]+") do
			table.insert(only :: { string }, name)
		end
		i += 1
	elseif a == "--check" then
		check = true
	else
		print(`wikimap: unknown argument {a}`)
		process.exit(2)
	end
	i += 1
end

local started = os.clock()
local result = WikiMap.build({
	only = only,
	readText = function(path: string): string?
		return if fs.isFile(path) then fs.readFile(path) else nil
	end,
})

if not check and not fs.isDir(outDir) then
	fs.writeDir(outDir)
end

local names = {}
for name in result.files do
	table.insert(names, name)
end
table.sort(names)

local differences = {}
local total = 0
print(string.format("%-28s %9s %9s", "file", "bytes", "elements"))
for _, name in names do
	local text = result.files[name]
	local path = `{outDir}/{name}.svg`
	if check then
		if not fs.isFile(path) or fs.readFile(path) ~= text then
			table.insert(differences, path)
		end
	else
		fs.writeFile(path, text)
	end
	local _, elements = string.gsub(text, "<%a", "")
	total += #text
	print(string.format("%-28s %9d %9d", name .. ".svg", #text, elements))
end
print(string.format("%-28s %9d   %.1f s", "total", total, os.clock() - started))
for _, w in result.warnings do
	print(`warning: {w}`)
end
if check then
	if #differences > 0 then
		print(`out of date ({#differences}): {table.concat(differences, ", ")}`)
		process.exit(1)
	end
	print("up to date")
end
