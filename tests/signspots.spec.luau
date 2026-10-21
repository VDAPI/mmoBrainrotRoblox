--!strict
-- Owner 2026-10-21 (the forge's "Kuźnia" board stood in front of the smith): no signpost's post or board stands on an
-- NPC's footprint on any map (Logic/SignSpots, Logic/TownSigns), the wandering merchant's stops included.

local MeadowsTerrain = require("../src/shared/Logic/MeadowsTerrain")
local Npcs = require("../src/shared/Data/Npcs")
local RegionTerrain = require("../src/shared/Logic/RegionTerrain")
local SignSpots = require("../src/shared/Logic/SignSpots")
local Town = require("../src/shared/Data/Town")
local TownSigns = require("../src/shared/Logic/TownSigns")
local WanderingMerchant = require("../src/shared/Logic/WanderingMerchant")
local T = require("./Test")

type Point = { id: string, x: number, z: number }

-- The ground the region layouts keep signs off (World/Layouts/meadows, World/RegionLayout ctx.wet).
local function wetOf(map: string): ((x: number, z: number) -> boolean)?
	if map == "meadows" then
		return function(x: number, z: number): boolean
			return MeadowsTerrain.isWater(x, z) or MeadowsTerrain.streamDistance(x, z) < 5
		end
	end
	local terrain = RegionTerrain.get(map)
	if not terrain then
		return nil
	end
	return function(x: number, z: number): boolean
		return terrain.isWater(x, z) or terrain.streamDistance(x, z) < 5 or terrain.lavaDistance(x, z) < 6
	end
end

local function signsOf(map: string): { SignSpots.Spot }
	if map == "city" then
		local out: { SignSpots.Spot } = {}
		for _, sign in TownSigns.list() do
			table.insert(out, { x = sign.x, z = sign.z, rot = sign.rot })
		end
		return out
	end
	return SignSpots.forMap(map, wetOf(map))
end

-- Every NPC that stands on `map`: its spot (the city's from the plan) and the wandering merchant's stops.
local function npcsOf(map: string): { Point }
	local out: { Point } = {}
	for _, def in Npcs.list do
		if def.map == map and def.body ~= "board" then
			table.insert(out, { id = def.id, x = def.position.x, z = def.position.z })
		end
	end
	for _, spot in WanderingMerchant.spotsOf(map) do
		table.insert(out, { id = `wanderer@{spot.id}`, x = spot.x, z = spot.z })
	end
	return out
end

T.describe("Signposts and NPCs (owner 2026-10-21)", function()
	T.it("measures a board 7 studs wide in front of its post", function()
		-- a sign facing north (rot 0): the board runs east-west 0.4 studs north of the post
		local sign = { x = 0, z = 0, rot = 0 }
		T.expect(SignSpots.distance(sign, 0, -0.4)).toBe(0)
		T.expect(math.abs(SignSpots.distance(sign, 5.5, -0.4) - 2) < 1e-9).toBe(true)
		T.expect(math.abs(SignSpots.distance(sign, 0, -3.55) - 3) < 1e-9).toBe(true)
		-- turned a quarter (rot 90, front west): the board runs north-south
		local turned = { x = 0, z = 0, rot = 90 }
		T.expect(math.abs(SignSpots.distance(turned, -0.4, 5.5) - 2) < 1e-9).toBe(true)
		T.expect(SignSpots.covers(turned, -0.4, 3)).toBe(true)
		T.expect(SignSpots.covers(turned, 3, 0)).toBe(false)
	end)

	T.it("turns a prop's offsets like World/Prefabs (front = -sin, -cos)", function()
		local x, z = SignSpots.offset(10, 20, 90, 0, -1)
		T.expect(math.abs(x - 9) < 1e-9 and math.abs(z - 20) < 1e-9).toBe(true)
		x, z = SignSpots.offset(10, 20, 0, 1, 0)
		T.expect(math.abs(x - 11) < 1e-9 and math.abs(z - 20) < 1e-9).toBe(true)
	end)

	T.it("keeps every sign's post and board off every NPC on every map", function()
		local bad: { string } = {}
		local maps: { [string]: boolean } = { city = true }
		for _, def in Npcs.list do
			maps[def.map] = true
		end
		for map in maps do
			local signs = signsOf(map)
			T.expect({ map, #signs > 0 }).toEqual({ map, true })
			for _, npc in npcsOf(map) do
				for _, sign in signs do
					if SignSpots.covers(sign, npc.x, npc.z) then
						table.insert(
							bad,
							`{map}: {npc.id} at {npc.x}, {npc.z} / sign at {math.floor(sign.x)}, {math.floor(sign.z)}`
						)
					end
				end
			end
		end
		T.expect(bad).toEqual({})
	end)

	T.it("puts the forge's sign beside the smith, not in front of him", function()
		local smith = assert(Town.npcSpot("blacksmith"))
		for _, sign in TownSigns.list() do
			if sign.at == "kuznia" then
				T.expect(SignSpots.distance(sign, smith.x, smith.z) >= SignSpots.NPC_RADIUS + 1).toBe(true)
				-- beside him on his right (+X for a smith facing north), about TownSigns.SIDE away
				T.expect(math.abs(sign.x - (smith.x + TownSigns.SIDE)) < 0.01).toBe(true)
			end
		end
	end)

	T.it("names every region by its entrance and signs every cave", function()
		for _, map in { "meadows", "duskwood", "ashen", "frostpeak" } do
			T.expect({ map, SignSpots.nameSign(map) ~= nil }).toEqual({ map, true })
		end
		T.expect(SignSpots.nameSign("city")).toBe(nil)
	end)
end)

return nil
