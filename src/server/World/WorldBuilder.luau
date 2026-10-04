--!strict
-- Builds placeholder map geometry at server start. S01: the capital (plaza, block buildings, title sign).
-- S02: zone volumes (tag "ZoneVolume") and spawn points (tag "SpawnPoint") plus a test strip east of the
-- city: a yellow training meadow and a small walled red cave. S08 replaces this with layout-driven
-- generation (World/Layouts) using the same tags and attributes.

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local Maps = require(game:GetService("ReplicatedStorage").Shared.Data.Maps)

local WorldBuilder = {}

local FLOOR_TOP = 1 -- sits 1 stud above Studio's default Baseplate (top at y=0) to avoid z-fighting

local function part(props: { [string]: any }, parent: Instance): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function building(parent: Instance, origin: Vector3, size: Vector3, wall: Color3, roof: Color3, name: string)
	local model = Instance.new("Model")
	model.Name = name
	part({
		Name = "Walls",
		Size = size,
		CFrame = CFrame.new(origin + Vector3.new(0, FLOOR_TOP + size.Y / 2, 0)),
		Color = wall,
		Material = Enum.Material.Brick,
	}, model)
	part({
		Name = "Roof",
		Size = Vector3.new(size.X + 2, 2, size.Z + 2),
		CFrame = CFrame.new(origin + Vector3.new(0, FLOOR_TOP + size.Y + 1, 0)),
		Color = roof,
		Material = Enum.Material.Slate,
	}, model)
	part({
		Name = "Door",
		Size = Vector3.new(4, 7, 0.4),
		CFrame = CFrame.new(origin + Vector3.new(0, FLOOR_TOP + 3.5, size.Z / 2 + 0.2)),
		Color = Color3.fromHex("#3B2A1E"),
		Material = Enum.Material.Wood,
	}, model)
	model.Parent = parent
end

local function sign(parent: Instance, position: Vector3, title: string, subtitle: string)
	local board = part({
		Name = "TitleSign",
		Size = Vector3.new(28, 8, 1),
		CFrame = CFrame.new(position),
		Color = Color3.fromHex("#252832"),
		Material = Enum.Material.Wood,
	}, parent)
	for _, offsetX in { -12, 12 } do
		part({
			Name = "Post",
			Size = Vector3.new(1, position.Y - FLOOR_TOP, 1),
			CFrame = CFrame.new(position.X + offsetX, (position.Y + FLOOR_TOP) / 2, position.Z),
			Color = Color3.fromHex("#3B2A1E"),
			Material = Enum.Material.Wood,
		}, parent)
	end
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.PixelsPerStud = 40
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.Parent = board
		local titleLabel = Instance.new("TextLabel")
		titleLabel.BackgroundTransparency = 1
		titleLabel.Size = UDim2.fromScale(1, 0.65)
		titleLabel.Text = title
		titleLabel.TextScaled = true
		titleLabel.FontFace = Font.fromEnum(Enum.Font.Fondamento)
		titleLabel.TextColor3 = Color3.fromHex("#C9A45C")
		titleLabel.Parent = gui
		local subLabel = Instance.new("TextLabel")
		subLabel.BackgroundTransparency = 1
		subLabel.Position = UDim2.fromScale(0, 0.62)
		subLabel.Size = UDim2.fromScale(1, 0.3)
		subLabel.Text = subtitle
		subLabel.TextScaled = true
		subLabel.FontFace = Font.fromEnum(Enum.Font.BuilderSans)
		subLabel.TextColor3 = Color3.fromHex("#EADDBE")
		subLabel.Parent = gui
	end
end

-- Invisible, non-colliding volume read by ZoneService.
local function zoneVolume(
	parent: Instance,
	mapId: string,
	pvp: string,
	nameKey: string?,
	minX: number,
	maxX: number,
	o: Vector3,
	depth: number
)
	local volume = part({
		Name = `Zone_{pvp}_{nameKey or mapId}`,
		Size = Vector3.new(maxX - minX, 400, depth),
		CFrame = CFrame.new(o + Vector3.new((minX + maxX) / 2, 150, 0)),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	}, parent)
	volume:SetAttribute("MapId", mapId)
	volume:SetAttribute("PvpZone", pvp)
	if nameKey then
		volume:SetAttribute("NameKey", nameKey)
	end
	CollectionService:AddTag(volume, "ZoneVolume")
