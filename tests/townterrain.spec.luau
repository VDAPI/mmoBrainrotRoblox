--!strict
local T = require("./Test")
local TownTerrain = require("../src/shared/Logic/TownTerrain")
local Town = require("../src/shared/Data/Town")
local vectors = require("./fixtures/cityHeights")

T.describe("TownTerrain", function()
	T.it("matches the Python reference heights", function()
		local worst, at = 0, ""
		for _, v in vectors do
			local h = TownTerrain.heightAt(v[1], v[2])
			local diff = math.abs(h - v[3])
			if diff > worst then
				worst, at = diff, `{v[1]},{v[2]} lua {h} py {v[3]}`
			end
		end
		if worst > 1e-3 then
			error(`worst {worst} at {at}`)
		end
	end)
	T.it("paints the surface materials from the plan", function()
		local city = Town.city
		local function at(x: number, z: number): string
			return TownTerrain.materialAt(x, z, TownTerrain.heightAt(x, z), 0)
		end
		T.expect(at(city.spawn.x, city.spawn.z)).toBe("Limestone")
		T.expect(at(city.arena.x, city.arena.z)).toBe("Sand")
		local known = {}
		for _, name in TownTerrain.MATERIALS do
			known[name] = true
		end
		for _, street in city.streets do
			local a, b = street.pts[1], street.pts[2]
			local m = at((a[1] + b[1]) / 2, (a[2] + b[2]) / 2)
			T.expect(known[m]).toBe(true)
		end
		local river = city.terrain.river.pts[2]
		T.expect(at(river[1], river[2])).toBe("Mud")
		for x = -400, 400, 40 do
			for z = -400, 400, 40 do
				T.expect(known[at(x, z)]).toBe(true)
			end
		end
	end)

	T.it("fills voxel blocks for WriteVoxels", function()
		local spawn = Town.city.spawn
		local x0 = math.floor(spawn.x / 4) * 4
		local z0 = math.floor(spawn.z / 4) * 4
		local block = TownTerrain.voxels(x0, z0, 2, 3, -12, 10)
		T.expect(#block.materials).toBe(2)
		T.expect(#block.materials[1]).toBe(10)
		T.expect(#block.materials[1][1]).toBe(3)
		local h = TownTerrain.heightAt(x0 + 2, z0 + 2)
		for j = 1, 10 do
			local y = -12 + 4 * (j - 1)
			local o = block.occupancy[1][j][1]
			T.expect(o >= 0 and o <= 1).toBe(true)
			if y + 4 <= h then
				T.expect(o).toBe(1)
			elseif y >= h then
				T.expect(o).toBe(0)
				T.expect(block.materials[1][j][1]).toBe("Air")
			end
		end
		-- the river is water up to the water level
		local p = Town.city.terrain.river.pts[2]
		local rx, rz = math.floor(p[1] / 4) * 4, math.floor(p[2] / 4) * 4
		local wet = TownTerrain.voxels(rx, rz, 1, 1, -12, 4)
		local hasWater = false
		for j = 1, 4 do
			if wet.materials[1][j][1] == "Water" then
				hasWater = true
			end
		end
		T.expect(hasWater).toBe(true)
	end)

	T.it("knows open ground for placing characters", function()
		local city = Town.city
		T.expect(TownTerrain.isOpen(city.spawn.x, city.spawn.z)).toBe(true)
		for _, gate in city.gates do
			T.expect(TownTerrain.isOpen(gate.arrive[1], gate.arrive[2])).toBe(true)
		end
		for _, lot in city.lots do
			T.expect(TownTerrain.isOpen(lot.x, lot.z)).toBe(false)
		end
		T.expect(TownTerrain.isOpen(0, 380)).toBe(false) -- outside the walls
	end)
end)
