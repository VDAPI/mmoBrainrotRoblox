--!strict
-- Owner 2026-11-10 ("nothing can be collapsed"): the open and folded sections of the windows (Logic/SectionFold,
-- UI/Components/Section), kept on the account (account.settings.sections, SetSetting "sections").
local fs = require("@lune/fs")

local T = require("./Test")
local AccountSchema = require("../src/shared/Logic/AccountSchema")
local SectionFold = require("../src/shared/Logic/SectionFold")

T.describe("SectionFold", function()
	T.it("knows its sections and their defaults", function()
		T.expect(SectionFold.known("charStats")).toBe(true)
		T.expect(SectionFold.known("charSets")).toBe(true)
		T.expect(SectionFold.known("nope")).toBe(false)
		for id, open in SectionFold.DEFAULTS do
			T.expect(type(id)).toBe("string")
			T.expect(type(open)).toBe("boolean")
		end
	end)

	T.it("reads the saved choice, the default without one", function()
		T.expect(SectionFold.isOpen({}, "charStats")).toBe(true)
		T.expect(SectionFold.isOpen({ charStats = false }, "charStats")).toBe(false)
		T.expect(SectionFold.isOpen({ charSets = true }, "charSets")).toBe(true)
		-- anything else than a table, or than a boolean under the id, reads as no choice
		T.expect(SectionFold.isOpen("x", "charStats")).toBe(true)
		T.expect(SectionFold.isOpen({ charStats = 1 }, "charStats")).toBe(true)
		T.expect(SectionFold.isOpen(nil, "nope")).toBe(false)
	end)

	T.it("keeps only the choices that differ from the default", function()
		T.expect(SectionFold.with({}, "charStats", false)).toEqual({ charStats = false })
		T.expect(SectionFold.with({ charStats = false }, "charStats", true)).toEqual({})
		T.expect(SectionFold.with({ charStats = false }, "charSets", true))
			.toEqual({ charStats = false, charSets = true })
		-- unknown ids drop out
		T.expect(SectionFold.with({ old = true }, "charSets", false)).toEqual({})
	end)

	T.it("compares what two settings open", function()
		T.expect(SectionFold.same({}, { charStats = true })).toBe(true)
		T.expect(SectionFold.same({}, { charStats = false })).toBe(false)
		T.expect(SectionFold.same(nil, {})).toBe(true)
	end)

	T.it("the server takes only known ids with booleans", function()
		T.expect(SectionFold.valid({})).toBe(true)
		T.expect(SectionFold.valid({ charStats = false, charSets = true })).toBe(true)
		T.expect(SectionFold.valid({ charStats = "no" })).toBe(false)
		T.expect(SectionFold.valid({ other = true })).toBe(false)
		T.expect(SectionFold.valid({ true })).toBe(false)
		T.expect(SectionFold.valid("charStats")).toBe(false)
		T.expect(SectionFold.valid(nil)).toBe(false)
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
end)

return nil
