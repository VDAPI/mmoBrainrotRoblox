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
local KitPick = require(ReplicatedStorage.Shared.Logic.KitPick)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)

local KitAssets = {}

export type Slot = { key: string, p: { number }, s: number, lod: string }
export type Placement = {
	template: Model,
	cframe: CFrame,
	scale: number,
	tint: Color3?,
	paint: { color: Color3, material: Enum.Material }?,
	persistent: boolean?, -- W29: a big landmark kept streamed to every player (Config.Kit.persistentSize)
}
-- (slot, frame of the Build) -> where the slot's model stands, or nil (keep the pieces)
export type Resolver = (slot: Slot, base: CFrame) -> Placement?

type Template = { model: Model, height: number, width: number }

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
	local t: Template = { model = model, height = size.Y, width = math.max(size.X, size.Z) }
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
		local tint = choice.variant.tint
		local paint = choice.variant.paint
		local material: Enum.Material? = nil
		if paint then
			local ok, value = pcall(function()
				return (Enum.Material :: any)[paint.material]
			end)
			material = if ok then value else Enum.Material.Rock
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

-- A placed copy of a placement's model.
function KitAssets.place(placement: Placement, parent: Instance): Model
	local model = placement.template:Clone()
	if math.abs(placement.scale - 1) > 1e-3 then
		model:ScaleTo(placement.scale)
	end
	model:PivotTo(placement.cframe)
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
	if placement.persistent then
		model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
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
