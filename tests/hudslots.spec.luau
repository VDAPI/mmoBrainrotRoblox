--!strict
-- Package A review (owner 2026-11-10, "things covering each other, nothing folds"): the HUD column's Fusion graph
-- (UI/HudSlots over Logic/HudStack) with the real Fusion 0.3 of Packages (tests/FusionGraph). A panel tells the column
-- its height as the player folded it (`open`) and draws itself folded while the column folds it (`forced`): an event
-- that starts, grows, folds or opens again reaches the column at once, with no Fusion error, and the panel never
-- stands over the tracker, on a tall and a short PC screen. A box that read the column's fold fed the column back:
-- Fusion stopped that loop ("infinite loop") before the column saw the new height, so the panel stayed out of the
-- column or covered the tracker. The source check: no HudSlots.join box in src/client reads anything that comes
-- from the column (its fold, its places or a slot), directly or through the locals it reads.

local fs = require("@lune/fs")

local FusionGraph = require("./FusionGraph")
local HudStack = require("../src/shared/Logic/HudStack")
local T = require("./Test")

type Rect = HudStack.Rect

-- A client graph on a PC screen `w` x `h` with the real UI/HudSlots and the stubs it reads.
local function column(w: number, h: number)
	local graph = FusionGraph.new()
	local s = graph.scope
	local size = s:Value({ X = w, Y = h })
	graph.stubs["src/client/UI/Device"] = { Touch = s:Value(false) }
	graph.stubs["src/client/UI/NavTarget"] = { Target = s:Value(nil) }
	graph.stubs["src/client/UI/PhoneLayout"] = { Compact = s:Value(false), Others = s:Value(0) }
	graph.stubs["src/client/UI/Scale"] = {
		Value = s:Value(1),
		HudSize = size,
		get = function(): number
			return 1
		end,
	}
	graph.stubs["src/client/UI/State"] = {
		Value = function(): any
			return s:Value(nil)
		end,
	}
	local HudSlots = graph.require("src/client/UI/HudSlots")
	return graph, HudSlots
end

-- An event panel wired as the HUD's panels are: the column hears the player's fold, the drawing folds with the
-- column too (Hud/WorldEventPanel: 32 folded, 120 open, 230 once active).
local function panel(graph: any, HudSlots: any, id: string)
	local Fusion = graph.Fusion
	local s = Fusion.scoped(Fusion)
	local open = s:Value(true)
	local active = s:Value(false)
	local shown = s:Value(false)
	local forced = HudSlots.forced(s, id)
	local folded = s:Computed(function(use): boolean
		return not use(open) or use(forced)
	end)
	local function heightOf(use: any, shut: boolean): number
		if shut then
			return 32
		end
		return if use(active) then 230 else 120
	end
	local drawn = s:Computed(function(use): number
		return heightOf(use, use(folded))
	end)
	local slot = HudSlots.join(
		s,
		id,
		s:Computed(function(use): any
			return { shown = use(shown), w = 280, h = heightOf(use, not use(open)), line = 32 }
		end)
	)
	return {
		open = open,
		active = active,
		shown = shown,
		forced = forced,
		drawn = drawn,
		slot = slot,
		scope = s,
	}
end

-- The quest tracker's box as Hud/QuestTracker gives it (open: at least its header and two lines).
local function tracker(graph: any, HudSlots: any)
	local s = graph.Fusion.scoped(graph.Fusion)
	return HudSlots.join(s, "questTracker", { shown = true, w = 300, h = HudStack.TRACKER_MIN, line = 42 })
end

local function overlap(a: Rect, b: Rect): boolean
	return a.left < b.right and b.left < a.right and a.top < b.bottom and b.top < a.bottom
end

-- The panel stands in the column with its drawn height, clear of the tracker, and Fusion reported nothing.
local function settled(graph: any, p: any, trackerSlot: any, step: string)
	local peek = graph.Fusion.peek
	T.expect(`{step}: {table.concat(graph.errors, " | ")}`).toBe(`{step}: `)
	local at: Rect? = peek(p.slot)
	assert(at, `{step}: the panel has no place in the column`)
	T.expect(at.bottom - at.top).toBe(peek(p.drawn))
	local below: Rect? = peek(trackerSlot)
	assert(below, `{step}: the tracker has no place in the column`)
	if overlap(at, below) then
		error(`{step}: the panel ({at.top}..{at.bottom}) covers the tracker ({below.top}..{below.bottom})`)
	end
