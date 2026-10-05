--!strict
-- Map building context shared by the layouts (World/Layouts/*). Coordinates are map-relative (x, z) studs;
-- the ground top of every map is y = 0 (terrain), heights are read back with a raycast against Terrain.
-- Besides geometry the context collects what other systems need: zone volumes and spawn points (tags),
-- portals and dungeon gates (tags + attributes), gathering node placements and a light-weight sketch of the
-- map (paths, water, buildings, icons) for the minimap and the world map.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local AreaSpawns = require(game:GetService("ReplicatedStorage").Shared.Logic.AreaSpawns)
local Areas = require(game:GetService("ReplicatedStorage").Shared.Data.Areas)
local Maps = require(game:GetService("ReplicatedStorage").Shared.Data.Maps)
local Rng = require(game:GetService("ReplicatedStorage").Shared.Logic.Rng)

local Build = {}

export type Shape =
	{ t: "rect", x: number, z: number, w: number, h: number, r: number?, c: string }
	| { t: "circle", x: number, z: number, r: number, c: string }
	| { t: "line", p: { number }, w: number, c: string }

export type Icon = { t: string, x: number, z: number, id: string? }

export type NodePlacement = { kind: string, x: number, z: number }

export type Context = {
	map: Maps.MapDef,
	origin: Vector3,
	folder: Folder,
	decor: Folder,
	rng: Rng.Rng,
	-- Ray start height above y = 0 for ground lookups (low inside caves so the roof is not hit).
	rayFrom: number,
	sketch: { shapes: { Shape }, icons: { Icon } },
	nodes: { NodePlacement },
	parts: number,
	trees: { { number } }, -- tree positions; the published sketch merges them into forest patches (S20)
}

local terrain = Workspace.Terrain

-- Map-relative x/z -> world position at height y.
function Build.at(ctx: Context, x: number, y: number, z: number): Vector3
	return ctx.origin + Vector3.new(x, y, z)
end

-- Ground height (map-relative y) at x/z, from the terrain surface.
function Build.groundY(ctx: Context, x: number, z: number): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { terrain }
	params.IgnoreWater = true
	local start = Build.at(ctx, x, ctx.rayFrom, z)
	local hit = Workspace:Raycast(start, Vector3.new(0, -(ctx.rayFrom + 60), 0), params)
	return if hit then hit.Position.Y - ctx.origin.Y else 0
end

function Build.ground(ctx: Context, x: number, z: number): Vector3
	return Build.at(ctx, x, Build.groundY(ctx, x, z), z)
end

function Build.new(map: Maps.MapDef, root: Instance): Context
	local folder = Instance.new("Folder")
	folder.Name = map.id
	folder.Parent = root
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = folder
	local seed = 0
	for i = 1, #map.id do
		seed = (seed * 31 + string.byte(map.id, i)) % 2147483647
	end
	return {
		map = map,
		origin = Vector3.new(map.offset.x, map.offset.y, map.offset.z),
		folder = folder,
		decor = decor,
		rng = Rng.new(seed),
		rayFrom = 160,
		sketch = { shapes = {}, icons = {} },
		nodes = {},
		parts = 0,
		trees = {},
	}
end

-- Terrain ----------------------------------------------------------------------------------------

-- Solid ground slab with its top at y = 0 over a rectangle.
function Build.fill(
	ctx: Context,
	x1: number,
	z1: number,
	x2: number,
	z2: number,
	material: Enum.Material,
	depth: number?
)
	local d = depth or 16
	local size = Vector3.new(math.abs(x2 - x1), d, math.abs(z2 - z1))
	local centre = Build.at(ctx, (x1 + x2) / 2, -d / 2, (z1 + z2) / 2)
	terrain:FillBlock(CFrame.new(centre), size, material)
end

-- Paints the top layer of a rectangle (rotated by `angle` radians) with another material.
function Build.paint(ctx: Context, x: number, z: number, w: number, h: number, angle: number, material: Enum.Material)
	local cf = CFrame.new(Build.at(ctx, x, -2, z)) * CFrame.Angles(0, angle, 0)
	terrain:FillBlock(cf, Vector3.new(w, 4, h), material)
	-- Large ground patches (sand, mud, ash...) go on the map (S20); roads are recorded by Build.path.
	if w >= 100 and h >= 100 and ctx.rayFrom > 20 then
		table.insert(
			ctx.sketch.shapes,
			{ t = "rect", x = x, z = z, w = w, h = h, r = math.deg(angle), c = `ground:{material.Name}` }
		)
	end
end

-- Hill: a half-buried ball; `height` is how much rises above the ground.
function Build.hill(ctx: Context, x: number, z: number, radius: number, height: number, material: Enum.Material)
	local r = math.max(radius, height)
	terrain:FillBall(Build.at(ctx, x, height - r, z), r, material)
	table.insert(ctx.sketch.shapes, { t = "circle", x = x, z = z, r = radius * 0.8, c = "hill" })
end

-- Path through points {x1, z1, x2, z2, ...}: painted ground segments, recorded in the sketch.
function Build.path(ctx: Context, points: { number }, width: number, material: Enum.Material)
	for i = 1, #points - 3, 2 do
		local ax, az, bx, bz = points[i], points[i + 1], points[i + 2], points[i + 3]
		local dx, dz = bx - ax, bz - az
		local length = math.sqrt(dx * dx + dz * dz)
		local angle = math.atan2(-dz, dx)
		Build.paint(ctx, (ax + bx) / 2, (az + bz) / 2, length + width, width, angle, material)
	end
	table.insert(ctx.sketch.shapes, { t = "line", p = points, w = width, c = "path" })
end

-- Round lake: carves a bowl and fills it with water up to y = -0.5.
function Build.lake(ctx: Context, x: number, z: number, radius: number, depth: number)
	terrain:FillCylinder(CFrame.new(Build.at(ctx, x, -depth / 2, z)), depth + 4, radius, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(Build.at(ctx, x, -depth - 1, z)), 4, radius, Enum.Material.Mud)
	terrain:FillCylinder(CFrame.new(Build.at(ctx, x, -depth / 2 - 0.5, z)), depth, radius - 2, Enum.Material.Water)
	table.insert(ctx.sketch.shapes, { t = "circle", x = x, z = z, r = radius, c = "water" })
end

-- Ring of mountains just outside the map edge plus invisible walls on the boundary. S19: the balls have
-- radius BORDER_RADIUS and their centres sit BORDER_RADIUS outside the edge, so no slope reaches into the map
-- (portals near the edge used to stand 40–80 studs up the mountains).
Build.BORDER_RADIUS = 70

function Build.border(ctx: Context, material: Enum.Material, height: number)
	local hx, hz = ctx.map.size.x / 2, ctx.map.size.z / 2
	local step = 60
	local r = Build.BORDER_RADIUS
	local function mountain(x: number, z: number)
		local rise = math.min(r, height + ctx.rng:float(-10, 15))
		terrain:FillBall(Build.at(ctx, x, rise - r, z), r, material)
		-- A second, higher ball further out keeps the skyline tall.
		local far = r * 1.5
		local fx = if math.abs(x) > hx then x + math.sign(x) * r * 0.9 else x
		local fz = if math.abs(z) > hz then z + math.sign(z) * r * 0.9 else z
		terrain:FillBall(Build.at(ctx, fx, height * 1.3 - far, fz), far, material)
	end
	for x = -hx, hx, step do
		for _, z in { -hz - r, hz + r } do
			mountain(x + ctx.rng:float(-12, 12), z)
		end
	end
	for z = -hz, hz, step do
		for _, x in { -hx - r, hx + r } do
			mountain(x, z + ctx.rng:float(-12, 12))
		end
	end
	-- The border hills are not part of the minimap.
	local kept = {}
	for _, shape in ctx.sketch.shapes do
		if not (shape.t == "circle" and shape.c == "hill" and (math.abs(shape.x) > hx or math.abs(shape.z) > hz)) then
			table.insert(kept, shape)
		end
	end
	ctx.sketch.shapes = kept
	for _, wall in
		{
			{ 0, -hz, hx * 2, 4 },
			{ 0, hz, hx * 2, 4 },
			{ -hx, 0, 4, hz * 2 },
			{ hx, 0, 4, hz * 2 },
		}
	do
		local p = Instance.new("Part")
		p.Name = "Boundary"
		p.Anchored = true
		p.Transparency = 1
		p.CanQuery = false
		p.Size = Vector3.new(wall[3], 300, wall[4])
		p.CFrame = CFrame.new(Build.at(ctx, wall[1], 140, wall[2]))
		p.Parent = ctx.folder
	end
end

-- Cave: a solid rock block over the whole map; rooms and corridors are carved with `carve*`.
function Build.caveShell(ctx: Context, material: Enum.Material, height: number)
	local hx, hz = ctx.map.size.x / 2 + 40, ctx.map.size.z / 2 + 40
	terrain:FillBlock(
		CFrame.new(Build.at(ctx, 0, (height - 16) / 2, 0)),
		Vector3.new(hx * 2, height + 16, hz * 2),
		material
	)
	ctx.rayFrom = 6
end

-- Carves a room (flat floor at y = 0) with a domed ceiling.
function Build.carveRoom(ctx: Context, x: number, z: number, radius: number, height: number)
	terrain:FillCylinder(CFrame.new(Build.at(ctx, x, height / 2, z)), height, radius, Enum.Material.Air)
	terrain:FillBall(Build.at(ctx, x, height * 0.6, z), radius * 0.85, Enum.Material.Air)
	table.insert(ctx.sketch.shapes, { t = "circle", x = x, z = z, r = radius, c = "floor" })
end

-- Carves a straight corridor between two points.
function Build.carveCorridor(
	ctx: Context,
	ax: number,
	az: number,
	bx: number,
	bz: number,
	width: number,
	height: number
)
	local dx, dz = bx - ax, bz - az
	local length = math.sqrt(dx * dx + dz * dz)
	local cf = CFrame.new(Build.at(ctx, (ax + bx) / 2, height / 2, (az + bz) / 2))
		* CFrame.Angles(0, math.atan2(-dz, dx), 0)
	terrain:FillBlock(cf, Vector3.new(length + width, height, width), Enum.Material.Air)
	table.insert(ctx.sketch.shapes, { t = "line", p = { ax, az, bx, bz }, w = width, c = "floor" })
end

-- Gameplay markers ---------------------------------------------------------------------------------

-- Zone volume read by ZoneService (smallest containing volume wins).
function Build.zone(ctx: Context, pvp: string, nameKey: string?, x1: number, z1: number, x2: number, z2: number)
	local p = Instance.new("Part")
	p.Name = `Zone_{nameKey or ctx.map.id}`
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.new(math.abs(x2 - x1), 400, math.abs(z2 - z1))
	p.CFrame = CFrame.new(Build.at(ctx, (x1 + x2) / 2, 150, (z1 + z2) / 2))
	p:SetAttribute("MapId", ctx.map.id)
	p:SetAttribute("PvpZone", pvp)
	if nameKey then
		p:SetAttribute("NameKey", nameKey)
	end
	CollectionService:AddTag(p, "ZoneVolume")
	p.Parent = ctx.folder
end

-- Respawn marker (DeathService picks the nearest of the map).
function Build.spawnPoint(ctx: Context, x: number, z: number, lookX: number?, lookZ: number?)
	local position = Build.ground(ctx, x, z)
	local look = Build.at(ctx, lookX or 0, position.Y - ctx.origin.Y, (lookZ or 0) + 0.001)
	local p = Instance.new("Part")
	p.Name = "SpawnPoint"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Size = Vector3.new(6, 0.2, 6)
	p.CFrame = CFrame.lookAt(position + Vector3.new(0, 0.15, 0), look)
	p.Color = Color3.fromHex("#C9A45C")
	p.Material = Enum.Material.Neon
	p.Transparency = 0.6
	p:SetAttribute("MapId", ctx.map.id)
	CollectionService:AddTag(p, "SpawnPoint")
	p.Parent = ctx.folder
	table.insert(ctx.sketch.icons, { t = "spawn", x = x, z = z })
end

function Build.node(ctx: Context, kind: string, x: number, z: number)
	table.insert(ctx.nodes, { kind = kind, x = x, z = z })
end

-- Roads of a region map from Data/Areas (one source with the monster areas and the map, S19).
function Build.roads(ctx: Context, data: Areas.MapAreas)
	for _, road in data.roads do
		local ok, material = pcall(function()
			return (Enum.Material :: any)[road.material]
		end)
		Build.path(ctx, road.points, road.width, if ok and material then material else Enum.Material.Ground)
	end
end

-- Placement filter for props and nodes: off the roads, out of the water and the avoided circles.
function Build.clearOf(data: Areas.MapAreas, margin: number?): (x: number, z: number) -> boolean
	local m = margin or 6
	return function(x: number, z: number): boolean
		if AreaSpawns.nearRoad(data.roads, x, z, m) then
			return false
		end
		for _, list in { data.lakes, data.avoid } do
			for _, c in list do
				if (x - c.x) ^ 2 + (z - c.z) ^ 2 < (c.r + m) ^ 2 then
					return false
				end
			end
		end
		for _, entrance in data.caves do
			if (x - entrance.x) ^ 2 + (z - entrance.z) ^ 2 < 40 * 40 then
				return false
			end
		end
		return true
	end
end

-- Flattens the ground around a point: clears terrain above y = 0 and fills a solid slab below (portals,
-- cave mouths), so nothing stands on a slope.
function Build.flatten(ctx: Context, x: number, z: number, radius: number, material: Enum.Material?)
	terrain:FillCylinder(CFrame.new(Build.at(ctx, x, 30, z)), 60, radius, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(Build.at(ctx, x, -4, z)), 8, radius, material or Enum.Material.Ground)
end

-- Scatters `n` gathering nodes of `kind` in a rectangle, away from the circles in `avoid` ({x, z, r}) and
-- from other nodes (S19: many more nodes per map).
function Build.scatterNodes(
	ctx: Context,
	kind: string,
	n: number,
	rect: { number },
	avoid: { { x: number, z: number, r: number } }?,
	allow: ((x: number, z: number) -> boolean)?
)
	local placed = 0
	local tries = 0
	while placed < n and tries < n * 40 do
		tries += 1
		local x, z = ctx.rng:float(rect[1], rect[3]), ctx.rng:float(rect[2], rect[4])
		local ok = allow == nil or allow(x, z)
		if ok then
			for _, c in (avoid or {}) :: { { x: number, z: number, r: number } } do
				if (x - c.x) ^ 2 + (z - c.z) ^ 2 < c.r * c.r then
					ok = false
					break
				end
			end
		end
		if ok then
			for _, other in ctx.nodes do
				if (x - other.x) ^ 2 + (z - other.z) ^ 2 < 24 * 24 then
					ok = false
					break
				end
			end
		end
		if ok then
			Build.node(ctx, kind, x, z)
			placed += 1
		end
	end
end

function Build.icon(ctx: Context, kind: string, x: number, z: number, id: string?)
	table.insert(ctx.sketch.icons, { t = kind, x = x, z = z, id = id })
end

function Build.rect(ctx: Context, x: number, z: number, w: number, h: number, kind: string, angle: number?)
	table.insert(ctx.sketch.shapes, { t = "rect", x = x, z = z, w = w, h = h, r = angle, c = kind })
end

return Build
