--!strict
-- W08: the base motion of the player's own character (StarterCharacterScripts.Animate: Roblox does not add its default
-- Animate when the character already has one). Idle with variants, walk / run blended by speed, jump, fall, landing
-- after a long fall, climb, swim and floating: clips and numbers from Data/Locomotion, choices from Logic/LocomotionPick.
-- The tracks play on the character's Animator, so they replicate to the other players like the default Animate did.
-- Attacks, skills, emotes and the rider's legs stay on top (AnimationController writes Motor6D.Transform after the
-- Animator); these clips use the priorities Idle / Movement, never Action. A clip that does not load (no permission,
-- moderation) falls back to the Roblox default of its state with one warning.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Locomotion = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Data"):WaitForChild("Locomotion"))
local LocomotionPick =
	require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Logic"):WaitForChild("LocomotionPick"))

local character = script.Parent :: Model
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local root = character:WaitForChild("HumanoidRootPart") :: BasePart
local animator = (humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator")) :: Animator

-- The clip's track, loaded once; a clip whose track keeps no length after LOAD_SECONDS swaps to the fallback id.
local LOAD_SECONDS = 4
local tracks: { [string]: AnimationTrack } = {}
local warned: { [string]: boolean } = {}

local function load(
	key: string,
	id: string,
	fallback: string,
	priority: Enum.AnimationPriority,
	looped: boolean
): AnimationTrack?
	if id == "" then
		return nil
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok or not track then
		if fallback ~= "" and fallback ~= id then
			return load(key, fallback, "", priority, looped)
		end
		return nil
	end
	track.Priority = priority
	track.Looped = looped
	if fallback ~= "" and fallback ~= id then
		task.delay(LOAD_SECONDS, function()
			if track.Length > 0 or tracks[key] ~= track then
				return
			end
			if not warned[id] then
				warned[id] = true
				warn(`[Animate] clip {id} ({key}) did not load; the Roblox default plays`)
			end
			local replacement = load(key, fallback, "", priority, looped)
			if replacement then
				local wasPlaying = track.IsPlaying
				track:Stop(0)
				tracks[key] = replacement
				if wasPlaying then
					replacement:Play(0)
				end
			end
		end)
	end
	tracks[key] = track
	return track
end

local clips, fallback = Locomotion.clips, Locomotion.fallback
local IDLE, MOVE = Enum.AnimationPriority.Idle, Enum.AnimationPriority.Movement
load("idle", clips.idle, fallback.idle, IDLE, true)
load("walk", clips.walk, fallback.walk, MOVE, true)
load("run", clips.run, fallback.run, MOVE, true)
load("jump", clips.jump, fallback.jump, MOVE, false)
load("fall", clips.fall, fallback.fall, MOVE, true)
load("land", clips.land, fallback.land, MOVE, false)
load("climb", clips.climb, fallback.climb, MOVE, true)
load("swim", clips.swim, fallback.swim, MOVE, true)
load("swimIdle", clips.swimIdle, fallback.swimIdle, MOVE, true)
local variants: { string } = {}
for i, id in clips.idleVariants do
	local key = `idleVariant{i}`
	if load(key, id, "", IDLE, false) then
		table.insert(variants, key)
	end
end

-- Which tracks each clip of LocomotionPick plays.
local GROUPS: { [string]: { string } } = {
	idle = { "idle" },
	move = { "walk", "run" },
	jump = { "jump" },
	fall = { "fall" },
	climb = { "climb" },
	swim = { "swim" },
	swimIdle = { "swimIdle" },
	none = {},
}

local current: LocomotionPick.Clip = "none" :: LocomotionPick.Clip
local airborneAt: number? = nil
local jumpedAt = -math.huge -- the Jumping state lasts a frame: the jump clip plays for air.fallAfter after it
local airborneY = 0
local idleSince = os.clock()
local variantDue = LocomotionPick.variantDelay(math.random())
local playingVariant: AnimationTrack? = nil
local lastHealth = humanoid.Health
local hurtAt = -math.huge

local function heightScale(): number
	local value = humanoid:FindFirstChild("BodyHeightScale")
	return if value and value:IsA("NumberValue") then math.max(value.Value, 0.5) else 1
end

local function stopGroup(clip: LocomotionPick.Clip, fade: number)
	local keys: { string } = GROUPS[clip] or {}
	for _, key in keys do
		local track = tracks[key]
		if track and track.IsPlaying then
			track:Stop(fade)
		end
	end
end

local function playGroup(clip: LocomotionPick.Clip, fade: number)
	local keys: { string } = GROUPS[clip] or {}
	for _, key in keys do
		local track = tracks[key]
		if track and not track.IsPlaying then
			track:Play(fade, if clip == "move" then 0.001 else 1, 1)
		end
	end
end

local function reducedState(): LocomotionPick.State
	local s = humanoid:GetState()
	if s == Enum.HumanoidStateType.Dead or humanoid.Health <= 0 then
		return "dead"
	elseif s == Enum.HumanoidStateType.Jumping then
		return "jump"
	elseif s == Enum.HumanoidStateType.Freefall or s == Enum.HumanoidStateType.FallingDown then
		return "fall"
	elseif s == Enum.HumanoidStateType.Climbing then
		return "climb"
	elseif s == Enum.HumanoidStateType.Swimming then
		return "swim"
	elseif s == Enum.HumanoidStateType.Seated then
		return "seated"
	elseif s == Enum.HumanoidStateType.Physics or s == Enum.HumanoidStateType.PlatformStanding then
		return "none"
	end
	return "ground"
end

local function sinceCombat(now: number): number
	local action = character:GetAttribute("VaelthornActionAt")
	local acted = if type(action) == "number" then action else -math.huge
	return now - math.max(acted, hurtAt)
end

humanoid.HealthChanged:Connect(function(health: number)
	if health < lastHealth then
		hurtAt = os.clock()
	end
	lastHealth = health
end)

-- Landing after a long fall: a short clip over whatever the ground state plays.
humanoid.StateChanged:Connect(function(_, new: Enum.HumanoidStateType)
	if new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
		if airborneAt then
			local height = airborneY - root.Position.Y
			airborneAt = nil
			local land = tracks.land
			if land and LocomotionPick.lands(height / heightScale()) then
				land:Play(Locomotion.fade.land, 1, 1)
			end
		end
	elseif new == Enum.HumanoidStateType.Jumping or new == Enum.HumanoidStateType.Freefall then
		if new == Enum.HumanoidStateType.Jumping then
			jumpedAt = os.clock()
		end
		if not airborneAt then
			airborneAt = os.clock()
			airborneY = root.Position.Y
		end
	end
end)

local function step()
	local now = os.clock()
	local state = reducedState()
	if state == "fall" and now - jumpedAt < Locomotion.air.fallAfter then
		state = "jump"
	end
	local velocity = root.AssemblyLinearVelocity
	local scale = heightScale()
	local horizontal = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local mount = character:GetAttribute("Mount")
	if airborneAt and (state == "fall" or state == "jump") then
		airborneY = math.max(airborneY, root.Position.Y)
	end
	local input = {
		state = state,
		speed = if state == "climb" then velocity.Y else horizontal,
		heightScale = scale,
		airTime = if state == "jump" then now - jumpedAt elseif airborneAt then now - airborneAt else 0,
		mounted = type(mount) == "string" and mount ~= "",
	}
	local clip: LocomotionPick.Clip = LocomotionPick.clip(input :: any)
	if clip ~= current then
		local fade = LocomotionPick.fade(current, clip)
		stopGroup(current, fade)
		playGroup(clip, fade)
		if clip == "idle" then
			idleSince = now
			variantDue = LocomotionPick.variantDelay(math.random())
		end
		if playingVariant and clip ~= "idle" then
			playingVariant:Stop(fade)
			playingVariant = nil
		end
		current = clip
	end
	if clip == "move" then
		local b = LocomotionPick.blend(horizontal, scale)
		local walk, run = tracks.walk, tracks.run
		if walk then
			walk:AdjustWeight(math.max(b.walk, 0.001), 0.1)
			walk:AdjustSpeed(b.walkSpeed)
		end
		if run then
			run:AdjustWeight(math.max(b.run, 0.001), 0.1)
			run:AdjustSpeed(b.runSpeed)
		end
	elseif clip == "climb" or clip == "swim" then
		local track = tracks[clip]
		if track then
			track:AdjustSpeed(LocomotionPick.rate(clip, if clip == "climb" then velocity.Y else horizontal, scale))
		end
	elseif clip == "idle" and #variants > 0 and not playingVariant then
		if LocomotionPick.variantAllowed(clip, now - idleSince, variantDue, sinceCombat(now)) then
			local track = tracks[variants[math.random(1, #variants)]]
			if track then
				track:Play(0.3, 1, 1)
				playingVariant = track
				track.Stopped:Once(function()
					if playingVariant == track then
						playingVariant = nil
					end
					idleSince = os.clock()
					variantDue = LocomotionPick.variantDelay(math.random())
				end)
			end
		end
	end
end

local connection = RunService.Heartbeat:Connect(function()
	local ok, err = pcall(function()
		step()
	end)
	if not ok then
		warn(`[Animate] {err}`)
	end
end)

humanoid.Died:Connect(function()
	connection:Disconnect()
	for _, track in tracks do
		track:Stop(0.2)
	end
end)
