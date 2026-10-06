--!strict
-- Client-only small decorations (S20, DESIGN §3.7): grass tufts, flowers, pebbles, mushrooms, ferns, reeds
-- by the water, fallen leaves; in caves stalactites, small crystals, webs and bones. Generated per chunk
-- (Config.DecorChunk studs) from the map id + chunk seed, so every client sees the same; only chunks within
-- the "World detail" radius exist. Parts come from a pool: unloading a chunk returns them instead of
-- destroying. The server never creates or replicates any of this.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AreaSpawns = require(ReplicatedStorage.Shared.Logic.AreaSpawns)
local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local Config = require(ReplicatedStorage.Shared.Config)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local State = require(script.Parent.Parent.UI.State)
local TownTerrain = require(ReplicatedStorage.Shared.Logic.TownTerrain)

local DecorController = {
	Name = "DecorController",
}

type Template = {
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?,
	transparency: number?,
	lift: number, -- height above the ground of the part centre (negative: hanging from a ceiling)
	tilt: boolean?, -- random tilt (leaves, ferns)
	water: boolean?, -- only near water
	ceiling: boolean?, -- hangs from the ceiling (caves)
}

local function rgb(hex: string): Color3
	return Color3.fromHex(hex)
end

local T: { [string]: Template } = {
	tuft = { size = Vector3.new(0.5, 1.1, 0.5), color = rgb("#5C8A3A"), material = Enum.Material.Grass, lift = 0.4 },
	tuftDark = {
		size = Vector3.new(0.5, 1.2, 0.5),
		color = rgb("#34502A"),
		material = Enum.Material.Grass,
		lift = 0.45,
	},
	tuftDry = { size = Vector3.new(0.5, 0.9, 0.5), color = rgb("#B8A060"), material = Enum.Material.Grass, lift = 0.35 },
	flowerY = {
		size = Vector3.one * 0.6,
		color = rgb("#F2E8A0"),
		material = Enum.Material.SmoothPlastic,
		shape = Enum.PartType.Ball,
		lift = 0.5,
	},
	flowerP = {
		size = Vector3.one * 0.6,
		color = rgb("#E8A0C9"),
		material = Enum.Material.SmoothPlastic,
		shape = Enum.PartType.Ball,
		lift = 0.5,
	},
	flowerB = {
		size = Vector3.one * 0.55,
		color = rgb("#8FB8F0"),
		material = Enum.Material.SmoothPlastic,
		shape = Enum.PartType.Ball,
		lift = 0.45,
	},
	pebble = {
		size = Vector3.new(1, 0.5, 0.8),
		color = rgb("#8A8478"),
		material = Enum.Material.Slate,
		shape = Enum.PartType.Ball,
		lift = 0.1,
	},
	pebbleSnow = {
		size = Vector3.new(1, 0.5, 0.8),
		color = rgb("#A8B8C8"),
		material = Enum.Material.Slate,
		shape = Enum.PartType.Ball,
		lift = 0.1,
	},
	pebbleRed = {
		size = Vector3.new(1, 0.5, 0.8),
		color = rgb("#7A4A3A"),
		material = Enum.Material.Basalt,
		shape = Enum.PartType.Ball,
		lift = 0.1,
	},
	mushroom = {
		size = Vector3.new(0.8, 0.5, 0.8),
		color = rgb("#B8423A"),
		material = Enum.Material.SmoothPlastic,
		shape = Enum.PartType.Ball,
		lift = 0.5,
	},
	fern = {
		size = Vector3.new(1.8, 0.15, 0.7),
		color = rgb("#3F6B2E"),
		material = Enum.Material.Grass,
		lift = 0.4,
		tilt = true,
	},
	leaf = {
		size = Vector3.new(0.9, 0.08, 0.9),
		color = rgb("#A0602A"),
		material = Enum.Material.SmoothPlastic,
		lift = 0.05,
		tilt = true,
	},
	reed = {
		size = Vector3.new(0.2, 3, 0.2),
		color = rgb("#7A8A4A"),
		material = Enum.Material.Grass,
		lift = 1.4,
		water = true,
	},
	bone = {
		size = Vector3.new(1.4, 0.25, 0.25),
		color = rgb("#E8E2D0"),
		material = Enum.Material.SmoothPlastic,
		lift = 0.12,
		tilt = true,
	},
	stalactite = {
		size = Vector3.new(0.8, 3.2, 0.8),
		color = rgb("#5A5650"),
		material = Enum.Material.Slate,
		lift = -1.6,
		ceiling = true,
	},
	crystal = {
		size = Vector3.new(0.5, 1.4, 0.5),
		color = rgb("#9FE0FF"),
		material = Enum.Material.Neon,
		lift = 0.6,
		tilt = true,
	},
	web = {
		size = Vector3.new(3, 3, 0.05),
		color = rgb("#E8E8F0"),
		material = Enum.Material.SmoothPlastic,
		transparency = 0.7,
		lift = 2.5,
		tilt = true,
	},
}

