--!strict
local PathOps = require("../src/shared/Logic/PathOps")
local T = require("./Test")

T.describe("PathOps", function()
	T.it("get reads nested values and tolerates missing branches", function()
		local root = { a = { b = { c = 5 } } }
		T.expect(PathOps.get(root, { "a", "b", "c" })).toBe(5)
		T.expect(PathOps.get(root, { "a", "x", "c" })).toBeNil()
		T.expect(PathOps.get(root, { "a", "b", "c", "d" })).toBeNil()
		T.expect(PathOps.get(root, {})).toBe(root)
	end)

	T.it("set creates intermediate tables and deletes with nil", function()
		local root: any = {}
		PathOps.set(root, { "character", "stats", "str" }, 10)
		T.expect(root).toEqual({ character = { stats = { str = 10 } } })
		PathOps.set(root, { "character", "stats", "str" }, nil)
		T.expect(root).toEqual({ character = { stats = {} } })
	end)

	T.it("set refuses to walk through non-tables", function()
		local root = { a = 5 }
		T.expect(function()
			PathOps.set(root, { "a", "b" }, 1)
		end).toThrow("is not a table")
	end)

	T.it("insert and remove on arrays", function()
		local root: any = { list = { "a", "c" } }
		T.expect(PathOps.insert(root, { "list" }, "b", 2)).toBe(2)
		T.expect(PathOps.insert(root, { "list" }, "d")).toBe(4)
		T.expect(root.list).toEqual({ "a", "b", "c", "d" })
		T.expect(PathOps.remove(root, { "list" }, 1)).toBe("a")
		T.expect(root.list).toEqual({ "b", "c", "d" })
		PathOps.insert(root, { "fresh" }, 1)
		T.expect(root.fresh).toEqual({ 1 })
	end)

	T.it("apply replays diffs", function()
		local server: any = { gold = 0, list = {} }
		local client: any = { gold = 0, list = {} }
		local diffs = {
			{ op = "set", path = { "gold" }, value = 50 },
			{ op = "insert", path = { "list" }, value = "x", index = 1 },
			{ op = "insert", path = { "list" }, value = "y", index = 2 },
			{ op = "remove", path = { "list" }, index = 1 },
		}
		server.gold = 50
		server.list = { "y" }
		for _, diff in diffs do
			PathOps.apply(client, diff :: any)
		end
		T.expect(client).toEqual(server)
	end)

	T.it("apply rejects unknown ops", function()
		T.expect(function()
			PathOps.apply({}, { op = "explode", path = { "a" } } :: any)
		end).toThrow("unknown op")
	end)

	T.it("startsWith and key", function()
		T.expect(PathOps.startsWith({ "a", "b", "c" }, { "a", "b" })).toBe(true)
		T.expect(PathOps.startsWith({ "a" }, { "a", "b" })).toBe(false)
		T.expect(PathOps.startsWith({ "a", "x" }, { "a", "b" })).toBe(false)
		T.expect(PathOps.startsWith({ "a" }, {})).toBe(true)
		T.expect(PathOps.key({ "character", "inventory", 3 })).toBe("character.inventory.3")
	end)
end)

return nil
