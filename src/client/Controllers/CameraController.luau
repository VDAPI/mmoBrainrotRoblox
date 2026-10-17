--!strict
-- W01: the "from above" camera (option "Camera", settings.cameraMode "top"; docs/WYGLAD.md §1). The Roblox camera keeps
-- running (turning with the right mouse button or a drag, the shift lock); right after it, this controller puts the
-- camera at a fixed angle above the character (Config.Camera.topPitch) at its own distance (mouse wheel, pinch) and
-- pulls it in front of walls. Underground (caves, crypts, boss chambers) the angle is flatter and the reach shorter.
-- Only while the camera is the player's (CameraType Custom): cutscenes, screens and AnimLab take it over as before and
-- get it back in the chosen mode. Looks only: aiming and the server do not depend on it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local MapLooks = require(ReplicatedStorage.Shared.Data.MapLooks)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local State = require(script.Parent.Parent.UI.State)

local CameraController = {
	Name = "CameraController",
}

local STEP_NAME = "VaelthornTopCamera"
local WHEEL_STEP = 4

local player = Players.LocalPlayer
local distance = Config.Camera.topDefault
local lastFlat = Vector3.new(0, 0, -1)
local pinchStart: number? = nil

local function topMode(): boolean
	return State.Get({ "account", "settings", "cameraMode" }) == "top"
end

local function underground(): boolean
	local mapId = State.Get({ "character", "location", "map" })
	local map = if type(mapId) == "string" then Maps.get(mapId) else nil
	return map ~= nil and MapLooks.isUnderground(map.biome)
end

local function limits(): (number, number, number)
	local c = Config.Camera
	if underground() then
		return c.underPitch, c.topMin, math.min(c.topMax, c.underMax)
	end
	return c.topPitch, c.topMin, c.topMax
end

-- Same turn as the Roblox camera, flattened (the last good one when it looks straight down).
local function flatLook(camera: Camera): Vector3
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude > 1e-3 then
		lastFlat = flat.Unit
	end
	return lastFlat
end

local function step()
	if not topMode() then
		return
	end
	local camera = Workspace.CurrentCamera
	if not camera or camera.CameraType ~= Enum.CameraType.Custom then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not root or not humanoid then
		return
	end
	local pitch, minD, maxD = limits()
	distance = math.clamp(distance, minD, maxD)
	-- CameraOffset carries the hit shake (CombatFxController)
	local focus = root.Position + Vector3.new(0, 2, 0) + humanoid.CameraOffset
	local rad = math.rad(pitch)
	local back = -flatLook(camera)
	local direction = (back * math.cos(rad) + Vector3.yAxis * math.sin(rad)).Unit
	local reach = distance
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.IgnoreWater = true
	local hit = Workspace:Raycast(focus, direction * reach, params)
	if hit then
		reach = math.max(2, (hit.Position - focus).Magnitude - Config.Camera.wallMargin)
	end
	local at = focus + direction * reach
	camera.CFrame = CFrame.lookAt(at, focus)
	camera.Focus = CFrame.new(focus)
end

local function zoom(by: number)
	local _, minD, maxD = limits()
	distance = math.clamp(distance + by, minD, maxD)
end

function CameraController.Start()
	RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Camera.Value + 1, step)
	UserInputService.InputChanged:Connect(function(input: InputObject, processed: boolean)
		if processed or not topMode() then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseWheel then
			zoom(-input.Position.Z * WHEEL_STEP)
		end
	end)
	UserInputService.TouchPinch:Connect(function(_, scale: number, _, state: Enum.UserInputState, processed: boolean)
		if processed or not topMode() then
			return
		end
		if state == Enum.UserInputState.Begin then
			pinchStart = distance
		elseif state == Enum.UserInputState.Change and pinchStart and scale > 0 then
			local _, minD, maxD = limits()
			distance = math.clamp((pinchStart :: number) / scale, minD, maxD)
		else
			pinchStart = nil
		end
	end)
end

return CameraController
