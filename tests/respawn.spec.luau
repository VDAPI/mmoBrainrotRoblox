--!strict
-- S22: where a dead character comes back (Logic/Respawn).

local Respawn = require("../src/shared/Logic/Respawn")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local function spot(inside: boolean?, below: boolean?, blocked: boolean?, free: boolean?): Respawn.Spot
	return {
		inside = if inside == nil then true else inside,
		belowFloor = below == true,
		blocked = blocked == true,
		freeNearby = free == true,
	}
end

describe("Respawn.place", function()
	it("sends 'city' to the city from anywhere", function()
		expect(Respawn.place("grass", "city", spot())).toBe("city")
		expect(Respawn.place("dungeon", "city", spot())).toBe("city")
		expect(Respawn.place("cave", "city", spot(false, true))).toBe("city")
	end)

	it("brings 'here' back where the character fell", function()
		expect(Respawn.place("grass", "here", spot())).toBe("here")
		expect(Respawn.place("cave", "here", spot())).toBe("here")
		expect(Respawn.place("city", "here", spot())).toBe("here")
	end)

	it("uses the dungeon entrance in a dungeon", function()
		expect(Respawn.place("dungeon", "here", spot())).toBe("entrance")
	end)

	it("uses the nearest spawn point under or off the map", function()
		expect(Respawn.place("grass", "here", spot(true, true))).toBe("spawnPoint")
		expect(Respawn.place("snow", "here", spot(false))).toBe("spawnPoint")
	end)

	it("uses a free spot nearby in water or a wall, else the spawn point", function()
		expect(Respawn.place("grass", "here", spot(true, false, true, true))).toBe("here")
		expect(Respawn.place("grass", "here", spot(true, false, true, false))).toBe("spawnPoint")
	end)
end)

describe("Respawn.searchOffsets", function()
	it("stays within the radius, nearest first, all around", function()
		local offsets = Respawn.searchOffsets(20)
		expect(#offsets > 16).toBe(true)
		local last = 0
		for _, o in offsets do
			local d = math.sqrt(o[1] ^ 2 + o[2] ^ 2)
			expect(d <= 20 + 1e-9).toBe(true)
			expect(d >= last - 1e-9).toBe(true)
			last = d
		end
	end)
end)
