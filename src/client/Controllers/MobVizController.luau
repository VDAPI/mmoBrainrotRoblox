--!strict
-- Admin look preview (S24, /mobviz and /lookstats): the server checks the command and sends "MobViz" to the
-- admin only; looks are built locally in a row in front of the player (no monsters on the server), each with a
-- label (id, plan, part count, real model or generator). With "anim" the previews cycle idle -> walk ->
-- attack -> hit -> death -> spawn every 1.5 s (Logic/Gait on their Gait_* joints, LookRoot anchored).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local Gait = require(ReplicatedStorage.Shared.Logic.Gait)
local MonsterLooks = require(ReplicatedStorage.Shared.Data.MonsterLooks)
local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)
local Net = require(ReplicatedStorage.Shared.Net)
local Text = require(script.Parent.Parent.UI.Text)

local MobVizController = {
	Name = "MobVizController",
	Deps = { "MonsterViewController", "NotificationController", "AnimationController" },
}

local STATES = { "idle", "walk", "attack", "hit", "death", "spawn" }
local STATE_SECONDS = 1.5
local GAP = 2.5 -- studs between two previews
local DISTANCE = 14 -- studs in front of the player
local PET_PREVIEW = 2 -- pets are shown bigger than they follow players

type Item = { id: string, look: MonsterLooks.Look, variant: string, scale: number }
type Joint = { motor: Motor6D, joint: Gait.Joint, scale: number }
type Preview = { model: Model, joints: { Joint } }

local MonsterView: any
local Notifications: any
local Animation: any
local folder: Folder? = nil
local previews: { Preview } = {}
local animate = false
local started = 0
local cycle = 0

local function items(target: string, variant: string): { Item }
	local out: { Item } = {}
	local function monster(def: Monsters.MonsterDef)
		local look = MonsterLooks.get(def.id, def.region)
		if look then
			local v = if def.elites or variant == "normal" then variant else "normal"
			table.insert(out, { id = def.id, look = look, variant = v, scale = def.size })
		end
	end
	local function boss(def: Bosses.BossDef)
		local look = MonsterLooks.get(def.id)
		if look then
			table.insert(out, { id = def.id, look = look, variant = "boss", scale = def.look.size })
		end
	end
	local function pet(def: Cosmetics.Def)
		if def.kind == "pet" and def.look then
			table.insert(
				out,
				{ id = def.id, look = def.look, variant = "pet", scale = Cosmetics.PET_SCALE * PET_PREVIEW }
			)
		end
	end
	local region = tonumber(target)
	if target == "all" or region then
		for _, def in Monsters.list do
			if not region or def.region == region then
				monster(def)
			end
		end
		if target == "all" then
			for _, def in Bosses.list do
				boss(def)
			end
		end
	elseif target == "bosses" then
		for _, def in Bosses.list do
			boss(def)
		end
	elseif target == "pets" then
		for _, def in Cosmetics.list do
			pet(def)
		end
	else
		local def = Monsters.get(target)
		local bossDef = Bosses.get(target)
		local cosmetic = Cosmetics.get(target)
		if def then
			monster(def)
		elseif bossDef then
			boss(bossDef)
		elseif cosmetic then
			pet(cosmetic)
		end
	end
	return out
end

local function clear()
	for _, preview in previews do
		preview.model:Destroy()
	end
	table.clear(previews)
	if folder then
		folder:Destroy()
		folder = nil
	end
end

