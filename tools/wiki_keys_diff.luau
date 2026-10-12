--!strict
-- Wiki key guard (S83, balance plan 2.3): `lune run tools/wiki_keys_diff.luau [--dir <data dir>]` compares the KEY
-- SETS of every wiki/src/data/*.json in the working tree (or `--dir`) with the same file at git HEAD. Values do not
-- matter: a balance session changes numbers, never the shape of what the wiki shows. Keys follow the exporter schema
-- (tools/WikiData Schema.files): record fields by name (optional ones: the union over all records), map -> `*`,
-- array -> `[]`, a "data" field -> its JSON keys literally, except the paths in DATA_WILDCARDS (object keys -> `*`).
-- types.ts is compared as text (a change = a schema change). Prints `+ file: path` / `- file: path` and exits 1 on
-- any difference.
--
-- A deliberate shape change (a wiki session, or a new field the owner decided to show) passes with
--   WIKI_KEYS_ALLOW="items:items[].newField,skills:skills[].x.y,types.ts"
-- (comma separated `file:path` entries; `types.ts` alone allows the types file; `file:*` allows a whole file).
-- No git, or no wiki/src/data at HEAD: prints why and exits 0.

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local WikiDump = require("./WikiData")
local Schema = require("./WikiData/Schema")

-- "data" fields whose object keys are ids or level thresholds (icons.json: icon ids, tier thresholds).
local DATA_WILDCARDS: { [string]: boolean } = {
	["icons.icons.*"] = true,
	["icons.tierTint.*"] = true,
}

local args = process.args
local dir = WikiDump.DATA_DIR
for i, a in args do
	if a == "--dir" and args[i + 1] then
		dir = args[i + 1]
	end
end

local function git(argv: { string }): string?
	local ok, result = pcall(process.exec, "git", argv)
	if ok and result.ok then
		return result.stdout
	end
	return nil
end

local headList = git({ "ls-tree", "--name-only", "HEAD", `{WikiDump.DATA_DIR}/` })
if not headList then
	print("wiki_keys_diff: no git or no HEAD, skipped")
	process.exit(0)
end
local headFiles: { [string]: boolean } = {}
for line in string.gmatch(headList :: string, "[^\r\n]+") do
	local name = string.match(line, "([^/]+)$")
	if name then
		headFiles[name] = true
	end
end
if next(headFiles) == nil then
	print(`wiki_keys_diff: no {WikiDump.DATA_DIR} at HEAD, skipped`)
	process.exit(0)
end
if not fs.isDir(dir) then
	print(`wiki_keys_diff: no directory {dir}`)
	process.exit(1)
end

local allow: { [string]: boolean } = {}
for entry in string.gmatch(process.env.WIKI_KEYS_ALLOW or "", "[^,]+") do
	allow[(string.gsub(entry, "^%s+", ""))] = true
end
local function allowed(file: string, path: string): boolean
	return allow[`{file}:{path}`] == true or allow[`{file}:*`] == true
end

local function isArray(v: { [any]: any }): boolean
	local n = #v
	if n == 0 then
		return false
	end
	local count = 0
	for _ in v do
		count += 1
	end
	return count == n
end

-- Key paths of a JSON value `v` of schema type `t` under `path`.
local function collect(v: any, t: any, path: string, out: { [string]: boolean })
	if type(v) ~= "table" then
		return
	end
	if t == "data" or t == nil then
		local wildcard = DATA_WILDCARDS[`{path}.*`] == true
		if isArray(v) then
			for _, item in v do
				out[`{path}[]`] = true
				collect(item, "data", `{path}[]`, out)
			end
		else
			for k, item in v do
				local p = if wildcard then `{path}.*` else `{path}.{k}`
				out[p] = true
				collect(item, "data", p, out)
			end
		end
		return
	end
	if type(t) ~= "table" then
		return -- a scalar type holding a table: the exporter's validation reports it
	end
	if t.kind == "array" then
		for _, item in v do
			out[`{path}[]`] = true
			collect(item, t.of, `{path}[]`, out)
		end
	elseif t.kind == "map" then
		for _, item in v do
			out[`{path}.*`] = true
			collect(item, t.of, `{path}.*`, out)
		end
	elseif t.kind == "record" then
		local fields: { [string]: any } = {}
		for _, field in Schema.fields(t) do
			fields[field.name] = field.t
		end
		for k, item in v do
			local p = `{path}.{k}`
			out[p] = true
			collect(item, fields[k], p, out)
		end
	end
end

local function keysOf(file: string, text: string): { [string]: boolean }
	local out: { [string]: boolean } = {}
	local ok, value = pcall(serde.decode, "json", text)
	if not ok then
		out["<invalid JSON>"] = true
		return out
	end
	local root = Schema.files[file]
	if root then
		collect(value, root, file, out)
	elseif type(value) == "table" then
		for k in value do
			out[`{file}.{k}`] = true
		end
	end
	return out
end

local lines: { string } = {}
local blocking = 0
local function report(sign: string, file: string, path: string)
	local ok = allowed(file, path)
	table.insert(lines, `{sign} {file}: {path}{if ok then "  (WIKI_KEYS_ALLOW)" else ""}`)
	if not ok then
		blocking += 1
	end
end

local workFiles: { [string]: boolean } = {}
for _, name in fs.readDir(dir) do
	if string.match(name, "%.json$") or name == "types.ts" then
		workFiles[name] = true
	end
end

local names: { string } = {}
for name in workFiles do
	table.insert(names, name)
end
for name in headFiles do
	if not workFiles[name] and (string.match(name, "%.json$") or name == "types.ts") then
		table.insert(names, name)
	end
end
table.sort(names)

for _, name in names do
	local file = string.gsub(name, "%.json$", "")
	local headText = if headFiles[name] then git({ "show", `HEAD:{WikiDump.DATA_DIR}/{name}` }) else nil
	local workText = if workFiles[name] then fs.readFile(`{dir}/{name}`) else nil
	if name == "types.ts" then
		local norm = function(s: string?): string?
			return if s then (string.gsub(s, "\r\n", "\n")) else nil
		end
		if norm(headText) ~= norm(workText) then
			local ok = allow["types.ts"] == true
			table.insert(lines, `~ types.ts: changed (schema){if ok then "  (WIKI_KEYS_ALLOW)" else ""}`)
			if not ok then
				blocking += 1
			end
		end
	elseif headText == nil then
		report("+", file, "(new file)")
	elseif workText == nil then
		report("-", file, "(file removed)")
	else
		local before, now = keysOf(file, headText :: string), keysOf(file, workText :: string)
		local added, removed = {}, {}
		for k in now do
			if not before[k] then
				table.insert(added, k)
			end
		end
		for k in before do
			if not now[k] then
				table.insert(removed, k)
			end
		end
		table.sort(added)
		table.sort(removed)
		for _, k in added do
			report("+", file, k)
		end
		for _, k in removed do
			report("-", file, k)
		end
	end
end

for _, line in lines do
	print(line)
end
if blocking > 0 then
	print(`wiki_keys_diff: {blocking} key difference(s) against HEAD in {dir} (deliberate? WIKI_KEYS_ALLOW, header)`)
	process.exit(1)
end
print(`wiki_keys_diff: 0 differences ({#names} files, {#lines} allowed)`)