end

T.describe("HUD column graph (package A review)", function()
	T.it("an event that starts, grows, folds and opens again moves the column at once (1920x1000)", function()
		local graph, HudSlots = column(1920, 1000)
		local trackerSlot = tracker(graph, HudSlots)
		local p = panel(graph, HudSlots, "worldEvent")
		local peek = graph.Fusion.peek
		p.shown:set(true)
		settled(graph, p, trackerSlot, "start")
		T.expect(peek(p.drawn)).toBe(120)
		p.active:set(true)
		settled(graph, p, trackerSlot, "active")
		T.expect(peek(p.drawn)).toBe(230)
		p.open:set(false)
		settled(graph, p, trackerSlot, "folded by the player")
		T.expect(peek(p.drawn)).toBe(32)
		p.open:set(true)
		settled(graph, p, trackerSlot, "open again")
		T.expect(peek(p.drawn)).toBe(230)
		T.expect(peek(p.forced)).toBe(false)
	end)

	T.it(
		"on a short screen the column folds the panel to its line, and a pick from the list keeps it (1920x760)",
		function()
			local graph, HudSlots = column(1920, 760)
			local trackerSlot = tracker(graph, HudSlots)
			local p = panel(graph, HudSlots, "worldEvent")
			local peek = graph.Fusion.peek
			p.shown:set(true)
			settled(graph, p, trackerSlot, "start")
			p.active:set(true)
			settled(graph, p, trackerSlot, "active")
			-- no room for 230 over the tracker: the column folds the panel to its header line, the player's fold stays
			T.expect(peek(p.forced)).toBe(true)
			T.expect(peek(p.drawn)).toBe(32)
			T.expect(peek(p.open)).toBe(true)
			p.open:set(false)
			settled(graph, p, trackerSlot, "folded by the player")
			p.open:set(true)
			settled(graph, p, trackerSlot, "open again")
			T.expect(peek(p.drawn)).toBe(32)
			-- the player picks the panel ('+N' list or a click on its line): the tracker gives way first
			HudSlots.bring("worldEvent")
			T.expect(table.concat(graph.errors, " | ")).toBe("")
			local at = peek(p.slot)
			T.expect(at ~= nil).toBe(true)
			T.expect(peek(p.drawn)).toBe(if peek(p.forced) then 32 else 230)
		end
	)

	T.it("an element that leaves the column gives its place back (cleanup)", function()
		local graph, HudSlots = column(1920, 1000)
		local trackerSlot = tracker(graph, HudSlots)
		local p = panel(graph, HudSlots, "worldEvent")
		local peek = graph.Fusion.peek
		p.shown:set(true)
		local with: Rect = assert(peek(trackerSlot))
		graph.Fusion.doCleanup(p.scope)
		local without: Rect = assert(peek(trackerSlot))
		T.expect(without.top < with.top).toBe(true)
		T.expect(table.concat(graph.errors, " | ")).toBe("")
	end)
end)

-- Source check -----------------------------------------------------------------------------------------------------

-- What reads the column: its fold, its places, its chip, a slot (HudSlots.join and what follows a slot).
local COLUMN = {
	"HudSlots.forced",
	"HudSlots.Arranged",
	"HudSlots.Places",
	"HudSlots.Hidden",
	"HudSlots.Chip",
	"HudSlots.join",
	"HudSlots.position",
	"HudSlots.visible",
}

