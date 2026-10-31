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
-- Studio review 2026-10-31 (2): the camera stayed Scriptable at an AnimLab stage after a teleport and at a scene's
-- shot while the player walked on, and the character could not move. The camera has one owner at a time
-- (Logic/CameraLease): `Claim` / `Release` (the select screen, a scene, AnimLab); the last owner has it, and when none
-- is left the player's camera comes back (Custom on the character). A claim may lock the movement input (a scene) and
-- may end with a teleport, a map change or a new character (AnimLab). A watchdog every frame takes back leases past
-- their deadline and gives the player an ownerless Scriptable camera after CameraLease.GRACE seconds. The camera's
-- attributes VaelthornCameraOwner / VaelthornMoveLock name the holders (for a look in Studio).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local CameraClear = require(ReplicatedStorage.Shared.Logic.CameraClear)
local CameraLease = require(ReplicatedStorage.Shared.Logic.CameraLease)
local Config = require(ReplicatedStorage.Shared.Config)
local Log = require(ReplicatedStorage.Shared.Util.Log)
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

local log = Log.new("CameraController")

-- Camera ownership (Logic/CameraLease) and what each owner wants called when it loses or gets back the camera.
export type ClaimOptions = {
	camera: boolean?, -- takes the camera (Scriptable); false: only the movement lock (default true)
	lockMovement: boolean?, -- the player's movement input is off while it holds
	ttl: number?, -- seconds until the watchdog takes it back (and calls onLost)
	travel: boolean?, -- let go when the character teleports, changes map or is replaced (and call onLost)
	onLost: (() -> ())?, -- taken back by the watchdog (deadline, travel)
	onRegain: (() -> ())?, -- the camera is this owner's again after a later owner let go
}
type Hooks = { onLost: (() -> ())?, onRegain: (() -> ())? }
local lease = CameraLease.new()
local hooks: { [string]: Hooks } = {}
local controlsOff = false
local seenCharacter: Model? = nil
local seenMap: string? = nil
local seenRoot: { number }? = nil

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

-- The PlayerModule's controls (movement input), nil when they cannot be had.
local function controls(): any
	local ok, result = pcall(function()
		local module = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)
		return (require :: any)(module):GetControls()
	end)
	return if ok then result else nil
end

-- The player's own camera: Custom on the character's humanoid.
local function gameCamera()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	camera.CameraType = Enum.CameraType.Custom
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

-- After any change of the leases: the movement lock follows them, the camera goes to its holder or the player.
local function settle(regain: boolean)
	local locked = CameraLease.locked(lease)
	if locked ~= controlsOff then
		controlsOff = locked
		task.spawn(function()
			local c = controls()
			if c then
				pcall(function()
					if controlsOff then
						c:Disable()
					else
						c:Enable()
					end
				end)
			end
		end)
	end
	local holder = CameraLease.holder(lease)
	local camera = Workspace.CurrentCamera
	if camera then
		camera:SetAttribute("VaelthornCameraOwner", holder)
		local lockers: { string } = {}
		for _, item in lease.leases do
			if item.lock then
				table.insert(lockers, item.owner)
			end
		end
		camera:SetAttribute("VaelthornMoveLock", if #lockers > 0 then table.concat(lockers, ",") else nil)
	end
	if holder == nil then
		gameCamera()
	elseif regain then
		local hook = hooks[holder]
		if hook and hook.onRegain then
			local ok: boolean, err: any = pcall(hook.onRegain)
			if not ok then
				log:warn("%s onRegain failed: %s", holder, tostring(err))
			end
		end
	end
end

-- Owners taken back by the watchdog: their onLost, then the camera and the lock settle.
local function dropped(owners: { string }, why: string)
	if #owners == 0 then
		return
	end
	for _, owner in owners do
		log:info("camera owner %s let go (%s)", owner, why)
		local hook = hooks[owner]
		hooks[owner] = nil
		if hook and hook.onLost then
			local ok: boolean, err: any = pcall(hook.onLost)
			if not ok then
				log:warn("%s onLost failed: %s", owner, tostring(err))
			end
		end
	end
	settle(true)
end

-- `owner` takes the camera (Scriptable; it moves the camera itself) or, with camera = false, only the movement lock.
-- Taking it again refreshes the options. Pair every Claim with a Release on every way out.
function CameraController.Claim(owner: string, options: ClaimOptions?)
	local o: ClaimOptions = options or {}
	CameraLease.claim(lease, owner, os.clock(), {
		camera = o.camera,
		lock = o.lockMovement,
		ttl = o.ttl,
		travel = o.travel,
	})
	hooks[owner] = { onLost = o.onLost, onRegain = o.onRegain }
	local camera = Workspace.CurrentCamera
	if camera and o.camera ~= false then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	settle(false)
end

-- `owner` lets go (safe to call when it holds nothing): the camera goes to the previous owner or to the player.
function CameraController.Release(owner: string)
	local wasHolder = CameraLease.holder(lease) == owner
	CameraLease.release(lease, owner)
	hooks[owner] = nil
	settle(wasHolder)
end

-- The owner of the camera now (nil: the player's camera).
function CameraController.Holder(): string?
	return CameraLease.holder(lease)
end

-- Every frame: deadlines, travel (teleport, map change, new character) and an ownerless Scriptable camera.
local function watchdog(camera: Camera)
	local now = os.clock()
	dropped(CameraLease.expired(lease, now), "deadline")
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local mapId = currentMap()
	local at: { number }? = if root then { root.Position.X, root.Position.Y, root.Position.Z } else nil
	if character ~= seenCharacter or mapId ~= seenMap or CameraLease.teleported(seenRoot, at) then
		dropped(CameraLease.travelled(lease), "travel")
	end
	seenCharacter, seenMap, seenRoot = character, mapId, at
	if CameraLease.watch(lease, camera.CameraType == Enum.CameraType.Scriptable, now) then
		log:warn("Scriptable camera with no owner: back to the player")
		gameCamera()
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
	if not camera then
		return
	end
	watchdog(camera)
	if camera.CameraType ~= Enum.CameraType.Custom then
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
