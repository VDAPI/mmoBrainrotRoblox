--!strict
-- Quest companions on the client (S101b, DESIGN-15 §3.5; the server drives them: CompanionService). Every figure in
-- Workspace.World.Companions gets a nameplate (npc.<id>.name; its owner also sees "companion" under it) and the
-- default R15 walk / idle animations, played locally by its speed (the figure from a HumanoidDescription has no
-- Animate script on the server). The comments of its phases are said by BarkController.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)

local CompanionController = {
	Name = "CompanionController",
	Deps = { "UIController" },
}

-- Roblox's default R15 animations (catalogue assets, the same every avatar uses).
local WALK_ANIMATION = "rbxassetid://507777826"
local IDLE_ANIMATION = "rbxassetid://507766388"
local WALKING_SPEED = 1 -- studs per second over which the walk plays

type Figure = { model: Model, scope: any, walk: AnimationTrack?, idle: AnimationTrack?, walking: boolean }

local scope = Fusion.scoped(Fusion)
local figures: { [Model]: Figure } = {}

-- The plate's language observer lives in the figure's own scope (cleaned up when the figure goes).
local function plate(figureScope: any, model: Model)
	local head = model:FindFirstChild("Head") :: BasePart?
	local npcId = model:GetAttribute("CompanionNpc")
	if not head or type(npcId) ~= "string" or model:FindFirstChild("VaelthornPlate") then
		return
	end
	local mine = model:GetAttribute("CompanionOf") == Players.LocalPlayer.UserId
	local gui = Instance.new("BillboardGui")
	gui.Name = "VaelthornPlate"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(240, if mine then 44 else 26)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	gui.Parent = model
	local name = Instance.new("TextLabel")
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(1, 0, 0, 24)
	name.Text = Text.now(`npc.{npcId}.name`)
	name.TextSize = 20
	name.FontFace = Theme.Fonts.BodyBold
	name.TextColor3 = Theme.Colors.Parchment
	name.TextStrokeTransparency = 0.35
	name.Parent = gui
	local tag: TextLabel? = nil
	if mine then
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromOffset(0, 24)
		label.Size = UDim2.new(1, 0, 0, 18)
		label.Text = Text.now("companion.tag")
		label.TextSize = 15
		label.FontFace = Theme.Fonts.BodyMedium
		label.TextColor3 = Theme.Colors.GoldBright
		label.TextStrokeTransparency = 0.4
		label.Parent = gui
		tag = label
	end
	figureScope:Observer(Text.Lang):onChange(function()
		name.Text = Text.now(`npc.{npcId}.name`)
		if tag then
			tag.Text = Text.now("companion.tag")
		end
	end)
end

local function load(animator: Animator, id: string, priority: Enum.AnimationPriority): AnimationTrack?
	local animation = Instance.new("Animation")
	animation.AnimationId = id
	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	if not ok or not track then
		return nil
	end
	track.Priority = priority
	track.Looped = true
	return track
end

local function add(model: Instance)
	if not model:IsA("Model") or figures[model] then
		return
	end
	local figureScope = scope:innerScope()
	local figure: Figure = { model = model, scope = figureScope, walking = false }
	figures[model] = figure
	plate(figureScope, model)
	local humanoid = model:FindFirstChildOfClass("Humanoid") or model:WaitForChild("Humanoid", 5)
	if figures[model] ~= figure then
		return -- removed while waiting
	end
	if humanoid and humanoid:IsA("Humanoid") then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			local created = Instance.new("Animator")
			created.Parent = humanoid
			animator = created
		end
		if animator then
			figure.walk = load(animator, WALK_ANIMATION, Enum.AnimationPriority.Movement)
			figure.idle = load(animator, IDLE_ANIMATION, Enum.AnimationPriority.Idle)
			if figure.idle then
				figure.idle:Play()
			end
		end
	end
end

local function remove(model: Instance)
	local figure = figures[model :: Model]
	if figure then
		if figure.walk then
			figure.walk:Stop()
		end
		if figure.idle then
			figure.idle:Stop()
		end
		Fusion.doCleanup(figure.scope)
		figures[model :: Model] = nil
	end
end

function CompanionController.Init(_registry) end

function CompanionController.Start()
	local world = Workspace:WaitForChild("World")
	local folder = world:WaitForChild("Companions", 120)
	if not folder then
		return
	end
	for _, child in folder:GetChildren() do
		task.spawn(add, child)
	end
	folder.ChildAdded:Connect(function(child)
		task.spawn(add, child)
	end)
	folder.ChildRemoved:Connect(remove)
	RunService.Heartbeat:Connect(function()
		for model, figure in figures do
			local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				continue
			end
			local velocity = root.AssemblyLinearVelocity
			local walking = Vector3.new(velocity.X, 0, velocity.Z).Magnitude > WALKING_SPEED
			if walking ~= figure.walking then
				figure.walking = walking
				local walk = figure.walk
				if walk then
					if walking then
						walk:Play(0.2)
					else
						walk:Stop(0.2)
					end
				end
			end
		end
	end)
end

return CompanionController
