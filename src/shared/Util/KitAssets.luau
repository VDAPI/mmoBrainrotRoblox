--!strict
-- W02: the models of the asset kit (Data/Kit) in ReplicatedStorage.Assets.Kit.<folder> and where one stands for a
-- kit slot of a Blueprint (Logic/TownGen/Blueprint beginKit). Shared by the server (shell slots: big trees, rocks) and
-- the client (detail slots: undergrowth, filler trees; TownDetailController): both read the same Data/Kit, the same
-- replicated folder and Logic/KitPick, so they agree on every slot without sending anything.
--
-- A template is prepared once per model: anchored, no collision, no queries or touches (the slot's old shell pieces
-- keep the collision), its pivot moved to the bottom centre and its height and widest side measured. A missing model
-- warns once per name and leaves the slot to the generator's pieces.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Kit = require(ReplicatedStorage.Shared.Data.Kit)
local KitPick = require(ReplicatedStorage.Shared.Logic.KitPick)
local MapTerrain = require(ReplicatedStorage.Shared.Logic.MapTerrain)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)

local KitAssets = {}

export type Slot = { key: string, p: { number }, s: number, lod: string, x: number?, skirt: number? }
export type Placement = {
	template: Model,
	cframe: CFrame,
	scale: number,
	tint: Color3?,
	paint: { color: Color3, material: Enum.Material }?,
	persistent: boolean?, -- W29: a big landmark kept streamed to every player (Config.Kit.persistentSize)
	-- 2026-10-20: stretched by `stretch` along `axis` (world) after the scale: a wall piece's length, a house's front
	stretch: number?,
	axis: Vector3?,
	extent: number, -- W29: the template's larger side (height or width) before scaling
	skirt: number?, -- 2026-10-31: depth of the stone skirt under the foot (a house on a slope)
}
-- (slot, frame of the Build) -> where the slot's model stands, or nil (keep the pieces)
export type Resolver = (slot: Slot, base: CFrame) -> Placement?

type Template = { model: Model, height: number, width: number, sizeX: number, sizeZ: number }

