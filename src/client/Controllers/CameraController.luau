--!strict
-- W01: the "from above" camera (option "Camera", settings.cameraMode "top"; docs/WYGLAD.md §1). The Roblox camera keeps
-- running (turning with the right mouse button or a drag, the shift lock); right after it, this controller puts the
-- camera at a fixed angle above the character (Config.Camera.topPitch) at its own distance (mouse wheel, pinch) and
-- pulls it in front of walls. Underground (caves, crypts, boss chambers) the angle is flatter and the reach shorter.
-- Only while the camera is the player's (CameraType Custom): cutscenes, screens and AnimLab take it over as before and
-- get it back in the chosen mode. Looks only: aiming and the server do not depend on it.
-- Studio review 2026-10-31 (the first view in a roof and a lamp): the kit models of the city (houses, walls, lamps,
-- trees) neither collide nor take rays; their collision is invisible, and the Roblox camera's Popper only sees opaque
-- colliding parts. Both modes now pull the camera in front of the map's colliding geometry: one ray a frame from the
-- focus to the camera over the terrain and the map's own folder (World.<map>: no NPCs, monsters or players), in at
-- once and back out eased (Logic/CameraClear). The free camera keeps its turn and zoom: only its position moves along
-- its own line. A fresh character also gets the camera behind it once the server has placed it (the Roblox camera
-- turns behind a new character before the server pivots it to its spot and facing).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local CameraClear = require(ReplicatedStorage.Shared.Logic.CameraClear)
local Config = require(ReplicatedStorage.Shared.Config)
local MapLooks = require(ReplicatedStorage.Shared.Data.MapLooks)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.UI.State)

local CameraController = {
	Name = "CameraController",
}

local STEP_NAME = "VaelthornTopCamera"
local WHEEL_STEP = 4
-- A fresh character waits at most this long (seconds) for its placement before the camera is left to Roblox.
local RESET_WAIT = 15
-- The placed root lies within this many studs of the server's target (WorldController's ground check uses the same).
local RESET_NEAR = 12

local player = Players.LocalPlayer
local distance = Config.Camera.topDefault
local lastFlat = Vector3.new(0, 0, -1)
local pinchStart: number? = nil

-- The camera ray: colliding map geometry only (the kit models' invisible collision counts, their look does not).
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
rayParams.FilterDescendantsInstances = { Workspace.Terrain }
rayParams.IgnoreWater = true
rayParams.RespectCanCollide = true
local rayMap: string? = nil
local rayFolder: Instance? = nil
local rayRetry = 0
-- CameraClear.ease: the distance the camera was held to last frame (nil: free).
local held: number? = nil

-- Fresh character: armed by CharacterAdded, aimed by the server's GroundCheck (the spot the model was placed on).
local resetArmed = false
local resetUntil = 0
local resetFrames = 0
local groundTarget: Vector3? = nil
local groundAt = 0
local armedAt = 0

local function topMode(): boolean
	return State.Get({ "account", "settings", "cameraMode" }) == "top"
end

local function currentMap(): string?
	local mapId = State.Get({ "character", "location", "map" })
	return if type(mapId) == "string" then mapId else nil
end

local function underground(): boolean
	local mapId = currentMap()
	local map = if mapId then Maps.get(mapId) else nil
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

-- The ray's filter follows the map (and waits for the map's folder to arrive, checked once a second).
local function refreshFilter()
	local mapId = currentMap()
	if mapId == rayMap and rayFolder ~= nil and rayFolder.Parent ~= nil then
		return
	end
	local now = os.clock()
	if mapId == rayMap and now < rayRetry then
		return
	end
	rayMap, rayRetry = mapId, now + 1
	local world = Workspace:FindFirstChild("World")
	rayFolder = if world and mapId then world:FindFirstChild(mapId) else nil
	rayParams.FilterDescendantsInstances = if rayFolder then { Workspace.Terrain, rayFolder } else { Workspace.Terrain }
