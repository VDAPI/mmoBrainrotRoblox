--!strict
-- Studio re-measure 2026-11-01: kit models on the ground Roblox draws (Logic/KitSeat). Rocks on a ravine's lip sank
-- 19 studs to its foot and pines under its wall had the wall in their crowns: the generators leave those slots out.

local Blueprint = require("../src/shared/Logic/TownGen/Blueprint")
local KitSeat = require("../src/shared/Logic/KitSeat")
local MapTerrain = require("../src/shared/Logic/MapTerrain")
local T = require("./Test")
local WorldGen = require("../src/shared/Logic/WorldGen")

T.describe("Kit models on the drawn ground (2026-11-01)", function()
	T.it("draws the ground from the 4-stud columns' centres, bilinear between them", function()
		local function height(x: number, z: number): number
			return x * 0.5 + z * z * 0.01
		end
		T.expect(KitSeat.drawn(height, 6, 10)).toBe(height(6, 10))
		local mid = KitSeat.drawn(height, 8, 10)
		T.expect(math.abs(mid - (height(6, 10) + height(10, 10)) / 2) < 1e-9).toBe(true)
		-- a small prop on even ground stands on it, on a slope at most BURY in it
		T.expect(KitSeat.seat(function()
			return 3
		end, 0, 0, 1)).toBe(3 - KitSeat.GAP)
		local foot = KitSeat.seat(function(x: number): number
			return x
		end, 0, 0, 1)
		local lo, hi = KitSeat.range(function(x: number): number
			return x
		end, 0, 0, 1)
		T.expect(math.abs(foot - (hi - KitSeat.BURY)) < 1e-9).toBe(true)
		T.expect(foot > lo).toBe(true)
	end)

	T.it("drops a kit slot with its pieces and keeps the later slots' pieces theirs", function()
		local bp = Blueprint.new(1)
		for i = 1, 3 do
			bp:beginKit("rock", i, 0, 0, 1, "shell")
			bp:box(1, 1, 1, i, 0, 0, { c = "#808080", m = "Rock", lod = "shell" })
			bp:box(1, 1, 1, i, 1, 0, { c = "#808080", m = "Rock", lod = "detail" })
			bp:endKit()
		end
		bp:box(1, 1, 1, 9, 0, 0, { c = "#808080", m = "Rock", lod = "shell" })
		bp:dropKit(2)
		T.expect(#bp.kits).toBe(2)
		T.expect(#bp.pieces).toBe(5)
		T.expect(bp.shell).toBe(3)
		T.expect(bp.detail).toBe(2)
		T.expect(bp.kits[2].p[1]).toBe(3)
		for _, piece in bp.pieces do
			if piece.k then
				T.expect(bp.kits[piece.k].p[1]).toBe(piece.p[1])
			end
		end
	end)

	T.it("leaves no rock on a cliff and no tree with a wall in its crown on the height-field maps", function()
		for _, id in { "meadows", "duskwood", "ashen", "frostpeak" } do
			local function height(x: number, z: number): number
				return MapTerrain.height(id, x, z) :: number
			end
			local gen = assert(WorldGen.get(id), id)
			local rocks, trees = 0, 0
			for _, b in gen.all() do
				local r = math.rad(b.at.rot or 0)
				local c, s = math.cos(r), math.sin(r)
				for _, slot in b.bp.kits do
					if slot.key == "rock" or string.sub(slot.key, 1, 5) == "tree:" then
						local x, z = b.at.x + slot.p[1] * c + slot.p[3] * s, b.at.z - slot.p[1] * s + slot.p[3] * c
						if KitSeat.cliff(height, slot.key, slot.s, x, b.at.y + slot.p[2], z) then
							error(`{id}: {slot.key} at {x},{z} stands on a cliff`)
						end
						if slot.key == "rock" then
							rocks += 1
						else
							trees += 1
						end
					end
				end
				for _, piece in b.bp.pieces do
					if piece.k and not b.bp.kits[piece.k] then
						error(`{id}: {b.name} has a piece of a dropped slot`)
					end
				end
			end
			-- the generators keep their rocks and their forests (the cliffs take a handful)
			T.expect(rocks > 250).toBe(true)
			T.expect(trees > 300).toBe(true)
		end
	end)
end)