-- 2026-10-31: the part of a rock's / a tree's widest side (a rock's whole base, a trunk) that must stand in the ground:
-- on a slope the model sinks to the lowest drawn ground there (the terrain is drawn at the height function since the
-- half-voxel lift, Logic/TerrainLayers, so a downhill edge no longer hides 2 studs in the ground)
local BASE: { [string]: number } = { rock = 0.5, tree = 0.1 }
local UNDERGROUND: { [string]: boolean } = { cave = true, crypt = true, dungeon = true }

local templates: { [string]: Template | false } = {}
local warned: { [string]: boolean } = {}

-- Runtime switch of the admin command /kit: the Workspace attribute "Kit" (true / false; replicated, so the clients
-- follow the server); unset = Config.Kit.enabled.
function KitAssets.enabled(): boolean
	local value = workspace:GetAttribute("Kit")
	if type(value) == "boolean" then
		return value
	end
	return Config.Kit.enabled
end

local function folder(): Instance?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild("Kit")
end

local function prepare(name: string): Template?
	local cached = templates[name]
	if cached == false then
		return nil
	elseif cached then
		return cached :: Template
	end
	local root = folder()
	local sub = root and root:FindFirstChild((string.split(name, "_"))[1])
	local source = sub and sub:FindFirstChild(name)
	if not source or not (source:IsA("Model") or source:IsA("BasePart")) then
		templates[name] = false
		if not warned[name] then
			warned[name] = true
			warn(`[Kit] no model {name} in ReplicatedStorage.Assets.Kit; the generator's pieces stay`)
		end
		return nil
	end
	local model: Model
	if source:IsA("Model") then
		model = source:Clone()
	else
		model = Instance.new("Model")
		local copy = (source :: Instance):Clone()
		copy.Parent = model
	end
	model.Name = name
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Locked = true
		elseif
			d:IsA("LuaSourceContainer")
			or d:IsA("ProximityPrompt")
			or d:IsA("ClickDetector")
			or d:IsA("DragDetector")
			or d:IsA("Sound")
		then
			-- never run code or take input from a kit model (a free model's prompt would steal the interact key)
			d:Destroy()
		end
	end
	local box, size = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(box.Position - Vector3.new(0, size.Y / 2, 0))
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local t: Template =
		{ model = model, height = size.Y, width = math.max(size.X, size.Z), sizeX = size.X, sizeZ = size.Z }
	templates[name] = t
	return t
end

-- Resolver for a map (nil when the kit is off for it or has no folder: every slot keeps its pieces).
function KitAssets.resolver(mapId: string): Resolver?
	if not KitAssets.enabled() or Config.Kit.skipMaps[mapId] or not folder() then
		return nil
	end
	local map = Maps.get(mapId)
	if not map then
		return nil
	end
	local biome = map.biome :: string
	local offset = map.offset
	-- the drawn ground (world y) of a map with a height function above ground, else nil
	local ground: ((x: number, z: number) -> number?)? = nil
	if MapTerrain.has(mapId) and not UNDERGROUND[biome] then
		ground = function(x: number, z: number): number?
			local h = MapTerrain.height(mapId, x - offset.x, z - offset.z)
			return if h then offset.y + h else nil
		end
	end
	return function(slot: Slot, base: CFrame): Placement?
		local foot = base * Vector3.new(slot.p[1], slot.p[2], slot.p[3])
		local choice = KitPick.pick(slot.key, biome, foot.X, foot.Z, slot.s)
		if not choice then
			return nil
		end
		local t = prepare(choice.variant.model)
		if not t then
			return nil
		end
		local native = if choice.fit == "width" then t.width else t.height
		if native <= 0 then
			return nil
		end
		local scale = choice.size / native
		local drop = choice.sink * t.height * scale
		local reach = BASE[(string.split(slot.key, ":"))[1]]
		if reach and ground then
			local r = t.width * scale * reach
			local low = foot.Y - drop
			for i = 0, 6 do
				local a = i * math.pi / 3
				local h = ground(foot.X + math.cos(a) * r * math.min(i, 1), foot.Z + math.sin(a) * r * math.min(i, 1))
				if h then
					low = math.min(low, h - 0.1)
				end
			end
			drop = foot.Y - low
		end
		local tint = choice.variant.tint
		local paint = choice.variant.paint
		local material: Enum.Material? = nil
		if paint then
			local ok, value = pcall(function()
				return (Enum.Material :: any)[paint.material]
			end)
			material = if ok then value else Enum.Material.Rock
		end
		-- a slot with a length (`x`): a fixed-turn model stretched along the slot's local X to that length (a wall piece,
		-- a house front), at most 0.6x..1.6x so the painted texture keeps its look
		local stretch: number? = nil
		if slot.x and not choice.variant.yaw then
			local quarter = math.floor((choice.yaw % 180) / 90 + 0.5) % 2 == 1
			local length = (if quarter then t.sizeZ else t.sizeX) * scale
			if length > 0 then
				stretch = math.clamp(slot.x / length, 0.6, 1.6)
			end
		end
		return {
			template = t.model,
			-- a model with a fixed turn (a landmark: its front matters) turns with its building, a random one only by
			-- its own yaw
			cframe = if choice.variant.yaw
				then CFrame.new(foot - Vector3.new(0, drop, 0)) * CFrame.Angles(0, math.rad(choice.yaw), 0)
				else CFrame.new(foot - Vector3.new(0, drop, 0)) * base.Rotation * CFrame.Angles(
					0,
					math.rad(choice.yaw),
					0
				),
			scale = scale,
			tint = if tint then Color3.fromHex(tint) else nil,
			paint = if paint and material then { color = Color3.fromHex(paint.color), material = material } else nil,
			persistent = string.sub(slot.key, 1, 9) == "landmark:" and choice.size >= Config.Kit.persistentSize,
			stretch = stretch,
			axis = if stretch then base.XVector else nil,
			extent = math.max(t.height, t.width),
			skirt = slot.skirt,
		}
	end
end

-- W12: the prepared model `name` of the kit (pivot at its bottom centre) and its height, or nil when the place has none
-- (one warning); for horizons and other placements outside the Blueprint slots.
function KitAssets.model(name: string): (Model?, number)
	local t = prepare(name)
	if not t then
		return nil, 0
	end
	return t.model, t.height
end

-- Box of a part in the frame `pivot` (yaw only): centre and half sizes.
local function boxIn(pivot: CFrame, part: BasePart): (Vector3, Vector3)
	local rel = pivot:ToObjectSpace(part.CFrame)
	local h = part.Size / 2
	local x, y, z = rel.RightVector, rel.UpVector, rel.LookVector
	return rel.Position,
		Vector3.new(
			math.abs(x.X) * h.X + math.abs(y.X) * h.Y + math.abs(z.X) * h.Z,
			math.abs(x.Y) * h.X + math.abs(y.Y) * h.Y + math.abs(z.Y) * h.Z,
			math.abs(x.Z) * h.X + math.abs(y.Z) * h.Y + math.abs(z.Z) * h.Z
		)
end

-- 2026-10-31: the stone skirt of a house on a slope, from its foot `depth` studs down (Logic/TownGen/Houses). The
-- model's plinth (the lowest part as wide and deep as everything that stands on the ground, at most a third of the
-- model's height) is copied downward, so the skirt is the same stone; a model without one gets a stone block
-- (Data/Kit.skirt) under the parts on the ground.
local function addSkirt(model: Model, pivot: CFrame, depth: number)
	local ground: { { part: BasePart, lo: Vector3, hi: Vector3 } } = {}
	local lo, hi = Vector3.new(math.huge, 0, math.huge), Vector3.new(-math.huge, 0, -math.huge)
	local top = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			local c, h = boxIn(pivot, d)
			top = math.max(top, c.Y + h.Y)
			if c.Y - h.Y < 0.25 then
				table.insert(ground, { part = d, lo = c - h, hi = c + h })
				lo = Vector3.new(math.min(lo.X, c.X - h.X), 0, math.min(lo.Z, c.Z - h.Z))
				hi = Vector3.new(math.max(hi.X, c.X + h.X), 0, math.max(hi.Z, c.Z + h.Z))
			end
		end
	end
	if #ground == 0 then
		return
	end
	local span = hi - lo
	local band: { part: BasePart, lo: Vector3, hi: Vector3 }? = nil
	for _, g in ground do
		local size = g.hi - g.lo
		if
			size.X >= span.X * 0.85
			and size.Z >= span.Z * 0.85
			and size.Y <= top / 3
			and (band == nil or size.Y < (band.hi - band.lo).Y)
		then
			band = g
		end
	end
	if band then
		local step = (band.hi - band.lo).Y - 0.02
		for k = 1, math.min(math.ceil(depth / step), 12) do
			local copy = band.part:Clone()
			copy.Name = "Skirt"
			copy.CFrame = band.part.CFrame - Vector3.new(0, k * step, 0)
			copy.Parent = model
		end
		return
	end
	local look = Kit.skirt
	local block = Instance.new("Part")
	block.Name = "Skirt"
	block.Anchored = true
	block.CanCollide = false
	block.CanQuery = false
	block.CanTouch = false
	block.Locked = true
	block.TopSurface = Enum.SurfaceType.Smooth
	block.BottomSurface = Enum.SurfaceType.Smooth
	block.Color = Color3.fromHex(look.color)
	block.Material = (Enum.Material :: any)[look.material]
	block.Size = Vector3.new(span.X - 0.1, depth + 0.1, span.Z - 0.1)
	block.CFrame = pivot * CFrame.new((lo.X + hi.X) / 2, 0.05 - depth / 2, (lo.Z + hi.Z) / 2)
	block.Parent = model
end

-- A placed copy of a placement's model.
function KitAssets.place(placement: Placement, parent: Instance): Model
	local model = placement.template:Clone()
	if math.abs(placement.scale - 1) > 1e-3 then
		model:ScaleTo(placement.scale)
	end
	model:PivotTo(placement.cframe)
	local stretch, axis = placement.stretch, placement.axis
	if stretch and axis and math.abs(stretch - 1) > 1e-3 then
		-- every part moves away from the pivot along the axis and grows along its own side closest to the axis (the
		-- Tripo models are one mesh, square to the slot)
		local origin = placement.cframe.Position
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				local part = d :: BasePart
				local along = axis:Dot(part.Position - origin)
				local cf = part.CFrame
				local x = math.abs(cf.RightVector:Dot(axis))
				local y = math.abs(cf.UpVector:Dot(axis))
				local z = math.abs(cf.LookVector:Dot(axis))
				local size = part.Size
				if x >= y and x >= z then
					size = Vector3.new(size.X * stretch, size.Y, size.Z)
				elseif y >= z then
					size = Vector3.new(size.X, size.Y * stretch, size.Z)
				else
					size = Vector3.new(size.X, size.Y, size.Z * stretch)
				end
				part.Size = size
				part.CFrame = cf + axis * along * (stretch - 1)
			end
		end
	end
	local tint = placement.tint
	if tint then
		-- the leaves: colourless leaf textures take the variant's colour (Data/Kit `tint`)
		for _, d in model:GetDescendants() do
			if
				d:IsA("SurfaceAppearance")
				and d.Parent
				and (d.Parent.Name:find("Canopy") or d.Parent.Name:find("Leaves"))
			then
				d.Color = tint
				-- W28: the leaf mesh itself in the tint too, so a canopy whose texture has not loaded yet is a
				-- tinted crown, never a pale or bright green blob
				local leaves = d.Parent
				if leaves and leaves:IsA("BasePart") then
					(leaves :: BasePart).Color = tint
				end
			end
		end
	end
	local paint = placement.paint
	if paint then
		for _, d in model:GetDescendants() do
			if d:IsA("MeshPart") then
				d.TextureID = ""
				d.Color = paint.color
				d.Material = paint.material
			elseif d:IsA("SurfaceAppearance") then
				d:Destroy()
			end
		end
	end
	local skirt = placement.skirt
	if skirt and skirt > 0.05 then
		addSkirt(model, placement.cframe, skirt)
	end
	if placement.persistent then
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	end
	-- W29: small props (bushes, undergrowth, pebbles) cast no shadow
	if placement.extent * placement.scale < Config.Kit.shadowMin then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.CastShadow = false
			end
		end
	end
	model.Parent = parent
	return model
end

-- Drops the prepared templates (after Assets.Kit changed in Studio).
function KitAssets.Reset()
	table.clear(templates)
	table.clear(warned)
end

return KitAssets
