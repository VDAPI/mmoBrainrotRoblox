--!strict
-- Package A review (owner 2026-11-10): a call of a localized text passes every placeholder of its key. Locale keeps a
-- placeholder no argument fills as it is, so a call that passes other names puts "{range}" on the screen. Package A
-- gave area.label one level band ("{name} · {range}", one HUD line for the minimap's caption) and its one-line hook
-- in Hud/AreaBanner (package B) passes `range`; a banner that still passed `min` and `max` (package B's own version
-- of the file, the natural pick in a merge) read "Polana Królików · {range}". The check: every Text.get, Text.now,
-- Text.T and Locale.T call in src with a literal key and a literal argument table names each placeholder of the key's
-- pl and en text, so such a merge fails here instead of on the screen. Final UI review 2026-11-10: the arena's queue
-- texts pass the mode's name, never its id.

local fs = require("@lune/fs")

local Arena = require("../src/shared/Data/Arena")
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

	T.it("the arena's queue texts name the mode, never its id (final UI review 2026-11-10)", function()
		-- known item 2: the pill read '⌛ 1v1 · 0:42', its tooltip 'Kolejka 1v1: czeka 3' and the join toast 'Czekasz w
		-- kolejce 1v1.', where the arena window says '1 na 1'
		local panel = fs.readFile("src/client/UI/Screens/Hud/ArenaPanel.luau")
		T.expect(string.find(panel, "mode = q.mode", 1, true)).toBeNil()
		local _, named = string.gsub(panel, "mode = modeName%(use, q%.mode%)", "")
		T.expect(named).toBe(3)
		T.expect(string.find(panel, "return Text.get(use, `arena.mode.{id}`)", 1, true) ~= nil).toBe(true)
		-- the server's toast sends the name's key ('@', UI/NotificationController's escapeArgs)
		local service = fs.readFile("src/server/Services/ArenaService.luau")
		T.expect(string.find(service, '"arena.joined", { mode = "@arena.mode." .. modeId }', 1, true) ~= nil).toBe(true)
		T.expect(string.find(service, "{ mode = modeId }", 1, true)).toBeNil()
		for _, id in { "1v1", "3v3" } do
			T.expect(Arena.mode(id) ~= nil).toBe(true)
			for _, lang in LANGS do
				T.expect({ lang.name, id, type(lang.texts[`arena.mode.{id}`]) }).toEqual({ lang.name, id, "string" })
			end
		end
	end)

	T.it("the HUD's decimals take the language's mark: '2,5' in Polish (final UI review 2026-11-10)", function()
		-- the cooldowns, the effect timers, the EXP hover, the world boss's share and the reward card read '2.5' where
		-- the windows say '2,5' (format.decimal, S31/S33); seams 2026-11-11: so did the fight card's 'udział 12.5%'
		-- (FightView.placeLine rounds with math.floor, no string.format for the walk below to find)
		T.expect({ pl = pl["format.decimal"], en = en["format.decimal"] }).toEqual({ pl = ",", en = "." })
		local sites = {
			["src/client/UI/Screens/Hud/SkillBar.luau"] = 1,
			["src/client/UI/Screens/Hud/EffectIcons.luau"] = 1,
			["src/client/UI/Screens/Hud/init.luau"] = 1,
			["src/client/UI/Screens/Hud/WorldBossPanel.luau"] = 1,
			["src/client/UI/Screens/BossReward.luau"] = 1,
			["src/client/UI/FightView.luau"] = 1,
		}
		for path, least in sites do
			local _, marks = string.gsub(fs.readFile(path), '"format%.decimal"', "")
			T.expect({ path, marks >= least }).toEqual({ path, true })
		end
		-- every HUD file that writes a decimal with string.format reads the mark too
		local function walk(dir: string)
			for _, name in fs.readDir(dir) do
				local path = `{dir}/{name}`
				if fs.isDir(path) then
					walk(path)
				elseif string.sub(name, -5) == ".luau" then
					local source = code(fs.readFile(path))
					local raw = fs.readFile(path)
					if string.find(raw, '"%%%.%d+f"') and string.find(source, "string.format", 1, true) then
						T.expect({ path, string.find(raw, '"format.decimal"', 1, true) ~= nil }).toEqual({ path, true })
					end
				end
			end
		end
		walk("src/client/UI/Screens/Hud")
	end)

	T.it(
		"the windows' decimals take the language's mark too: '2,5 s', 'K/D 1,50' (final UI review 2026-11-11)",
		function()
			-- the boss's channel bar read 'Przerwijcie zaklęcie · 2.5 s', the smith's Ulepsz preview 'Szansa na krytyk:
			-- 2.5%' and a profile 'K/D 1.50' where the item tooltip says '2,5%' (the derived list: charactersections.spec)
			local sites = {
				["src/client/UI/Components/ChannelBar.luau"] = 1,
				["src/client/UI/Screens/BlacksmithWindow/Upgrade.luau"] = 1,
				["src/client/UI/Screens/ProfileWindow.luau"] = 1,
				["src/client/UI/Screens/CharacterWindow/DerivedList.luau"] = 2,
			}
			for path, least in sites do
				local _, marks = string.gsub(fs.readFile(path), '"format%.decimal"', "")
				T.expect({ path, marks >= least }).toEqual({ path, true })
			end
			-- every window and component that writes a decimal with string.format reads the mark too; not the developer's
			-- window (its numbers are for the team) or the map preview's timing (a console line)
			local skip = {
				["src/client/UI/Screens/Hud"] = true, -- the HUD's own test above
				["src/client/UI/Components/Prompt"] = true, -- the HUD lane's prompts
				["src/client/UI/Screens/DevWindow"] = true,
				["src/client/UI/Screens/WorldMap/Preview.luau"] = true,
			}
			local checked = 0
			local function walk(dir: string)
				for _, name in fs.readDir(dir) do
					local path = `{dir}/{name}`
					if skip[path] then
						continue
					elseif fs.isDir(path) then
						walk(path)
					elseif string.sub(name, -5) == ".luau" then
						local raw = fs.readFile(path)
						if string.find(raw, '"%%%.%d+f"') and string.find(code(raw), "string.format", 1, true) then
							checked += 1
							T.expect({ path, string.find(raw, '"format.decimal"', 1, true) ~= nil })
								.toEqual({ path, true })
						end
					end
				end
			end
			walk("src/client/UI/Screens")
			walk("src/client/UI/Components")
			T.expect(checked >= 3).toBe(true)
		end
	)
end)
