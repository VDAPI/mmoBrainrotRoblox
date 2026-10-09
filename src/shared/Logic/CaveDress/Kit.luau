--!strict
-- Shared kit of the cave dressing (S48): the generation state of one cave (`Env`: terrain, rooms, spawners, the
-- places that must stay free), spot finders on the engine's floor (by the wall of a room, free of cores, spawners and
-- landing points) and the props every cave theme uses: torches, lanterns, candles, crates, barrels, rope, webs,
-- cocoons, glowing mushrooms, bones, banners, totems, ore veins in the rock. Draws into Blueprints (Logic/TownGen)
-- through Logic/WorldGen/Kit (not WorldGen/init: no cycle). Pure.

local AreaSpawns = require("../AreaSpawns")
local AreaTypes = require("../../Data/Areas/Types")
local CaveShapes = require("../../Data/CaveShapes")
local CaveTerrain = require("../CaveTerrain")
local Caves = require("../../Data/Areas/Caves")
local Maps = require("../../Data/Maps")
local Portals = require("../../Data/Portals")
local TerrainLayers = require("../TerrainLayers")
local WK = require("../WorldGen/Kit")

local o = WK.o

local Kit = {}

export type BP = WK.BP
export type Build = WK.Build
export type Swatch = WK.Swatch

export type Spot = { x: number, z: number, r: number }

export type Env = {
	mapId: string,
	ctx: WK.Ctx,
	T: CaveTerrain.Cave,
	cave: AreaTypes.Cave?,
	shape: CaveShapes.Shape,
	spawners: { Spot },
	keep: { Spot }, -- points that stay free of anything collidable (exit, respawn, gate, landings)
	clearings: { Spot }, -- footprints of what is built (props keep apart)
	nodes: { { kind: string, x: number, z: number } },
}

Kit.o = o
Kit.FIRE = WK.FIRE
Kit.GREEN = "#7CFF5A"
Kit.MOSS = "#8CE05A"
Kit.PALE = "#CFE8FF"

Kit.rock = { c = "#5A5650", m = "Slate" }
Kit.darkRock = { c = "#3E3B38", m = "Slate" }
Kit.wood = { c = "#5A4632", m = "Wood" }
Kit.oldWood = { c = "#4A3E34", m = "Wood" }
Kit.planks = WK.planks
Kit.rope = WK.rope
Kit.cloth = WK.cloth
Kit.hide = WK.hide
Kit.fur = WK.fur
Kit.bone = WK.bone
Kit.oldBone = WK.oldBone
Kit.iron = { c = "#4A4E56", m = "CorrodedMetal" }
Kit.gold = { c = "#C9A45C", m = "Metal" }
Kit.red = { c = "#8A2A22", m = "Fabric" }
Kit.silk = { c = "#E8E6F0", m = "SmoothPlastic" }
Kit.moss = { c = "#3E5A2E", m = "Grass" }
Kit.dark = WK.dark

-- New generation state of a cave map.
function Kit.env(mapId: string): Env
	local T = assert(CaveTerrain.get(mapId), `no cave shape for {mapId}`)
	local ctx = WK.new(mapId, function(x: number, z: number): number
		return T.floor(x, z) or 0
	end)
	local cave = Caves.get(mapId)
	local spawners: { Spot } = {}
	if cave then
		for _, s in AreaSpawns.cave(cave) do
			table.insert(spawners, { x = s.position.x, z = s.position.z, r = s.radius })
		end
	end
	local keep: { Spot } = {}
	for _, p in Portals.onMap(mapId) do
		table.insert(keep, { x = p.x, z = p.z, r = 10 })
	end
	local map = Maps.get(mapId)
	if map then
		table.insert(keep, { x = map.spawn.x, z = map.spawn.z, r = 6 })
		local e = map.dungeonEntrance
		if e then
			table.insert(keep, { x = e.x, z = e.z, r = 6 })
			for dx = 20, 24, 2 do
				table.insert(keep, { x = e.x - dx, z = e.z, r = 6 })
			end
		end
	end
	if string.sub(mapId, 1, 8) == "dungeon_" then
		-- the chamber: exit, respawn, the party's landing line, the summons ring
		table.insert(keep, { x = 0, z = 60, r = 6 })
		table.insert(keep, { x = 0, z = 55, r = 12 })
	elseif cave and cave.seed then
		local plan = T.rooms[1]
		table.insert(keep, { x = plan.x + 8, z = plan.z, r = 6 })
	elseif mapId == "meadows_cave" then
		table.insert(keep, { x = -240, z = 0, r = 6 })
	end
	return {
		mapId = mapId,
		ctx = ctx,
		T = T,
		cave = cave,
		shape = CaveShapes.byMap[mapId],
		spawners = spawners,
		keep = keep,
		clearings = {},
		nodes = {},
	}
