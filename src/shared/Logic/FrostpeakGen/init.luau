--!strict
-- Frost Peaks generator (S47): plan data in (Data/Areas/frostpeak sites, Data/Terrain/frostpeak), Builds out, like
-- Logic/AshenGen. Pure and deterministic: the server builds the "shell" level of every Build and each client builds
-- "detail" and "fine" near its camera from the same list (TownDetailController via Logic/WorldGen). Every hunting
-- ground looks like what lives there:
--
--   * Valley (cairn, trappers' camp, Howling Rock, leopards' ledge), Slopes (Yeti's Den, burrows, throwing
--     boulders, the avalanche cone), Harpy (the Queen's nest, climbers' camp, nests on the spires), Pass (the Giants'
--     Gate, the Hall of Thrones and the giants' fire, rune stones, boulder field, giant stairs, harpy nests), Lake
--     (the frozen boat, the Frozen Falls, the crystal garden, the hoard in the ice, mammoth trails), Tundra (the
--     Mammoth Graveyard and the tusk arch, the hunting camp, erratics), Temple (the Dragon Stairs and terrace walls,
--     the sanctuary, offering altars, the cult), Fortress (the Ice Watch), Wyrm (the skeleton, burrows, obelisk, snow
--     plumes), Mouths (Ice Grotto, Frozen Hold, Glacier Heart),
--   * wooden bridges over the frozen Ice Brook (Logic/WorldGen/Structures), snow poles along the trails, rocks, and
--     the trees last (Logic/WorldGen/Flora: snowy spruces, frost-killed trees, ice spikes; none above ~y 62 but the
--     spikes).
-- Also: gathering node placements by theme (`nodes`), life points (`life`), map sketch shapes (`sketch`).

local AreaSpawns = require("./AreaSpawns")
local Env = require("@self/Env")
local Flora = require("./WorldGen/Flora")
local Fortress = require("@self/Fortress")
local Harpy = require("@self/Harpy")
local Kit = require("./WorldGen/Kit")
local Lake = require("@self/Lake")
local Maps = require("../Data/Maps")
local Mouths = require("@self/Mouths")
local Pass = require("@self/Pass")
local Props = require("@self/Props")
local Rng = require("./Rng")
local Shapes = require("../Data/Terrain")
local Slopes = require("@self/Slopes")
local Structures = require("./WorldGen/Structures")
local Temple = require("@self/Temple")
local TerrainLayers = require("./TerrainLayers")
local Tundra = require("@self/Tundra")
local Valley = require("@self/Valley")
local Wyrm = require("@self/Wyrm")

local o = Kit.o

local FrostpeakGen = {}

export type Build = Kit.Build
export type Life = Kit.Life
export type NodePlacement = { kind: string, x: number, z: number }

local SHAPE = Shapes.byMap.frostpeak
local TREE_LINE = 62 -- no trees above this height (ice spikes grow anywhere)

local cache: { Build }? = nil
local treeCache: { Flora.TreeInfo } = {}
local env: Env.Env? = nil

local function envOf(): Env.Env
	if not env then
		env = Env.new()
	end
	return env :: Env.Env
end

-- Clearings that come from data: portals, cave mouths, respawn points, the scout, crossings, monster groups.
local function dataClearings(e: Env.Env)
	for _, p in { { -770, 0 }, { -770, 160 } } do
		Env.clear(e, p[1], p[2], 22)
	end
	for _, c in e.areas.caves do
		Env.clear(e, c.x, c.z, 26)
	end
	for _, r in SHAPE.respawns do
		Env.clear(e, r.x, r.z, 10)
	end
	Env.clear(e, -690, -36, 9)
	for _, c in e.T.crossings() do
		Env.clear(e, c.x, c.z, c.span / 2 + 8)
	end
	local map = Maps.get("frostpeak")
	for _, s in AreaSpawns.region(e.areas, if map then map.size else { x = 1600, z = 1600 }) do
		Env.clear(e, s.position.x, s.position.z, 9)
	end
end

-- Snow poles along the trails every ~40 studs (red-and-white tops), alternating sides, off bridges and buildings.
local function poles(e: Env.Env, out: { Build })
	local n = 0
	for ri, road in e.areas.roads do
		local line = e.T.roadLine(ri)
		local s = 24
		local side = 1
		local b: Build? = nil
		while s < line.length - 12 do
			local x, z, dx, dz = TerrainLayers.pointAt(line, s)
			local off = road.width / 2 + 2
			local px, pz = x - dz * off * side, z + dx * off * side
			if math.abs(px) < 780 and math.abs(pz) < 780 and Env.isClear(e, px, pz, -4) and Env.safe(e, px, pz, 8) then
				if not b or (b.at.x - px) ^ 2 + (b.at.z - pz) ^ 2 > 120 * 120 then
					n += 1
					b = Kit.build(e.ctx, `SnowPoles_{n}`, "poles", px, pz, 0)
					table.insert(out, b :: Build)
				end
				local pb = b :: Build
				local lx, lz = px - pb.at.x, pz - pb.at.z
				local y = e.ctx.ground(px, pz) - pb.at.y
				pb.bp:box(0.35, 5, 0.35, lx, y + 2.2, lz, o(Props.oldWood, "detail", { col = false }))
				pb.bp:box(
					0.4,
					1,
					0.4,
					lx,
					y + 4.6,
					lz,
					o({ c = "#B23A2A", m = "SmoothPlastic" }, "detail", { col = false })
				)
			end
			side = -side
			s += 40
		end
	end
end

-- Rock outcrops by theme (shell lumps collide), frosted, with a snow cap.
local ROCKS: { [string]: { n: number, size: { number } } } = {
	snowforest = { n = 10, size = { 3, 6 } },
	snowfield = { n = 16, size = { 4, 8 } },
	harpyrocks = { n = 8, size = { 3, 6 } },
	giants = { n = 18, size = { 3, 7 } },
	icelake = { n = 6, size = { 3, 5 } },
	tundra = { n = 10, size = { 4, 8 } },
	dragontemple = { n = 6, size = { 3, 5 } },
	icefort = { n = 8, size = { 3, 6 } },
	wyrmpeak = { n = 10, size = { 4, 7 } },
}

local function rocks(e: Env.Env, out: { Build })
	local rng = Rng.new(4705)
	local placed: { [string]: number } = {}
	local tries = 0
	while tries < 6000 do
		tries += 1
		local x, z = rng:float(-770, 770), rng:float(-770, 770)
		local theme = e.T.themeAt(x, z)
		local spec = ROCKS[theme]
		if
			spec
			and (placed[theme] or 0) < spec.n
			and Env.isClear(e, x, z, 4)
			and e.T.slope(x, z, 3) < 0.9
			and Env.safe(e, x, z, 10)
			and e.T.roadDistance(x, z) > 6
			and not e.T.glacierAt(x, z)
		then
			placed[theme] = (placed[theme] or 0) + 1
			local b = Kit.build(e.ctx, `Rocks_{theme}_{placed[theme]}`, "rocks", x, z, rng:float(0, 360))
			local size = rng:float(spec.size[1], spec.size[2])
			Props.boulder(b.bp, 0, -0.2, 0, size)
			for _ = 1, rng:int(1, 3) do
				local a = rng:float(0, math.pi * 2)
				local d = size * rng:float(0.8, 1.4)
				local lx, lz = math.cos(a) * d, math.sin(a) * d
				Kit.rock(
					b.bp,
					lx,
					Kit.gy(e.ctx, b, lx, lz) - 0.2,
					lz,
					size * rng:float(0.25, 0.45),
					Props.frostStone,
					"detail"
				)
			end
			Env.clear(e, x, z, size)
			table.insert(out, b)
		end
	end
end

-- Terrain shapes of the sketch (drawn under the buildings): frozen lakes and the brook as ice, the ice holes as
-- water, glaciers with moraines, crevasses, ridges and the horn, spires, the temple's terraces,
-- roads.
local function terrainSketch(e: Env.Env)
	local ctx = e.ctx
	for _, g in assert(SHAPE.glaciers, "glaciers") do
		local pts = {}
		local w = 0
		for _, p in g.pts do
			table.insert(pts, p[1])
			table.insert(pts, p[2])
			w = math.max(w, p[3])
		end
		Kit.line(ctx, "moraine", pts, w * 2 + (g.side + (g.moraineW or 0)) * 2)
		Kit.line(ctx, "glacier", pts, w * 2)
	end
	for _, fl in assert(SHAPE.frozenLakes, "frozenLakes") do
		for _, lobe in fl.lobes do
			Kit.circle(ctx, "ice", lobe.x, lobe.z, (lobe.rx + lobe.rz) / 2 * 0.95)
			if math.abs(lobe.rx - lobe.rz) > 20 then
				Kit.rect(ctx, "ice", lobe.x, lobe.z, lobe.rx * 1.6, lobe.rz * 1.4, lobe.rot)
			end
		end
	end
	for _, st in assert(e.areas.streams, "streams") do
		Kit.line(ctx, "ice", st.points, 9)
	end
	for _, lake in e.areas.lakes do
		Kit.circle(ctx, "water", lake.x, lake.z, lake.r)
	end
	for _, c in assert(SHAPE.crevasses, "crevasses") do
		Kit.line(ctx, "crevasse", c.points, c.width)
	end
	for _, r in SHAPE.ridges do
		local pts = {}
		for _, p in r.pts do
			table.insert(pts, p[1])
			table.insert(pts, p[2])
		end
		Kit.line(ctx, "ridge", pts, if #r.pts > 4 then 46 else 26)
	end
	for _, p in assert(SHAPE.peaks, "peaks") do
		Kit.circle(ctx, "ridge", p.x, p.z, p.r * 0.7)
	end
	for _, s in assert(SHAPE.spires, "spires") do
		Kit.circle(ctx, "spire", s.x, s.z, s.r)
	end
	Kit.rect(ctx, "plateau", 700, 0, 200, 330, 0)
	for _, road in e.areas.roads do
		Kit.line(ctx, "path", road.points, road.width)
	end
end

-- Buildings and walls on the sketch.
local function buildingSketch(e: Env.Env)
	local ctx = e.ctx
	local s = e.sites
	Kit.rect(ctx, "building", s.trapperCamp.x, s.trapperCamp.z + 4, 12, 10, s.trapperCamp.rot)
	Kit.rect(ctx, "building", s.keep.x + 10, s.keep.z, 30, 26, 0)
	Kit.ring(ctx, "wall", s.keep.x, s.keep.z, 64 * 1.41, 4, 4)
	Kit.rect(ctx, "building", s.sanctuary.x, s.sanctuary.z, 40, 30, 0)
	Kit.circle(ctx, "building", s.thrones.x, s.thrones.z, 6)
	Kit.circle(ctx, "building", s.huntingCamp.x, s.huntingCamp.z, 6)
	for k = 0, 3 do
		local a = k * math.pi / 2 + 0.6
		Kit.circle(ctx, "building", s.huntingCamp.x + math.cos(a) * 20, s.huntingCamp.z + math.sin(a) * 20, 4)
	end
	Kit.rect(ctx, "building", s.mammothGraveyard.x, s.mammothGraveyard.z, 30, 20, 0)
	for _, x in { 500, 580, 650 } do
		Kit.rect(ctx, "wall", x - 4, 0, 3, 400 - (x - 500) * 0.8, 0)
	end
end

-- Every Build of the Frost Peaks in a fixed order (cached; identical on the server and every client).
function FrostpeakGen.all(): { Build }
	if cache then
		return cache
	end
	local e = envOf()
	table.clear(e.ctx.life)
	table.clear(e.ctx.sketch)
	table.clear(e.clearings)
	terrainSketch(e)
	dataClearings(e)
	local out: { Build } = {}
	Valley.all(e, out)
	Pass.all(e, out)
	Lake.all(e, out)
	Temple.all(e, out)
	Mouths.all(e, out)
	Fortress.all(e, out)
	Tundra.all(e, out)
	Wyrm.all(e, out)
	Slopes.all(e, out)
	Harpy.all(e, out)
	Structures.bridges(e.ctx, e.T :: any, out)
	buildingSketch(e)
	for _, b in out do
		if b.tag == "bridge" then
			Kit.circle(e.ctx, "bridge", b.at.x, b.at.z, 6)
		end
	end
	poles(e, out)
	rocks(e, out)
	local tiles, trees = Flora.forest({
		ctx = e.ctx,
		ground = e.T :: any,
		rules = SHAPE.flora,
		default = SHAPE.defaultTheme,
		seed = 4704,
		half = 800,
		waterKinds = { snowPine = 80, frozenDead = 20 },
		clear = function(x: number, z: number, extra: number): boolean
			if not Env.isClear(e, x, z, extra) or not Env.safe(e, x, z, 8) then
				return false
			end
			local T = e.T
			if T.mountainAt(x, z) or T.glacierAt(x, z) then
				return false
			end
			return T.height(x, z) < TREE_LINE or T.themeAt(x, z) == "wyrmpeak"
		end,
	})
	for _, b in tiles do
		table.insert(out, b :: any)
	end
	treeCache = trees
	cache = out
	return out
end

-- Big trees (x, z, kind).
function FrostpeakGen.trees(): { Flora.TreeInfo }
	FrostpeakGen.all()
	return treeCache
end

-- Points the client brings to life (Controllers/WorldLifeController): "snowPlume", "steam", "smoke",
-- "smokeColumn", "eagles", "avalanche", "icicleDust", "harpyGlint".
function FrostpeakGen.life(): { Life }
	FrostpeakGen.all()
	return envOf().ctx.life
end

-- Map sketch shapes: terrain (ice, water, glaciers, crevasses, ridges, spires, roads), then buildings and walls.
function FrostpeakGen.sketch(): { { [string]: any } }
	FrostpeakGen.all()
	return envOf().ctx.sketch
end

-- Horizontal reach of a Build from its `at` point.
function FrostpeakGen.radius(build: Build): number
	local r = 0
	for _, piece in build.bp.pieces do
		local p, size = piece.p, piece.size
		r = math.max(r, math.sqrt(p[1] * p[1] + p[3] * p[3]) + math.max(size[1], size[2], size[3]) / 2)
	end
	return r
end

-- Parts per level of detail over all Builds.
function FrostpeakGen.counts(): { shell: number, detail: number, fine: number, builds: number, lights: number }
	local c = { shell = 0, detail = 0, fine = 0, builds = 0, lights = 0 }
	for _, b in FrostpeakGen.all() do
		c.builds += 1
		c.lights += #b.bp.lights
		for _, piece in b.bp.pieces do
			c[piece.lod] += 1
		end
	end
	return c
end

-- Gathering nodes ----------------------------------------------------------------------------------------------

type NodeRule = {
	kind: string,
	count: number,
	where: (x: number, z: number, theme: string) -> boolean,
	box: { number }?,
}

local function themeIs(name: string): (x: number, z: number, theme: string) -> boolean
	return function(_x, _z, theme)
		return theme == name
	end
end

-- Ores and herbs by the areas' character: mithril in the outcrops of the slopes and the valley, at the spires' feet
-- and in the scree under the North Ridge; adamantite on the temple's terraces, at the horn's foot, on the Ice
-- Watch's rocks and the tundra's erratics; frostleaf in sheltered places (the lee of slopes, under spruces, by the
-- brook, on the lake's shore).
local function nodeRules(e: Env.Env): { NodeRule }
	local T = e.T
	local function lee(x: number, z: number): boolean
		local dir = T.windAt(x, z)
		local b = math.rad(dir)
		local up = T.height(x - math.sin(b) * 8, z + math.cos(b) * 8)
		return up > T.height(x, z) + 0.6
	end
	return {
		{ kind = "vein_mithril", count = 4, where = themeIs("snowfield") },
		{ kind = "vein_mithril", count = 3, where = themeIs("snowforest") },
		{
			kind = "vein_mithril",
			count = 2,
			where = function(x, z, theme)
				for _, s in assert(SHAPE.spires, "spires") do
					local d = math.sqrt((x - s.x) ^ 2 + (z - s.z) ^ 2) - s.r
					if d > 6 and d < 26 then
						return theme == "harpyrocks"
					end
				end
				return false
			end,
		},
		{ kind = "vein_mithril", count = 2, where = themeIs("giants"), box = { -120, -240, 200, -150 } },
		{ kind = "vein_adamantite", count = 4, where = themeIs("dragontemple") },
		{ kind = "vein_adamantite", count = 3, where = themeIs("wyrmpeak") },
		{ kind = "vein_adamantite", count = 2, where = themeIs("icefort") },
		{ kind = "vein_adamantite", count = 2, where = themeIs("tundra") },
		{
			kind = "bush_frostleaf",
			count = 8,
			where = function(x, z, theme)
				return theme == "snowforest" and (lee(x, z) or T.streamDistance(x, z) < 30)
			end,
		},
		{
			kind = "bush_frostleaf",
			count = 5,
			where = function(_x, _z, theme)
				return theme == "harpyrocks"
			end,
		},
		{
			kind = "bush_frostleaf",
			count = 5,
			where = function(x, z, theme)
				return theme == "icelake" and T.ice(x, z) == nil and T.dryAround(x, z, 4)
			end,
		},
		{
			kind = "bush_frostleaf",
			count = 2,
			where = function(x, z, theme)
				return theme == "giants" and lee(x, z)
			end,
		},
		{
			kind = "bush_frostleaf",
			count = 3,
			where = function(x, z, theme)
				return theme == "snowfield" and (lee(x, z) or T.slope(x, z, 4) < 0.1)
			end,
		},
		{
			kind = "bush_frostleaf",
			count = 3,
			where = function(_x, _z, theme)
				return theme == "tundra"
			end,
		},
	}
end

local nodeCache: { NodePlacement }? = nil

local function blocked(e: Env.Env, x: number, z: number): boolean
	if AreaSpawns.nearRoad(e.areas.roads, x, z, 6) then
		return true
	end
	for _, list in { e.areas.avoid, e.areas.lakes } do
		for _, c in list do
			if (x - c.x) ^ 2 + (z - c.z) ^ 2 < (c.r + 6) ^ 2 then
				return true
			end
		end
	end
	for _, c in e.areas.caves do
		if (x - c.x) ^ 2 + (z - c.z) ^ 2 < 40 * 40 then
			return true
		end
	end
	return false
end

-- Gathering node placements (fishing spots, herbs, ores), 24+ studs apart, on firm gentle ground away from roads,
-- ice, crevasses, buildings and monster groups.
function FrostpeakGen.nodes(): { NodePlacement }
	if nodeCache then
		return nodeCache
	end
	FrostpeakGen.all()
	local e = envOf()
	local out: { NodePlacement } = {}
	for _, spot in FrostpeakGen.fishingSpots() do
		table.insert(out, { kind = "fishing_frostpeak", x = spot.x, z = spot.z })
	end
	local map = Maps.get("frostpeak")
	local groups = AreaSpawns.region(e.areas, if map then map.size else { x = 1600, z = 1600 })
	local rng = Rng.new(4706)
	for _, rule in nodeRules(e) do
		local placed, tries = 0, 0
		local box = rule.box or { -770, -770, 770, 770 }
		while placed < rule.count and tries < rule.count * 1500 do
			tries += 1
			local x, z = rng:float(box[1], box[3]), rng:float(box[2], box[4])
			local theme = e.T.themeAt(x, z)
			local ok = rule.where(x, z, theme) and not blocked(e, x, z)
			if ok then
				for _, other in out do
					if (x - other.x) ^ 2 + (z - other.z) ^ 2 < 24 * 24 then
						ok = false
						break
					end
				end
			end
			if ok then
				for _, g in groups do
					if (x - g.position.x) ^ 2 + (z - g.position.z) ^ 2 < 20 * 20 then
						ok = false
						break
					end
				end
			end
			if ok and Env.isClear(e, x, z, -2) and e.T.walkable(x, z) and Env.safe(e, x, z, 10) then
				local nx, nz = math.floor(x + 0.5), math.floor(z + 0.5)
				if e.T.walkable(nx, nz) and e.T.ice(nx, nz) == nil then
					table.insert(out, { kind = rule.kind, x = nx, z = nz })
					placed += 1
				end
			end
		end
	end
	nodeCache = out
	return out
end

-- Fishing spots: dry ice just north of each ice hole, with all three buoys of Services/GatherService (x + 9 cos(2.1 i),
-- z + 8 + 5 sin(2.1 i)) in open water, a stud clear of the hole's edge.
function FrostpeakGen.fishingSpots(): { { x: number, z: number } }
	local e = envOf()
	local T = e.T
	local out = {}
	for _, lake in e.areas.lakes do
		local best: { x: number, z: number }? = nil
		local bestD = math.huge
		local tx, tz = lake.x, lake.z - lake.r - 1.5
		for dx = -12, 12 do
			for dz = -8, 8 do
				local x, z = tx + dx, tz + dz
				if T.water(x, z) == nil and T.slope(x, z, 2) < 0.28 then
					local ok = true
					for i = 1, 3 do
						local bx, bz = x + 9 * math.cos(2.1 * i), z + 8 + 5 * math.sin(2.1 * i)
						local d = math.sqrt((bx - lake.x) ^ 2 + (bz - lake.z) ^ 2)
						if T.water(bx, bz) == nil or d > lake.r - 1 then
							ok = false
							break
						end
					end
					local d = dx * dx + dz * dz
					if ok and d < bestD then
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

return FrostpeakGen
