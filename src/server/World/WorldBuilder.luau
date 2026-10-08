--!strict
-- Builds the world at server start (ARCHITECTURE §8): every map with buildMode "generated" and a module in
-- World/Layouts is built into Workspace.World.<mapId> plus Roblox terrain. The layouts use World/Build
-- (terrain, zones, spawn points, sketch) and World/Prefabs (placeholder props). Collected per map:
--   * portals (registry for TravelService), gathering node placements (GatherService),
--   * a sketch (paths, water, buildings, icons) published as JSON in ReplicatedStorage.MapSketches.<mapId>
--     for the minimap and the world map.
-- `rebuild(mapId)` clears the map's terrain region and builds it again (admin /rebuild).
--
-- S45: maps with `buildLate = true` in Data/Maps (the shaped regions: Duskwood, later S46/S47; caves and dungeons
-- may join when the start grows) are skipped by `build()` and built by `buildLate()` after every service started
-- (WorldService.Start), with a pause after every ~10 ms of work (ctx.pace). Until a map is done, `built[id]` is
-- false and its MapSketches.<id> missing: portals show "Soon", TravelService refuses, a character saved there
-- waits (WorldService.WaitBuilt). `MapBuilt` fires (mapId) after every map built in the background or rebuilt;
-- GatherService places that map's nodes on it.

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Build = require(script.Parent.Build)
local Config = require(ReplicatedStorage.Shared.Config)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Signal = require(ReplicatedStorage.Packages.Signal)

local log = Log.new("WorldBuilder")

local WorldBuilder = {}

export type Placement = { map: string, kind: string, x: number, z: number }
export type Portal = { id: string, map: string, target: string, position: Vector3, arrive: { x: number, z: number }? }

WorldBuilder.FLOOR_TOP = 0
WorldBuilder.built = {} :: { [string]: boolean }
WorldBuilder.placements = {} :: { Placement }
WorldBuilder.portals = {} :: { [string]: Portal }
WorldBuilder.partCounts = {} :: { [string]: number } -- parts per built map (/perf, S20)
WorldBuilder.late = {} :: { string } -- S45: maps waiting for the background build, in build order
WorldBuilder.lateSeconds = {} :: { [string]: number } -- S45: wall-clock seconds of each background build
WorldBuilder.MapBuilt = Signal.new() -- S45: (mapId) after a background build or a rebuild

-- Work slice of a background build before it yields a frame.
local SLICE = 0.010

local MATERIAL_COLORS: { [Enum.Material]: string } = {
	[Enum.Material.Grass] = "#5C7A3A",
	[Enum.Material.LeafyGrass] = "#34452A",
	[Enum.Material.Ground] = "#7A6A4E",
	[Enum.Material.Mud] = "#3F3A2E",
	[Enum.Material.Cobblestone] = "#8A8070",
	[Enum.Material.Pavement] = "#7A7468",
	[Enum.Material.Rock] = "#5A5650",
	[Enum.Material.Slate] = "#4A4744",
	[Enum.Material.Basalt] = "#2F2B30",
	[Enum.Material.Sand] = "#C2A878",
	[Enum.Material.Snow] = "#EEF3F7",
	[Enum.Material.Glacier] = "#A8D8F0",
	[Enum.Material.Ice] = "#C9E8F7",
	[Enum.Material.CrackedLava] = "#D6542A",
	-- S21: light warm stone of the city market and temple square (no other map uses it).
	[Enum.Material.Limestone] = "#B9AE96",
	-- S26: gravel of the Meadows' quarry terraces and stream beds (no other map uses it; Pebble is a part-only
	-- material, terrain rejects it).
	[Enum.Material.Salt] = "#8A847A",
	-- S45: dark red rock of Duskwood's Blood Cliffs (S46's red crags of the Ashen Wastes match it).
	[Enum.Material.Sandstone] = "#6E2F2A",
}

local function layoutModule(mapId: string): ModuleScript?
	local folder = script.Parent:FindFirstChild("Layouts")
	local module = folder and folder:FindFirstChild(mapId)
	return if module and module:IsA("ModuleScript") then module else nil
