--!strict
-- 2026-11-01 (owner's tester: crows hanging in the air on Crow Field, flying off as the player came): the decorative
-- birds' perches. A species drew its bird's life point in its blueprint's own frame (a forest tile's, a Build's) as if
-- it were the world, so every dead tree's crow hung round the map's middle; now it marks the point in the blueprint
-- (Blueprint.mark) and the generator puts the marks in the world. Crow Field has no decorative crows at all.

local Areas = require("../src/shared/Data/Areas")
local Blueprint = require("../src/shared/Logic/TownGen/Blueprint")
local MapTerrain = require("../src/shared/Logic/MapTerrain")
local MeadowsGen = require("../src/shared/Logic/MeadowsGen")
local WorldGen = require("../src/shared/Logic/WorldGen")
local WorldKit = require("../src/shared/Logic/WorldGen/Kit")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

-- The life kinds of perched birds and how far their point (the middle of the client's bird) sits over its seat.
local SIT: { [string]: number } = { perch = WorldKit.SIT.perch, vulturePerch = WorldKit.SIT.vulturePerch }

-- How far a world point is from a piece's box, and the height of the way to the box's nearest point.
local function touch(b: any, piece: Blueprint.Piece, wx: number, wy: number, wz: number): (number, number)
	local r = math.rad(b.at.rot or 0)
	local c, s = math.cos(r), math.sin(r)
	local dx, dz = wx - b.at.x, wz - b.at.z
	local d1, d2, d3 = c * dx - s * dz - piece.p[1], wy - b.at.y - piece.p[2], s * dx + c * dz - piece.p[3]
	local m = piece.r
	local q = {
		m[1] * d1 + m[4] * d2 + m[7] * d3,
		m[2] * d1 + m[5] * d2 + m[8] * d3,
		m[3] * d1 + m[6] * d2 + m[9] * d3,
	}
	local way = table.create(3, 0)
	local dist2 = 0
	for i = 1, 3 do
		local h = piece.size[i] / 2
		way[i] = math.clamp(q[i], -h, h) - q[i]
		dist2 += way[i] * way[i]
	end
	return math.sqrt(dist2), m[4] * way[1] + m[5] * way[2] + m[6] * way[3]
end

-- Whether a bird at `p` rests on something: the ground, or a piece its body touches from above (within its sit and a
-- tenth of a stud, the nearest point of the piece at least half as far down as away).
local function rests(mapId: string, builds: { any }, radius: { number }, p: any, sit: number): boolean
	local ground = MapTerrain.height(mapId, p.x, p.z)
	if ground and p.y - ground <= sit + 0.1 and p.y - ground > -0.5 then
		return true
	end
	for i, b in builds do
		if (b.at.x - p.x) ^ 2 + (b.at.z - p.z) ^ 2 <= (radius[i] + 2) ^ 2 then
			for _, piece in b.bp.pieces do
				local d, down = touch(b, piece, p.x, p.y, p.z)
				if d < 0.05 or (d <= sit + 0.1 and down <= -0.5 * d) then
					return true
				end
			end
		end
	end
	return false
end

-- A bird on a landmark that a kit model stands in for (Data/Kit "landmark:*": the Duskwood's Old Tree, the Wastes'
-- ribcage): the model's shape is not the generator's pieces, Studio checks those.
local function onKitLandmark(builds: { any }, p: any): boolean
	for _, b in builds do
		for _, slot in b.bp.kits do
			if string.sub(slot.key, 1, 9) == "landmark:" and (b.at.x - p.x) ^ 2 + (b.at.z - p.z) ^ 2 < 25 * 25 then
				return true
			end
		end
	end
	return false
end

describe("Perches: marks in a blueprint's frame", function()
	it("keeps a mark in building space through the frames, with its kit slot; dropKit leaves it out", function()
		local bp = Blueprint.new(1)
		bp:push(10, 0, 0, 0, 90, 0)
		bp:beginKit("tree:a", 0, 0, 0, 1, "shell")
		bp:mark("perch", 1, 2, 0)
		bp:endKit()
		bp:beginKit("tree:b", 0, 0, 0, 1, "shell")
		bp:mark("perch", 0, 3, 0)
		bp:endKit()
		bp:pop()
		bp:mark("mist", 0, 0, 0, 5)
		expect(#bp.marks).toBe(3)
		local first = bp.marks[1]
		expect(first.p[1]).toBeNear(10, 1e-9)
		expect(first.p[2]).toBeNear(2, 1e-9)
		expect(first.p[3]).toBeNear(-1, 1e-9)
		expect(first.k).toBe(1)
		expect(bp.marks[2].k).toBe(2)
		expect(bp.marks[3].k).toBeNil()
		expect(bp.marks[3].r).toBe(5)
		bp:dropKit(1)
		expect(#bp.marks).toBe(2)
		expect(bp.marks[1].k).toBe(1)
		expect(bp.marks[1].p[2]).toBeNear(3, 1e-9)
		expect(bp.marks[2].kind).toBe("mist")
	end)

	it("finds the top of a beam: half its height over a level one, more over a pitched one", function()
		local x, y, z = Blueprint.beamTop(0, 0, 0, 10, 0, 0, 1, 0.5)
		expect(x).toBeNear(5, 1e-9)
		expect(y).toBeNear(0.5, 1e-9)
		expect(z).toBeNear(0, 1e-9)
		local _, py = Blueprint.beamTop(0, 0, 0, 10, 10, 0, 1, 0.5)
		expect(py).toBeNear(5 + 0.5 * math.sqrt(2), 1e-9)
	end)
end)

describe("Perches: Crow Field", function()
	it("has no decorative crows; the Meadows keep them elsewhere", function()
		local crows = 0
		for _, p in MeadowsGen.life() do
			if p.kind == "perch" then
				crows += 1
				local area = Areas.areaAt("meadows", p.x, p.z)
				expect(area ~= nil and area.id == "meadows_crowfield").toBe(false)
			end
		end
		expect(crows > 20).toBe(true)
	end)
end)

describe("Perches: birds on their perch", function()
	for _, mapId in { "meadows", "duskwood", "ashen" } do
		it(`{mapId}: every perched bird rests on what it perches on`, function()
			local gen = assert(WorldGen.get(mapId), mapId)
			local builds = gen.all()
			local radius: { number } = {}
			for i, b in builds do
				radius[i] = gen.radius(b)
			end
			local birds, off = 0, {}
			for _, p in gen.life() do
				local sit = SIT[p.kind]
				if sit and not onKitLandmark(builds, p) then
					birds += 1
					if not rests(mapId, builds, radius, p, sit) then
						table.insert(off, `{p.kind} {math.floor(p.x)} {math.floor(p.y)} {math.floor(p.z)}`)
					end
				end
			end
			expect(birds > 0).toBe(true)
			expect(table.concat(off, ", ")).toBe("")
		end)
	end
end)
