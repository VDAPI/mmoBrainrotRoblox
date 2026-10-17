--!strict
-- S135 "Parchment and iron": the window checklist (Data/UiWindows) and the token rules.
--   G1 every literal window id registered with WindowManager.Register has an entry, every entry's files exist
--   G2 files of windows with `paper = true`: no legacy Theme.Colors, no colour literals, no text-size literals, no
--      Color3.fromHex of any argument (a game-data colour goes through Theme.readable)
--   G3 every component (UI/Components): no colour literals
--   G4 the windows still on the legacy look are exactly PENDING_S136 (S136 empties the list)
-- A line is checked without its `--` comment. ALLOWED excuses a line of a file containing a plain substring, each with
-- the reason; nothing that is interface colour or text belongs there.

local fs = require("@lune/fs")

local T = require("./Test")
local UiWindows = require("../src/shared/Data/UiWindows")

local describe, it, expect = T.describe, T.it, T.expect

local CLIENT = "src/client/"

-- G4: windows S136 moves to parchment.
local PENDING_S136 = {
	"alchemy",
	"arena",
	"areapicker",
	"auction",
	"backpacks",
	"blacksmith",
	"bloodmoon",
	"deposit",
	"dev",
	"dungeon",
	"fightlog",
	"friends",
	"guild",
	"guildfound",
	"huntshop",
	"login",
	"look",
	"lootlog",
	"map",
	"mounts",
	"premium",
	"questboard",
	"rankings",
	"stonepicker",
	"unbind",
	"vip",
	"wardrobe",
}

type Allowed = { pattern: string, why: string }

-- Paths relative to src/client.
local ALLOWED: { [string]: { Allowed } } = {
	["UI/Components/LookPreview.luau"] = {
		{
			pattern = "Ambient = Color3.fromRGB",
			why = "3D viewport lighting of the look preview, not interface colour",
		},
		{ pattern = "LightColor = Color3.fromRGB", why = "3D viewport lighting of the look preview" },
	},
	["UI/Screens/SkillsWindow/Preview.luau"] = {
		{ pattern = "Color3.fromRGB", why = "3D preview: dummy body, ground and light colours" },
		{ pattern = "Color3.new(", why = "3D preview: dummy body, ground and light colours" },
		{ pattern = 'Color3.fromHex("#', why = "3D preview: dummy body, ground and light colours" },
	},
}

local COLOUR_PATTERNS = {
	'Color3%.fromHex%(%s*"#',
	"Color3%.fromRGB%(",
	"Color3%.new%(%s*[%d%.]",
	'"#%x%x%x%x%x%x"',
}
local PAPER_PATTERNS = {
	"Theme%.Colors%.",
	"Color3%.fromHex%(",
	"TextSize%s*=%s*%d",
	"[%a]ize%s+or%s+%d",
	'size="%d',
}

local function filesUnder(path: string): { string }
	local full = CLIENT .. path
	if fs.isFile(full) then
		return { path }
	end
	local out = {}
	if fs.isDir(full) then
		for _, name in fs.readDir(full) do
			for _, file in filesUnder(`{path}/{name}`) do
				table.insert(out, file)
			end
		end
	end
	table.sort(out)
	return out
end

local function code(line: string): string
	local at = string.find(line, "--", 1, true)
	return if at then string.sub(line, 1, at - 1) else line
end

local function excused(file: string, line: string): boolean
	for _, allowed in ALLOWED[file] or {} do
		if string.find(line, allowed.pattern, 1, true) then
			return true
		end
	end
	return false
end

-- "file:line: text" for every line of `file` matching one of `patterns`.
local function offences(file: string, patterns: { string }): { string }
	local out = {}
	if string.sub(file, -5) ~= ".luau" then
		return out
	end
	local n = 0
	for line in string.gmatch(fs.readFile(CLIENT .. file) .. "\n", "([^\n]*)\n") do
		n += 1
		local body = code(line)
		for _, pattern in patterns do
			if string.find(body, pattern) and not excused(file, line) then
				table.insert(out, `{file}:{n}: {string.gsub(line, "^%s+", "")}`)
				break
			end
		end
	end
	return out
end

local function concat(a: { string }, b: { string }): { string }
	local out = table.clone(a)
	table.move(b, 1, #b, #out + 1, out)
	return out
end

describe("Window checklist (S135 G1)", function()
	it("every registered window has an entry in Data/UiWindows", function()
		local missing = {}
		local found = 0
		for _, name in fs.readDir(CLIENT .. "Controllers") do
			local text = fs.readFile(`{CLIENT}Controllers/{name}`)
			for block in string.gmatch(text, "WindowManager%.Register%(%{(.-)\n%s*build") do
				local id = string.match(block, 'id = "([%w_]+)"')
				if id then
					found += 1
					if not UiWindows.list[id] then
						table.insert(missing, id)
					end
				end
			end
		end
		expect(found >= 40).toBe(true)
		expect(table.concat(missing, ", ")).toBe("")
	end)

	it("every entry names existing files", function()
		local missing = {}
		for id, entry in UiWindows.list do
			expect(#entry.files > 0).toBe(true)
			for _, path in entry.files do
				if #filesUnder(path) == 0 then
					table.insert(missing, `{id}: {path}`)
				end
			end
			expect(entry.session == "S135" or entry.session == "S136").toBe(true)
		end
		expect(table.concat(missing, ", ")).toBe("")
	end)
end)

describe("Parchment windows use tokens only (S135 G2)", function()
	it("no Theme.Colors, colour or text-size literals in their files", function()
		local bad: { string } = {}
		local seen: { [string]: boolean } = {}
		for _, entry in UiWindows.list do
			if not entry.paper then
				continue
			end
			for _, path in entry.files do
				for _, file in filesUnder(path) do
					if not seen[file] then
						seen[file] = true
						bad = concat(bad, offences(file, concat(COLOUR_PATTERNS, PAPER_PATTERNS)))
					end
				end
			end
		end
		expect(table.concat(bad, "\n")).toBe("")
	end)

	it("every ALLOWED entry has a reason", function()
		for _, list in ALLOWED do
			for _, allowed in list do
				expect(#allowed.why > 10).toBe(true)
			end
		end
	end)
end)

describe("Components without colour literals (S135 G3)", function()
	it("UI/Components", function()
		local bad: { string } = {}
		for _, file in filesUnder("UI/Components") do
			bad = concat(bad, offences(file, COLOUR_PATTERNS))
		end
		expect(table.concat(bad, "\n")).toBe("")
	end)
end)

describe("Windows waiting for S136 (S135 G4)", function()
	it("the legacy windows are exactly PENDING_S136", function()
		local legacy = {}
		for id, entry in UiWindows.list do
			if not entry.paper then
				table.insert(legacy, id)
			end
			expect(entry.paper == (entry.session == "S135")).toBe(true)
		end
		table.sort(legacy)
		local pending = table.clone(PENDING_S136)
		table.sort(pending)
		expect(table.concat(legacy, " ")).toBe(table.concat(pending, " "))
	end)
end)
