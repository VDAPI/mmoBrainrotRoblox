--!strict
local DepSort = require("../src/shared/Logic/DepSort")
local T = require("./Test")

local function names(list: { any }): { string }
	local out = {}
	for _, module in list do
		table.insert(out, module.Name)
	end
	return out
end

T.describe("DepSort", function()
	T.it("puts dependencies first, ties alphabetical", function()
		local sorted = DepSort.sort({
			{ Name = "CharacterService", Deps = { "DataService", "NameService" } },
			{ Name = "NameService", Deps = { "DataService" } },
			{ Name = "DataService" },
			{ Name = "AdminService", Deps = { "CharacterService" } },
		})
		T.expect(names(sorted)).toEqual({ "DataService", "NameService", "CharacterService", "AdminService" })
	end)

	T.it("rejects missing dependencies", function()
		T.expect(function()
			DepSort.sort({ { Name = "A", Deps = { "Ghost" } } })
		end).toThrow("missing module 'Ghost'")
	end)

	T.it("rejects cycles", function()
		T.expect(function()
			DepSort.sort({ { Name = "A", Deps = { "B" } }, { Name = "B", Deps = { "A" } } })
		end).toThrow("cycle")
	end)

	T.it("rejects duplicate names", function()
		T.expect(function()
			DepSort.sort({ { Name = "A" }, { Name = "A" } })
		end).toThrow("duplicate")
	end)
end)

return nil