end

local function sketchFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild("MapSketches")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "MapSketches"
		folder.Parent = ReplicatedStorage
	end
	return folder :: Folder
end

local function round(n: number): number
	return math.floor(n + 0.5)
end

-- Compacts the sketch (whole studs) and publishes it.
local function publishSketch(ctx: Build.Context)
	local shapes = {}
	for _, shape in ctx.sketch.shapes do
		local s = table.clone(shape) :: any
		for key, value in s do
			if type(value) == "number" then
				s[key] = round(value)
			end
		end
		if s.p then
			local points = {}
			for i, v in s.p do
				points[i] = round(v)
			end
			s.p = points
		end
		table.insert(shapes, s)
	end
	-- Trees as forest patches (S20): 80-stud cells with 3+ trees become one circle each.
	local cells: { [string]: { number } } = {}
	for _, tree in ctx.trees do
		local key = `{math.floor(tree[1] / 80)}:{math.floor(tree[2] / 80)}`
		local cell = cells[key] or { 0, 0, 0 }
		cell[1] += tree[1]
		cell[2] += tree[2]
		cell[3] += 1
		cells[key] = cell
	end
	for _, cell in cells do
		if cell[3] >= 3 then
			table.insert(shapes, {
				t = "circle",
				x = round(cell[1] / cell[3]),
				z = round(cell[2] / cell[3]),
				r = round(math.min(60, 22 + cell[3] * 4)),
				c = "forest",
			})
		end
	end
	local icons = {}
	for _, icon in ctx.sketch.icons do
		table.insert(icons, { t = icon.t, x = round(icon.x), z = round(icon.z), id = icon.id })
	end
	for _, node in ctx.nodes do
		table.insert(icons, { t = "node", x = round(node.x), z = round(node.z), id = node.kind })
	end
	local value = sketchFolder():FindFirstChild(ctx.map.id) :: StringValue?
	if not value then
		local created = Instance.new("StringValue")
		created.Name = ctx.map.id
		created.Parent = sketchFolder()
		value = created
	end
	assert(value, "sketch value missing")
	value.Value = HttpService:JSONEncode({ size = ctx.map.size, shapes = shapes, icons = icons })
end

local function collect(ctx: Build.Context, nodes: boolean)
	if nodes then
		for _, node in ctx.nodes do
			table.insert(WorldBuilder.placements, { map = ctx.map.id, kind = node.kind, x = node.x, z = node.z })
		end
	end
	for _, model in ctx.folder:GetChildren() do
		if model:IsA("Model") then
			local id = model:GetAttribute("PortalId")
			local target = model:GetAttribute("TargetMap")
			if type(id) == "string" and type(target) == "string" and model.PrimaryPart then
				local ax, az = model:GetAttribute("ArriveX"), model:GetAttribute("ArriveZ")
				WorldBuilder.portals[id] = {
					id = id,
					map = ctx.map.id,
					target = target,
					position = model.PrimaryPart.Position,
					arrive = if type(ax) == "number" and type(az) == "number" then { x = ax, z = az } else nil,
				}
			end
		end
	end
end

