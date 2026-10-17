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