end

-- Visible gold marker where characters respawn (DeathService picks the nearest one of the map).
local function spawnPoint(parent: Instance, mapId: string, at: Vector3, lookAt: Vector3)
	local marker = part({
		Name = "SpawnPoint",
		Size = Vector3.new(6, 0.2, 6),
		CFrame = CFrame.lookAt(
			Vector3.new(at.X, FLOOR_TOP + 0.2, at.Z),
			Vector3.new(lookAt.X, FLOOR_TOP + 0.2, lookAt.Z + 0.001)
		),
		Color = Color3.fromHex("#C9A45C"),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Transparency = 0.6,
	}, parent)
	marker:SetAttribute("MapId", mapId)
	CollectionService:AddTag(marker, "SpawnPoint")
end

-- S02 test strip: green city (west part), yellow meadow, red cave at the east edge.
local function buildTestStrip(parent: Instance, map: Maps.MapDef, o: Vector3)
	local halfX, depth = map.size.x / 2, map.size.z
	local cityEdge, caveStart = 256, halfX - 90

	zoneVolume(parent, map.id, "green", nil, -halfX, cityEdge, o, depth)
	zoneVolume(parent, map.id, "yellow", "zone.trainingMeadow", cityEdge, halfX, o, depth)
	zoneVolume(parent, map.id, "red", "zone.trialCave", caveStart, halfX, o, 120)

	-- Low fence marking the city border, with a gap for the road.
	for _, z in { -150, 150 } do
		part({
			Name = "CityFence",
			Size = Vector3.new(1.5, 4, 200),
			CFrame = CFrame.new(o + Vector3.new(cityEdge, FLOOR_TOP + 2, z + (if z < 0 then -56 else 56))),
			Color = Color3.fromHex("#5A4632"),
			Material = Enum.Material.WoodPlanks,
		}, parent)
	end
	part({
		Name = "Road",
		Size = Vector3.new(caveStart - 60, 0.2, 14),
		CFrame = CFrame.new(o + Vector3.new(30 + (caveStart - 60) / 2, FLOOR_TOP + 0.1, 0)),
		Color = Color3.fromHex("#8A7A5C"),
		Material = Enum.Material.Ground,
	}, parent)
	-- Meadow dressing: a few placeholder trees.
	for i, offset in
		{ Vector3.new(330, 0, -80), Vector3.new(380, 0, 90), Vector3.new(450, 0, -130), Vector3.new(300, 0, 160) }
	do
		part({
			Name = `Trunk{i}`,
			Size = Vector3.new(2, 10, 2),
			CFrame = CFrame.new(o + offset + Vector3.new(0, FLOOR_TOP + 5, 0)),
			Color = Color3.fromHex("#5A4632"),
			Material = Enum.Material.Wood,
		}, parent)
		part({
			Name = `Crown{i}`,
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(12, 12, 12),
			CFrame = CFrame.new(o + offset + Vector3.new(0, FLOOR_TOP + 13, 0)),
			Color = Color3.fromHex("#3F6B2E"),
			Material = Enum.Material.Grass,
		}, parent)
	end

	-- Cave: three rock walls and a roof, open towards the city.
	local rock = Color3.fromHex("#4A4744")
	local caveCentre = o + Vector3.new((caveStart + halfX) / 2, 0, 0)
	local caveLength = halfX - caveStart
	for _, z in { -60, 60 } do
		part({
			Name = "CaveWall",
			Size = Vector3.new(caveLength, 24, 4),
			CFrame = CFrame.new(caveCentre + Vector3.new(0, FLOOR_TOP + 12, z)),
			Color = rock,
			Material = Enum.Material.Slate,
		}, parent)
	end
	part({
		Name = "CaveBack",
		Size = Vector3.new(4, 24, 124),
		CFrame = CFrame.new(o + Vector3.new(halfX - 2, FLOOR_TOP + 12, 0)),
		Color = rock,
		Material = Enum.Material.Slate,
	}, parent)
	local roof = part({
		Name = "CaveRoof",
		Size = Vector3.new(caveLength, 4, 124),
		CFrame = CFrame.new(caveCentre + Vector3.new(0, FLOOR_TOP + 26, 0)),
		Color = rock,
		Material = Enum.Material.Slate,
	}, parent)
	part({
		Name = "CaveFloor",
		Size = Vector3.new(caveLength, 0.2, 116),
		CFrame = CFrame.new(caveCentre + Vector3.new(0, FLOOR_TOP + 0.1, 0)),
		Color = Color3.fromHex("#2F2B28"),
		Material = Enum.Material.Rock,
	}, parent)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex("#D64A3E")
	light.Range = 40
	light.Brightness = 1.5
	light.Parent = roof

	-- Respawn points: meadow, and just outside the cave entrance (DESIGN §3.4).
	spawnPoint(parent, map.id, o + Vector3.new(cityEdge + 50, 0, 20), o)
	spawnPoint(parent, map.id, o + Vector3.new(caveStart - 14, 0, 0), o)
