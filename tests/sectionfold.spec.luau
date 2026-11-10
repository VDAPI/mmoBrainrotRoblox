--!strict
-- Owner 2026-11-10 ("nothing can be collapsed"): the open and folded sections of the windows (Logic/SectionFold,
-- UI/Components/Section), kept on the account (account.settings.sections, SetSetting "sections"). UI plan 2026-11-10
-- (docs/UI-ZASADY.md §4): the defaults live per area in Data/Folds and may differ on a phone ({ pc, phone }); what the
-- players saved before reads the same.
local fs = require("@lune/fs")

local T = require("./Test")
local AccountSchema = require("../src/shared/Logic/AccountSchema")
local Folds = require("../src/shared/Data/Folds")
local SectionFold = require("../src/shared/Logic/SectionFold")

-- Runs `body` over defaults merged from `areas` (the game has no per-device section yet), then puts the game's back,
-- also when `body` fails.
local function withDefaults(areas: { Folds.Area }, body: () -> ())
	local real = SectionFold.DEFAULTS
	SectionFold.DEFAULTS = SectionFold.merge(areas)
	local ok, err = pcall(body)
	SectionFold.DEFAULTS = real
	if not ok then
		error(err, 0)
	end
end

-- A HUD panel open on PC and one line on a phone, its opposite, a plain boolean and a pair equal on both devices.
local DEVICE_AREAS: { Folds.Area } = {
	{ name = "Hud", folds = { panel = { pc = true, phone = false }, sheet = { pc = false, phone = true } } },
	{ name = "Menu", folds = { plain = true, both = { pc = false, phone = false } } },
}

-- SectionFold before the per-device defaults (9960eb8a), to read the old saved settings with.
local OLD_DEFAULTS: { [string]: boolean } = { charStats = true, charSets = false }

local function oldIsOpen(saved: any, id: string): boolean
	local value = if type(saved) == "table" then saved[id] else nil
	if type(value) == "boolean" then
		return value
	end
	return OLD_DEFAULTS[id] == true
end

local function oldWith(saved: any, id: string, open: boolean): { [string]: boolean }
	local out: { [string]: boolean } = {}
	for known, default in OLD_DEFAULTS do
		local value = if known == id then open else oldIsOpen(saved, known)
		if value ~= default then
			out[known] = value
		end
	end
	return out
end

-- Every setting the old client could save (known ids to booleans), the odd values the old rules read anyway, and
-- whether the old validator took it.
local OLD_SAVES: { { value: any, valid: boolean } } = {
	{ value = {}, valid = true },
	{ value = { charStats = false }, valid = true },
	{ value = { charStats = true }, valid = true },
	{ value = { charSets = true }, valid = true },
	{ value = { charSets = false }, valid = true },
	{ value = { charStats = false, charSets = true }, valid = true },
	{ value = { charStats = true, charSets = false }, valid = true },
	{ value = { charStats = false, charSets = false }, valid = true },
	{ value = { charStats = true, charSets = true }, valid = true },
	{ value = { charStats = 1 }, valid = false },
	{ value = { charStats = "no" }, valid = false },
	{ value = { other = true }, valid = false },
	{ value = { true }, valid = false },
	{ value = "charStats", valid = false },
	{ value = false, valid = false },
	{ valid = false }, -- no setting at all (nil)
}

local function luauFiles(dir: string): { string }
	local out = {}
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			for _, file in luauFiles(path) do
				table.insert(out, file)
			end
		elseif string.sub(name, -5) == ".luau" then
			table.insert(out, path)
		end
	end
	table.sort(out)
	return out
end

-- A literal section id where the client opens, reads or builds a section.
local ID_PATTERNS = {
	'Section%.new%(%s*[%w_]+%s*,%s*{%s*Id%s*=%s*"([%w_]+)"',
	'Section%.state%(%s*[%w_]+%s*,%s*"([%w_]+)"',
	'Section%.Open%(%s*"([%w_]+)"',
	'Section%.set%(%s*"([%w_]+)"',
	'Section%.toggle%(%s*"([%w_]+)"',
}