-- Weighted templates and items per chunk by biome.
local BIOMES: { [string]: { count: number, mix: { { string | number } } } } = {
	-- S21: the starting city; only on grass (never on paving), sparse inside the walls, denser outside.
	city = {
		count = 30,
		mix = {
			{ "tuft", 10 },
			{ "tuftDark", 4 },
			{ "flowerY", 2 },
			{ "flowerP", 2 },
			{ "flowerB", 1 },
			{ "pebble", 3 },
			{ "fern", 1 },
		},
	},
	grass = {
		count = 34,
		mix = {
			{ "tuft", 10 },
			{ "flowerY", 3 },
			{ "flowerP", 3 },
			{ "flowerB", 2 },
			{ "pebble", 3 },
			{ "mushroom", 1 },
			{ "fern", 2 },
			{ "reed", 3 },
		},
	},
	forest = {
		count = 30,
		mix = { { "tuftDark", 8 }, { "fern", 6 }, { "mushroom", 3 }, { "leaf", 6 }, { "pebble", 2 }, { "reed", 2 } },
	},
	desert = { count = 16, mix = { { "tuftDry", 6 }, { "pebbleRed", 6 }, { "bone", 2 } } },
	snow = { count = 18, mix = { { "pebbleSnow", 6 }, { "tuftDry", 3 }, { "crystal", 1 } } },
	cave = { count = 14, mix = { { "stalactite", 5 }, { "pebble", 4 }, { "crystal", 2 }, { "web", 1 }, { "bone", 2 } } },
	crypt = {
		count = 14,
		mix = { { "stalactite", 3 }, { "pebble", 3 }, { "bone", 4 }, { "web", 3 }, { "crystal", 1 } },
	},
}

-- Share of the city biome's items kept inside the walls (the streets are busy; outside it grows freely).
local CITY_INSIDE_SHARE = 0.4

local folder: Folder
local pool: { [string]: { BasePart } } = {}
local chunks: { [string]: { BasePart } } = {}
local currentMap: string? = nil
local frameTime = 0

local function acquire(key: string): BasePart
	local list = pool[key]
	local part = list and table.remove(list)
	if part then
		return part
	end
	local template = T[key]
	local p = Instance.new("Part")
	p.Name = key
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = template.size
	p.Color = template.color
	p.Material = template.material
	p.Transparency = template.transparency or 0
	if template.shape then
		p.Shape = template.shape
	end
	return p
end

local function release(part: BasePart)
	part.Parent = nil
	local list = pool[part.Name]
	if not list then
		list = {}
		pool[part.Name] = list
	end
	table.insert(list, part)
end

local function seedOf(text: string): number
	local seed = 17
	for i = 1, #text do
		seed = (seed * 31 + string.byte(text, i)) % 2147483647
	end
	return seed
end

local function pick(mix: { { string | number } }, rng: Random): string
	local total = 0
	for _, entry in mix do
		total += entry[2] :: number
	end
	local roll = rng:NextNumber() * total
	for _, entry in mix do
		roll -= entry[2] :: number
		if roll <= 0 then
			return entry[1] :: string
		end
	end
	return mix[1][1] :: string
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { Workspace.Terrain }
rayParams.IgnoreWater = false

-- Inside a cave room (caves only have decorations in their rooms).
local function inRoom(rooms: { any }?, x: number, z: number): boolean
	if not rooms then
		return true
	end
	for _, room in rooms do
		if (x - room.x) ^ 2 + (z - room.z) ^ 2 < (room.r * 0.9) ^ 2 then
			return true
		end
	end
	return false
end

local function nearWater(lakes: { any }?, x: number, z: number): boolean
	for _, lake in (lakes or {}) :: { any } do
		local d = math.sqrt((x - lake.x) ^ 2 + (z - lake.z) ^ 2)
		if d > lake.r - 4 and d < lake.r + 10 then
			return true
		end
	end
	return false
end

