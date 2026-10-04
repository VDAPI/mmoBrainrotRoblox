--!strict
local NameRules = require("../src/shared/Logic/NameRules")
local T = require("./Test")

local function reason(name: string): string?
	local _, err = NameRules.validate(name)
	return err
end

T.describe("NameRules", function()
	T.it("accepts letters, digits and Polish letters", function()
		T.expect((NameRules.validate("Aria"))).toBe(true)
		T.expect((NameRules.validate("Łukasz99"))).toBe(true)
		T.expect((NameRules.validate("ŻÓŁĆęśąźń"))).toBe(true)
		T.expect((NameRules.validate("abc"))).toBe(true)
		T.expect((NameRules.validate("A234567890123456"))).toBe(true)
	end)

	T.it("rejects bad lengths", function()
		T.expect(reason("ab")).toBe("tooShort")
		T.expect(reason("")).toBe("tooShort")
		T.expect(reason("A2345678901234567")).toBe("tooLong")
		-- Length is counted in characters, not bytes.
		T.expect((NameRules.validate("ŻŻŻŻŻŻŻŻŻŻŻŻŻŻŻŻ"))).toBe(true)
	end)

	T.it("rejects other characters", function()
		T.expect(reason("Ar ia")).toBe("invalidChars")
		T.expect(reason("Aria_")).toBe("invalidChars")
		T.expect(reason("Ärger")).toBe("invalidChars")
		T.expect(reason("Ar<b>ia")).toBe("invalidChars")
	end)

	T.it("requires a letter", function()
		T.expect(reason("12345")).toBe("noLetter")
	end)

	T.it("rejects invalid UTF-8", function()
		T.expect(reason("abc\255")).toBe("invalidUtf8")
	end)

	T.it("normalizes case including Polish letters", function()
		T.expect(NameRules.normalize("ŁukASZ")).toBe("łukasz")
		T.expect(NameRules.normalize("ŻÓŁW")).toBe(NameRules.normalize("żółw"))
		T.expect(NameRules.normalize("Abc12")).toBe("abc12")
	end)

	T.it("builds localization keys", function()
		T.expect(NameRules.errorKey("taken")).toBe("error.name.taken")
	end)
end)

return nil
