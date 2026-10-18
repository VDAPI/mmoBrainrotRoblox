--!strict
-- S135/S136 "Parchment and iron": the window and screen checklist (Data/UiWindows) and the strict token rules.
--   G1 every literal window id registered with WindowManager.Register has an entry, every entry's files exist, the
--      surface is "paper" or "iron" (an iron window says why)
--   G2 every file of UI/Screens, UI/Components and UI/*.luau (but UI/Theme and the map drawing UI/MapSketch): no
--      colour literal, no text-size literal, no Color3.fromHex of any argument (a game-data colour goes through
--      Theme.readable as text, Theme.tint as a graphic)
--   G3 no legacy Theme.Colors anywhere in src/client (S136 removed it), Window has no `Paper` mode any more
--   G4 every file of UI/Screens belongs to a window or to UiWindows.SCREENS
-- A line is checked without its `--` comment. ALLOWED excuses a line of a file containing a plain substring, each with
-- the reason (one entry per exception); nothing that is interface colour or text belongs there.

local fs = require("@lune/fs")

local T = require("./Test")
local UiWindows = require("../src/shared/Data/UiWindows")

local describe, it, expect = T.describe, T.it, T.expect

local CLIENT = "src/client/"

-- G2: files outside the rules: the palette itself and the world-map drawing (terrain, biomes, roads: graphics).
local EXEMPT: { [string]: string } = {
	["UI/Theme.luau"] = "builds the Color3 roles from Data/UiPalette",
	["UI/MapSketch.luau"] = "the world-map drawing (biome, road and water colours are graphics, not interface)",
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
	["UI/Screens/MountWindow.luau"] = {
		{ pattern = "Ambient = Color3.fromRGB", why = "3D viewport lighting of the mount preview" },
		{ pattern = "LightColor = Color3.fromRGB", why = "3D viewport lighting of the mount preview" },
	},
	["UI/Screens/Wardrobe.luau"] = {
		{ pattern = "Ambient = Color3.fromRGB", why = "3D viewport lighting of the wardrobe preview" },
		{ pattern = "LightColor = Color3.fromRGB", why = "3D viewport lighting of the wardrobe preview" },
	},
	["UI/Screens/WorldMap/Preview.luau"] = {
		{ pattern = "Ambient = Color3.fromRGB", why = "3D viewport lighting of the creature preview on a map card" },
		{ pattern = "LightColor = Color3.fromRGB", why = "3D viewport lighting of the creature preview on a map card" },
	},
	["UI/Screens/Hud/Minimap.luau"] = {
		{ pattern = "UiArtState.decorate(", why = "pixel size of a map icon image, not a text size" },
	},
	["UI/Screens/WorldMap/Overlay.luau"] = {
		{ pattern = "UiArtState.decorate(", why = "pixel size of a map icon image, not a text size" },
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
local STRICT_PATTERNS = {
	"Theme%.Colors",
	"Color3%.fromHex%(",
	"TextSize%s*=%s*%d",
	"[Tt]ext[Ss]ize%s+or%s+%d",
	"line%.size%s+or%s+%d",
	'size="%d',
	"TextSize%s*=%s*if.-then%s+%d", -- `TextSize = if a then 16 else 14`
	"TextSize%s*=%s*if.-else%s+%d",
	"%f[%w_]size%s*=%s*%d", -- `{ text = ..., size = 14 }` (DetailCard lines and the like)
}
-- Inside `TextSize = scope:Computed(function ...)`: a number returned directly (`return if touch then 14 else 15`).
local COMPUTED_SIZE_PATTERNS = { "return%s+%d", "then%s+%d", "else%s+%d" }

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

-- "file:line: text" for every number literal returned inside a `TextSize = ...Computed(` block of `file`.
local function computedSizes(file: string): { string }
	local out = {}
	if string.sub(file, -5) ~= ".luau" then
		return out
	end
	local n, inside = 0, false
	for line in string.gmatch(fs.readFile(CLIENT .. file) .. "\n", "([^\n]*)\n") do
		n += 1
		local body = code(line)
		if string.find(body, "TextSize%s*=%s*[%w_.:]*Computed%(") then
			inside = true
		elseif inside then
			for _, pattern in COMPUTED_SIZE_PATTERNS do
				if string.find(body, pattern) and not excused(file, line) then
					table.insert(out, `{file}:{n}: {string.gsub(line, "^%s+", "")}`)
					break
				end
			end
			if string.find(body, "^%s*end%)") then
				inside = false
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

-- Every interface file the strict rules cover: UI/Screens, UI/Components and the modules directly in UI.
local function interfaceFiles(): { string }
	local out = concat(filesUnder("UI/Screens"), filesUnder("UI/Components"))
	for _, name in fs.readDir(CLIENT .. "UI") do
		if fs.isFile(`{CLIENT}UI/{name}`) then
			table.insert(out, `UI/{name}`)
		end
	end
	return out
end

local function covers(path: string, file: string): boolean
	return file == path or string.sub(file, 1, #path + 1) == path .. "/"
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

	it("every entry names existing files and a surface", function()
		local missing = {}
		for id, entry in UiWindows.list do
			expect(#entry.files > 0).toBe(true)
			for _, path in entry.files do
				if #filesUnder(path) == 0 then
					table.insert(missing, `{id}: {path}`)
				end
			end
			-- S151b: a window added after the move names its own session (the achievements window; S152b the season
			-- pass; S153 the "What has changed" letter)
			expect(
				entry.session == "S135"
					or entry.session == "S136"
					or entry.session == "S151b"
					or entry.session == "S152b"
					or entry.session == "S153"
			).toBe(true)
			expect(entry.surface == "paper" or entry.surface == "iron").toBe(true)
			if entry.surface == "iron" then
				expect(#(entry.why or "") > 10).toBe(true)
			end
		end
		for path, surface in UiWindows.SCREENS do
			if #filesUnder(path) == 0 then
				table.insert(missing, `SCREENS: {path}`)
			end
			expect(surface == "paper" or surface == "iron").toBe(true)
		end
		expect(table.concat(missing, ", ")).toBe("")
	end)

	it("every window but the admin overlay is on parchment", function()
		local iron = {}
		for id, entry in UiWindows.list do
			if entry.surface ~= "paper" then
				table.insert(iron, id)
			end
		end
		expect(table.concat(iron, " ")).toBe("dev")
	end)
end)

describe("Interface files use tokens only (S136 G2, strict)", function()
	it("no colour literal, text-size literal or Color3.fromHex in UI/Screens, UI/Components and UI/*.luau", function()
		local bad: { string } = {}
		for _, file in interfaceFiles() do
			if not EXEMPT[file] then
				bad = concat(bad, offences(file, concat(COLOUR_PATTERNS, STRICT_PATTERNS)))
				bad = concat(bad, computedSizes(file))
			end
		end
		expect(table.concat(bad, "\n")).toBe("")
	end)

	it("every exception has a reason and names an existing file", function()
		for file, list in ALLOWED do
			expect(fs.isFile(CLIENT .. file)).toBe(true)
			for _, allowed in list do
				expect(#allowed.why > 10).toBe(true)
			end
		end
		for file, why in EXEMPT do
			expect(fs.isFile(CLIENT .. file)).toBe(true)
			expect(#why > 10).toBe(true)
		end
	end)
end)

describe("Legacy tokens gone (S136 G3)", function()
	it("no Theme.Colors in src/client", function()
		local bad: { string } = {}
		for _, file in filesUnder("") do
			bad = concat(bad, offences(string.sub(file, 2), { "Theme%.Colors" }))
		end
		expect(table.concat(bad, "\n")).toBe("")
	end)

	it("Window has no legacy look", function()
		local window = fs.readFile(CLIENT .. "UI/Components/Window.luau")
		expect(string.find(window, "Paper:", 1, true)).toBeNil()
		expect(string.find(window, "LEGACY", 1, true)).toBeNil()
		local theme = fs.readFile(CLIENT .. "UI/Theme.luau")
		expect(string.find(theme, "Theme.Colors", 1, true)).toBeNil()
	end)
end)

describe("Every screen file is on the checklist (S136 G4)", function()
	it("each file of UI/Screens belongs to a window or to SCREENS", function()
		local paths: { string } = {}
		for _, entry in UiWindows.list do
			for _, path in entry.files do
				table.insert(paths, path)
			end
		end
		for path in UiWindows.SCREENS do
			table.insert(paths, path)
		end
		local orphans = {}
		for _, file in filesUnder("UI/Screens") do
			local listed = false
			for _, path in paths do
				if covers(path, file) then
					listed = true
					break
				end
			end
			if not listed then
				table.insert(orphans, file)
			end
		end
		expect(table.concat(orphans, ", ")).toBe("")
	end)
end)
