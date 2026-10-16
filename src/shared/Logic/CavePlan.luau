--!strict
-- S134h: the one source of a cave's plan on the cave engine. A cave's shape (Data/CaveShapes) may carry `scale`
-- (default 1): the drawn cave is its plan stretched by it. Every horizontal measure of the plan and the shape (rooms,
-- corridors, features, their radii and widths) grows by `scale`; floors, liquids and their levels stay; the gap
-- between floor and ceiling grows by half of it (CavePlan.heightScale = 1 + (scale - 1) / 2). Logic/CaveTerrain draws
-- the cave the same way (the plan's column at (x / scale, z / scale)), so every rule tuned on the plan (shores, steps,
-- cores) holds, and the layout, the dressing and the anchors stay where they were relative to the rooms.
-- Everything that reads a cave's room plan or an authored point in a cave reads it through here: Logic/AreaSpawns
-- (spawners), Logic/CaveTerrain (T.rooms, T.shape), the dressing (Logic/CaveDress: `shape` and the fixed points through
-- Kit.at = CavePlan.coord), the quest anchors (World/CaveLayout, Data/Areas.anchorById), Data/Portals (exit, gate),
-- Data/Maps (size, spawn, dungeon entrance), Data/Cutscenes (shots in caves) and the tools. The data (Data/Areas/Caves
-- rooms and anchors, Data/CaveShapes, Logic/CaveGen) stays in plan units. Pure (Lune); requires no Logic/CaveTerrain
-- and no Data/Maps.

local AreaTypes = require("../Data/Areas/Types")
local CaveGen = require("./CaveGen")
local CaveShapes = require("../Data/CaveShapes")

local CavePlan = {}

export type Room = AreaTypes.Room
export type Corridor = CaveGen.Corridor
export type Plan = { rooms: { Room }, corridors: { Corridor } }

-- Horizontal scale of a map on the cave engine (1 for maps without `scale` and maps without a shape).
function CavePlan.scale(mapId: string): number
	local shape = CaveShapes.byMap[mapId]
	return if shape and shape.scale then shape.scale else 1
end

