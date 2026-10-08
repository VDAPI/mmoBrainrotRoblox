--!strict
-- Shared state of one Duskwood generation (S45): the generator context (Logic/WorldGen/Kit: ground, life points,
-- sketch), the terrain (Logic/RegionTerrain), the sites and the clearings the trees keep away from (footprints of
-- everything the modules build). Created by DuskwoodGen.all and passed to every module. Pure.

local AreaTypes = require("../../Data/Areas/Types")
local Areas = require("../../Data/Areas/duskwood")
local Kit = require("../WorldGen/Kit")
local RegionTerrain = require("../RegionTerrain")

local Env = {}

export type Clear = { x: number, z: number, r: number }

export type Env = {
	ctx: Kit.Ctx,
	T: RegionTerrain.Terrain,
	sites: { [string]: AreaTypes.Site },
	areas: AreaTypes.MapAreas,
	clearings: { Clear },
}

function Env.new(): Env
	local T = assert(RegionTerrain.get("duskwood"), "duskwood terrain")
	return {
		ctx = Kit.new("duskwood", T.height),
		T = T,
		sites = assert(Areas.sites, "duskwood sites"),
		areas = Areas,
		clearings = {},
	}
end

-- Marks a circle no tree may stand in (a building's footprint, a camp, a path).
function Env.clear(env: Env, x: number, z: number, r: number)
	table.insert(env.clearings, { x = x, z = z, r = r })
end

-- Whether a point is free of every clearing (grown by `extra`).
function Env.isClear(env: Env, x: number, z: number, extra: number): boolean
	for _, c in env.clearings do
		local r = c.r + extra
		if math.abs(x - c.x) < r and math.abs(z - c.z) < r and (x - c.x) ^ 2 + (z - c.z) ^ 2 < r * r then
			return false
		end
	end
	return true
end

-- Build at a site (its rot unless given), registered as a clearing of radius `r`.
function Env.atSite(env: Env, name: string, tag: string, r: number, rot: number?, lift: number?): Kit.Build
	local s = env.sites[name]
	Env.clear(env, s.x, s.z, r)
	return Kit.build(env.ctx, name, tag, s.x, s.z, rot or s.rot, lift)
end

return Env
