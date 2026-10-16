--!strict
-- S134h: the two Elite IIs of every cave (Logic/AreaSpawns.cave): A ({id}_elite2) in the deepest fighting room, B
-- ({id}_elite2b) in the fighting room farthest from it, fixed kinds (no `choices`), at least ELITE2_SEPARATION apart,
-- both in the spawn area of a room (0.65 r), never in the entrance or the boss antechamber, each with the cave's Elite II
-- respawn (S134e); three normal groups in the big rooms.

local Areas = require("../src/shared/Data/Areas")
local AreaSpawns = require("../src/shared/Logic/AreaSpawns")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

describe("Cave spawners: two Elite IIs (S134h)", function()
	it("gives every cave two Elite II spawners of its two kinds, apart, in the cores of fighting rooms", function()
		for _, cave in Areas.caves.list do
			local rooms = AreaSpawns.caveRooms(cave)
			local last = if cave.boss then #rooms - 1 else #rooms
			local found: { [string]: any } = {}
			local n = 0
			for _, s in AreaSpawns.cave(cave) do
				if s.variant == "elite2" then
					n += 1
					found[s.id] = s
					expect(s.choices).toBeNil()
					expect(s.count).toBe(1)
					expect(s.respawn).toEqual(AreaSpawns.elite2Respawn(cave.levels[2]))
					-- in the spawn area of a fighting room (not the entrance, not the antechamber)
					local inRoom = false
					for i = 2, last do
						local r = rooms[i]
						local d = math.sqrt((s.position.x - r.x) ^ 2 + (s.position.z - r.z) ^ 2)
						if d <= r.r * 0.65 + 1 then
							inRoom = true
						end
					end
					expect(`{s.id} {inRoom}`).toBe(`{s.id} true`)
					for _, i in { 1, if cave.boss then #rooms else 0 } do
						local r = rooms[i]
						if r then
							local d = math.sqrt((s.position.x - r.x) ^ 2 + (s.position.z - r.z) ^ 2)
							expect(`{s.id} room {i} {d > r.r}`).toBe(`{s.id} room {i} true`)
						end
					end
				end
			end
			expect(n).toBe(2)
			local a, b = found[`{cave.id}_elite2`], found[`{cave.id}_elite2b`]
			expect(a ~= nil and b ~= nil).toBe(true)
			expect(a.monster).toBe(cave.elite2[1])
			expect(b.monster).toBe(cave.elite2[2])
			local d = math.sqrt((a.position.x - b.position.x) ^ 2 + (a.position.z - b.position.z) ^ 2)
			expect(`{cave.id} {d >= AreaSpawns.ELITE2_SEPARATION}`).toBe(`{cave.id} true`)
		end
	end)

	it("puts three normal groups in the big rooms and keeps the respawn of S134e", function()
		expect(AreaSpawns.THREE_GROUPS_RADIUS).toBe(70)
		local big = 0
		for _, cave in Areas.caves.list do
			local rooms = AreaSpawns.caveRooms(cave)
			local last = if cave.boss then #rooms - 1 else #rooms
			local expected = 0
			for i = 2, last do
				local r = rooms[i]
				expected += if r.r >= AreaSpawns.THREE_GROUPS_RADIUS then 3 elseif r.r >= 45 then 2 else 1
				big += if r.r >= AreaSpawns.THREE_GROUPS_RADIUS then 1 else 0
			end
			local normal = 0
			for _, s in AreaSpawns.cave(cave) do
				normal += if s.variant == "normal" then 1 else 0
			end
			expect(`{cave.id} {normal}`).toBe(`{cave.id} {expected}`)
		end
		expect(big > 0).toBe(true)
		-- S134e: 300 s + 3 s a level, +-15 %
		local mid = AreaSpawns.elite2Respawn(66)
		expect(math.abs((mid.min + mid.max) / 2 - (300 + 3 * 66)) <= 1).toBe(true)
	end)
end)
