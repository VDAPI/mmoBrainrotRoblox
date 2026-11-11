--!strict
-- Package A review (owner 2026-11-10): a call of a localized text passes every placeholder of its key. Locale keeps a
-- placeholder no argument fills as it is, so a call that passes other names puts "{range}" on the screen. Package A
-- gave area.label one level band ("{name} · {range}", one HUD line for the minimap's caption) and its one-line hook
-- in Hud/AreaBanner (package B) passes `range`; a banner that still passed `min` and `max` (package B's own version
-- of the file, the natural pick in a merge) read "Polana Królików · {range}". The check: every Text.get, Text.now,
-- Text.T and Locale.T call in src with a literal key and a literal argument table names each placeholder of the key's
-- pl and en text, so such a merge fails here instead of on the screen.

local fs = require("@lune/fs")

local T = require("./Test")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local LANGS: { { name: string, texts: { [string]: string } } } = {
	{ name = "pl", texts = pl :: any },
	{ name = "en", texts = en :: any },
}

-- The source with its comments and the insides of its strings blanked (the same length, so positions stay), quotes
-- and newlines kept: braces and "=" in a string or a comment are not code.
local function code(src: string): string
	local out = table.create(#src)
	local i = 1
	while i <= #src do
		local c = string.sub(src, i, i)
		if c == "-" and string.sub(src, i + 1, i + 1) == "-" then
			-- a comment to the end of its line
			while i <= #src and string.sub(src, i, i) ~= "\n" do
				table.insert(out, " ")
				i += 1
			end
		elseif c == '"' or c == "'" or c == "`" then
			table.insert(out, c)
			i += 1
			while i <= #src and string.sub(src, i, i) ~= c and string.sub(src, i, i) ~= "\n" do
				if string.sub(src, i, i) == "\\" then
					table.insert(out, " ")
					i += 1
				end
				table.insert(out, " ")
				i += 1
			end
			if i <= #src then
				table.insert(out, string.sub(src, i, i))
				i += 1
			end
		else
			table.insert(out, c)
			i += 1
		end
	end
	return table.concat(out)
end

-- The end of the balanced table that opens at `at` in blanked code.
local function tableEnd(blank: string, at: number): number?
	local depth = 0
	for i = at, #blank do
		local c = string.sub(blank, i, i)
		if c == "{" then
			depth += 1
		elseif c == "}" then
			depth -= 1
			if depth == 0 then
				return i
			end
		end
	end
	return nil
end

-- The names a table literal gives at its top level: `name =` and `["name"] =`.
local function fieldsOf(src: string, blank: string, from: number, to: number): { [string]: boolean }
	local names: { [string]: boolean } = {}
	local depth = 0
	local top = table.create(to - from + 1)
	for i = from + 1, to - 1 do
		local c = string.sub(blank, i, i)
		if depth == 0 and c == "[" then
			-- a bracketed key, read from the source: ["until"] = ...
			local close = string.find(blank, "]", i, true)
			local name = if close then string.match(string.sub(src, i, close), '^%[%s*"([%w_]+)"%s*%]$') else nil
			if name and close and string.match(blank, "^%s*=[^=]", close + 1) then
				names[name] = true
			end
		end
		if c == "{" or c == "(" or c == "[" then
			depth += 1
		elseif c == "}" or c == ")" or c == "]" then
			depth -= 1
		end
		table.insert(top, if depth == 0 and c ~= "}" and c ~= ")" and c ~= "]" then c else " ")
	end
	for name in string.gmatch(table.concat(top), "([%a_][%w_]*)%s*=[^=]") do
		names[name] = true
	end
	return names
end

export type Problem = { path: string, line: number, key: string, lang: string, missing: string }

-- The calls of `source` with a literal key and a literal table: each key read and each placeholder its table misses.
local function check(path: string, source: string): ({ string }, { Problem })
	local blank = code(source)
	local keys: { string } = {}
	local problems: { Problem } = {}
	for atPos, openPos in string.gmatch(blank, '()"[^"\n]*"%s*,%s*(){') do
		-- position captures: numbers
		local at, open = (atPos :: any) :: number, (openPos :: any) :: number
		local before = string.sub(blank, math.max(1, at - 48), at - 1)
		local call = string.find(before, "Text%.[%a]+%(%s*[%w_]*%s*,?%s*$") ~= nil
			or string.find(before, "Locale%.T%(%s*$") ~= nil
		local _, keyEnd = string.find(source, '^"[%w_%.]+"', at)
		local stop = tableEnd(blank, open)
		if call and keyEnd and stop then
			local key = string.sub(source, at + 1, keyEnd - 1)
			if pl[key] ~= nil then
				table.insert(keys, key)
				local names = fieldsOf(source, blank, open, stop)
				for _, lang in LANGS do
					for name in string.gmatch(lang.texts[key] or "", "{([%w_]+)}") do
						if not names[name] then
							local _, lines = string.gsub(string.sub(source, 1, at), "\n", "")
							table.insert(
								problems,
								{ path = path, line = lines + 1, key = key, lang = lang.name, missing = name }
							)
						end
					end
				end
			end
		end
	end
	return keys, problems
end

local function files(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			files(path, out)
		elseif string.match(name, "%.luau$") and not string.find(path, "Data/Localization/", 1, true) then
			table.insert(out, path)
		end
	end
end

T.describe("Localized text calls (package A review, owner 2026-11-10)", function()
	T.it("every call with a literal key and a literal table passes each placeholder of the key", function()
		local all: { string } = {}
		files("src", all)
		local calls = 0
		local seen: { [string]: boolean } = {}
		local report: { string } = {}
		for _, path in all do
			local keys, problems = check(path, fs.readFile(path))
			calls += #keys
			for _, key in keys do
				seen[`{path} {key}`] = true
			end
			for _, p in problems do
				table.insert(report, `{p.path}:{p.line} {p.key} ({p.lang}) has no '{p.missing}'`)
			end
		end
		T.expect(table.concat(report, "\n")).toBe("")
		-- the scan reads the calls: hundreds of them, the area banner's and the minimap's among them
		T.expect(calls > 500).toBe(true)
		T.expect(seen["src/client/UI/Screens/Hud/AreaBanner.luau area.label"]).toBe(true)
		T.expect(seen["src/client/UI/Screens/Hud/Minimap.luau area.label"]).toBe(true)
	end)

	T.it("the check sees a call that passes other names (an area banner with min and max)", function()
		local sample = table.concat({
			"-- the banner's line (it's one line)",
			'local line = Text.now("area.label", { name = Text.now(area.nameKey), min = area.lv[1], max = area.lv[2] })',
			'local ok = Text.get(use, "mail.title", { title = name, ["until"] = "{x}" })',
		}, "\n")
		local keys, problems = check("sample", sample)
		T.expect(keys).toEqual({ "area.label", "mail.title" })
		local missing = {}
		for _, p in problems do
			table.insert(missing, `{p.line} {p.key} {p.lang} {p.missing}`)
		end
		T.expect(missing).toEqual({ "2 area.label pl range", "2 area.label en range" })
	end)
end)
