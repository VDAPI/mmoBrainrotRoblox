--!strict
-- Target selection (DESIGN §24): click/tap a monster or player, Tab = next nearest target in front of the
-- camera, Esc = clear. The selected model gets a Highlight; the server is told with SetTarget and runs the
-- auto-attack. While the target is out of range the character walks to it (Humanoid:MoveTo) until the
-- player moves on their own.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Combat = require(ReplicatedStorage.Shared.Data.Combat)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Components.Toast)

local TargetController = {
	Name = "TargetController",
	Deps = { "WindowManager" },
}

local scope = Fusion.scoped(Fusion)
-- Currently selected model (monster or player character), observable by the UI.
TargetController.Target = scope:Value(nil :: Model?)

local CLICK_MAX_MOVE = 8 -- pixels; more means the player was dragging the camera
local TAB_RANGE = 60
local APPROACH_INTERVAL = 0.25

local player = Players.LocalPlayer
local highlight: Highlight
local approaching = false
local controls: any = nil

local function entityModel(instance: Instance?): Model?
	local node = instance
	while node and node ~= Workspace do
		if node:IsA("Model") and node:GetAttribute("EntityId") ~= nil then
			return node
		end
		node = node.Parent
	end
	return nil
end

local function isAlive(model: Model): boolean
	return model.Parent ~= nil and model:GetAttribute("Dead") ~= true
end

local function myRoot(): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function attackRange(): number
	local derived = State.Get({ "derived" })
	local classId = State.Get({ "character", "class" })
	local class = Classes.get(classId or "")
	local ranged = if derived and derived.weapon
		then derived.weapon.ranged
		elseif class then class.basicAttack.ranged
		else false
	return if ranged then Combat.rangedRange else Combat.meleeRange
end

function TargetController.SetTarget(model: Model?)
	if model == player.Character then
		model = nil
	end
	if model and not isAlive(model) then
		model = nil
	end
	if Fusion.peek(TargetController.Target) == model then
		return
	end
	TargetController.Target:set(model)
	highlight.Adornee = model
	highlight.Enabled = model ~= nil
	if model then
		local isMonster = model:GetAttribute("MonsterId") ~= nil
		highlight.OutlineColor = if isMonster then Theme.Colors.ZoneRed else Theme.Colors.GoldBright
		approaching = true
	else
		approaching = false
	end
	Net.Send("SetTarget", if model then model:GetAttribute("EntityId") else nil)
end

function TargetController.Clear()
	TargetController.SetTarget(nil)
end

local function candidates(): { Model }
	local list = {}
	local monsters = Workspace:FindFirstChild("Monsters")
	if monsters then
		for _, child in monsters:GetChildren() do
			if child:IsA("Model") and child:GetAttribute("EntityId") and isAlive(child) then
				table.insert(list, child)
			end
		end
	end
	for _, other in Players:GetPlayers() do
		local character = other.Character
		if other ~= player and character and character:GetAttribute("EntityId") then
			table.insert(list, character)
		end
	end
	return list
end

-- Nearest living monster (players only when `includePlayers`) within `range`, preferring what the camera faces.
function TargetController.FindNearest(range: number, includePlayers: boolean, inFront: boolean): Model?
	local root = myRoot()
	local camera = Workspace.CurrentCamera
	if not root or not camera then
		return nil
	end
	local current = Fusion.peek(TargetController.Target)
	local best: Model? = nil
	local bestScore = math.huge
	for _, model in candidates() do
		local isMonster = model:GetAttribute("MonsterId") ~= nil
		if (isMonster or includePlayers) and model ~= current then
			local position = model:GetPivot().Position
			local offset = position - root.Position
			local distance = offset.Magnitude
			if distance <= range then
				local facing = camera.CFrame.LookVector:Dot(offset.Unit)
				if not inFront or facing > 0.2 then
					local score = distance * (2 - facing)
					if score < bestScore then
						best = model
						bestScore = score
					end
				end
			end
		end
	end
	return best
end

-- Mobile attack button: keep the current target or pick the nearest monster.
function TargetController.AttackNearest()
	local current = Fusion.peek(TargetController.Target)
	if current and isAlive(current) then
		approaching = true
		return
	end
	local found = TargetController.FindNearest(TAB_RANGE, false, false)
	if found then
		TargetController.SetTarget(found)
	else
		Toast.push(Text.now("combat.noTarget"), "info", 2)
	end
end

local function pick(screenPosition: Vector2)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local ray = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	if player.Character then
		table.insert(exclude, player.Character)
	end
	local effects = Workspace:FindFirstChild("Vaelthorn_Effects")
	if effects then
		table.insert(exclude, effects)
	end
	params.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	local model = entityModel(hit and hit.Instance)
	if model then
		TargetController.SetTarget(model)
	end
end

local function moveInput(): Vector3
	if controls == nil then
		local ok, module = pcall(function()
			local playerModule = player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 5)
			return (require :: any)(playerModule):GetControls()
		end)
		controls = if ok and module then module else false
	end
	if controls then
		local ok, vector = pcall(function()
			return controls:GetMoveVector()
		end)
		if ok and typeof(vector) == "Vector3" then
			return vector
		end
	end
	return Vector3.zero
end

local function approachStep()
	local target = Fusion.peek(TargetController.Target)
	if not target then
		return
	end
	if not isAlive(target) then
		TargetController.Clear()
		return
	end
	if not approaching then
		return
	end
	if moveInput().Magnitude > 0.1 then
		approaching = false -- the player took over movement
		return
	end
	local root = myRoot()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local targetPosition = target:GetPivot().Position
	local flatOffset = Vector3.new(targetPosition.X - root.Position.X, 0, targetPosition.Z - root.Position.Z)
	local stopAt = attackRange() - 1.5
	if flatOffset.Magnitude > stopAt then
		humanoid:MoveTo(targetPosition - flatOffset.Unit * math.max(1, stopAt - 1))
	else
		humanoid:MoveTo(root.Position)
		approaching = false
	end
end

function TargetController.Init(registry)
	highlight = Instance.new("Highlight")
	highlight.Name = "Vaelthorn_TargetHighlight"
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Enabled = false
	highlight.Parent = player:WaitForChild("PlayerGui")

	registry.Get("WindowManager").SetEscapeHandler(function(): boolean
		if Fusion.peek(TargetController.Target) then
			TargetController.Clear()
			return true
		end
		return false
	end)
end

function TargetController.Start()
	local pressedAt: Vector2? = nil
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			pressedAt = Vector2.new(input.Position.X, input.Position.Y)
		elseif input.KeyCode == Enum.KeyCode.Tab then
			local found = TargetController.FindNearest(TAB_RANGE, true, true)
			if found then
				TargetController.SetTarget(found)
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input, processed)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 or processed then
			return
		end
		local start = pressedAt
		pressedAt = nil
		local position = Vector2.new(input.Position.X, input.Position.Y)
		if start and (position - start).Magnitude <= CLICK_MAX_MOVE then
			pick(position)
		end
	end)
	UserInputService.TouchTap:Connect(function(positions: { Vector2 }, processed: boolean)
		if not processed and positions[1] then
			pick(positions[1])
		end
	end)

	-- Leaving the world or dying clears the target.
	State.Changed:Connect(function()
		if State.Get({ "session", "phase" }) ~= "playing" or State.Get({ "death" }) ~= nil then
			if Fusion.peek(TargetController.Target) then
				TargetController.Clear()
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(APPROACH_INTERVAL)
			local ok = pcall(approachStep)
			if not ok then
				approaching = false
			end
		end
	end)
end

return TargetController
