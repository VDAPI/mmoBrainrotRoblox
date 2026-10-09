--!strict
-- Shared state of one Frost Peaks generation (S47, like Logic/AshenGen/Env): the generator context
-- (Logic/WorldGen/Kit: ground, life points, sketch), the terrain (Logic/RegionTerrain), the sites and the clearings
-- the trees and rocks keep away from (footprints of everything the modules build). Created by FrostpeakGen.all and passed
-- to every module. Pure.

local AreaTypes = require("../../Data/Areas/Types")
local Areas = require("../../Data/Areas/frostpeak")
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
	local T = assert(RegionTerrain.get("frostpeak"), "frostpeak terrain")
	return {
		ctx = Kit.new("frostpeak", T.height),
		T = T,
		sites = assert(Areas.sites, "frostpeak sites"),
		areas = Areas,
		clearings = {},
	}
end

-- Marks a circle no tree or rock may stand in (a building's footprint, a camp, a path).
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

-- Firm ground for props, trees and rocks: dry, off the ice of the lakes and the brook, away from crevasses.
function Env.safe(env: Env, x: number, z: number, crevasse: number): boolean
	local T = env.T
	return not T.isWater(x, z) and T.ice(x, z) == nil and T.crevasseDistance(x, z) > crevasse
end

return Env