end

function Kit.clear(env: Env, x: number, z: number, r: number)
	table.insert(env.clearings, { x = x, z = z, r = r })
end

-- Whether something collidable of radius r may stand at (x, z): floor, dry, headroom, outside every core, clear of
-- every spawner by its radius + 4, of the kept points and of what is already built.
function Kit.free(env: Env, x: number, z: number, r: number, collides: boolean?): boolean
	local T = env.T
	local c = T.column(x, z)
	if not c.open or c.liquid or c.ceiling - c.floor < 6 then
		return false
	end
	if collides ~= false then
		for _, room in T.rooms do
			if room.core > 0 and (x - room.x) ^ 2 + (z - room.z) ^ 2 < (room.core + r) ^ 2 then
				return false
			end
		end
		for _, s in env.spawners do
			if (x - s.x) ^ 2 + (z - s.z) ^ 2 < (s.r + 4 + r) ^ 2 then
				return false
			end
		end
	end
	for _, k in env.keep do
		if (x - k.x) ^ 2 + (z - k.z) ^ 2 < (k.r + r) ^ 2 then
			return false
		end
	end
	for _, k in env.clearings do
		if (x - k.x) ^ 2 + (z - k.z) ^ 2 < (k.r + r) ^ 2 then
			return false
		end
	end
	return true
end