local function buildChunk(map: Maps.MapDef, cx: number, cz: number): { BasePart }
	local parts: { BasePart } = {}
	local biome = BIOMES[map.biome]
	if not biome then
		return parts
	end
	local rng = Random.new(seedOf(`{map.id}:{cx}:{cz}`))
	local size = Config.DecorChunk
	local areas = Areas.byMap[map.id]
	local cave = Areas.caves.get(map.id)
	local rooms = if cave then AreaSpawns.caveRooms(cave) else nil
	local inCave = map.biome == "cave" or map.biome == "crypt"
	local origin = Vector3.new(map.offset.x, map.offset.y, map.offset.z)
	for _ = 1, biome.count do
		local key = pick(biome.mix, rng)
		local template = T[key]
		local x = cx * size + rng:NextNumber() * size
		local z = cz * size + rng:NextNumber() * size
		if math.abs(x) > map.size.x / 2 - 4 or math.abs(z) > map.size.z / 2 - 4 then
			continue
		end
		if inCave and not inRoom(rooms, x, z) then
			continue
		end
		if areas then
			if template.water and not nearWater(areas.lakes, x, z) then
				continue
			end
			if AreaSpawns.nearRoad(areas.roads, x, z, 1) then
				continue
			end
		elseif template.water then
			continue
		end
		local inCity = map.biome == "city"
		local insideWalls = inCity and TownTerrain.insideWalls(x, z)
		if insideWalls and (rng:NextNumber() > CITY_INSIDE_SHARE or not TownTerrain.isOpen(x, z, 1)) then
			continue
		end
		local from = origin + Vector3.new(x, if inCave then 4 else 120, z)
		local hit = Workspace:Raycast(from, Vector3.new(0, -200, 0), rayParams)
		if not hit or hit.Material == Enum.Material.Water then
			continue
		end
		if inCity and hit.Material ~= Enum.Material.Grass and hit.Material ~= Enum.Material.LeafyGrass then
			continue
		end
		local position = hit.Position
		if template.ceiling then
			local up = Workspace:Raycast(hit.Position + Vector3.new(0, 1, 0), Vector3.new(0, 60, 0), rayParams)
			if not up then
				continue
			end
			position = up.Position
		end
		local yaw = rng:NextNumber() * math.pi * 2
		local cframe = CFrame.new(position + Vector3.new(0, template.lift, 0)) * CFrame.Angles(0, yaw, 0)
		if template.tilt then
			cframe *= CFrame.Angles((rng:NextNumber() - 0.5) * 0.6, 0, (rng:NextNumber() - 0.5) * 0.6)
		end
		local part = acquire(key)
		part.CFrame = cframe
		part.Parent = folder
		table.insert(parts, part)
	end
	return parts
end

local function unloadAll()
	for key, parts in chunks do
		for _, part in parts do
			release(part)
		end
		chunks[key] = nil
	end
end

local function radius(): number
	local setting = State.Get({ "account", "settings", "decor" })
	return (Config.DecorRadius :: any)[setting or "mid"] or Config.DecorRadius.mid
end

-- Loads up to `budget` missing chunks around the player and unloads far ones.
local function update(budget: number)
	local mapId = State.Get({ "character", "location", "map" })
	local map = type(mapId) == "string" and Maps.get(mapId) or nil
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not map or not root then
		return
	end
	if map.id ~= currentMap then
		unloadAll()
		currentMap = map.id
	end
	local size = Config.DecorChunk
	local reach = radius()
	local px, pz = root.Position.X - map.offset.x, root.Position.Z - map.offset.z
	local wanted: { [string]: { number } } = {}
	local minX, maxX = math.floor((px - reach) / size), math.floor((px + reach) / size)
	local minZ, maxZ = math.floor((pz - reach) / size), math.floor((pz + reach) / size)
	for cx = minX, maxX do
		for cz = minZ, maxZ do
			local mx, mz = (cx + 0.5) * size, (cz + 0.5) * size
			if (mx - px) ^ 2 + (mz - pz) ^ 2 <= (reach + size * 0.7) ^ 2 then
				wanted[`{cx}:{cz}`] = { cx, cz, (mx - px) ^ 2 + (mz - pz) ^ 2 }
			end
		end
	end
	for key, parts in chunks do
		if not wanted[key] then
			for _, part in parts do
				release(part)
			end
			chunks[key] = nil
		end
	end
	-- Nearest missing chunks first.
	local missing = {}
	for key, c in wanted do
		if not chunks[key] then
			table.insert(missing, { key = key, cx = c[1], cz = c[2], d = c[3] })
		end
	end
	table.sort(missing, function(a, b)
		return a.d < b.d
	end)
	for i = 1, math.min(budget, #missing) do
		local c = missing[i]
		chunks[c.key] = buildChunk(map, c.cx, c.cz)
	end
end

-- Active chunks and pooled parts (admin /perf on the client).
function DecorController.Stats(): (number, number, number)
	local active, parts = 0, 0
	for _, list in chunks do
		active += 1
		parts += #list
	end
	return active, parts, frameTime
end

function DecorController.Init()
	folder = Instance.new("Folder")
	folder.Name = "Vaelthorn_ClientDecor"
	folder.Parent = Workspace
end

function DecorController.Start()
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt: number)
		frameTime = frameTime * 0.9 + dt * 0.1
		accumulator += dt
		if accumulator < 0.25 then
			return
		end
		accumulator = 0
		local ok, err = pcall(function()
			update(2)
		end)
		if not ok then
			warn(`[DecorController] {err}`)
		end
	end)
end

return DecorController
