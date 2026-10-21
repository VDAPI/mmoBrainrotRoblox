--!strict
-- Owner 2026-10-21 (Studio): the Portal Master stood with his back to the east gate and the city guard behind him showed
-- its plate over his head. Every NPC faces where its data says, and no other NPC's plate lines up behind it seen from
-- where a player talks to it (Logic/Nameplate.npcDistance: the guards' plates show only close by).

local Nameplate = require("../src/shared/Logic/Nameplate")
local Npcs = require("../src/shared/Data/Npcs")
local Town = require("../src/shared/Data/Town")
local TownGeom = require("../src/shared/Logic/TownGeom")
local T = require("./Test")

-- Where the camera looks from while a player talks to an NPC: the player a few studs in front, the camera behind.
local VIEW = 14
-- Two plates closer than this (degrees, seen from the camera) cover each other (a 280 px plate is ~15 degrees wide).
local APART = 10

local function angle(ax: number, az: number, bx: number, bz: number): number
	local la, lb = math.sqrt(ax * ax + az * az), math.sqrt(bx * bx + bz * bz)
	return math.deg(math.acos(math.clamp((ax * bx + az * bz) / (la * lb), -1, 1)))
end

T.describe("NPC places and plates (owner 2026-10-21)", function()
	T.it("turns the Portal Master to the east gate", function()
		local def = assert(Npcs.get("portalmaster"))
		local gate = assert(Town.gate("meadows"))
		local fx, fz = TownGeom.front(def.facing)
		local dx, dz = gate.arrive[1] - def.position.x, gate.arrive[2] - def.position.z
		-- facing the arrivals' landing point and the gate behind it within 30 degrees
		T.expect(angle(fx, fz, dx, dz) < 30).toBe(true)
		T.expect(angle(fx, fz, gate.x - def.position.x, gate.z - def.position.z) < 30).toBe(true)
	end)

	T.it("shows a guard's plate only close by", function()
		T.expect(Nameplate.npcDistance(true) < Nameplate.npcDistance(false)).toBe(true)
		T.expect(Nameplate.npcDistance(nil)).toBe(Nameplate.NPC_DISTANCE)
	end)

	T.it("lines up no plate behind an NPC seen from where a player talks to it", function()
		local bad: { string } = {}
		for _, a in Npcs.list do
			if a.decoration or a.body == "board" then
				continue
			end
			local fx, fz = TownGeom.front(a.facing)
			local vx, vz = a.position.x + fx * VIEW, a.position.z + fz * VIEW
			local ax, az = a.position.x - vx, a.position.z - vz
			local near = math.sqrt(ax * ax + az * az)
			for _, b in Npcs.list do
				if b == a or b.map ~= a.map or b.body == "board" then
					continue
				end
				local bx, bz = b.position.x - vx, b.position.z - vz
				local far = math.sqrt(bx * bx + bz * bz)
				if far > near and far <= Nameplate.npcDistance(b.decoration) and angle(ax, az, bx, bz) < APART then
					table.insert(bad, `{a.id} / {b.id}`)
				end
			end
		end
		T.expect(bad).toEqual({})
	end)

	T.it("keeps the guards off the line from the town street to the Portal Master", function()
		local def = assert(Npcs.get("portalmaster"))
		-- a player walking east to the gate along the street, the camera a dozen studs behind
		for x = 200, 236, 4 do
			local ax, az = def.position.x - x, def.position.z
			for _, id in { "guard1", "guard2" } do
				local guard = assert(Npcs.get(id))
				local gx, gz = guard.position.x - x, guard.position.z
				T.expect({ id, x, angle(ax, az, gx, gz) >= 5 }).toEqual({ id, x, true })
			end
		end
	end)
end)

return nil
