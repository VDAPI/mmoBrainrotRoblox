--!strict
-- The camera kick (owner 2026-11-10, skill juice): the one writer of Humanoid.CameraOffset for every shake of the game
-- (a boss's blow or roar, a heavy hit on us, our own big skills, others' big skills nearby; CombatFxController.shake
-- and VfxController call Kick). A kick's size and time come from Logic/CameraShake (the "Hit feel" option
-- settings.shake, 0 = none, and the graphics level); while any kick runs, a RenderStep just before the camera's (the
-- Roblox camera and CameraController's view from above both read CameraOffset) writes their sum, and the offset goes
-- back to zero after the last one. Runs on the effect clock (AnimLab freezes a kick with the effect).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CameraShakeLogic = require(ReplicatedStorage.Shared.Logic.CameraShake)
local Clock = require(script.Parent.Clock)
local State = require(script.Parent.Parent.UI.State)

local CameraShake = {}

local STEP_NAME = "VaelthornCameraKick"
local MAX_KICKS = 8 -- the oldest goes when more run at once (a storm of blows)
local MIN_STUDS = 0.01 -- a kick smaller than this is not started

local kicks: { CameraShakeLogic.Kick } = {}
local bound = false
local lastHumanoid: Humanoid? = nil
local rng = Random.new()

local function humanoidOf(): Humanoid?
	local character = Players.LocalPlayer.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

local function step()
	local humanoid = humanoidOf()
	-- a new character: the old one keeps no offset
	if lastHumanoid and lastHumanoid ~= humanoid and lastHumanoid.Parent then
		lastHumanoid.CameraOffset = Vector3.zero
	end
	lastHumanoid = humanoid
	local now = Clock.now()
	if CameraShakeLogic.prune(kicks, now) == 0 then
		if humanoid then
			humanoid.CameraOffset = Vector3.zero
		end
		lastHumanoid = nil
		bound = false
		RunService:UnbindFromRenderStep(STEP_NAME)
		return
	end
	if humanoid then
		local x, y = CameraShakeLogic.offset(kicks, now)
		humanoid.CameraOffset = Vector3.new(x, y, 0)
	end
end

-- Shakes our camera with `strength` (0..1.5: 0.2 a light jolt, 0.5 a heavy blow, 1 a boss's slam), scaled by the
-- "Hit feel" option and the graphics level.
function CameraShake.Kick(strength: number)
	local amp = CameraShakeLogic.amp(
		strength,
		State.Get({ "account", "settings", "shake" }),
		State.Get({ "account", "settings", "quality" })
	)
	if amp < MIN_STUDS or not humanoidOf() then
		return
	end
	table.insert(kicks, {
		amp = amp,
		start = Clock.now(),
		seconds = CameraShakeLogic.seconds(strength),
		seed = rng:NextNumber(0, 2 * math.pi),
	})
	if #kicks > MAX_KICKS then
		table.remove(kicks, 1)
	end
	if not bound then
		bound = true
		RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Camera.Value - 1, step)
	end
end

return CameraShake
