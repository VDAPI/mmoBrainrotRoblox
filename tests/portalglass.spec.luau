--!strict
-- Studio review 2026-10-21 (Moss Cave on the Meadows: the portal's purple glow gone): Roblox draws no transparent part
-- behind a Glass part, and the water curtain over the cave's mouth was Glass 1.6 studs before the portal's veil. No
-- Glass piece of any map's dressing (Logic/WorldGen, the city's TownGen) stands before a portal's veil: in the box from
-- the veil out over the arch's width and height on its face (-Z of the portal's frame), on both sides of an open arch
-- between maps and of a city gate. The Moss Cave's curtain hangs behind the veil now, before the dark hole.

local CaveMouth = require("../src/shared/Data/CaveMouth")
local MapTerrain = require("../src/shared/Logic/MapTerrain")
local PortalClearance = require("./PortalClearance")
local Portals = require("../src/shared/Data/Portals")
local Test = require("./Test")
local Town = require("../src/shared/Data/Town")
local TownGen = require("../src/shared/Logic/TownGen")
local TownTerrain = require("../src/shared/Logic/TownTerrain")
local Water = require("../src/shared/Logic/MeadowsGen/Water")
local WorldGen = require("../src/shared/Logic/WorldGen")

local describe, it, expect = Test.describe, Test.it, Test.expect

type Mat = { number }
type Vec = { number }

local function ry(deg: number): Mat
	local r = math.rad(deg)
	local c, s = math.cos(r), math.sin(r)
	return { c, 0, s, 0, 1, 0, -s, 0, c }
end

local function mul(a: Mat, b: Mat): Mat
	local out = table.create(9, 0)
	for i = 0, 2 do
		for j = 0, 2 do
			out[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[j + 4] + a[i * 3 + 3] * b[j + 7]
		end
	end
	return out
end

local function transpose(a: Mat): Mat
	return { a[1], a[4], a[7], a[2], a[5], a[8], a[3], a[6], a[9] }
end

local function apply(a: Mat, v: Vec): Vec
	return {
		a[1] * v[1] + a[2] * v[2] + a[3] * v[3],
		a[4] * v[1] + a[5] * v[2] + a[6] * v[3],
		a[7] * v[1] + a[8] * v[2] + a[9] * v[3],
	}
end

local DEPTH = 16 -- studs before the veil a Glass piece would hide it from (the camera stands farther)
local A = Portals.ARCH
-- the arch's opening and a little round it, from the ground up, before the veil (z < 0) or behind it
local FRONT = {
	center = { 0, A.height / 2 + 1, -DEPTH / 2 + 0.15 },
	half = { A.pillarX + 4, A.height / 2 + 1, DEPTH / 2 + 0.15 },
}
local BACK = { center = { 0, FRONT.center[2], DEPTH / 2 - 0.15 }, half = FRONT.half }

-- A veil to keep Glass from: its frame (rotation, centre at the ground of the arch or the gate field's centre) and
-- the boxes in that frame.
type Veil = { name: string, x: number, y: number, z: number, inv: Mat, boxes: { { center: Vec, half: Vec } } }

-- Every Glass piece of `builds` inside a box of a veil: "<veil> <build> #<piece>".
local function glassBefore(veils: { Veil }, builds: { any }): { string }
	local out = {}
	for _, b in builds do
		local frame = ry(b.at.rot)
		for _, v in veils do
			if (b.at.x - v.x) ^ 2 + (b.at.z - v.z) ^ 2 < 160 ^ 2 then
				local rot = mul(v.inv, frame)
				for k, piece in b.bp.pieces do
					if piece.m == "Glass" then
						local world = apply(frame, piece.p)
						local c =
							apply(v.inv, { b.at.x + world[1] - v.x, b.at.y + world[2] - v.y, b.at.z + world[3] - v.z })
						local h = { piece.size[1] / 2, piece.size[2] / 2, piece.size[3] / 2 }
						for _, box in v.boxes do
							if PortalClearance.overlaps(c, mul(rot, piece.r), h, box.center, box.half) then
								table.insert(out, `{v.name} {b.name} #{k} at ({c[1]}, {c[2]}, {c[3]})`)
								break
							end
						end
					end
				end
			end
		end
	end
	return out
end

describe("Portals: no Glass before a veil (studio review 2026-10-21)", function()
	it("keeps every Glass piece of every map's dressing out from before its portals", function()
		local checked = 0
		for _, mapId in WorldGen.maps() do
			local gen = WorldGen.get(mapId)
			local veils: { Veil } = {}
			for _, p in Portals.onMap(mapId) do
				-- an open arch between maps is seen from both sides; a cave mouth, an exit and a gate from their face
				local boxes = if p.kind == "portal" then { FRONT, BACK } else { FRONT }
				table.insert(veils, {
					name = p.id,
					x = p.x,
					y = MapTerrain.height(mapId, p.x, p.z) or 0,
					z = p.z,
					inv = transpose(ry(p.rot)),
					boxes = boxes,
				})
			end
			if gen and #veils > 0 then
				checked += #veils
				local hits = glassBefore(veils, gen.all())
				if #hits > 0 then
					error(`{mapId}: Glass before a portal's veil:\n{table.concat(hits, "\n")}`)
				end
			end
		end
		expect(checked >= 30).toBe(true)
	end)

	it("keeps Glass from both sides of the city gates' fields", function()
		local builds = TownGen.all(Town.city, TownTerrain.heightAt) :: any
		local veils: { Veil } = {}
		for _, b in builds do
			for _, piece in b.bp.pieces do
				if piece.tag == "portal" then
					local frame = ry(b.at.rot)
					local w = apply(frame, piece.p)
					local half = { piece.size[1] / 2 + 3, piece.size[2] / 2 + 2, DEPTH / 2 }
					table.insert(veils, {
						name = b.name,
						x = b.at.x + w[1],
						y = b.at.y + w[2],
						z = b.at.z + w[3],
						inv = transpose(mul(frame, piece.r)),
						boxes = {
							{ center = { 0, 0, -DEPTH / 2 }, half = half },
							{ center = { 0, 0, DEPTH / 2 }, half = half },
						},
					})
				end
			end
		end
		expect(#veils).toBe(4)
		local hits = glassBefore(veils, builds)
		if #hits > 0 then
			error(`city: Glass before a gate's field:\n{table.concat(hits, "\n")}`)
		end
	end)

	it("hangs the Moss Cave's curtain behind the veil, before the dark hole, out of the arch", function()
		local gen = assert(WorldGen.get("meadows"), "meadows generator")
		local portal = assert(Portals.get("meadows_meadows_cave"), "the Moss Cave's mouth")
		local box = assert(Portals.clearance("cave"), "cave clearance")
		-- the dark hole of World/Prefabs.caveMouth (Data/CaveMouth) behind the veil
		local hole = CaveMouth.HOLE.p[3] - CaveMouth.HOLE.size[3] / 2
		expect(hole > 2).toBe(true)
		local sheets = 0
		for _, b in gen.all() do
			if b.name == "CaveCurtain" then
				expect({ b.at.x, b.at.z, b.at.rot }).toEqual({ portal.x, portal.z, portal.rot })
				for _, piece in b.bp.pieces do
					expect(piece.m).toBe("SmoothPlastic")
					local z, d = piece.p[3], piece.size[3] / 2
					expect(z - d > box.center[3] + box.half[3]).toBe(true)
					expect(z + d < hole).toBe(true)
					sheets += 1
				end
			end
		end
		expect(sheets).toBe(3)
		expect(Water.CURTAIN_Z > 0).toBe(true)
	end)
end)

return nil