-- Scale of the gap between floor and ceiling (the rooms' heights): half of the horizontal growth.
function CavePlan.heightScale(mapId: string): number
	return 1 + (CavePlan.scale(mapId) - 1) / 2
end

-- An authored horizontal coordinate (one number) of a cave map, as it stands in the drawn cave.
function CavePlan.coord(mapId: string, v: number): number
	return v * CavePlan.scale(mapId)
end

-- An authored point (x, z) of a cave map, as it stands in the drawn cave.
function CavePlan.point(mapId: string, x: number, z: number): (number, number)
	local s = CavePlan.scale(mapId)
	return x * s, z * s
end

-- Map size (studs) of a cave on the engine from its plan size (the generated caves CaveGen.SIZE, the boss caves 640).
function CavePlan.size(mapId: string, planSize: number): number
	return math.ceil(planSize * CavePlan.scale(mapId))
end

-- Rooms and corridors of a cave in plan units: its listed rooms (boss caves; no corridors: the shape's tunnels join
-- them) or the plan of Logic/CaveGen from its seed. Only Logic/CaveTerrain (which stretches it itself) reads this;
-- everything else reads CavePlan.plan.
function CavePlan.basePlan(cave: AreaTypes.Cave): Plan
	if cave.rooms then
		return { rooms = cave.rooms, corridors = {} }
	end
	return CaveGen.generate(cave.seed or 1)
end

local planCache: { [string]: Plan } = {}

-- Rooms and corridors of a cave as drawn (CavePlan.basePlan stretched). Cached; never modify the result.
function CavePlan.plan(cave: AreaTypes.Cave): Plan
	local cached = planCache[cave.id]
	if cached then
		return cached
	end
	local s, hs = CavePlan.scale(cave.id), CavePlan.heightScale(cave.id)
	local base = CavePlan.basePlan(cave)
	local plan: Plan = { rooms = {}, corridors = {} }
	for _, r in base.rooms do
		table.insert(plan.rooms, { x = r.x * s, z = r.z * s, r = r.r * s, h = r.h * hs })
	end
	for _, c in base.corridors do
		table.insert(plan.corridors, { ax = c.ax * s, az = c.az * s, bx = c.bx * s, bz = c.bz * s, w = c.w * s })
	end
	planCache[cave.id] = plan
	return plan
end

-- Rooms of a cave as drawn (CavePlan.plan): rooms[1] is the entrance; boss caves: the last room is the antechamber.
function CavePlan.rooms(cave: AreaTypes.Cave): { Room }
	return CavePlan.plan(cave).rooms
end

-- The quest anchors of a cave as they stand in the drawn cave (x / z scaled, y and the rest kept).
function CavePlan.anchors(cave: AreaTypes.Cave): { AreaTypes.QuestAnchor }
	local s = CavePlan.scale(cave.id)
	local list: { AreaTypes.QuestAnchor } = {}
	for _, a in cave.questAnchors or {} :: { AreaTypes.QuestAnchor } do
		local copy = table.clone(a)
		copy.x, copy.z = a.x * s, a.z * s
		table.insert(list, copy)
	end
	return list
end

-- Horizontal measures of a feature (positions, radii, widths, ramps); `points` (flat x, z lists), `hole`, `windows`,
-- `bands`, `spokes` and `gap` are handled apart. Vertical measures (level, depth, drop, dy, height, rise, roof) stay;
-- the ceiling-side ones grow with the headroom (HEIGHT_KEYS).
local FEATURE_KEYS =
	{ "x", "z", "r", "ax", "az", "bx", "bz", "inner", "outer", "hx", "hz", "pool", "width", "w", "blend", "bank" }
-- Ceiling-side heights by kind: the gap between floor and ceiling grows by the height scale.
local HEIGHT_KEYS: { [string]: { string } } = {
	niche = { "h" },
	chimney = { "h" },
	stalactites = { "length" },
	waterfall = { "top" },
	lavafall = { "top" },
	icefall = { "top" },
}

local function scaleFeature(f: CaveShapes.Feature, s: number, hs: number): CaveShapes.Feature
	local out = table.clone(f)
	for _, key in FEATURE_KEYS do
		if type(f[key]) == "number" then
			out[key] = f[key] * s
		end
	end
	local heights: { string } = HEIGHT_KEYS[f.kind] or {}
	for _, key in heights do
		if type(f[key]) == "number" then
			out[key] = f[key] * hs
		end
	end
	if type(f.points) == "table" then
		local points = {}
		for i, v in f.points do
			points[i] = v * s
		end
		out.points = points
	end
	if type(f.hole) == "table" then
		out.hole = { x = f.hole.x * s, z = f.hole.z * s, r = f.hole.r * s }
	end
	if type(f.windows) == "table" then
		local windows = {}
		for i, w in f.windows do
			local copy = table.clone(w)
			copy.x, copy.z = w.x * s, w.z * s
			if type(w.w) == "number" then
				copy.w = w.w * s
			end
			windows[i] = copy
		end
		out.windows = windows
	end
	if type(f.bands) == "table" then
		local bands = {}
		for i, b in f.bands do
			bands[i] = { b[1] * s, b[2] * s, b[3] }
		end
		out.bands = bands
	end
	if type(f.spokes) == "table" then
		local spokes: { [string]: any } = table.clone(f.spokes)
		for _, key in { "from", "to", "width" } do
			if type(spokes[key]) == "number" then
				spokes[key] *= s
			end
		end
		out.spokes = spokes
	end
	if type(f.gap) == "table" and type(f.gap.width) == "number" then
		local gap: { [string]: any } = table.clone(f.gap)
		gap.width *= s
		out.gap = gap
	end
	return out
end

local shapeCache: { [string]: CaveShapes.Shape } = {}

-- The shape of a map as it is drawn: Data/CaveShapes stretched (the entry itself when its scale is 1). nil for maps
-- without a shape. Cached; never modify the result.
function CavePlan.shape(mapId: string): CaveShapes.Shape?
	local shape = CaveShapes.byMap[mapId]
	if not shape then
		return nil
	end
	local s = CavePlan.scale(mapId)
	if s == 1 then
		return shape
	end
	local cached = shapeCache[mapId]
	if cached then
		return cached
	end
	local hs = CavePlan.heightScale(mapId)
	local out = table.clone(shape)
	out.wall = { amp = shape.wall.amp * s, scale = shape.wall.scale * s }
	out.ceiling = { amp = shape.ceiling.amp * hs, scale = shape.ceiling.scale * s }
	out.tunnelH = (shape.tunnelH or 14) * hs
	out.wiggle = if shape.wiggle then shape.wiggle * s else nil
	if shape.rooms then
		local rooms: { [number]: CaveShapes.RoomShape } = {}
		for i, r in shape.rooms do
			local copy = table.clone(r)
			copy.hx = if r.hx then r.hx * s else nil
			copy.hz = if r.hz then r.hz * s else nil
			copy.h = if r.h then r.h * hs else nil
			rooms[i] = copy
		end
		out.rooms = rooms
	end
	if shape.tunnels then
		local tunnels: { CaveShapes.Tunnel } = {}
		for i, t in shape.tunnels do
			local copy = table.clone(t)
			copy.ax, copy.az, copy.bx, copy.bz = t.ax * s, t.az * s, t.bx * s, t.bz * s
			copy.w = t.w * s
			copy.h = if t.h then t.h * hs else nil
			copy.wiggle = if t.wiggle then t.wiggle * s else nil
			tunnels[i] = copy
		end
		out.tunnels = tunnels
	end
	if shape.extraRooms then
		local extra: { CaveShapes.ExtraRoom } = {}
		for i, e in shape.extraRooms do
			local copy = table.clone(e)
			copy.x, copy.z, copy.r, copy.h = e.x * s, e.z * s, e.r * s, e.h * hs
			copy.hx = if e.hx then e.hx * s else nil
			copy.hz = if e.hz then e.hz * s else nil
			extra[i] = copy
		end
		out.extraRooms = extra
	end
	local features: { CaveShapes.Feature } = {}
	for i, f in shape.features do
		features[i] = scaleFeature(f, s, hs)
	end
	out.features = features
	if shape.arena then
		out.arena = { x = shape.arena.x * s, z = shape.arena.z * s, r = shape.arena.r * s }
	end
	if shape.braziers then
		local braziers = {}
		for i, p in shape.braziers do
			braziers[i] = { p[1] * s, p[2] * s }
		end
		out.braziers = braziers
	end
	shapeCache[mapId] = out
	return out
end

return CavePlan