-- A point by the wall of a room at bearing `angle` (radians): walks out from the centre while the floor goes on and
-- the headroom stays over `minHead`, then steps back `inset` studs. Nil when nothing fits.
function Kit.wallSpot(
	env: Env,
	room: CaveTerrain.Room,
	angle: number,
	inset: number,
	minHead: number?
): (number?, number?)
	local T = env.T
	local head = minHead or 8
	local found = false
	local d = 4
	local limit = room.r + 30
	local path = {}
	while d < limit do
		local x, z = room.x + math.cos(angle) * d, room.z + math.sin(angle) * d
		local c = T.column(x, z)
		if not c.open or c.ceiling - c.floor < head or c.liquid then
			break
		end
		table.insert(path, { x, z })
		found = true
		d += 2
	end
	if not found then
		return nil, nil
	end
	local back = math.max(1, #path - math.floor(inset / 2))
	local p = path[back]
	return p[1], p[2]
end

-- A free spot by the wall near bearing `angle`: tries a few bearings round it and smaller insets until something of
-- radius r fits (Kit.free). Nil when nothing fits.
function Kit.spot(
	env: Env,
	room: CaveTerrain.Room,
	angle: number,
	inset: number,
	r: number,
	collides: boolean?
): (number?, number?)
	for _, da in { 0, 0.25, -0.25, 0.5, -0.5, 0.8, -0.8 } do
		for _, ins in { inset, math.max(2, inset - 3), 2 } do
			local x, z = Kit.wallSpot(env, room, angle + da, ins)
			if x and z and Kit.free(env, x, z, r, collides) then
				return x, z
			end
		end
	end
	return nil, nil
end

-- Ceiling over a point (nil in rock).
function Kit.ceil(env: Env, x: number, z: number): number?
	return env.T.ceiling(x, z)
end

-- Build standing on the floor (Logic/WorldGen/Kit.build with the cave's ground).
function Kit.build(env: Env, name: string, tag: string, x: number, z: number, rot: number, lift: number?): Build
	return WK.build(env.ctx, name, tag, x, z, rot, lift)
end

function Kit.gy(env: Env, b: Build, lx: number, lz: number): number
	return WK.gy(env.ctx, b, lx, lz)
end

Kit.toWorld = WK.toWorld
Kit.life = WK.life
Kit.lifeAt = WK.lifeAt
Kit.rect = WK.rect
Kit.circle = WK.circle
Kit.line = WK.line
Kit.ring = WK.ring
Kit.campfire = WK.campfire
Kit.fire = WK.fire
Kit.candle = WK.candle
Kit.lantern = WK.lantern
Kit.skull = WK.skull
Kit.bones = WK.bones
Kit.claws = WK.claws

-- Props -------------------------------------------------------------------------------------------------------------

-- A standing torch: a pole with an iron cup and a flame (fire tag, light).
function Kit.torch(bp: BP, x: number, y: number, z: number, color: string?, lod: any?)
	local l = lod or "detail"
	bp:box(0.5, 5, 0.5, x, y + 2.4, z, o(Kit.wood, l, { col = false }))
	bp:add("cyl", 0.8, 1.2, 1.2, x, y + 5, z, 0, 0, 90, o(Kit.iron, l, { col = false }))
	WK.fire(bp, x, y + 5.6, z, 0.8, color or WK.FIRE, l)
end

-- A cluster of candles on the floor or a ledge.
function Kit.candles(bp: BP, x: number, y: number, z: number, n: number, color: string?)
	for i = 1, n do
		local a = i * 2.3
		WK.candle(bp, x + math.cos(a) * 0.7 * (i % 3), y, z + math.sin(a) * 0.7 * (i % 3), 0.5 + (i % 3) * 0.25, color)
	end
end

function Kit.crate(bp: BP, x: number, y: number, z: number, s: number, yaw: number, lod: any?)
	bp:rbox(2.6 * s, 2.2 * s, 2.6 * s, x, y + 1.1 * s, z, 0, yaw, 0, o(Kit.planks, lod or "shell", { q = false }))
	bp:rbox(2.7 * s, 0.3 * s, 0.3 * s, x, y + 2.1 * s, z, 0, yaw, 0, o(Kit.oldWood, "fine", { col = false }))
end

function Kit.barrel(bp: BP, x: number, y: number, z: number, s: number, lod: any?)
	bp:add("cyl", 3 * s, 2.2 * s, 2.2 * s, x, y + 1.5 * s, z, 0, 0, 90, o(Kit.wood, lod or "shell", { q = false }))
	for _, h in { 0.5, 2.5 } do
		bp:add("cyl", 0.25, 2.3 * s, 2.3 * s, x, y + h * s, z, 0, 0, 90, o(Kit.iron, "fine", { col = false }))
	end
end

function Kit.ropeCoil(bp: BP, x: number, y: number, z: number)
	bp:add("cyl", 0.5, 2, 2, x, y + 0.25, z, 0, 0, 90, o(Kit.rope, "fine", { col = false }))
end

-- A web strung between two points (thin translucent strands and a few spokes).
function Kit.web(bp: BP, ax: number, ay: number, az: number, bx: number, by: number, bz: number, lod: any?)
	local l = lod or "detail"
	bp:beam(ax, ay, az, bx, by, bz, 0.08, o(Kit.silk, l, { col = false, t = 0.35 }))
	local mx, my, mz = (ax + bx) / 2, (ay + by) / 2, (az + bz) / 2
	for k = 0, 4 do
		local a = k * math.pi * 2 / 5
		bp:beam(
			mx,
			my,
			mz,
			mx + math.cos(a) * 3,
			my + math.sin(a) * 3,
			mz,
			0.06,
			o(Kit.silk, "fine", { col = false, t = 0.4 })
		)
	end
	bp:add("cyl", 0.06, 5, 5, mx, my, mz, 90, 0, 0, o(Kit.silk, "fine", { col = false, t = 0.7 }))
end

-- A silk cocoon hanging on a thread (`feet`: goblin feet stick out of it).
function Kit.cocoon(bp: BP, x: number, y: number, z: number, top: number, feet: boolean?)
	bp:box(
		0.08,
		math.max(0.5, top - y - 2),
		0.08,
		x,
		(top + y + 2) / 2,
		z,
		o(Kit.silk, "fine", { col = false, t = 0.3 })
	)
	bp:add("ball", 1.4, 3, 1.4, x, y + 1, z, 0, 0, 0, o(Kit.silk, "detail", { col = false, t = 0.1 }))
	if feet then
		for _, s in { -1, 1 } do
			bp:box(
				0.35,
				0.6,
				0.6,
				x + s * 0.3,
				y - 0.6,
				z - 0.1,
				o({ c = "#5E7A3A", m = "SmoothPlastic" }, "fine", { col = false })
			)
		end
	end
end

-- A glowing mushroom (cap with the "glow" tag: it breathes; light with `light`).
function Kit.glowCap(bp: BP, x: number, y: number, z: number, s: number, color: string?, light: boolean?, lod: any?)
	local c = color or Kit.MOSS
	local l = lod or "detail"
	bp:add(
		"cyl",
		2.4 * s,
		0.6 * s,
		0.6 * s,
		x,
		y + 1.2 * s,
		z,
		0,
		0,
		90,
		o({ c = "#D8D2C0", m = "SmoothPlastic" }, l, { col = false })
	)
	bp:add("ball", 2.6 * s, 1 * s, 2.6 * s, x, y + 2.5 * s, z, 0, 0, 0, {
		c = c,
		m = "Neon",
		lod = l,
		col = false,
		q = false,
		tag = "glow",
		jitter = 0,
		fxColor = c,
		t = 0.15,
	})
	if light then
		bp:light(x, y + 3 * s, z, c, 12 + 4 * s, 0.9, "crystal")
	end
end

-- A banner on a pole (flapping: flag tag).
function Kit.banner(bp: BP, x: number, y: number, z: number, h: number, cloth: Swatch, lod: any?)
	local l = lod or "detail"
	bp:box(0.4, h, 0.4, x, y + h / 2, z, o(Kit.wood, l, { col = false }))
	bp:box(2.6, 0.25, 0.25, x + 1.2, y + h - 0.3, z, o(Kit.wood, l, { col = false }))
	bp:box(2.4, 5, 0.15, x + 1.3, y + h - 3, z, { c = cloth.c, m = cloth.m, lod = l, col = false, tag = "flag" })
end

-- A warning totem: a pole with a skull, horns and rags.
function Kit.totem(bp: BP, x: number, y: number, z: number, h: number, lod: any?)
	bp:box(0.8, h, 0.8, x, y + h / 2, z, o(Kit.oldWood, lod or "shell", { q = false }))
	WK.skull(bp, x, y + h, z - 0.2, 1.4, 0)
	for _, s in { -1, 1 } do
		bp:beam(x, y + h - 0.8, z, x + s * 1.4, y + h + 0.4, z, 0.25, o(Kit.bone, "fine", { col = false }))
	end
	bp:box(1.4, 1.8, 0.1, x, y + h - 2.4, z - 0.45, o(Kit.red, "fine", { col = false }))
end

-- An ore vein in the rock behind a node: streaks of the ore's colour (copper, iron, silver...).
local VEIN: { [string]: string } = {
	vein_copper = "#B87333",
	vein_iron = "#8A8C90",
	vein_silver = "#D8D8E0",
	vein_mithril = "#9FE0FF",
	vein_adamantite = "#7A5ACB",
	vein_gold = "#E8C25A",
}
function Kit.vein(bp: BP, x: number, y: number, z: number, kind: string, yaw: number)
	local c = VEIN[kind] or "#9A9A9A"
	bp:push(x, y, z, 0, yaw, 0)
	for k = 0, 4 do
		bp:rbox(
			0.5,
			0.4,
			2.4 + k * 0.4,
			(k - 2) * 0.6,
			1 + k * 0.9,
			0,
			30 + k * 20,
			0,
			15,
			o({ c = c, m = "Metal" }, "detail", { col = false })
		)
	end
	bp:pop()
end

-- Lava (S50) ---------------------------------------------------------------------------------------------------------

Kit.LAVA = "#FF5A1A"
Kit.METAL = "#FFC860" -- molten metal in the forges' gutters (brighter)
Kit.slag = { c = "#2A1A14", m = "Basalt" }
Kit.basalt = { c = "#2F2B30", m = "Basalt" }

local function lavaOpts(color: string, t: number?, tag: string?, lod: any?): any
	return {
		c = color,
		m = "Neon",
		lod = lod or "detail",
		col = false,
		q = false,
		t = t or 0.3,
		tag = tag or "lava",
		jitter = 0,
		fxColor = color,
	}
end
Kit.lavaOpts = lavaOpts

local CRUST: any =
	{ c = "#2A1A14", m = "Basalt", lod = "detail", col = false, q = false, tag = "lavaCrust", jitter = 0.1 }

-- The glow of every lava feature of the cave (client detail, tag "lava": the colour pulses; dark floes "lavaCrust";
-- falls "lavafall"; lights of kind "lava" every ~36 studs, managed with the cave's lights): one Build per feature,
-- standing on the lava. Embers and heat haze over the lava, bubbles on the pools. `metal` = molten metal (brighter).
function Kit.lavaGlow(env: Env, out: { Build })
	local T = env.T
	for i, f in env.shape.features do
		local kind = f.kind
		local color = if f.metal then Kit.METAL else Kit.LAVA
		if kind == "pool" and f.liquid == "lava" then
			local b = Kit.build(env, `LavaPool_{i}`, "lava", f.x, f.z, 0)
			local y = Kit.gy(env, b, 0, 0)
			b.bp:add("cyl", 0.2, f.r * 1.9, f.r * 1.9, 0, y + 0.3, 0, 0, 0, 90, lavaOpts(color, 0.3))
			if f.r >= 5 then
				for k = 1, math.min(6, math.floor(f.r / 3)) do
					local a = k * 2.4
					local d = f.r * 0.5 * ((k % 3) / 3 + 0.3)
					b.bp:rbox(1.6 + (k % 2), 0.25, 1.1, math.cos(a) * d, y + 0.45, math.sin(a) * d, 0, k * 47, 0, CRUST)
				end
			end
			b.bp:light(0, y + 4, 0, color, math.min(40, 14 + f.r * 2), 1.4, "lava")
			Kit.lifeAt(env.ctx, b, if f.r >= 5 then "lavaBubbles" else "embers", 0, 0.5, 0, f.r)
			if f.r >= 8 then
				Kit.lifeAt(env.ctx, b, "haze", 0, 1, 0, f.r)
			end
			table.insert(out, b)
		elseif kind == "stream" and f.liquid == "lava" then
			local line = TerrainLayers.line(TerrainLayers.pairs(f.points))
			local x0, z0 = TerrainLayers.pointAt(line, 0)
			local b = Kit.build(env, `LavaStream_{i}`, "lava", x0, z0, 0)
			local s = 0
			local lightIn = 0
			local k = 0
			while s < line.length do
				local x, z, dx, dz = TerrainLayers.pointAt(line, s)
				local lx, lz = x - b.at.x, z - b.at.z
				local liquid = T.liquid(x, z)
				if liquid and liquid.kind == "lava" then
					local y = liquid.level - b.at.y
					local yaw = math.deg(math.atan2(dx, dz))
					local step = math.min(8, line.length - s)
					local cx, cz = lx + dx * step / 2, lz + dz * step / 2
					b.bp:rbox(f.width * 0.9, 0.2, step + 0.6, cx, y + 0.3, cz, 0, yaw, 0, lavaOpts(color, 0.3))
					k += 1
					if f.width >= 6 and k % 2 == 0 then
						local ox, oz = dz * f.width * 0.15, -dx * f.width * 0.15
						b.bp:rbox(f.width * 0.3, 0.25, 2.2, lx + ox, y + 0.45, lz + oz, 0, yaw + 20, 0, CRUST)
					end
					lightIn -= step
					if lightIn <= 0 then
						b.bp:light(lx, y + 4, lz, color, if f.width >= 6 then 36 else 20, 1.3, "lava")
						lightIn = 36
					end
					if k % 3 == 1 then
						Kit.lifeAt(env.ctx, b, "embers", lx, y + 0.5, lz, math.max(2, f.width / 2))
					end
					if f.width >= 6 and k % 3 == 2 then
						Kit.lifeAt(env.ctx, b, "haze", lx, y + 1, lz, f.width)
					end
				end
				s += 8
			end
			table.insert(out, b)
		elseif kind == "vent" then
			local b = Kit.build(env, `Vent_{i}`, "vent", f.x, f.z, 0)
			local y = Kit.gy(env, b, 0, 0)
			b.bp:add("cyl", 0.2, f.r * 2, f.r * 2, 0, y + 0.2, 0, 0, 0, 90, lavaOpts(Kit.LAVA, 0.35, "vent"))
			for k = 0, 4 do
				local a = k * 1.3
				local d = f.r + 0.8
				b.bp:rbox(
					1.2,
					0.6,
					0.8,
					math.cos(a) * d,
					y + 0.2,
					math.sin(a) * d,
					0,
					k * 60,
					10,
					o(Kit.slag, "detail", { col = false })
				)
			end
			b.bp:light(0, y + 2, 0, Kit.LAVA, 14, 1, "lava")
			Kit.lifeAt(env.ctx, b, "steam", 0, 0.5, 0, 2)
			Kit.lifeAt(env.ctx, b, "embers", 0, 0.5, 0, 2)
			table.insert(out, b)
		elseif kind == "crack" then
			local pts = f.points
			local b = Kit.build(env, `Crack_{i}`, "lava", pts[1], pts[2], 0)
			local y0 = Kit.gy(env, b, 0, 0)
			for k = 1, #pts - 3, 2 do
				local ax, az = pts[k] - b.at.x, pts[k + 1] - b.at.z
				local bx, bz = pts[k + 2] - b.at.x, pts[k + 3] - b.at.z
				local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
				local mx, mz = (ax + bx) / 2, (az + bz) / 2
				local yaw = math.deg(math.atan2(bx - ax, bz - az))
				b.bp:rbox(
					f.width * 0.8,
					0.15,
					len,
					mx,
					Kit.gy(env, b, mx, mz) + 0.2,
					mz,
					0,
					yaw,
					0,
					lavaOpts(Kit.LAVA, 0.25, "ember")
				)
			end
			b.bp:light(0, y0 + 3, 0, Kit.LAVA, 22, 1.2, "lava")
			Kit.lifeAt(env.ctx, b, "embers", 0, 0.5, 0, 4)
			table.insert(out, b)
		elseif kind == "moat" then
			-- the Build stands on the lava (on the ring towards +x)
			local mid = (f.inner + f.outer) / 2
			local b = Kit.build(env, `LavaMoat_{i}`, "lava", f.x + mid, f.z, 0)
			local width = f.outer - f.inner
			local n = math.max(8, math.floor(2 * math.pi * mid / 12))
			for k = 0, n - 1 do
				local a = (k + 0.5) * 2 * math.pi / n
				local wx, wz = f.x + math.cos(a) * mid, f.z + math.sin(a) * mid
				local liquid = T.liquid(wx, wz)
				if liquid and liquid.kind == "lava" then
					local lx, lz = wx - b.at.x, wz - b.at.z
					local y = liquid.level - b.at.y
					local seg = 2 * math.pi * mid / n + 0.8
					b.bp:rbox(width * 0.9, 0.2, seg, lx, y + 0.3, lz, 0, math.deg(-a), 0, lavaOpts(color, 0.3))
					if k % 3 == 0 then
						b.bp:light(lx, y + 4, lz, color, math.min(40, 16 + width * 2), 1.3, "lava")
						Kit.lifeAt(env.ctx, b, "embers", lx, y + 0.5, lz, width / 2)
					end
				end
			end
			table.insert(out, b)
		elseif kind == "lavafall" then
			-- the foot stands on the lava; the sheets lean back towards bearing rot (degrees) up to `top`
			local b = Kit.build(env, `Lavafall_{i}`, "lavafall", f.x, f.z, f.rot or 0)
			local y = Kit.gy(env, b, 0, 0)
			local top = f.top
			for k = -1, 1 do
				b.bp:rbox(2.6 - math.abs(k) * 0.8, top, 0.5, k * 1.6, y + top / 2, 1.5, -6, 0, k * 3, {
					c = color,
					m = "Neon",
					lod = "detail",
					col = false,
					q = false,
					t = 0.12 + math.abs(k) * 0.15,
					tag = if k == 0 then "lavafall" else "lava",
					jitter = 0,
					fxColor = color,
				})
			end
			b.bp:add("ball", 6, 1.2, 5, 0, y + 0.4, 0, 0, 0, 0, lavaOpts(color, 0.35, "vent"))
			b.bp:light(0, y + 4, 0, color, 30, 1.6, "lava")
			Kit.lifeAt(env.ctx, b, "smoke", 0, 2, 0, 4)
			Kit.lifeAt(env.ctx, b, "embers", 0, 1, 0, 4)
			table.insert(out, b)
		end
	end
end

return Kit
