--!strict
-- 2026-10-31 (the owner's tester: "the doors of the cottages, and the cottages, go into the ground"): the terrain is
-- drawn at the height function (Logic/TerrainLayers fills the cells half a voxel under it, as Roblox draws the
-- surface that much higher), and every ordinary house of the city stands on its level pad (Logic/LotPads): its door
-- sill over the ground before it, its plinth neither buried nor floating (the stone skirt reaches the ground).

local Kit = require("../src/shared/Data/Kit")
local KitPick = require("../src/shared/Logic/KitPick")
local LotPads = require("../src/shared/Logic/LotPads")
local T = require("./Test")
local TerrainLayers = require("../src/shared/Logic/TerrainLayers")
local Town = require("../src/shared/Data/Town")
local TownGen = require("../src/shared/Logic/TownGen")
local TownTerrain = require("../src/shared/Logic/TownTerrain")

local city = Town.city
local V = TerrainLayers.VOXEL
-- the lowest door sill over the model's foot (Studio 2026-10-31: 1.5 to 2.2 studs at the city's 1.6x to 2x scale)
local SILL = 1.5

-- The ground Roblox draws from the written voxels: the column centres (the writer's blocks start on the 4-stud grid)
-- and the surface between them.
local columns: { [number]: number } = {}
local function drawn(x: number, z: number): number
	local fx, fz = (x - V / 2) / V, (z - V / 2) / V
	local i, k = math.floor(fx), math.floor(fz)
	local tx, tz = fx - i, fz - k
	local function at(a: number, b: number): number
		local key = a * 100000 + b
		local h = columns[key]
		if not h then
			h = TownTerrain.heightAt(V * a + V / 2, V * b + V / 2)
			columns[key] = h
		end
		return h :: number
	end
	local a, b, c, d = at(i, k), at(i + 1, k), at(i, k + 1), at(i + 1, k + 1)
	return a + (b - a) * tx + (c - a) * tz + (a - b - c + d) * tx * tz
end

type Item = { name: string, tag: string, bp: any, at: { x: number, y: number, z: number, rot: number } }

local houses: { [string]: Item } = {}
for _, b in TownGen.all(city, TownTerrain.heightAt) :: { Item } do
	if b.tag == "house" then
		houses[b.name] = b
	end
end

T.describe("Level house pads (2026-10-31)", function()
	T.it("fills the voxels half a voxel under the heights, so the drawn ground and water are the functions'", function()
		for _, h in { -3.3, 0, 0.54, 2, 3.75, 4, 5.9 } do
			local block = TerrainLayers.voxels(function()
				return h, nil
			end, function()
				return "Ground"
			end, function()
				return nil
			end, 0, 0, 1, 1, -16, 8)
			-- Roblox draws the top filled cell's surface at its centre plus its occupancy in voxels
			local top = -math.huge
			for j = 1, 8 do
				local o = block.occupancy[1][j][1]
				if o > 0 then
					top = -16 + V * (j - 1) + V / 2 + V * o
				end
			end
			T.expect(math.abs(top - h) < 1e-6).toBe(true)
		end
		-- a pond 3 studs deep: the water drawn at its level
		local block = TerrainLayers.voxels(function()
			return -2.5, nil
		end, function()
			return "Mud"
		end, function()
			return 0.5
		end, 0, 0, 1, 1, -16, 8)
		local water = -math.huge
		for j = 1, 8 do
			if block.materials[1][j][1] == "Water" then
				water = -16 + V * (j - 1) + V / 2 + V * block.occupancy[1][j][1]
			end
		end
		T.expect(math.abs(water - 0.5) < 1e-6).toBe(true)
	end)

	T.it("keeps the plan's ground for the Python reference and the river", function()
		local river = city.terrain.river
		for _, p in river.pts do
			T.expect(TownTerrain.heightAt(p[1], p[2])).toBe(TownTerrain.planHeight(p[1], p[2]))
		end
		T.expect(#TownTerrain.pads().pads).toBe(#city.lots)
	end)

	T.it("seats every house model without a sink, just under its pad", function()
		for i, lot in city.lots do
			local b = assert(houses[lot.id], lot.id)
			local slot = b.bp.kits[1]
			T.expect(string.sub(slot.key, 1, 6)).toBe("house:")
			local choice = assert(KitPick.pick(slot.key, "city", lot.x, lot.z, slot.s), slot.key)
			T.expect(choice.sink).toBe(0)
			T.expect(choice.variant.door ~= nil).toBe(true)
			local foot = b.at.y + slot.p[2]
			local level = LotPads.level(TownTerrain.pads(), i)
			if math.abs(foot - (level - LotPads.SEAT)) > 1e-6 then
				error(`{lot.id}: foot {foot}, pad {level}`)
			end
		end
		for key, entry in Kit.slots do
			if string.sub(key, 1, 6) == "house:" then
				for _, v in (entry :: any).city :: { Kit.Variant } do
					T.expect(v.sink == nil or v.sink == 0).toBe(true)
				end
			end
		end
	end)

	T.it("keeps the ground before every door under its sill", function()
		for _, lot in city.lots do
			local b = assert(houses[lot.id], lot.id)
			local foot = b.at.y + b.bp.kits[1].p[2]
			local W, D = LotPads.footprint(lot)
			local half = LotPads.doorHalf(lot)
			local r = math.rad(lot.rot)
			local c, s = math.cos(r), math.sin(r)
			for ix = -6, 6 do
				for _, dz in { 0.5, 1, 2 } do
					-- from the deepest front the model can have (a shallower model's door stands on its pad)
					local lx, lz = ix / 6 * math.min(half, W / 2), -D / 2 - dz
					local g = drawn(lot.x + lx * c + lz * s, lot.z - lx * s + lz * c)
					if g > foot + SILL - 1 then
						error(`{lot.id}: ground {g} before the door, foot {foot}`)
					end
				end
			end
		end
	end)

	T.it("neither buries nor floats a plinth: the outline's ground between the skirt's foot and the plinth", function()
		local skirts = 0
		for _, lot in city.lots do
			local b = assert(houses[lot.id], lot.id)
			local slot = b.bp.kits[1]
			local foot = b.at.y + slot.p[2]
			local bottom = foot - (slot.skirt or 0)
			if slot.skirt then
				skirts += 1
			end
			local W, D = LotPads.footprint(lot)
			local r = math.rad(lot.rot)
			local c, s = math.cos(r), math.sin(r)
			for t = -10, 10 do
				for _, p in { { t / 10, -1 }, { t / 10, 1 }, { -1, t / 10 }, { 1, t / 10 } } do
					local lx, lz = p[1] * W / 2, p[2] * D / 2
					local g = drawn(lot.x + lx * c + lz * s, lot.z - lx * s + lz * c)
					if g > foot + 0.5 then
						error(`{lot.id}: plinth buried {g - foot} at {lx},{lz}`)
					elseif g < bottom then
						error(`{lot.id}: floats {bottom - g} over the ground at {lx},{lz}`)
					end
				end
			end
		end
		-- the market's ring and the plateau's edges: houses on a slope show a stone foundation
		T.expect(skirts > 20).toBe(true)
	end)

	T.it("stands the lamps and the wells on the low side of a slope", function()
		for _, b in TownGen.all(city, TownTerrain.heightAt) :: { Item } do
			if b.tag == "lamp" or b.tag == "well" then
				for i = 0, 7 do
					local a = i * math.pi / 4
					local g = drawn(b.at.x + math.cos(a) * 0.7, b.at.z + math.sin(a) * 0.7)
					if g < b.at.y - 0.35 then
						error(`{b.name} at {b.at.x},{b.at.z} floats {b.at.y - g}`)
					end
				end
			end
		end
	end)
end)