local function files(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			files(path, out)
		elseif string.match(name, "%.luau$") then
			table.insert(out, path)
		end
	end
end

-- The source without comments (a "--" at a line's start or after a blank).
local function code(source: string): string
	local lines = {}
	for line in string.gmatch(source .. "\n", "(.-)\n") do
		local cut = string.find(line, "^%s*%-%-") or string.find(line, "%s%-%-")
		table.insert(lines, if cut then string.sub(line, 1, cut - 1) else line)
	end
	return table.concat(lines, "\n")
end

-- The text from the "(" at `open` to its ")" (strings skipped).
local function call(text: string, open: number): string
	local depth, i = 0, open
	while i <= #text do
		local c = string.sub(text, i, i)
		if c == '"' or c == "'" or c == "`" then
			local close = string.find(text, c, i + 1, true)
			i = close or #text
		elseif c == "(" then
			depth += 1
		elseif c == ")" then
			depth -= 1
			if depth == 0 then
				return string.sub(text, open, i)
			end
		end
		i += 1
	end
	return string.sub(text, open)
end

-- The locals `text` reads through Fusion (use(name)) and the local functions it calls with `use`.
local function reads(text: string): { string }
	local out = {}
	for name in string.gmatch(text, "[^%w_%.:]use%(%s*([%a_][%w_]*)%s*%)") do
		table.insert(out, name)
	end
	for before, name in string.gmatch(text, "(.)([%a_][%w_]*)%(%s*use[%s,%)]") do
		if before ~= "." and before ~= ":" and name ~= "use" then
			table.insert(out, name)
		end
	end
	return out
end

-- Every definition of local `name` in `lines`: "local name = ...", "local function name(...)" or "name = ..." with
-- the deeper lines under it and its closing line.
local function definitions(lines: { string }, name: string): { string }
	local out = {}
	for i, line in lines do
		local indent = string.match(line, `^(%s*)local {name}%s*=`)
			or string.match(line, `^(%s*)local function {name}%(`)
			or string.match(line, `^(%s*){name}%s*=%s*function`)
		if indent then
			local body = { line }
			local j = i + 1
			while j <= #lines do
				local next = lines[j]
				if string.match(next, "^%s*$") or #(string.match(next, "^(%s*)") :: string) > #indent then
					table.insert(body, next)
				else
					if string.match(next, "^%s*[%)%}]") or string.match(next, "^%s*end") then
						table.insert(body, next)
					end
					break
				end
				j += 1
			end
			table.insert(out, table.concat(body, "\n"))
		end
	end
	return out
end

-- The chain from a join box to the column, or nil.
local function reachesColumn(lines: { string }, text: string, seen: { [string]: boolean }, via: string): string?
	for _, token in COLUMN do
		if string.find(text, token, 1, true) then
			return `{via} -> {token}`
		end
	end
	for _, name in reads(text) do
		if not seen[name] then
			seen[name] = true
			for _, def in definitions(lines, name) do
				local chain = reachesColumn(lines, def, seen, `{via} -> {name}`)
				if chain then
					return chain
				end
			end
		end
	end
	return nil
end

T.describe("HUD column boxes (package A review)", function()
	T.it("no HudSlots.join box in src/client reads the column", function()
		local all = {}
		files("src/client", all)
		local joins, bad = 0, {}
		for _, path in all do
			local text = code(fs.readFile(path))
			local lines = string.split(text, "\n")
			local from = 1
			while true do
				local at, stop = string.find(text, "HudSlots.join(", from, true)
				if not at or not stop then
					break
				end
				if path ~= "src/client/UI/HudSlots.luau" then
					joins += 1
					local args = call(text, stop)
					local chain = reachesColumn(lines, args, {}, "box")
					if chain then
						table.insert(bad, `{path}: {chain}`)
					end
				end
				from = stop + 1
			end
		end
		-- the tracker, five event panels, the arena's pill, team list and phone panels, the guide line, the party
		T.expect(joins >= 10).toBe(true)
		T.expect(table.concat(bad, "\n")).toBe("")
	end)

	T.it("the check sees a box built from the column's fold", function()
		local source = table.concat({
			'local forced = HudSlots.forced(scope, "worldEvent")',
			"local folded = scope:Computed(function(use): boolean",
			"\treturn not use(open) or use(forced)",
			"end)",
			"local height = scope:Computed(function(use): number",
			"\treturn if use(folded) then 32 else 120",
			"end)",
			'local slot = HudSlots.join(scope, "worldEvent", scope:Computed(function(use)',
			"\treturn { shown = true, w = 280, h = use(height), line = 32 }",
			"end))",
		}, "\n")
		local lines = string.split(source, "\n")
		local _, stop = string.find(source, "HudSlots.join(", 1, true)
		local chain = reachesColumn(lines, call(source, assert(stop, "the sample joins")), {}, "box")
		T.expect(chain).toBe("box -> height -> folded -> forced -> HudSlots.forced")
	end)
end)