T.describe("SectionFold", function()
	T.it("knows its sections, each with a boolean or a { pc, phone } default", function()
		T.expect(SectionFold.known("charStats")).toBe(true)
		T.expect(SectionFold.known("charSets")).toBe(true)
		T.expect(SectionFold.known("nope")).toBe(false)
		for id, default in SectionFold.DEFAULTS do
			T.expect(type(id)).toBe("string")
			if type(default) == "table" then
				T.expect(type(default.pc)).toBe("boolean")
				T.expect(type(default.phone)).toBe("boolean")
			else
				T.expect(type(default)).toBe("boolean")
			end
		end
	end)

	T.it("merges the areas of Data/Folds; the backpack's two sections moved unchanged into Gear", function()
		local names = {}
		for _, area in Folds do
			table.insert(names, area.name)
		end
		T.expect(names).toEqual({ "Hud", "Gear", "World", "Menu" })
		T.expect(SectionFold.merge(Folds)).toEqual(SectionFold.DEFAULTS)
		local Gear = require("../src/shared/Data/Folds/Gear") :: any
		T.expect(Gear.charStats).toBe(true)
		T.expect(Gear.charSets).toBe(false)
		-- each default stands in exactly one area
		local listed, merged = 0, 0
		for _, area in Folds do
			for id, default in area.folds do
				listed += 1
				T.expect(SectionFold.DEFAULTS[id]).toEqual(default)
			end
		end
		for _ in SectionFold.DEFAULTS do
			merged += 1
		end
		T.expect(merged).toBe(listed)
		-- the folder module requires its areas by @self, as Data/Quests and Data/Items do
		local init = fs.readFile("src/shared/Data/Folds/init.luau")
		for _, name in names do
			T.expect(string.find(init, `require("@self/{name}")`, 1, true) ~= nil).toBe(true)
		end
	end)

	T.it("an id in two Folds files, or a malformed default, raises an error", function()
		T.expect(function()
			SectionFold.merge({
				{ name = "Hud", folds = { log = true } },
				{ name = "World", folds = { log = { pc = true, phone = false } } },
			})
		end).toThrow('section "log" is in both Hud and World')
		-- a package taking another package's section (the backpack's statistics) for its own window
		T.expect(function()
			SectionFold.merge({ Folds[2], { name = "World", folds = { charStats = false } } })
		end).toThrow('section "charStats" is in both Gear and World')
		local bad: { any } =
			{ { pc = true }, { pc = true, phone = "no" }, { pc = true, phone = false, tablet = true }, "open" }
		for _, default in bad do
			T.expect(function()
				SectionFold.merge({ { name = "Menu", folds = { odd = default } } })
			end).toThrow('Data/Folds.Menu: section "odd"')
		end
		-- the merged pairs are copies: changing the area's table changes nothing
		local pair = { pc = true, phone = false }
		local merged = SectionFold.merge({ { name = "Hud", folds = { panel = pair } } }) :: any
		pair.phone = true
		T.expect(merged.panel).toEqual({ pc = true, phone = false })
		T.expect(table.isfrozen(merged.panel)).toBe(true)
	end)

	T.it("old saved settings read the same, on PC and on a phone", function()
		for _, entry in OLD_SAVES do
			for _, id in { "charStats", "charSets", "nope" } do
				local old = oldIsOpen(entry.value, id)
				T.expect(SectionFold.isOpen(entry.value, id)).toBe(old)
				T.expect(SectionFold.isOpen(entry.value, id, false)).toBe(old)
				T.expect(SectionFold.isOpen(entry.value, id, true)).toBe(old)
			end
		end
	end)

	T.it("old settings fold and compare as before: a boolean default ignores the device", function()
		for _, entry in OLD_SAVES do
			for _, id in { "charStats", "charSets" } do
				for _, open in { true, false } do
					local old = oldWith(entry.value, id, open)
					T.expect(SectionFold.with(entry.value, id, open)).toEqual(old)
					T.expect(SectionFold.with(entry.value, id, open, false)).toEqual(old)
					T.expect(SectionFold.with(entry.value, id, open, true)).toEqual(old)
				end
			end
		end
		for _, a in OLD_SAVES do
			for _, b in OLD_SAVES do
				local old = oldIsOpen(a.value, "charStats") == oldIsOpen(b.value, "charStats")
					and oldIsOpen(a.value, "charSets") == oldIsOpen(b.value, "charSets")
				T.expect(SectionFold.same(a.value, b.value)).toBe(old)
			end
		end
		-- the cases of the first version of this spec
		T.expect(SectionFold.with({}, "charStats", false)).toEqual({ charStats = false })
		T.expect(SectionFold.with({ charStats = false }, "charStats", true)).toEqual({})
		T.expect(SectionFold.with({ charStats = false }, "charSets", true))
			.toEqual({ charStats = false, charSets = true })
		T.expect(SectionFold.with({ old = true }, "charSets", false)).toEqual({})
	end)

	T.it("a default may differ per device, and the player's choice wins on both", function()
		withDefaults(DEVICE_AREAS, function()
			T.expect(SectionFold.default("panel")).toBe(true)
			T.expect(SectionFold.default("panel", false)).toBe(true)
			T.expect(SectionFold.default("panel", true)).toBe(false)
			T.expect(SectionFold.default("sheet", false)).toBe(false)
			T.expect(SectionFold.default("sheet", true)).toBe(true)
			T.expect(SectionFold.default("plain", true)).toBe(true)
			T.expect(SectionFold.default("nope", true)).toBe(false)
			-- no choice: the device's default
			T.expect(SectionFold.isOpen({}, "panel")).toBe(true)
			T.expect(SectionFold.isOpen(nil, "panel", true)).toBe(false)
			T.expect(SectionFold.isOpen({ panel = 1 }, "panel", true)).toBe(false)
			T.expect(SectionFold.isOpen("x", "sheet", true)).toBe(true)
			-- a choice holds on every device
			for _, compact in { false, true } do
				T.expect(SectionFold.isOpen({ panel = false }, "panel", compact)).toBe(false)
				T.expect(SectionFold.isOpen({ panel = true }, "panel", compact)).toBe(true)
				T.expect(SectionFold.isOpen({ sheet = false }, "sheet", compact)).toBe(false)
			end
		end)
	end)

	T.it("with() stores the least: a choice only where it differs from a default", function()
		withDefaults(DEVICE_AREAS, function()
			-- a phone opens the panel PC opens anyway: kept, the phone's default is folded
			T.expect(SectionFold.with({}, "panel", true, true)).toEqual({ panel = true })
			-- what this device shows already: nothing stored, the other device keeps its own default
			T.expect(SectionFold.with({}, "panel", true, false)).toEqual({})
			T.expect(SectionFold.with({}, "panel", false, true)).toEqual({})
			T.expect(SectionFold.with({ panel = true }, "panel", true, false)).toEqual({ panel = true })
			-- PC folds it: folded on both devices
			T.expect(SectionFold.with({}, "panel", false, false)).toEqual({ panel = false })
			T.expect(SectionFold.with({ panel = true }, "panel", false, false)).toEqual({ panel = false })
			-- a choice equal to the default on both devices drops
			T.expect(SectionFold.with({ plain = false }, "plain", true)).toEqual({})
			T.expect(SectionFold.with({ both = true }, "both", false, true)).toEqual({})
			-- the other sections keep their choices, no default is written for them, unknown ids and non-booleans drop
			T.expect(SectionFold.with({ sheet = false, old = true, plain = 1, both = false }, "plain", false, true))
				.toEqual({ sheet = false, plain = false })

			-- every section, device and choice over a few saved settings (the sixth: no setting, nil)
			local saves: { any } =
				{ {}, { panel = true }, { panel = false, sheet = true }, { plain = false, both = true }, "x" }
			for i = 1, #saves + 1 do
				local saved = saves[i]
				for id in SectionFold.DEFAULTS do
					for _, compact in { false, true } do
						for _, open in { false, true } do
							local out = SectionFold.with(saved, id, open, compact)
							-- it reads as chosen on the device it was made on, and the server takes it
							T.expect(SectionFold.isOpen(out, id, compact)).toBe(open)
							T.expect(SectionFold.valid(out)).toBe(true)
							-- a choice that changes nothing here changes nothing anywhere
							if SectionFold.isOpen(saved, id, compact) == open then
								T.expect(SectionFold.same(out, saved)).toBe(true)
							end
							-- the other sections stay as they were on both devices
							for other in SectionFold.DEFAULTS do
								if other ~= id then
									for _, device in { false, true } do
										T.expect(SectionFold.isOpen(out, other, device))
											.toBe(SectionFold.isOpen(saved, other, device))
									end
								end
							end
							-- the least: no entry equals the default on both devices
							for key, value in out do
								local everywhere = SectionFold.default(key, false) == value
									and SectionFold.default(key, true) == value
								T.expect(everywhere).toBe(false)
							end
						end
					end
				end
			end
		end)
	end)

	T.it("compares what two settings open on PC and on a phone", function()
		T.expect(SectionFold.same({}, { charStats = true })).toBe(true)
		T.expect(SectionFold.same({}, { charStats = false })).toBe(false)
		T.expect(SectionFold.same(nil, {})).toBe(true)
		withDefaults(DEVICE_AREAS, function()
			-- open on PC either way, but a phone folds it only without the choice
			T.expect(SectionFold.same({}, { panel = true })).toBe(false)
			T.expect(SectionFold.same({ panel = false }, { panel = false, both = false })).toBe(true)
		end)
	end)

	T.it("the server takes every old setting, and only known ids with booleans", function()
		for _, entry in OLD_SAVES do
			T.expect(SectionFold.valid(entry.value)).toBe(entry.valid)
		end
		T.expect(SectionFold.valid({ charStats = false, nope = true })).toBe(false)
		withDefaults(DEVICE_AREAS, function()
			T.expect(SectionFold.valid({ panel = true, plain = false })).toBe(true)
			-- a choice is one boolean for every device, never a { pc, phone } pair
			T.expect(SectionFold.valid({ panel = { pc = true, phone = false } })).toBe(false)
			T.expect(SectionFold.valid({ panel = true, other = false })).toBe(false)
		end)
	end)

	T.it("every section the client builds or reads has its default", function()
		-- an unknown id would stop the window at Section.Open's assert
		local found = 0
		for _, path in luauFiles("src/client") do
			local src = fs.readFile(path)
			if string.find(src, "Components.Section)", 1, true) then
				for _, pattern in ID_PATTERNS do
					for id in string.gmatch(src, pattern) do
						found += 1
						T.expect(`{path} {id} {SectionFold.known(id)}`).toBe(`{path} {id} true`)
					end
				end
			end
		end
		T.expect(found >= 2).toBe(true)
	end)

	T.it("UI plan package A: every section of the HUD's files has its default in Data/Folds/Hud", function()
		local hud = require("../src/shared/Data/Folds/Hud") :: { [string]: any }
		local TextScan = require("./TextScan")
		local found = 0
		for _, path in luauFiles("src/client") do
			if TextScan.ownerOfFile(path) ~= "A" then
				continue
			end
			local src = fs.readFile(path)
			for _, pattern in ID_PATTERNS do
				for id in string.gmatch(src, pattern) do
					found += 1
					T.expect(`{path} {id} {hud[id] ~= nil}`).toBe(`{path} {id} true`)
				end
			end
		end
		-- the five event panels (the arena's two files share hudArena)
		T.expect(found >= 5).toBe(true)
		for _, id in { "hudWorldBoss", "hudWorldEvent", "hudBloodMoon", "hudTourney", "hudArena" } do
			T.expect({ id, hud[id] }).toEqual({ id, { pc = true, phone = false } })
		end
	end)

	T.it("Folds/Gear: the backpack and skills windows read every id there, and name no other", function()
		-- UI plan package D (owner 2026-11-10, "nothing folds"): the derived statistics in four sections (their ids
		-- in DerivedList's table, so the patterns above miss them) and the skill details' cost and breakpoints
		local Gear = require("../src/shared/Data/Folds/Gear") :: any
		local sources: { string } = {}
		for _, dir in { "src/client/UI/Screens/CharacterWindow", "src/client/UI/Screens/SkillsWindow" } do
			for _, path in luauFiles(dir) do
				table.insert(sources, fs.readFile(path))
			end
		end
		local all = table.concat(sources, "\n")
		for id in Gear do
			T.expect(`{id} {string.find(all, `"{id}"`, 1, true) ~= nil}`).toBe(`{id} true`)
		end
		-- a literal id there, or one of the derived groups', is Gear's, never another area's
		local named = 0
		for _, pattern in { 'Id%s*=%s*"([%w_]+)"', '%a+%s*=%s*"(char%u%a+)"' } do
			for id in string.gmatch(all, pattern) do
				named += 1
				T.expect(`{id} {Gear[id] ~= nil}`).toBe(`{id} true`)
			end
		end
		T.expect(named >= 8).toBe(true)
		-- what the plan folds: the statistics and the attack open, the rest to one line
		T.expect({ Gear.charStats, Gear.charOffense }).toEqual({ true, true })
		for _, id in { "charSets", "charDefense", "charResources", "charOther", "skillCost", "skillBreakpoints" } do
			T.expect(`{id} {Gear[id]}`).toBe(`{id} false`)
		end
	end)

	T.it("a new account starts with the defaults, and the setting is wired end to end", function()
		local account = AccountSchema.accountTemplate() :: any
		T.expect(account.settings.sections).toEqual({})
		local service = fs.readFile("src/server/Services/SettingsService.luau")
		T.expect(string.find(service, "SectionFold.valid(value)", 1, true) ~= nil).toBe(true)
		local types = fs.readFile("src/shared/Types.luau")
		T.expect(string.find(types, "sections: { [string]: boolean }", 1, true) ~= nil).toBe(true)
		local component = fs.readFile("src/client/UI/Components/Section.luau")
		T.expect(string.find(component, '"SetSetting", "sections"', 1, true) ~= nil).toBe(true)
		-- one header control: the arrow says open or folded, the whole header is the button
		T.expect(string.find(component, '"▾" else "▸"', 1, true) ~= nil).toBe(true)
		T.expect(string.find(component, "Theme.Size.MinTouch", 1, true) ~= nil).toBe(true)
	end)

	T.it("the component reads the device's default, and Section.state shares its one state and save", function()
		local component = fs.readFile("src/client/UI/Components/Section.luau")
		-- the phone layout flag of the HUD chooses between pc and phone, when reading and when saving
		local phone = fs.readFile("src/client/UI/PhoneLayout.luau")
		T.expect(string.find(phone, "PhoneLayout.Compact = ", 1, true) ~= nil).toBe(true)
		for _, name in { "Open", "set", "toggle" } do
			local body = assert(string.match(component, `function Section%.{name}%(.-\nend\n`))
			T.expect(string.find(body, "PhoneLayout.Compact", 1, true) ~= nil).toBe(true)
		end
		-- Section.state (a HUD panel's line, a settings group) reads Section.Open and writes through Section.set
		local state = assert(string.match(component, "function Section%.state%(.-\nend\n"))
		T.expect(string.find(state, "Section.Open(id)", 1, true) ~= nil).toBe(true)
		T.expect(string.find(state, "Section.set(id, value)", 1, true) ~= nil).toBe(true)
		-- one save path for both
		local _, sends = string.gsub(component, 'Net%.Send%("SetSetting", "sections"', "")
		T.expect(sends).toBe(1)
	end)
end)

return nil
