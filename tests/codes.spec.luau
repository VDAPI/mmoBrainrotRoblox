--!strict
local CodeData = require("../src/shared/Data/Codes")
local Codes = require("../src/shared/Logic/Codes")
local Items = require("../src/shared/Data/Items")
local T = require("./Test")

T.describe("Reward codes", function()
	T.it("normalizes case and spaces", function()
		T.expect(Codes.normalize("  vael thorn ")).toBe("VAELTHORN")
	end)

	T.it("accepts a known code once", function()
		local def, err = Codes.check("vaelthorn", {}, 0)
		T.expect(err).toBeNil()
		T.expect(def and def.code).toBe("VAELTHORN")
		local _, again = Codes.check("VAELTHORN", { VAELTHORN = 1 }, 0)
		T.expect(again).toBe("codes.error.used")
	end)

	T.it("rejects unknown and too short codes", function()
		T.expect(select(2, Codes.check("nope-nope", {}, 0))).toBe("codes.error.invalid")
		T.expect(select(2, Codes.check("a", {}, 0))).toBe("codes.error.invalid")
	end)

	T.it("data: upper case, unique, real items, small shard rewards", function()
		local seen = {}
		for _, def in CodeData.list do
			T.expect(def.code).toBe(string.upper(def.code))
			T.expect(seen[def.code]).toBeNil()
			seen[def.code] = true
			T.expect((def.shards or 0) <= 100).toBe(true)
			for _, entry in def.items or {} do
				T.expect(Items.get(entry.id) ~= nil).toBe(true)
				T.expect(entry.n >= 1).toBe(true)
			end
		end
	end)
end)
