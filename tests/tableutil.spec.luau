--!strict
local T = require("./Test")
local TableUtil = require("../src/shared/Util/TableUtil")

T.describe("TableUtil", function()
	T.it("deepCopy copies nested tables", function()
		local source = { a = 1, b = { c = { 2, 3 } } }
		local copy = TableUtil.deepCopy(source)
		T.expect(copy).toEqual(source)
		T.expect(copy.b == source.b).toBe(false)
		copy.b.c[1] = 99
		T.expect(source.b.c[1]).toBe(2)
	end)

	T.it("deepCopy passes non-tables through", function()
		T.expect(TableUtil.deepCopy(5)).toBe(5)
		T.expect(TableUtil.deepCopy("x")).toBe("x")
	end)

	T.it("deepEqual compares structure", function()
		T.expect(TableUtil.deepEqual({ a = { 1, 2 } }, { a = { 1, 2 } })).toBe(true)
		T.expect(TableUtil.deepEqual({ a = { 1, 2 } }, { a = { 1, 3 } })).toBe(false)
		T.expect(TableUtil.deepEqual({ a = 1 }, { a = 1, b = 2 })).toBe(false)
		T.expect(TableUtil.deepEqual({ a = 1, b = 2 }, { a = 1 })).toBe(false)
		T.expect(TableUtil.deepEqual(1, "1")).toBe(false)
	end)

	T.it("merge is shallow and does not mutate inputs", function()
		local base = { a = 1, b = 2 }
		local merged: any = TableUtil.merge(base, { b = 3, c = 4 })
		T.expect(merged).toEqual({ a = 1, b = 3, c = 4 })
		T.expect(base).toEqual({ a = 1, b = 2 })
	end)

	T.it("reconcile fills missing keys without overwriting", function()
		local target: any = { a = 5, nested = { x = 1 } }
		TableUtil.reconcile(target, { a = 0, b = "new", nested = { x = 0, y = 2 }, list = {} })
		T.expect(target).toEqual({ a = 5, b = "new", nested = { x = 1, y = 2 }, list = {} })
	end)

	T.it("reconcile copies template tables instead of sharing them", function()
		local template = { inner = { v = 1 } }
		local target: any = {}
		TableUtil.reconcile(target, template)
		target.inner.v = 2
		T.expect(template.inner.v).toBe(1)
	end)

	T.it("keys and count", function()
		local keys = TableUtil.keys({ a = 1, b = 2 })
		table.sort(keys)
		T.expect(keys).toEqual({ "a", "b" })
		T.expect(TableUtil.count({ a = 1, b = 2, [3] = 3 })).toBe(3)
	end)
end)

return nil
