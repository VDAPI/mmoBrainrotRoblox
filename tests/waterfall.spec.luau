--!strict
-- W30 (owner: "na mapie Niedźwiedzi Jar ... w aktualnym nie ma spadającej wody"): the waterfall of Bear Ravine
-- (MeadowsGen/Water) falls clear of the rock wall from the edge of the plateau into the pool (before, its sheets ran
-- from the lip to the foot of the wall and lay inside the rock), the middle sheet carries the client's falling water
-- ("waterfall"), foam lies on the pool, the wet rocks stay off the curtain and the client hangs its beams on it.

local fs = require("@lune/fs")

local MeadowsTerrain = require("../src/shared/Logic/MeadowsTerrain")
local Test = require("./Test")
local Water = require("../src/shared/Logic/MeadowsGen/Water")
local WorldGen = require("../src/shared/Logic/WorldGen")

local describe, it, expect = Test.describe, Test.it, Test.expect

type Vec = { number }

local function ry(deg: number): { number }
	local r = math.rad(deg)
	local c, s = math.cos(r), math.sin(r)
	return { c, 0, s, 0, 1, 0, -s, 0, c }
end

local function apply(a: { number }, v: Vec): Vec
	return {
		a[1] * v[1] + a[2] * v[2] + a[3] * v[3],
		a[4] * v[1] + a[5] * v[2] + a[6] * v[3],
		a[7] * v[1] + a[8] * v[2] + a[9] * v[3],
	}
end

local function waterfall(): any
	local gen = assert(WorldGen.get("meadows"))
	for _, b in gen.all() do
		if b.name == "Waterfall" then
			return b
		end
	end
	error("no Waterfall build on the Meadows")
end

-- World point of the piece-local point `v` of piece `piece` of build `b`.
local function world(b: any, piece: any, v: Vec): Vec
	local frame = ry(b.at.rot)
	local inBuild = apply(piece.r, v)
	local p = apply(frame, { piece.p[1] + inBuild[1], piece.p[2] + inBuild[2], piece.p[3] + inBuild[3] })
	return { b.at.x + p[1], b.at.y + p[2], b.at.z + p[3] }
end

describe("Bear Ravine waterfall (W30)", function()
	it("starts at the edge of the brook's water and ends in the pool", function()
		local g = Water.fallGeometry()
		expect(MeadowsTerrain.water(g.x, g.z) ~= nil).toBe(true)
		expect(MeadowsTerrain.water(g.x + g.dx * g.horiz, g.z + g.dz * g.horiz) ~= nil).toBe(true)
		expect(g.top - g.pool > 12).toBe(true)
		expect(g.horiz > 3 and g.horiz < 20).toBe(true)
	end)

	it("keeps every sheet of falling water out of the rock wall", function()
		local b = waterfall()
		local top = Water.fallGeometry().top
		local sheets = 0
		for _, piece in b.bp.pieces do
			if piece.m == "Glass" then
				sheets += 1
				local w, len, d = piece.size[1], piece.size[2], piece.size[3]
				-- along the sheet (local y) from its top to just above the pool, across its width, on its back face
				for t = -0.5, 0.5, 0.05 do
					for u = -0.5, 0.5, 0.25 do
						local p = world(b, piece, { u * w, t * len, d / 2 })
						local ground = MeadowsTerrain.height(p[1], p[3])
						-- (the top 1.5 studs pour over the edge's bank, the bottom 0.8 go into the pool)
						if p[2] > b.at.y + 0.8 and p[2] < top - 1.5 and p[2] < ground + 0.3 then
							error(
								string.format(
									"sheet in the rock at %.1f, %.1f, %.1f (ground %.1f)",
									p[1],
									p[2],
									p[3],
									ground
								)
							)
						end
					end
				end
			end
		end
		expect(sheets).toBe(3)
	end)

	it("tags the middle sheet for the falling water and the pool for foam", function()
		local b = waterfall()
		local tags: { [string]: number } = {}
		for _, piece in b.bp.pieces do
			if piece.tag then
				tags[piece.tag] = (tags[piece.tag] or 0) + 1
			end
		end
		expect(tags.waterfall).toBe(1)
		expect(tags.foam).toBe(1)
	end)

	it("keeps the wet rocks off the curtain", function()
		local b = waterfall()
		local F = Water.FALL
		local reach = F.sideAt + F.side / 2
		local foot = -Water.fallGeometry().horiz
		for _, slot in b.bp.kits do
			-- beside the curtain (the stones further out in the pool lie past its foot)
			if slot.key == "rock" and slot.p[3] > foot - 3 then
				-- a rock is at most 1.5 x its size wide (Kit.rock)
				expect(math.abs(slot.p[1]) - slot.s * 0.75 >= reach - 0.01).toBe(true)
			end
		end
	end)

	it("hangs curved falling-water beams with scrolling streaks on the client, fewer on low graphics", function()
		local fx = fs.readFile("src/client/Controllers/TownFxController.luau")
		expect(string.find(fx, "addFallBeams(part)", 1, true) ~= nil).toBe(true)
		expect(string.find(fx, "TextureMode = Enum.TextureMode.Wrap", 1, true) ~= nil).toBe(true)
		expect(string.find(fx, "FALL_STREAKS * quality.particles", 1, true) ~= nil).toBe(true)
	end)
end)
