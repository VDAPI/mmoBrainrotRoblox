--!strict
local Locale = require("../src/shared/Util/Locale")
local T = require("./Test")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local function placeholders(text: string): { [string]: boolean }
	local found = {}
	for name in string.gmatch(text, "{([%w_]+)}") do
		found[name] = true
	end
	return found
end

T.describe("Locale", function()
	T.it("every pl key exists in en", function()
		local missing = {}
		for key in pl do
			if en[key] == nil then
				table.insert(missing, key)
			end
		end
		table.sort(missing)
		T.expect(missing).toEqual({})
	end)

	T.it("every en key exists in pl", function()
		local missing = {}
		for key in en do
			if pl[key] == nil then
				table.insert(missing, key)
			end
		end
		table.sort(missing)
		T.expect(missing).toEqual({})
	end)

	T.it("no empty strings", function()
		for _, tbl in { en, pl } do
			for key, text in tbl do
				if text == "" then
					error(`empty text for {key}`)
				end
			end
		end
	end)

	T.it("pl and en use the same placeholders", function()
		for key, text in en do
			local other = pl[key]
			if other then
				T.expect({ key = key, args = placeholders(other) }).toEqual({ key = key, args = placeholders(text) })
			end
		end
	end)

	T.it("T substitutes arguments", function()
		T.expect(Locale.T("toast.enterWorld", { name = "Aria" }, "en")).toBe("Welcome to Vaelthorn, Aria!")
		T.expect(Locale.T("toast.enterWorld", { name = "Aria" }, "pl")).toBe("Witaj w Vaelthorn, Aria!")
	end)

	T.it("T keeps unknown placeholders and returns the key when missing", function()
		T.expect(Locale.T("toast.enterWorld", {}, "en")).toBe("Welcome to Vaelthorn, {name}!")
		T.expect(Locale.T("does.not.exist")).toBe("does.not.exist")
	end)

	T.it("unsupported languages fall back to English", function()
		T.expect(Locale.T("common.cancel", nil, "de")).toBe("Cancel")
		T.expect(Locale.isSupported("de")).toBe(false)
	end)

	T.it("maps Roblox locale ids", function()
		T.expect(Locale.fromRobloxLocale("pl-pl")).toBe("pl")
		T.expect(Locale.fromRobloxLocale("en-us")).toBe("en")
		T.expect(Locale.fromRobloxLocale("de-de")).toBe("en")
	end)

	T.it("setLanguage ignores unsupported languages", function()
		local before = Locale.getLanguage()
		Locale.setLanguage("xx")
		T.expect(Locale.getLanguage()).toBe(before)
		Locale.setLanguage("pl")
		T.expect(Locale.T("common.cancel")).toBe("Anuluj")
		Locale.setLanguage(before)
	end)
end)

return nil
