--!strict
-- Cave dressing (S48): Builds of every cave or boss chamber on the cave engine (Data/CaveShapes), by the shape's
-- theme module (S48 Moss, Smugglers, Warren, GoblinThrone; S49 Den, Barrow, Crypt, Tomb; S50 Mine, Lair, Forge, Furnace; S51 adds
-- its own), plus the ore veins along the
-- walls of the fighting rooms, life points and sketch shapes. Pure and deterministic: the server builds the "shell"
-- level, each client "detail" and "fine" near its camera (TownDetailController through Logic/WorldGen, which wraps
-- this module per map: `CaveDress.generator(mapId)`). Props that collide stay out of the rooms' cores and clear of
-- every spawner by its radius + 4, of the exit, the respawn point, the gate and the landing points.

local Barrow = require("@self/Barrow")
local CaveShapes = require("../Data/CaveShapes")
local Crypt = require("@self/Crypt")
local Den = require("@self/Den")
local Forge = require("@self/Forge")
local Furnace = require("@self/Furnace")
local GoblinThrone = require("@self/GoblinThrone")
local Kit = require("@self/Kit")
local Lair = require("@self/Lair")
local Mine = require("@self/Mine")
local Moss = require("@self/Moss")
local Rng = require("./Rng")
local Smugglers = require("@self/Smugglers")
local Tomb = require("@self/Tomb")
local Warren = require("@self/Warren")

local CaveDress = {}

export type Build = Kit.Build

local THEMES: { [string]: { all: (env: Kit.Env, out: { Build }) -> () } } = {
	Moss = Moss,
	Smugglers = Smugglers,
	Warren = Warren,
	GoblinThrone = GoblinThrone,
	-- S49: Duskwood
	Den = Den,
	Barrow = Barrow,
	Crypt = Crypt,
	Tomb = Tomb,
	-- S50: the Ashen Wastes
	Mine = Mine,
	Lair = Lair,
	Forge = Forge,
	Furnace = Furnace,
}

type State = { builds: { Build }, env: Kit.Env }
local cache: { [string]: State } = {}

