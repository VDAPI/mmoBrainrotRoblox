--!strict
-- W12: the land beyond the edge of the map the player is on (Data/Horizons, Logic/HorizonGen): parts built on this
-- client only (no server parts, no collision, no queries, no shadows), the kit's landmark models (Data/Horizons
-- landmarks, ReplicatedStorage.Assets.Kit) among them. Rebuilt when the map, the phase or the graphics level changes;
-- the low level gets the coarse ring. Looks only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Horizons = require(ReplicatedStorage.Shared.Data.Horizons)
local HorizonGen = require(ReplicatedStorage.Shared.Logic.HorizonGen)
local KitAssets = require(ReplicatedStorage.Shared.Util.KitAssets)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local State = require(script.Parent.Parent.UI.State)

local HorizonController = {}
HorizonController.Name = "HorizonController"
HorizonController.Deps = { "WorldController" }

local WorldController: any
local folder: Folder
local shown: string? = nil -- "<map>|<low>" being shown

local CHECK_EVERY = 1

local function low(): boolean
	return State.Get({ "account", "settings", "quality" }) == "low"
end

local function part(piece: HorizonGen.Piece, origin: Vector3): BasePart
	local p: BasePart
	if piece.shape == "wedge" then
		p = Instance.new("WedgePart")
	else
		p = Instance.new("Part")
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Locked = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Color = Color3.fromHex(piece.color)
	p.Size = Vector3.new(piece.sx, piece.sy, piece.sz)
	p.CFrame = CFrame.new(origin + Vector3.new(piece.x, piece.y, piece.z))
		* CFrame.Angles(0, math.rad(piece.yaw), 0)
		* CFrame.Angles(math.rad(piece.tilt), 0, 0)
	if piece.shape == "ellipsoid" then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	end
	return p
end

-- W17: a slow plume of dark smoke over the top of a landmark (a volcano) and an orange glow inside its crater.
local function smoke(landmark: Model, isLow: boolean)
	local cf, size = landmark:GetBoundingBox()
	local top = Instance.new("Part")
	top.Name = "Plume"
	top.Anchored = true
	top.CanCollide = false
	top.CanQuery = false
	top.CanTouch = false
	top.Transparency = 1
	top.Size = Vector3.new(size.X * 0.2, 1, size.Z * 0.2)
	top.CFrame = CFrame.new(cf.Position + Vector3.new(0, size.Y / 2 - size.Y * 0.04, 0))
	top.Parent = landmark
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromHex("#3A3230"), Color3.fromHex("#6A605A"))
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.4),
		NumberSequenceKeypoint.new(0.7, 0.7),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Size = NumberSequence.new(size.X * 0.12, size.X * 0.45)
	e.Lifetime = NumberRange.new(20, 28)
	e.Speed = NumberRange.new(size.Y * 0.03, size.Y * 0.05)
	e.SpreadAngle = Vector2.new(8, 8)
	e.Acceleration = Vector3.new(size.Y * 0.004, 0, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-5, 5)
	e.LightInfluence = 1
	e.Rate = if isLow then 0.6 else 1.4
	e.Parent = top
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromHex("#FF7A30")
	glow.Range = 60
	glow.Brightness = 3
	glow.Parent = top
end

local function clear()
	folder:ClearAllChildren()
	shown = nil
end

local function build(mapId: string, isLow: boolean)
	local map = Maps.get(mapId)
	local def = Horizons.get(mapId)
	if not map or not def then
		return
	end
	local origin = Vector3.new(map.offset.x, map.offset.y, map.offset.z)
	local model = Instance.new("Model")
	model.Name = `Horizon_{mapId}`
	for _, piece in HorizonGen.pieces(mapId, isLow) do
		part(piece, origin).Parent = model
	end
	for _, mark in def.landmarks do
		local template, height = KitAssets.model(mark.model)
		if template and height > 0 then
			local copy = template:Clone()
			copy:ScaleTo(mark.height / height)
			local x, z = HorizonGen.at(mark.deg, mark.dist)
			copy:PivotTo(
				CFrame.new(origin + Vector3.new(x, def.groundY - mark.height * 0.04, z))
					* CFrame.Angles(0, math.rad(mark.turn or 0), 0)
			)
			copy.Parent = model
			if mark.smoke then
				smoke(copy, isLow)
			end
		end
	end
	model.Parent = folder
end

local function check()
	local mapId = State.Get({ "character", "location", "map" })
	local playing = State.Get({ "session", "phase" }) == "playing"
	if type(mapId) ~= "string" or not playing or WorldController.IsLoading() or not Horizons.get(mapId) then
		if shown then
			clear()
		end
		return
	end
	local isLow = low()
	local key = `{mapId}|{isLow}`
	if key == shown then
		return
	end
	clear()
	shown = key
	build(mapId, isLow)
end

function HorizonController.Init(registry)
	WorldController = registry.Get("WorldController")
	folder = Instance.new("Folder")
	folder.Name = "Vaelthorn_Horizon"
	folder.Parent = Workspace
end

function HorizonController.Start()
	task.spawn(function()
		while true do
			local ok, err = pcall(function()
				check()
			end)
			if not ok then
				warn(`[Horizon] {err}`)
			end
			task.wait(CHECK_EVERY)
		end
	end)
end

return HorizonController
