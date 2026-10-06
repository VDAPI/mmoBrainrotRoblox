--!strict
-- Dumps world-space pieces of the city generator to JSON for the Python preview renderer.
-- lune run tools/dump.luau <out.json> <x1> <z1> <x2> <z2> [what=houses,walls,retaining,ramps,bridges,lamps,...]
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")

local Town = require("../src/shared/Data/Town")
local TownTerrain = require("../src/shared/Logic/TownTerrain")
local TownGen = require("../src/shared/Logic/TownGen")

local args = process.args
local out = args[1] or "pieces.json"
local x1, z1, x2, z2 =
	tonumber(args[2]) or -60, tonumber(args[3]) or -100, tonumber(args[4]) or 100, tonumber(args[5]) or 60
local what = args[6] or "houses,walls,retaining,ramps,bridges,lamps,specials,gardens,props,outside"
local want = {}
for w in string.gmatch(what, "[^,]+") do
	want[w] = true
end

local function ground(x: number, z: number): number
	return TownTerrain.heightAt(x, z)
end

local city = Town.city
local builds = {}
if want.houses then
	for _, lot in city.lots do
		local bp, at = TownGen.Houses.build(lot :: any, ground)
		table.insert(
			builds,
			{ name = lot.id, bp = bp, at = at, tag = "house", kind = lot.kind, style = lot.style, floors = lot.floors }
		)
	end
end
local S = TownGen.Structures
for _, key in { "walls", "retaining", "ramps", "bridges", "lamps" } do
	if want[key] and (S :: any)[key] then
		for _, b in (S :: any)[key](city, ground) do
			table.insert(builds, b)
		end
	end
end
for _, key in { "specials", "gardens", "props", "outside" } do
	local mod = (TownGen :: any)[string.upper(string.sub(key, 1, 1)) .. string.sub(key, 2)]
	if want[key] and mod and mod.all then
		for _, b in mod.all(city, ground) do
			table.insert(builds, b)
		end
	end
end

local pieces = {}
local stats = {}
for _, b in builds do
	local at = b.at
	if at.x >= x1 and at.x <= x2 and at.z >= z1 and at.z <= z2 then
		local r = math.rad(at.rot)
		local c, s = math.cos(r), math.sin(r)
		local R = { c, 0, s, 0, 1, 0, -s, 0, c }
		for _, p in b.bp.pieces do
			local px, py, pz = p.p[1], p.p[2], p.p[3]
			local wx = at.x + R[1] * px + R[3] * pz
			local wz = at.z + R[7] * px + R[9] * pz
			local m = p.r
			local wr = {}
			for i = 0, 2 do
				for j = 0, 2 do
					wr[i * 3 + j + 1] = R[i * 3 + 1] * m[j + 1] + R[i * 3 + 2] * m[j + 4] + R[i * 3 + 3] * m[j + 7]
				end
			end
			table.insert(
				pieces,
				{
					s = p.s,
					size = p.size,
					p = { wx, at.y + py, wz },
					r = wr,
					c = p.c,
					m = p.m,
					lod = p.lod,
					t = p.t,
					tag = p.tag,
				}
			)
		end
		table.insert(stats, {
			id = b.name,
			tag = b.tag,
			kind = (b :: any).kind,
			style = (b :: any).style,
			floors = (b :: any).floors,
			shell = b.bp.shell,
			detail = b.bp.detail,
			fine = b.bp.fine,
			x = at.x,
			z = at.z,
		})
	end
end
fs.writeFile(out, serde.encode("json", { pieces = pieces, stats = stats }))
print(`wrote {#pieces} pieces from {#stats} builds`)