end

-- How far from `focus` the camera may stand along `direction` (unit) when it wants `wanted` studs. One ray.
local function clearReach(focus: Vector3, direction: Vector3, wanted: number, dt: number): number
	refreshFilter()
	local hit = Workspace:Raycast(focus, direction * wanted, rayParams)
	local allowed = CameraClear.reach(wanted, if hit then hit.Distance else nil, Config.Camera.wallMargin)
	held = CameraClear.ease(held, allowed, wanted, dt)
	return held or wanted
end

-- The camera behind the placed character, START_PITCH down (what the Roblox camera does for a new character, but
-- with the facing the server gave it); the Roblox camera turns from this look on, the zoom stays its own.
local function resetBehind(camera: Camera, root: BasePart)
	local look = root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 1e-3 then
		return
	end
	lastFlat = flat.Unit
	held = nil
	local x, y, z = CameraClear.behind(CameraClear.yawOf(flat.X, flat.Z), CameraClear.START_PITCH)
	local focus = root.Position + Vector3.new(0, CameraClear.HEAD, 0)
	camera.CFrame = CFrame.lookAt(focus + Vector3.new(x, y, z) * CameraClear.START_ZOOM, focus)
end

local function checkReset(camera: Camera, root: BasePart)
	resetFrames += 1
	if os.clock() > resetUntil then
		resetArmed = false
		return
	end
	-- two frames after CharacterAdded the Roblox camera has made its own turn behind the model (it would undo ours)
	local target = groundTarget
	if target and groundAt >= armedAt - 1 and resetFrames > 2 and (root.Position - target).Magnitude < RESET_NEAR then
		resetArmed = false
		resetBehind(camera, root)
	end
end

local function topStep(camera: Camera, root: BasePart, humanoid: Humanoid, dt: number)
	local pitch, minD, maxD = limits()
	distance = math.clamp(distance, minD, maxD)
	-- CameraOffset carries the hit shake (CombatFxController)
	local focus = root.Position + Vector3.new(0, 2, 0) + humanoid.CameraOffset
	local rad = math.rad(pitch)
	local back = -flatLook(camera)
	local direction = (back * math.cos(rad) + Vector3.yAxis * math.sin(rad)).Unit
	local at = focus + direction * clearReach(focus, direction, distance, dt)
	camera.CFrame = CFrame.lookAt(at, focus)
	camera.Focus = CFrame.new(focus)
end

-- The Roblox camera (Classic / Follow) as it placed itself, moved along its own line in front of the geometry its
-- Popper does not see. First person (under a stud from the focus) is left alone.
local function freeStep(camera: Camera, dt: number)
	local focus = camera.Focus.Position
	local offset = camera.CFrame.Position - focus
	local wanted = offset.Magnitude
	if wanted < 1 then
		held = nil
		return
	end
	local direction = offset / wanted
	local reach = clearReach(focus, direction, wanted, dt)
	if reach < wanted then
		camera.CFrame += direction * (reach - wanted)
	end
end

local function step(dt: number)
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
	if resetArmed then
		checkReset(camera, root)
	end
	if topMode() then
		topStep(camera, root, humanoid, dt)
	else
		freeStep(camera, dt)
	end
end

local function zoom(by: number)
	local _, minD, maxD = limits()
	distance = math.clamp(distance + by, minD, maxD)
end

function CameraController.Start()
	RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Camera.Value + 1, step)
	player.CharacterAdded:Connect(function()
		resetArmed = true
		resetFrames = 0
		armedAt = os.clock()
		resetUntil = armedAt + RESET_WAIT
	end)
	-- Every placement (spawn, travel, rescue) tells the client its target; only a fresh character's turns the camera.
	Net.On("GroundCheck", function(_token: number, target: Vector3)
		groundTarget = target
		groundAt = os.clock()
	end)
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
