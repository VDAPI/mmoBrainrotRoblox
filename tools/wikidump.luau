--!strict
-- Wiki data exporter CLI (S34, docs/WIKI.md §5). Run from the repository root:
--   lune run tools/wikidump.luau [--out wiki/src/data] [--rolls 100000] [--only items,monsters] [--check]
-- Writes wiki/src/data/*.json, wiki/src/data/types.ts, wiki/src/styles/tokens.data.css and docs/PRZEDMIOTY.md and
-- prints a table of the files. --check writes nothing: it compares with the files on disk and exits 1 on any
-- difference. The logic lives in tools/WikiData (pure modules, tested by tests/wikidump.spec.luau).

local fs = require("@lune/fs")
local process = require("@lune/process")

if not fs.isDir("src/shared") or not fs.isDir("tools/WikiData") then
	print("wikidump: uruchom z katalogu repozytorium (run it from the repository root)")
	process.exit(2)
end

local WikiDump = require("./WikiData")

local args = process.args
local outDir = WikiDump.DATA_DIR
local rolls: number? = nil
local only: { string }? = nil
local check = false
local i = 1
while i <= #args do
	local a = args[i]
	if a == "--out" then
		outDir = args[i + 1]
		i += 1
	elseif a == "--rolls" then
		rolls = tonumber(args[i + 1])
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
		print(`wikidump: unknown argument {a}`)
		process.exit(2)
	end
	i += 1
end

-- Commit and date of the data (src/shared and the exporter): no "now", so two runs give the same bytes.
local function gitInfo(): { commit: string, date: string }
	local ok, result =
		pcall(process.exec, "git", { "log", "-1", "--format=%h|%cI", "--", "src/shared", "tools/WikiData" })
	if ok and result.ok then
		local commit, date = string.match(result.stdout, "^(%w+)|(%S+)")
		if commit and date then
			return { commit = commit, date = date }
		end
	end
	return { commit = "unknown", date = "unknown" }
end

local started = os.clock()
local result = WikiDump.build({
	rolls = rolls,
	only = only,
	exists = fs.isFile,
	themeText = if fs.isFile("src/client/UI/Theme.luau") then fs.readFile("src/client/UI/Theme.luau") else nil,
	git = gitInfo(),
})

local function target(path: string): string
	if outDir ~= WikiDump.DATA_DIR and string.sub(path, 1, #WikiDump.DATA_DIR + 1) == WikiDump.DATA_DIR .. "/" then
		return outDir .. string.sub(path, #WikiDump.DATA_DIR + 1)
	end
	return path
end

local function parentOf(path: string): string?
	return string.match(path, "^(.*)/[^/]+$")
end

local paths = {}
for path in result.files do
	table.insert(paths, path)
end
table.sort(paths)

local differences = {}
for _, path in paths do
	local file = target(path)
	local text = result.files[path]
	if check then
		local current = if fs.isFile(file) then fs.readFile(file) else nil
		if current == nil or WikiDump.comparable(file, current) ~= WikiDump.comparable(file, text) then
			table.insert(differences, file)
		end
	else
		local dir = parentOf(file)
		if dir and not fs.isDir(dir) then
			fs.writeDir(dir)
		end
		fs.writeFile(file, text)
	end
end

local total = 0
print(string.format("%-40s %10s %8s", "file", "bytes", "records"))
for _, row in result.stats do
	total += row.bytes
	print(string.format("%-40s %10d %8d", target(row.file), row.bytes, row.records))
end
print(string.format("%-40s %10d", "total", total))
print(string.format("rolls %d, %.1f s", result.data.meta.rolls, os.clock() - started))
for _, w in result.warnings do
	print(`warning: {w}`)
end
if #result.missing > 0 then
	print(`missing texts ({#result.missing}): {table.concat(result.missing, ", ")}`)
end
if check then
	if #differences > 0 then
		print(`out of date ({#differences}): {table.concat(differences, ", ")}`)
		process.exit(1)
	end
	print("up to date")
end
