--!strict
-- Sprint (S18, DESIGN §24): hold the sprint key (LeftControl by default, rebindable) or toggle the touch
-- button. The server owns the walk speed (StatService.SetSprint); the client only reports the intent.
-- Owner 2026-11-10 ("they may block, but no climbing"): a monster's blocker column (Data/BodyGroups) stands over the
-- highest a player's body gets beside it, yet a character can still come down on it from above (a ledge, a cliff, a
-- jump off a rock) and ride the monster. Ten times a second this client checks its own character against the blockers
-- of the monsters near it (Logic/BlockerGuard decides) and slides it off one it stands on or is landing on: a short
-- push on the ground plane (a LinearVelocity on the root, height left to gravity), so it drops beside the monster.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local BlockerGuard = require(ReplicatedStorage.Shared.Logic.BlockerGuard)
local BodyGroups = require(ReplicatedStorage.Shared.Data.BodyGroups)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Keybinds = require(script.Parent.Parent.UI.Keybinds)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.UI.State)

local MovementController = {
	Name = "MovementController",
}

local scope = Fusion.scoped(Fusion)
-- True while sprinting, observable (touch button state).
MovementController.Sprinting = scope:Value(false)

local function set(on: boolean)
	if Fusion.peek(MovementController.Sprinting) == on then
		return
	end
	-- S96: no sprint in the saddle (the server ignores it there anyway)
	if on and State.Get({ "character", "mounts", "riding" }) == true then
		return
	end
	MovementController.Sprinting:set(on)
	Net.Send("SetSprint", on)
end

function MovementController.ToggleSprint()
	set(not Fusion.peek(MovementController.Sprinting))
end

-- Off monsters (owner 2026-11-10) ----------------------------------------------------------------------------------

local pushing = false -- a push holds the character
local attempts = 0 -- pushes in a row (Logic/BlockerGuard turns each next one: a wall may stand where one went)

-- Holds the root at the push's ground-plane velocity for its time; nothing else moves it meanwhile.
local function slide(root: BasePart, push: BlockerGuard.Push)
	local attachment = Instance.new("Attachment")
	attachment.Name = "BlockerGuard"
	local mover = Instance.new("LinearVelocity")
	mover.Name = "BlockerGuard"
	mover.Attachment0 = attachment
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	mover.PrimaryTangentAxis = Vector3.xAxis
	mover.SecondaryTangentAxis = Vector3.zAxis
	mover.PlaneVelocity = Vector2.new(push.vx, push.vz)
	-- stronger than the Humanoid's own walk, which would hold the character still on the column's top
	mover.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	mover.MaxForce = math.huge
	mover.Parent = attachment
	attachment.Parent = root
	pushing = true
	task.delay(push.time, function()
		attachment:Destroy()
		pushing = false
	end)
end

local function guard()
	if pushing then
		return
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local monsters = Workspace:FindFirstChild("Monsters")
	if
		not root
		or not root:IsA("BasePart")
		or not humanoid
		or not monsters
		or root.Anchored
		or humanoid.Health <= 0
		or humanoid.Sit
		or humanoid.PlatformStand
	then
		attempts = 0
		return
	end
	local at = root.Position
	local look = root.CFrame.LookVector
	-- R6 measures HipHeight from the bottom of its legs, 2 studs under the root (as MountService does)
	local legs = if humanoid.RigType == Enum.HumanoidRigType.R6 then 2 else 0
	local body: BlockerGuard.Body = {
		x = at.X,
		z = at.Z,
		feet = at.Y - root.Size.Y / 2 - legs - humanoid.HipHeight,
		half = math.max(root.Size.X, root.Size.Z) / 2,
		vy = root.AssemblyLinearVelocity.Y,
		lookX = look.X,
		lookZ = look.Z,
	}
	local range = BlockerGuard.RANGE * BlockerGuard.RANGE
	for _, model in monsters:GetChildren() do
		local blocker = model:FindFirstChild(BodyGroups.BLOCKER)
		-- a dead monster's column no longer collides: nobody stands on it
		if not blocker or not blocker:IsA("BasePart") or not blocker.CanCollide then
			continue
		end
		local centre = blocker.Position
		local dx, dz = centre.X - at.X, centre.Z - at.Z
		if dx * dx + dz * dz > range then
			continue
		end
		local right = blocker.CFrame.RightVector
		local velocity = blocker.AssemblyLinearVelocity
		local size = blocker.Size
		local push = BlockerGuard.push(body, {
			x = centre.X,
			y = centre.Y,
			z = centre.Z,
			rightX = right.X,
			rightZ = right.Z,
			width = size.X,
			height = size.Y,
			depth = size.Z,
			vx = velocity.X,
			vz = velocity.Z,
			collides = true,
		}, attempts)
		if push then
			attempts += 1
			slide(root, push)
			return
		end
	end
	attempts = 0
end

function MovementController.Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if Keybinds.is(input.KeyCode, "sprint") then
			set(true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Keyboard and Keybinds.is(input.KeyCode, "sprint") then
			set(false)
		end
	end)
	-- The server clears the sprint on death, respawn and mounting, already when the mount channel starts (S96);
	-- mirror that so the button never lies, also after an interrupted channel.
	State.Changed:Connect(function()
		if
			State.Get({ "death" }) ~= nil
			or State.Get({ "session", "phase" }) ~= "playing"
			or State.Get({ "character", "mounts", "riding" }) == true
			or State.Get({ "mountCast" }) ~= nil
		then
			if Fusion.peek(MovementController.Sprinting) then
				MovementController.Sprinting:set(false)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(BlockerGuard.EVERY)
			guard()
		end
	end)
end

return MovementController