end

local function buildCity(root: Instance, map: Maps.MapDef)
	local folder = Instance.new("Folder")
	folder.Name = map.id
	local o = Vector3.new(map.offset.x, map.offset.y, map.offset.z)

	part({
		Name = "Ground",
		Size = Vector3.new(map.size.x, 1, map.size.z),
		CFrame = CFrame.new(o + Vector3.new(0, FLOOR_TOP - 0.5, 0)),
		Color = Color3.fromHex("#5C7A3A"),
		Material = Enum.Material.Grass,
	}, folder)
	part({
		Name = "Plaza",
		Size = Vector3.new(120, 0.2, 120),
		CFrame = CFrame.new(o + Vector3.new(0, FLOOR_TOP + 0.1, 0)),
		Color = Color3.fromHex("#8A8070"),
		Material = Enum.Material.Cobblestone,
	}, folder)
	part({
		Name = "Fountain",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 22, 22),
		CFrame = CFrame.new(o + Vector3.new(0, FLOOR_TOP + 1.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromHex("#A8A39A"),
		Material = Enum.Material.Marble,
	}, folder)
	part({
		Name = "FountainWater",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.4, 18, 18),
		CFrame = CFrame.new(o + Vector3.new(0, FLOOR_TOP + 3.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromHex("#4A8FE7"),
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		CanCollide = false,
	}, folder)

	local wall = Color3.fromHex("#9C8A72")
	local roof = Color3.fromHex("#6B2F2A")
	local layout = {
		{ name = "Blacksmith", pos = Vector3.new(-70, 0, -70), size = Vector3.new(30, 16, 24) },
		{ name = "Healer", pos = Vector3.new(70, 0, -70), size = Vector3.new(24, 14, 22) },
		{ name = "Alchemist", pos = Vector3.new(-70, 0, 70), size = Vector3.new(24, 18, 24) },
		{ name = "Merchant", pos = Vector3.new(70, 0, 70), size = Vector3.new(28, 14, 22) },
		{ name = "GuildHall", pos = Vector3.new(0, 0, -130), size = Vector3.new(48, 24, 30) },
	}
	for _, b in layout do
		building(folder, o + b.pos, b.size, wall, roof, b.name)
	end

	sign(folder, o + Vector3.new(0, FLOOR_TOP + 10, 70), "Vaelthorn", "Capital  ·  Stolica")

	spawnPoint(folder, map.id, o + Vector3.new(map.spawn.x, 0, map.spawn.z), o)
	buildTestStrip(folder, map, o)

	folder.Parent = root
end

-- Builds every map into Workspace.World (idempotent: rebuilds if already present).
function WorldBuilder.build(): Folder
	local existing = Workspace:FindFirstChild("World")
	if existing then
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "World"
	local city = Maps.get("city")
	if city then
		buildCity(root, city)
	end
	root.Parent = Workspace
	return root
end

WorldBuilder.FLOOR_TOP = FLOOR_TOP

return WorldBuilder