-- Ore veins: `oreCount` nodes by the walls of the fighting rooms (kinds in turn from `ores`), each with a streak of
-- the ore in the rock behind it; on the floor with at least 16 studs of headroom, 24+ studs apart.
local function ores(env: Kit.Env, out: { Build })
	local cave = env.cave
	if not cave then
		return
	end
	local fight = {}
	for _, r in env.T.rooms do
		if r.fight then
			table.insert(fight, r)
		end
	end
	if #fight == 0 then
		return
	end
	local rng = Rng.new(4800 + #env.mapId)
	-- the Build stands in the first fighting room (its frame on the floor), the veins anywhere
	local b = Kit.build(env, "OreVeins", "traces", fight[1].x, fight[1].z, 0)
	for i = 1, cave.oreCount do
		local room = fight[(i - 1) % #fight + 1]
		local kind = cave.ores[(i - 1) % #cave.ores + 1]
		for _ = 1, 40 do
			local a = rng:float(0, math.pi * 2)
			local x, z = Kit.wallSpot(env, room, a, 6, 16)
			-- S50: and 8+ studs from lava
			if x and z and env.T.walkable(x, z, 2) and env.T.headroom(x, z) >= 16 and env.T.lavaDistance(x, z) >= 8 then
				local ok = true
				for _, n in env.nodes do
					if (n.x - x) ^ 2 + (n.z - z) ^ 2 < 24 * 24 then
						ok = false
						break
					end
				end
				for _, s in env.spawners do
					if (s.x - x) ^ 2 + (s.z - z) ^ 2 < (s.r + 4) ^ 2 then
						ok = false
						break
					end
				end
				if ok then
					local nx, nz = math.floor(x + 0.5), math.floor(z + 0.5)
					if env.T.walkable(nx, nz, 1) and env.T.headroom(nx, nz) >= 16 then
						table.insert(env.nodes, { kind = kind, x = nx, z = nz })
						local lx, lz = nx - b.at.x, nz - b.at.z
						Kit.vein(
							b.bp,
							lx + math.cos(a) * 3,
							Kit.gy(env, b, lx, lz),
							lz + math.sin(a) * 3,
							kind,
							math.deg(-a) + 90
						)
						Kit.clear(env, nx, nz, 3)
						break
					end
				end
			end
		end
	end
	table.insert(out, b)
end

local function generate(mapId: string): State
	local cached = cache[mapId]
	if cached then
		return cached
	end
	local env = Kit.env(mapId)
	local out: { Build } = {}
	ores(env, out)
	-- S50: the glow of the lava (pools, streams, vents, cracks, moats, falls) before the theme
	Kit.lavaGlow(env, out)
	local theme = THEMES[env.shape.theme]
	if theme then
		theme.all(env, out)
	end
	-- every fighting room gets at least one light (a torch by the wall when the theme gave it none)
	local lit: { { number } } = {}
	for _, b in out do
		for _, l in b.bp.lights do
			local x, z = Kit.toWorld(b.at.x, b.at.z, b.at.rot, l.p[1], l.p[3])
			table.insert(lit, { x, z })
		end
	end
	for i, room in env.T.rooms do
		if room.fight then
			local has = false
			for _, p in lit do
				if (p[1] - room.x) ^ 2 + (p[2] - room.z) ^ 2 < (room.r + 4) ^ 2 then
					has = true
					break
				end
			end
			if not has then
				local x, z = Kit.spot(env, room, i * 1.3, 4, 1, false)
				if x and z then
					local t = Kit.build(env, `RoomTorch_{i}`, "lamp", x, z, 0)
					Kit.torch(t.bp, 0, Kit.gy(env, t, 0, 0), 0, Kit.FIRE)
					table.insert(out, t)
				end
			end
		end
	end
	-- the sketch: liquids, bridges, landmarks
	for _, f in env.shape.features do
		local liquid = if f.liquid == "lava" then "lava" else "water" -- S50: lava orange on the map
		if f.kind == "pool" then
			Kit.circle(env.ctx, liquid, f.x, f.z, f.r)
		elseif f.kind == "stream" then
			Kit.line(env.ctx, liquid, f.points, f.width)
		elseif f.kind == "moat" then
			Kit.ring(env.ctx, "lava", f.x, f.z, (f.inner + f.outer) / 2, 32, f.outer - f.inner)
		elseif f.kind == "bridge" then
			Kit.line(env.ctx, "bridge", { f.ax, f.az, f.bx, f.bz }, f.width)
		end
	end
	for _, b in out do
		if b.tag == "landmark" then
			Kit.circle(env.ctx, "building", b.at.x, b.at.z, 3)
		elseif b.tag == "bridge" then
			Kit.rect(env.ctx, "bridge", b.at.x, b.at.z, 3, 12, b.at.rot)
		end
	end
	local state = { builds = out, env = env }
	cache[mapId] = state
	return state
end

-- Every Build of a cave (cached).
function CaveDress.all(mapId: string): { Build }
	return generate(mapId).builds
end

function CaveDress.life(mapId: string): { { kind: string, x: number, y: number, z: number, r: number? } }
	return generate(mapId).env.ctx.life
end

function CaveDress.sketch(mapId: string): { { [string]: any } }
	return generate(mapId).env.ctx.sketch
end

function CaveDress.nodes(mapId: string): { { kind: string, x: number, z: number } }
	return generate(mapId).env.nodes
end

function CaveDress.radius(build: Build): number
	local r = 0
	for _, piece in build.bp.pieces do
		local p, size = piece.p, piece.size
		r = math.max(r, math.sqrt(p[1] * p[1] + p[3] * p[3]) + math.max(size[1], size[2], size[3]) / 2)
	end
	return r
end

function CaveDress.counts(
	mapId: string
): { shell: number, detail: number, fine: number, builds: number, lights: number }
	local c = { shell = 0, detail = 0, fine = 0, builds = 0, lights = 0 }
	for _, b in CaveDress.all(mapId) do
		c.builds += 1
		c.lights += #b.bp.lights
		for _, piece in b.bp.pieces do
			c[piece.lod] += 1
		end
	end
	return c
end

-- The generator object of a cave map for the Logic/WorldGen registry.
function CaveDress.generator(mapId: string): any
	return {
		all = function()
			return CaveDress.all(mapId)
		end,
		trees = function()
			return {}
		end,
		life = function()
			return CaveDress.life(mapId)
		end,
		sketch = function()
			return CaveDress.sketch(mapId)
		end,
		nodes = function()
			return CaveDress.nodes(mapId)
		end,
		counts = function()
			return CaveDress.counts(mapId)
		end,
		radius = CaveDress.radius,
	}
end

-- Maps on the cave engine (sorted).
function CaveDress.maps(): { string }
	local list = {}
	for id in CaveShapes.byMap do
		table.insert(list, id)
	end
	table.sort(list)
	return list
end

return CaveDress