local function buildMap(map: Maps.MapDef, root: Instance, nodes: boolean, pace: (() -> ())?): boolean
	local module = layoutModule(map.id)
	if map.buildMode ~= "generated" or not module then
		return false
	end
	local started = os.clock()
	local ctx = Build.new(map, root)
	ctx.pace = pace
	local layout = (require :: any)(module) :: (Build.Context) -> ()
	local ok, err = pcall(function()
		layout(ctx)
	end)
	if not ok then
		log:error("layout %s failed: %s", map.id, tostring(err))
		return false
	end
	collect(ctx, nodes)
	publishSketch(ctx)
	WorldBuilder.built[map.id] = true
	log:info("built %s in %.2f s (%d parts, %d nodes)", map.id, os.clock() - started, ctx.parts, #ctx.nodes)
	WorldBuilder.partCounts[map.id] = ctx.parts
	local limit = map.maxParts or Config.MaxPartsPerMap
	if ctx.parts > limit then
		log:warn("map %s has %d parts (limit %d)", map.id, ctx.parts, limit)
	end
	return true
end

local function clearTerrain(map: Maps.MapDef)
	local size = Vector3.new(map.size.x + 400, 400, map.size.z + 400)
	local centre = Vector3.new(map.offset.x, map.offset.y + 120, map.offset.z)
	Workspace.Terrain:FillBlock(CFrame.new(centre), size, Enum.Material.Air)
end

-- Removes a Baseplate left in the place file (S21): the default 2048 x 16 x 2048 plate with its top at y = 0
-- would cover the city's river and moat (water at -1.5) and every valley below 0. Anything else the game
-- does not create is left alone, except other huge flat slabs lying near y = 0 (a renamed baseplate).
local function removeBaseplate()
	for _, child in Workspace:GetChildren() do
		local slab = child:IsA("BasePart")
			and child.Size.X >= 500
			and child.Size.Z >= 500
			and child.Size.Y <= 40
			and math.abs(child.Position.Y + child.Size.Y / 2) < 4
		if child:IsA("BasePart") and (child.Name == "Baseplate" or slab) then
			log:warn("removed %s (%s) from Workspace: it would cover the city terrain", child.Name, child.ClassName)
			child:Destroy()
		end
	end
end

-- Builds every map into Workspace.World (idempotent: rebuilds if already present).
function WorldBuilder.build(): Folder
	removeBaseplate()
	local existing = Workspace:FindFirstChild("World")
	if existing then
		existing:Destroy()
	end
	for material, color in MATERIAL_COLORS do
		Workspace.Terrain:SetMaterialColor(material, Color3.fromHex(color))
	end
	local root = Instance.new("Folder")
	root.Name = "World"
	root.Parent = Workspace
	local started = os.clock()
	local ids = {}
	for id in Maps.byId do
		table.insert(ids, id)
	end
	table.sort(ids)
	table.clear(WorldBuilder.late)
	for _, id in ids do
		local map = Maps.get(id)
		if map and map.buildLate and layoutModule(id) then
			table.insert(WorldBuilder.late, id)
		elseif map then
			buildMap(map, root, true)
		end
	end
	log:info("world built in %.2f s (%d maps left for the background)", os.clock() - started, #WorldBuilder.late)
	return root
end

-- Pacer of a background build: yields a frame once SLICE seconds of work passed since the last pause.
local function pacer(): () -> ()
	local last = os.clock()
	return function()
		if os.clock() - last >= SLICE then
			task.wait()
			last = os.clock()
		end
	end
end

-- Builds the maps left by `build()` one after another, yielding between slices of work (S45). Called once from
-- WorldService.Start; returns when every late map is built.
function WorldBuilder.buildLate()
	local root = Workspace:FindFirstChild("World")
	if not root then
		return
	end
	for _, id in table.clone(WorldBuilder.late) do
		local map = Maps.get(id)
		if map and not WorldBuilder.built[id] then
			local started = os.clock()
			if buildMap(map, root, true, pacer()) then
				local seconds = os.clock() - started
				WorldBuilder.lateSeconds[id] = seconds
				log:info("background %s built in %.2f s", id, seconds)
				WorldBuilder.MapBuilt:Fire(id)
			end
		end
	end
	table.clear(WorldBuilder.late)
end

-- Rebuilds one map in place (admin). Gathering nodes and NPCs are owned by their services and stay.
function WorldBuilder.rebuild(mapId: string): boolean
	local map = Maps.get(mapId)
	local root = Workspace:FindFirstChild("World")
	if not map or not root then
		return false
	end
	local old = root:FindFirstChild(mapId)
	if old then
		old:Destroy()
	end
	clearTerrain(map)
	local portals = {}
	for id, portal in WorldBuilder.portals do
		if portal.map ~= mapId then
			portals[id] = portal
		end
	end
	WorldBuilder.portals = portals
	-- Gathering node models are owned by GatherService and stay in place.
	local ok = buildMap(map, root, false)
	if ok then
		WorldBuilder.MapBuilt:Fire(mapId)
	end
	return ok
end

return WorldBuilder
