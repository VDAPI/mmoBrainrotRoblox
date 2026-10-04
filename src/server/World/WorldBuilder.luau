--!strict
-- Builds the world at server start (ARCHITECTURE §8): every map with buildMode "generated" and a module in
-- World/Layouts is built into Workspace.World.<mapId> plus Roblox terrain. The layouts use World/Build
-- (terrain, zones, spawn points, sketch) and World/Prefabs (placeholder props). Collected per map:
--   * portals (registry for TravelService), gathering node placements (GatherService),
--   * a sketch (paths, water, buildings, icons) published as JSON in ReplicatedStorage.MapSketches.<mapId>
--     for the minimap and the world map.
-- `rebuild(mapId)` clears the map's terrain region and builds it again (admin /rebuild).

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Build = require(script.Parent.Build)
local Config = require(ReplicatedStorage.Shared.Config)
local Log = require(ReplicatedStorage.Shared.Util.Log)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)

local log = Log.new("WorldBuilder")

local WorldBuilder = {}

export type Placement = { map: string, kind: string, x: number, z: number }
export type Portal = { id: string, map: string, target: string, position: Vector3, arrive: { x: number, z: number }? }

WorldBuilder.FLOOR_TOP = 0
WorldBuilder.built = {} :: { [string]: boolean }
WorldBuilder.placements = {} :: { Placement }
WorldBuilder.portals = {} :: { [string]: Portal }

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

local function buildMap(map: Maps.MapDef, root: Instance, nodes: boolean): boolean
	local module = layoutModule(map.id)
	if map.buildMode ~= "generated" or not module then
		return false
	end
	local started = os.clock()
	local ctx = Build.new(map, root)
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
	if ctx.parts > Config.MaxPartsPerMap then
		log:warn("map %s has %d parts (limit %d)", map.id, ctx.parts, Config.MaxPartsPerMap)
	end
	return true
end

local function clearTerrain(map: Maps.MapDef)
	local size = Vector3.new(map.size.x + 400, 400, map.size.z + 400)
	local centre = Vector3.new(map.offset.x, map.offset.y + 120, map.offset.z)
	Workspace.Terrain:FillBlock(CFrame.new(centre), size, Enum.Material.Air)
end

-- Builds every map into Workspace.World (idempotent: rebuilds if already present).
function WorldBuilder.build(): Folder
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
	for _, id in ids do
		local map = Maps.get(id)
		if map then
			buildMap(map, root, true)
		end
	end
	log:info("world built in %.2f s", os.clock() - started)
	return root
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
	return buildMap(map, root, false)
end

return WorldBuilder
