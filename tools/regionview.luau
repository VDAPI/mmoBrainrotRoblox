--!strict
-- 3D preview export of a shaped map (S45, generalised from the S26 meadowsview) for tools/regionview.py:
--   lune run tools/regionview.luau <map> out.json x1 z1 x2 z2 [shell]
-- World-space pieces of every Build of the map's generator (Logic/WorldGen) inside the box (all levels of detail, or
-- only "shell") and the terrain heights, materials and water every 2 studs. Maps: meadows and every Data/Terrain/<map>.

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local MeadowsTerrain = require("../src/shared/Logic/MeadowsTerrain")
local RegionTerrain = require("../src/shared/Logic/RegionTerrain")
local WorldGen = require("../src/shared/Logic/WorldGen")

local args = process.args
local mapId = args[1] or "duskwood"
local out = args[2] or "view.json"
local x1, z1 = tonumber(args[3]) or -100, tonumber(args[4]) or -100
local x2, z2 = tonumber(args[5]) or 100, tonumber(args[6]) or 100
local shellOnly = args[7] == "shell"

local gen = assert(WorldGen.get(mapId), `no generator for {mapId}`)
local terrain: any = if mapId == "meadows" then MeadowsTerrain else assert(RegionTerrain.get(mapId))

local pieces = {}
for _, b in gen.all() do
	local r = math.rad(b.at.rot)
	local c, s = math.cos(r), math.sin(r)
	-- CFrame.Angles(0, r, 0) rows
	local R = { c, 0, s, 0, 1, 0, -s, 0, c }
	for _, p in b.bp.pieces do
		if shellOnly and p.lod ~= "shell" then
			continue
		end
		local lx, ly, lz = p.p[1], p.p[2], p.p[3]
		local wx = b.at.x + R[1] * lx + R[2] * ly + R[3] * lz
		local wy = b.at.y + R[4] * lx + R[5] * ly + R[6] * lz
		local wz = b.at.z + R[7] * lx + R[8] * ly + R[9] * lz
		if wx >= x1 and wx <= x2 and wz >= z1 and wz <= z2 then
			local m = p.r
			local rot = {}
			for i = 0, 2 do
				for j = 0, 2 do
					rot[i * 3 + j + 1] = R[i * 3 + 1] * m[j + 1] + R[i * 3 + 2] * m[j + 4] + R[i * 3 + 3] * m[j + 7]
				end
			end
			table.insert(pieces, {
				s = p.s,
				size = p.size,
				p = { wx, wy, wz },
				r = rot,
				c = p.c,
				m = p.m,
				lod = p.lod,
				t = p.t,
				tag = p.tag,
			})
		end
	end
end

local step = 2
local heights, mats, water = {}, {}, {}
local z = z1
while z <= z2 do
	local hr, mr, wr = {}, {}, {}
	local x = x1
	while x <= x2 do
		local h, info = terrain.sample(x, z)
		table.insert(hr, h)
		table.insert(mr, terrain.materialAt(x, z, h, terrain.slope(x, z, 1), info))
		local w = terrain.water(x, z)
		table.insert(wr, if w then w else false)
		x += step
	end
	table.insert(heights, hr)
	table.insert(mats, mr)
	table.insert(water, wr)
	z += step
end

fs.writeFile(
	out,
	serde.encode("json", {
		pieces = pieces,
		terrain = { x1 = x1, z1 = z1, step = step, heights = heights, materials = mats, water = water },
	})
)
print(`{#pieces} pieces -> {out}`)