local function label(model: Model, text: string, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(220, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height + 1.2, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 250
	gui.Adornee = model.PrimaryPart :: BasePart
	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.TextColor3 = Color3.fromHex("#FFE6A0")
	textLabel.TextStrokeTransparency = 0.3
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamMedium
	textLabel.Text = text
	textLabel.Parent = gui
	gui.Parent = model
end

local function collect(model: Model): { Joint }
	local joints: { Joint } = {}
	for _, item in model:GetDescendants() do
		if item:IsA("Motor6D") and string.sub(item.Name, 1, 5) == "Gait_" then
			local role = item:GetAttribute("Role")
			if type(role) == "string" then
				table.insert(joints, {
					motor = item,
					joint = {
						role = role :: any,
						side = tonumber(item:GetAttribute("Side")) or 0,
						phase = tonumber(item:GetAttribute("Phase")) or 0,
						amp = tonumber(item:GetAttribute("Amp")) or 1,
					},
					scale = tonumber(item:GetAttribute("Scale")) or 1,
				})
			end
		end
	end
	return joints
end

local function show(target: string, variant: string, anim: boolean)
	clear()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local list = items(target, variant)
	if #list == 0 then
		return
	end
	local container = Instance.new("Folder")
	container.Name = "VaelthornMobViz"
	container.Parent = Workspace
	folder = container
	local groundY = root.Position.Y - root.Size.Y / 2 - humanoid.HipHeight
	local flat = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local forward = if flat.Magnitude > 0.01 then flat.Unit else Vector3.new(0, 0, -1)
	local right = forward:Cross(Vector3.yAxis)
	local centre = Vector3.new(root.Position.X, groundY, root.Position.Z) + forward * DISTANCE
	-- First pass for widths, so the row is centred.
	local built: { { model: Model, info: any } } = {}
	local total = 0
	for _, item in list do
		local model, info = MonsterView.BuildPreview(item.id, item.look, item.variant, item.scale, CFrame.new())
		table.insert(built, { model = model, info = info })
		total += info.width + GAP
	end
	local x = -total / 2
	for i, entry in built do
		local info = entry.info
		x += info.width / 2 + GAP / 2
		local at = centre + right * x + Vector3.new(0, info.hipHeight + info.rootHalf, 0)
		entry.model:PivotTo(CFrame.lookAt(at, at - forward))
		label(
			entry.model,
			Text.now("dev.mobviz.label", {
				id = list[i].id,
				plan = list[i].look.plan,
				parts = info.parts,
				source = Text.now(if info.real then "dev.mobviz.model" else "dev.mobviz.generator"),
			}),
			info.height - info.hipHeight - info.rootHalf
		)
		entry.model.Parent = container
		table.insert(previews, { model = entry.model, joints = collect(entry.model) })
		x += info.width / 2 + GAP / 2
	end
	animate = anim
	started = os.clock()
end

local function step(dt: number)
	if not animate or #previews == 0 then
		return
	end
	local t = os.clock() - started
	local index = math.floor(t / STATE_SECONDS) % #STATES + 1
	local state = STATES[index]
	local phaseTime = t % STATE_SECONDS
	local motion: Gait.Motion = { cycle = 0, move = 0, time = os.clock(), raise = 0, strike = 0, hit = 0, dead = 0 }
	if state == "walk" then
		cycle = Gait.advance(cycle, dt, 8, 1)
		motion.move = 1
	elseif state == "attack" then
		local raise, strike = Gait.attack(phaseTime, 0.6)
		motion.raise = raise
		motion.strike = strike
	elseif state == "hit" then
		motion.hit = math.max(0, 1 - phaseTime / 0.25)
	elseif state == "death" then
		motion.dead = math.clamp(phaseTime / 0.55, 0, 1)
	elseif state == "spawn" then
		motion.dead = 1 - math.clamp(phaseTime / 0.55, 0, 1)
	end
	motion.cycle = cycle
	for _, preview in previews do
		for _, j in preview.joints do
			local p = Gait.pose(j.joint, motion)
			local k = j.scale
			j.motor.Transform = CFrame.new(p.x * k, p.y * k, p.z * k) * CFrame.Angles(p.rx, p.ry, p.rz)
		end
	end
end

local function stats()
	local s = MonsterView.Stats()
	Notifications.System(Text.now("admin.lookstats.info", {
		tracked = s.tracked,
		full = s.full,
		hidden = s.hidden,
		far = s.far,
		parts = s.parts,
		queued = s.queued,
		previews = #previews,
		animated = Animation.AnimatedCount(),
	}))
end

function MobVizController.Init(registry: any)
	MonsterView = registry.Get("MonsterViewController")
	Notifications = registry.Get("NotificationController")
	Animation = registry.Get("AnimationController")
end

function MobVizController.Start()
	Net.On("MobViz", function(action: any, payload: any)
		if action == "clear" then
			clear()
		elseif action == "stats" then
			stats()
		elseif action == "show" and type(payload) == "table" then
			show(tostring(payload.target), tostring(payload.variant or "normal"), payload.anim == true)
		end
	end)
	RunService.PreSimulation:Connect(step)
end

return MobVizController
