--!strict
-- Whispering Meadows generator (S26): plan data in (Data/Areas/meadows sites, Data/Terrain/meadows), Builds out,
-- like TownGen for the city. Pure and deterministic, so the server builds the "shell" level of every Build and
-- each client builds "detail" and "fine" near its camera from the same list (TownDetailController).
--
--   * Homes: gate, shrine and old oak, farmstead, fisherman's hut and jetty, woodcutter, hunter's camp, warrens,
--   * Landmarks: burnt mill and withered fields, forest ruin, stone circle, wolf and bear dens, wallow, wagon wreck,
--     milestones,
--   * Camps: bandits and goblins, Quarry: the Old Quarry, Water: bridges, the ford, the waterfall, brook stones,
--   * Nature: rock outcrops and tree tiles (trees last: they keep clear of everything above).
-- Also: gathering node placements by theme (`nodes`), the life points the client animates (`life`) and the big
-- trees (`trees`, for the map's forest patches).

local Areas = require("../Data/Areas/meadows")
local AreaTypes = require("../Data/Areas/Types")
local AreaSpawns = require("./AreaSpawns")
local Camps = require("@self/Camps")
local Homes = require("@self/Homes")
local Kit = require("@self/Kit")
local Landmarks = require("@self/Landmarks")
local MeadowsTerrain = require("./MeadowsTerrain")
local Nature = require("@self/Nature")
local Quarry = require("@self/Quarry")
local Rng = require("./Rng")
local Water = require("@self/Water")

local MeadowsGen = {}

export type Build = Kit.Build
export type Life = Kit.Life
export type NodePlacement = { kind: string, x: number, z: number }

local cache: { Build }? = nil
local treeCache: { Nature.TreeInfo } = {}

-- Every Build of the Meadows in a fixed order (cached; identical on the server and every client).
function MeadowsGen.all(): { Build }
	if cache then
		return cache
	end
	table.clear(Kit.lifePoints)
	table.clear(Kit.sketch)
	local out: { Build } = {}
	Homes.all(out)
	Landmarks.all(out)
	Camps.all(out)
	Quarry.all(out)
	Water.bridges(out)
	Water.waterfall(out)
	Water.banks(out)
	for _, b in Nature.rocks() do
		table.insert(out, b :: any)
	end
	local tiles, trees = Nature.forest()
	for _, b in tiles do
		table.insert(out, b :: any)
	end
	treeCache = trees
	cache = out
	return out
end

-- Big trees (x, z, kind).
function MeadowsGen.trees(): { Nature.TreeInfo }
	MeadowsGen.all()
	return treeCache
end

-- Points the client brings to life: "perch" (crows), "sheep", "ducks", "mist", "butterflies".
function MeadowsGen.life(): { Life }
	MeadowsGen.all()
	return Kit.lifePoints
end

-- Map sketch shapes of the buildings, camps, fields, the quarry and the bridges (World/Meadows adds the terrain).
function MeadowsGen.sketch(): { { [string]: any } }
	MeadowsGen.all()
	return Kit.sketch
end

-- Horizontal reach of a Build from its `at` point (detail radius checks on the client).
function MeadowsGen.radius(build: Build): number
	local r = 0
	for _, piece in build.bp.pieces do
		local p, size = piece.p, piece.size
		r = math.max(r, math.sqrt(p[1] * p[1] + p[3] * p[3]) + math.max(size[1], size[2], size[3]) / 2)
	end
	return r
end

-- Parts per level of detail over all Builds.
function MeadowsGen.counts(): { shell: number, detail: number, fine: number, builds: number, lights: number }
	local c = { shell = 0, detail = 0, fine = 0, builds = 0, lights = 0 }
	for _, b in MeadowsGen.all() do
		c.builds += 1
		c.lights += #b.bp.lights
		for _, piece in b.bp.pieces do
			c[piece.lod] += 1
		end
	end
	return c
end

-- Gathering nodes ----------------------------------------------------------------------------------------------

-- `box` limits where the rule looks (x1, z1, x2, z2); default the whole map.
type NodeRule = {
	kind: string,
	count: number,
	where: (x: number, z: number, theme: string) -> boolean,
	box: { number }?,
}

local function nearWater(x: number, z: number): boolean
	local sd = MeadowsTerrain.streamDistance(x, z)
	local ld = MeadowsTerrain.lakeDistance(x, z)
	return (sd > 4 and sd < 26) or (ld > 4 and ld < 26)
end

-- Herbs and ores by the area's character: meadowsweet on the glades, nightshade in the forest, moonpetal by the
-- water, copper on the hills and in the quarry, iron in the quarry and the ravine.
local NODE_RULES: { NodeRule } = {
	{
		kind = "vein_copper",
		count = 7,
		where = function(_x, _z, theme)
			return theme == "hills" or theme == "goblin"
		end,
	},
	{
		kind = "vein_copper",
		count = 7,
		where = function(x, z, _theme)
			return MeadowsTerrain.quarryRadius(x, z) < 1
		end,
		box = { 430, -225, 690, -15 },
	},
	{
		kind = "vein_iron",
		count = 8,
		where = function(x, z, _theme)
			return MeadowsTerrain.quarryRadius(x, z) < 0.8
		end,
		box = { 430, -225, 690, -15 },
	},
	{
		kind = "vein_iron",
		count = 4,
		where = function(x, z, _theme)
			local floor = MeadowsTerrain.ravineFloor(x, z)
			return floor
		end,
		box = { 420, 240, 770, 350 },
	},
	{
		kind = "bush_meadowsweet",
		count = 14,
		where = function(_x, _z, theme)
			return theme == "meadow" or theme == "road" or theme == "hills"
		end,
	},
	{
		kind = "bush_nightshade",
		count = 10,
		where = function(_x, _z, theme)
			return theme == "forest"
		end,
	},
	{
		kind = "bush_moonpetal",
		count = 8,
		where = function(x, z, _theme)
			return nearWater(x, z)
		end,
	},
}

local nodeCache: { NodePlacement }? = nil

-- Places that must stay free of nodes: buildings, NPCs, quest objects, cave mouths, crossings, monster groups.
local function blocked(x: number, z: number): boolean
	if AreaSpawns.nearRoad(Areas.roads, x, z, 6) then
		return true
	end
	for _, list in { Areas.avoid, Areas.lakes } do
		for _, c in list do
			if (x - c.x) ^ 2 + (z - c.z) ^ 2 < (c.r + 6) ^ 2 then
				return true
			end
		end
	end
	for _, c in Areas.caves do
		if (x - c.x) ^ 2 + (z - c.z) ^ 2 < 40 * 40 then
			return true
		end
	end
	for _, a in (Areas.questAnchors or {}) :: { AreaTypes.QuestAnchor } do
		if (x - a.x) ^ 2 + (z - a.z) ^ 2 < 10 * 10 then
			return true
		end
	end
	return false
end

-- Gathering node placements (fishing spots, herbs, ores), 24+ studs apart, on dry gentle ground.
function MeadowsGen.nodes(): { NodePlacement }
	if nodeCache then
		return nodeCache
	end
	local out: { NodePlacement } = {}
	for _, spot in MeadowsGen.fishingSpots() do
		table.insert(out, { kind = "fishing_meadows", x = spot.x, z = spot.z })
	end
	local rng = Rng.new(2606)
	for _, rule in NODE_RULES do
		local placed, tries = 0, 0
		local box = rule.box or { -770, -770, 770, 770 }
		while placed < rule.count and tries < rule.count * 400 do
			tries += 1
			local x, z = rng:float(box[1], box[3]), rng:float(box[2], box[4])
			local theme = MeadowsTerrain.themeAt(x, z)
			local ok = rule.where(x, z, theme) and not blocked(x, z)
			if ok then
				for _, other in out do
					if (x - other.x) ^ 2 + (z - other.z) ^ 2 < 24 * 24 then
						ok = false
						break
					end
				end
			end
			if ok and MeadowsTerrain.walkable(x, z) and MeadowsTerrain.streamDistance(x, z) > 3 then
				table.insert(out, { kind = rule.kind, x = math.floor(x + 0.5), z = math.floor(z + 0.5) })
				placed += 1
			end
		end
	end
	nodeCache = out
	return out
end

-- Fishing spots: a dry point on the shore with open water 8-13 studs to the south (+Z), where the spot's buoys
-- float (GatherService builds the marker): by the jetty on Toad Pond, under the waterfall and at the bandits' pond.
function MeadowsGen.fishingSpots(): { { x: number, z: number } }
	local out = {}
	local sites = assert(Areas.sites, "meadows sites")
	for _, c in
		{ { sites.jetty.x - 8, sites.jetty.z - 8 }, { sites.waterfall.x - 14, sites.waterfall.z - 10 }, { -60, 520 } }
	do
		local best: { x: number, z: number }? = nil
		local bestD = math.huge
		for dx = -32, 32, 2 do
			for dz = -32, 32, 2 do
				local x, z = c[1] + dx, c[2] + dz
				if
					not MeadowsTerrain.isWater(x, z)
					and MeadowsTerrain.slope(x, z, 2) < 0.5
					and MeadowsTerrain.isWater(x, z + 9)
					and MeadowsTerrain.isWater(x, z + 12)
				then
					local d = dx * dx + dz * dz
					if d < bestD then
						bestD = d
						best = { x = x, z = z }
					end
				end
			end
		end
		if best then
			table.insert(out, best)
		end
	end
	return out
end

return MeadowsGen
