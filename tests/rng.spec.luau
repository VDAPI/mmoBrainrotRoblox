--!strict
local Rng = require("../src/shared/Logic/Rng")
local T = require("./Test")

T.describe("Rng", function()
	T.it("repeats the same sequence for the same seed", function()
		local a, b = Rng.new(1234), Rng.new(1234)
		for _ = 1, 100 do
			T.expect(a:nextUint()).toBe(b:nextUint())
		end
	end)

	T.it("differs for different seeds", function()
		local a, b = Rng.new(1), Rng.new(2)
		local same = 0
		for _ = 1, 50 do
			if a:nextUint() == b:nextUint() then
				same += 1
			end
		end
		T.expect(same < 50).toBe(true)
	end)

	T.it("handles seed 0 and negative seeds", function()
		T.expect(Rng.new(0):next()).toBeBetween(0, 1)
		T.expect(Rng.new(-5):next()).toBeBetween(0, 1)
	end)

	T.it("next() stays in [0, 1)", function()
		local rng = Rng.new(99)
		for _ = 1, 2000 do
			local v = rng:next()
			T.expect(v >= 0 and v < 1).toBe(true)
		end
	end)

	T.it("int(a, b) is inclusive and hits both ends", function()
		local rng = Rng.new(7)
		local seen = {}
		for _ = 1, 2000 do
			local v = rng:int(3, 6)
			T.expect(v).toBeBetween(3, 6)
			T.expect(v % 1).toBe(0)
			seen[v] = true
		end
		T.expect(seen).toEqual({ [3] = true, [4] = true, [5] = true, [6] = true })
	end)

	T.it("int(a, a) returns a and rejects b < a", function()
		local rng = Rng.new(7)
		T.expect(rng:int(5, 5)).toBe(5)
		T.expect(function()
			rng:int(5, 4)
		end).toThrow()
	end)

	T.it("float(a, b) stays in range", function()
		local rng = Rng.new(11)
		for _ = 1, 1000 do
			local v = rng:float(-2.5, 4)
			T.expect(v >= -2.5 and v < 4).toBe(true)
		end
	end)

	T.it("weighted() follows the weights roughly and skips zero weights", function()
		local rng = Rng.new(2024)
		local counts = { a = 0, b = 0, c = 0 }
		for _ = 1, 10000 do
			local key = rng:weighted({ a = 1, b = 3, c = 0 })
			counts[key] += 1
		end
		T.expect(counts.c).toBe(0)
		T.expect(counts.b / counts.a).toBeNear(3, 0.4)
	end)

	T.it("weighted() is deterministic for a seed", function()
		local weights = { sword = 5, shield = 2, ring = 1 }
		local a, b = Rng.new(5), Rng.new(5)
		for _ = 1, 50 do
			T.expect(a:weighted(weights)).toBe(b:weighted(weights))
		end
	end)

	T.it("weighted() rejects empty weights", function()
		T.expect(function()
			Rng.new(1):weighted({ a = 0 })
		end).toThrow("no positive weights")
	end)

	T.it("pick() returns list elements and rejects empty lists", function()
		local rng = Rng.new(3)
		local list = { "x", "y", "z" }
		for _ = 1, 100 do
			T.expect(table.find(list, rng:pick(list)) ~= nil).toBe(true)
		end
		T.expect(function()
			rng:pick({})
		end).toThrow("empty list")
	end)

	T.it("shuffle() keeps all elements", function()
		local list = { 1, 2, 3, 4, 5, 6, 7, 8 }
		Rng.new(8):shuffle(list)
		table.sort(list)
		T.expect(list).toEqual({ 1, 2, 3, 4, 5, 6, 7, 8 })
	end)
end)

return nil
