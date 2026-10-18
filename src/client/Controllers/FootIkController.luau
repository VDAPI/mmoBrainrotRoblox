--!strict
-- W08 (docs/ANIMACJE.md "Lokomocja (W08)"): foot IK on slopes. The own character and the nearest
-- Data/Locomotion.footIk.others player characters within its range, while they stand or walk on the ground (not running,
-- not in the air, not mounted, not dead), get an IKControl per leg that lifts the foot whose ground is higher than the
-- character's floor onto that ground (the Humanoid keeps the body over the highest point, so the uphill foot used to sink
-- into the slope). Only on the graphics levels of footIk.levels; nothing is created on "low". The hips stay where the
-- Humanoid holds them (W08: no change to physics or HipHeight). Looks only, local to this client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Locomotion = require(ReplicatedStorage.Shared.Data.Locomotion)
local State = require(script.Parent.Parent.UI.State)

local FootIkController = {
	Name = "FootIkController",
}

type Leg = { ik: IKControl, target: Attachment, foot: BasePart, weight: number }
type Rig = { model: Model, humanoid: Humanoid, root: BasePart, legs: { Leg } }

local rigs: { [Model]: Rig } = {}
local anchor: Part? = nil
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true

local function enabled(): boolean
	local quality = State.Get({ "account", "settings", "quality" })
	local level = if type(quality) == "string" then quality else Config.Graphics.default
	return (Locomotion.footIk.levels :: any)[level] == true
end

local function holder(): Part
	if anchor and anchor.Parent then
		return anchor
	end
	local p = Instance.new("Part")
	p.Name = "VaelthornFootIk"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one * 0.2
	p.CFrame = CFrame.new()
	p.Parent = Workspace
	anchor = p
	return p
end

local function buildRig(model: Model): Rig?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return nil
	end
	local legs: { Leg } = {}
	for _, side in { "Left", "Right" } do
		local upper = model:FindFirstChild(`{side}UpperLeg`)
		local foot = model:FindFirstChild(`{side}Foot`)
		if not upper or not foot or not foot:IsA("BasePart") then
			return nil
		end
		local target = Instance.new("Attachment")
		target.Name = `{model.Name}_{side}`
		target.Parent = holder()
		local ik = Instance.new("IKControl")
		ik.Name = `VaelthornFootIk{side}`
		ik.Type = Enum.IKControlType.Position
		ik.ChainRoot = upper :: Instance
		ik.EndEffector = foot :: Instance
		ik.Target = target
		ik.Weight = 0
		ik.SmoothTime = 0.08
		ik.Parent = humanoid
		table.insert(legs, { ik = ik, target = target, foot = foot :: BasePart, weight = 0 })
	end
	return { model = model, humanoid = humanoid, root = root :: BasePart, legs = legs }
end

local function drop(model: Model)
	local rig = rigs[model]
	if not rig then
		return
	end
	for _, leg in rig.legs do
		leg.ik:Destroy()
		leg.target:Destroy()
	end
	rigs[model] = nil
end

-- The characters that should have foot IK now: the own one first, then the nearest others in range.
local function wanted(): { [Model]: boolean }
	local out: { [Model]: boolean } = {}
	if not enabled() then
		return out
	end
	local me = Players.LocalPlayer.Character
	local myRoot = me and me:FindFirstChild("HumanoidRootPart") :: BasePart?
	if me and myRoot then
		out[me] = true
	else
		return out
	end
	local cfg = Locomotion.footIk
	local near: { { model: Model, d: number } } = {}
	for _, player in Players:GetPlayers() do
		local model = player.Character
		local r = model and model:FindFirstChild("HumanoidRootPart") :: BasePart?
		if model and r and model ~= me then
			local d = (r.Position - myRoot.Position).Magnitude
			if d <= cfg.range then
				table.insert(near, { model = model, d = d })
			end
		end
	end
	table.sort(near, function(a, b)
		return a.d < b.d
	end)
	for i = 1, math.min(cfg.others, #near) do
		out[near[i].model] = true
	end
	return out
end

local function active(rig: Rig): boolean
	local h = rig.humanoid
	if h.Health <= 0 or h.FloorMaterial == Enum.Material.Air then
		return false
	end
	local mount = rig.model:GetAttribute("Mount")
	if type(mount) == "string" and mount ~= "" then
		return false
	end
	local v = rig.root.AssemblyLinearVelocity
	return Vector3.new(v.X, 0, v.Z).Magnitude <= Locomotion.footIk.maxSpeed
end

local function update(rig: Rig, dt: number)
	local on = active(rig)
	local root = rig.root
	local floor = root.Position.Y - root.Size.Y / 2 - rig.humanoid.HipHeight
	params.FilterDescendantsInstances = { rig.model, holder() }
	local cfg = Locomotion.footIk
	for _, leg in rig.legs do
		local goal = 0
		local foot = leg.foot
		if on then
			local from = Vector3.new(foot.Position.X, floor + cfg.ray, foot.Position.Z)
			local hit = Workspace:Raycast(from, Vector3.new(0, -cfg.ray * 2, 0), params)
			local owner = hit and hit.Instance:FindFirstAncestorOfClass("Model")
			-- only the world: never a character or a monster (anything with a Humanoid)
			if hit and not (owner and owner:FindFirstChildOfClass("Humanoid")) then
				local rise = hit.Position.Y - floor
				if rise > 0.1 and rise <= cfg.maxDrop then
					leg.target.WorldPosition =
						Vector3.new(foot.Position.X, hit.Position.Y + foot.Size.Y / 2, foot.Position.Z)
					goal = 1
				end
			end
		end
		leg.weight += (goal - leg.weight) * math.min(1, dt * 12)
		leg.ik.Weight = if leg.weight < 0.01 then 0 else leg.weight
	end
end

function FootIkController.Start()
	local accumulator = 1
	RunService.PreSimulation:Connect(function(dt: number)
		accumulator += dt
		if accumulator >= 0.5 then
			accumulator = 0
			local want = wanted()
			for model in rigs do
				if not want[model] or not model.Parent then
					drop(model)
				end
			end
			for model in want do
				if not rigs[model] then
					local rig = buildRig(model)
					if rig then
						rigs[model] = rig
					end
				end
			end
		end
		for _, rig in rigs do
			local ok, err = pcall(function()
				update(rig, dt)
			end)
			if not ok then
				warn(`[FootIkController] {err}`)
			end
		end
	end)
end

return FootIkController
