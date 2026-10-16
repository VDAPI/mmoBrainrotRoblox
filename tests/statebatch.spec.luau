--!strict
-- S134f: a batch of diffs refreshes each touched client-state entry once (Logic/StateBatch).
local StateBatch = require("../src/shared/Logic/StateBatch")
local T = require("./Test")
local Types = require("../src/shared/Types")

type Path = Types.Path
type Diff = Types.Diff

-- The client mirror model: whole character, whole inventory, 200 slots, gold, buyback and an unrelated branch.
local function cachePaths(): { Path }
	local paths: { Path } = { { "character" }, { "character", "inventory" } }
	for i = 1, 200 do
		table.insert(paths, { "character", "inventory", tostring(i) })
	end
	table.insert(paths, { "character", "gold" })
	table.insert(paths, { "buyback" })
	table.insert(paths, { "party" })
	return paths
end

local function saleBatch(n: number): { Diff }
	local diffs: { Diff } = {}
	for i = 1, n do
		table.insert(diffs, { op = "set", path = { "character", "inventory", tostring(i * 3) }, value = nil })
	end
	table.insert(diffs, { op = "set", path = { "character", "gold" }, value = 100 })
	table.insert(diffs, { op = "set", path = { "buyback" }, value = {} })
	return diffs
end

T.describe("StateBatch.touched", function()
	T.it("touches each overlapping entry once per batch", function()
		local paths = cachePaths()
		local touched = StateBatch.touched(paths, saleBatch(60))
		local count: { [string]: number } = {}
		for _, index in touched do
			local key = table.concat(paths[index] :: any, ".")
			count[key] = (count[key] or 0) + 1
		end
		T.expect(count["character"]).toBe(1)
		T.expect(count["character.inventory"]).toBe(1)
		T.expect(count["character.gold"]).toBe(1)
		T.expect(count["buyback"]).toBe(1)
		T.expect(count["party"]).toBeNil()
		T.expect(count["character.inventory.3"]).toBe(1)
		T.expect(count["character.inventory.180"]).toBe(1)
		T.expect(count["character.inventory.4"]).toBeNil()
		T.expect(count["character.inventory.200"]).toBeNil()
		-- character + inventory + 60 slots + gold + buyback
		T.expect(#touched).toBe(64)
	end)

	T.it("has no repeats and a stable ascending order", function()
		local paths = cachePaths()
		local diffs = saleBatch(10)
		table.insert(diffs, { op = "set", path = { "character", "inventory", "3" }, value = nil })
		local touched = StateBatch.touched(paths, diffs)
		for i = 2, #touched do
			T.expect(touched[i] > touched[i - 1]).toBe(true)
		end
		T.expect(StateBatch.touched(paths, diffs)).toEqual(touched)
	end)

	T.it("a snapshot-like empty path touches every entry", function()
		local paths = cachePaths()
		local touched = StateBatch.touched(paths, { { op = "set", path = {}, value = nil } })
		T.expect(#touched).toBe(#paths)
	end)

	T.it("a deeper diff touches its ancestors but not its siblings", function()
		local paths = cachePaths()
		local touched = StateBatch.touched(
			paths,
			{ { op = "set", path = { "character", "inventory", "5", "locked" }, value = true } }
		)
		T.expect(#touched).toBe(3)
	end)
end)
