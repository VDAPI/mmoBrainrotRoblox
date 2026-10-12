--!strict
local Config = require("../src/shared/Config")
local LevelCurves = require("../src/shared/Logic/LevelCurves")
local Potions = require("../src/shared/Logic/Potions")
local T = require("./Test")

T.describe("LevelCurves", function()
	T.it("every curve starts at { 20, 1 }, ends on MaxLevel and has the 45 and 70 anchors", function()
		T.expect(#LevelCurves.ids() > 0).toBe(true)
		for _, id in LevelCurves.ids() do
			local anchors = LevelCurves.anchors(id)
			T.expect({ id = id, first = anchors[1] }).toEqual({ id = id, first = { 20, 1 } })
			T.expect({ id = id, last = anchors[#anchors][1] }).toEqual({ id = id, last = Config.MaxLevel })
			local levels: { [number]: boolean } = {}
			for i, anchor in anchors do
				levels[anchor[1]] = true
				T.expect({ id = id, positive = anchor[2] > 0 }).toEqual({ id = id, positive = true })
				if i > 1 then
					T.expect({ id = id, rising = anchor[1] > anchors[i - 1][1] }).toEqual({ id = id, rising = true })
				end
			end
			T.expect({ id = id, has45 = levels[45] == true, has70 = levels[70] == true }).toEqual({
				id = id,
				has45 = true,
				has70 = true,
			})
		end
	end)

	T.it("is exactly 1 up to level 20", function()
		for _, id in LevelCurves.ids() do
			for level = 1, 20 do
				T.expect(LevelCurves.at(id, level)).toBe(1)
			end
			T.expect(LevelCurves.at(id, 0)).toBe(1)
		end
	end)

	T.it("hits the anchors and stays between them without overshooting", function()
		for _, id in LevelCurves.ids() do
			local anchors = LevelCurves.anchors(id)
			for i, anchor in anchors do
				T.expect(LevelCurves.at(id, anchor[1])).toBeNear(anchor[2])
				if i > 1 then
					local a = anchors[i - 1]
					local low, high = math.min(a[2], anchor[2]), math.max(a[2], anchor[2])
					local rising = anchor[2] >= a[2]
					local previous = LevelCurves.at(id, a[1])
					for level = a[1] + 1, anchor[1] do
						local value = LevelCurves.at(id, level)
						T.expect(value).toBeBetween(low - 1e-9, high + 1e-9)
						local monotonic = if rising then value >= previous - 1e-9 else value <= previous + 1e-9
						T.expect({ id = id, level = level, monotonic = monotonic }).toEqual({
							id = id,
							level = level,
							monotonic = true,
						})
						previous = value
					end
				end
			end
		end
	end)

	T.it("follows a power law between anchors and stays flat above the last one", function()
		T.expect(LevelCurves.at("manaCost.Mage", 30)).toBeNear(math.sqrt(1.4))
		T.expect(LevelCurves.at("manaCost.Mage", 45)).toBeNear(1.4)
		T.expect(LevelCurves.at("potionCooldown", 30)).toBeNear(2)
		T.expect(LevelCurves.at("potionCooldown", 100)).toBeNear(6.67)
		for _, id in LevelCurves.ids() do
			local anchors = LevelCurves.anchors(id)
			T.expect(LevelCurves.at(id, Config.MaxLevel + 20)).toBe(anchors[#anchors][2])
		end
		T.expect(LevelCurves.has("heal")).toBe(true)
		T.expect(LevelCurves.has("manaCost.Cleric")).toBe(false)
		local ok = pcall(LevelCurves.at, "noSuchCurve", 50)
		T.expect(ok).toBe(false)
	end)

	T.it("DEX factor is 1 up to the rating level, then rating level / L", function()
		T.expect(LevelCurves.dexRatingLevel()).toBe(20)
		for level = 1, 20 do
			T.expect(LevelCurves.dexFactor(level)).toBe(1)
		end
		T.expect(LevelCurves.dexFactor(40)).toBeNear(0.5)
		T.expect(LevelCurves.dexFactor(100)).toBeNear(0.2)
	end)
end)

T.describe("Potions.interval", function()
	T.it("1.5 s up to 20, 6 s at 45, ~10 s from 70", function()
		T.expect(Potions.interval(1)).toBe(1.5)
		T.expect(Potions.interval(20)).toBe(1.5)
		T.expect(Potions.interval(30)).toBeNear(3.0)
		T.expect(Potions.interval(45)).toBeNear(6.0)
		T.expect(Potions.interval(70)).toBeNear(1.5 * 6.67)
		T.expect(Potions.interval(100)).toBeNear(1.5 * 6.67)
	end)
end)

return nil
