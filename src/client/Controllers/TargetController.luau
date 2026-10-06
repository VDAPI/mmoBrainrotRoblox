--!strict
-- Targeting and attack input (DESIGN §24, reworked in S16):
--   LMB / tap on an enemy  = select it and attack (the character walks into range, faces it, the server
--                            runs the auto-attack). Picking is forgiving: when the ray misses the model,
--                            the enemy drawn closest to the cursor within PICK_RADIUS pixels is used.
--   holding LMB            = keep fighting: when the target dies the next enemy near the cursor is picked.
--   auto target (option)   = after a kill, the nearest monster that is fighting us becomes the next target.
--   Tab (optional)         = next nearest target in front of the camera. Q (rebindable) / click on the
--                            ground = clear.
-- The hovered enemy gets a faint outline so the player sees what a click will hit. The selected model gets
-- a Highlight and the server is told with SetTarget(entityId, attack). S18: attacks start on mouse DOWN,
-- every click on an enemy resends SetTarget (the server may have dropped it), and any manual movement
-- (WASD / joystick) stops both the approach and the server auto-attack: the target stays selected but is not
-- attacked until it is clicked again or a skill is used on it, so the player can run away. For 1.5 s after
-- manual movement there is no auto retarget and no turning towards the target.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Combat = require(ReplicatedStorage.Shared.Data.Combat)
local Device = require(script.Parent.Parent.UI.Device)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Keybinds = require(script.Parent.Parent.UI.Keybinds)
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
-- Enemy under the mouse cursor (PC only), observable by the UI.
TargetController.Hover = scope:Value(nil :: Model?)

local PICK_RADIUS = 70 -- pixels around the cursor that still count as clicking an enemy
local TAB_RANGE = 60
local RETARGET_RANGE = 35 -- studs: auto target only picks monsters this close
local HOLD_PICK_RANGE = 30 -- studs from the character for "hold LMB" picks
local APPROACH_INTERVAL = 0.1
local FACE_SPEED = 14 -- turn rate toward the target while standing (higher = snappier)
local MANUAL_GRACE = 1.5 -- seconds after manual movement without auto retarget / facing

local player = Players.LocalPlayer
local highlight: Highlight
local hoverHighlight: Highlight
local approaching = false
local attacking = false -- the server is told to auto-attack the target
local movedAt = -math.huge -- os.clock() of the last manual movement
local holding = false
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

local function isMonster(model: Model): boolean
	return model:GetAttribute("MonsterId") ~= nil
end

-- Monsters always; other players only while they are open to attacks (PvP on or a red zone).
local function isHostile(model: Model): boolean
	if isMonster(model) then
		return model:GetAttribute("Returning") ~= true
	end
	return model:GetAttribute("PvpEnabled") == true or model:GetAttribute("PvpZone") == "red"
end

local function myRoot(): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function myHumanoid(): Humanoid?
	local character = player.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
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

local function radiusOf(model: Model): number
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then math.max(root.Size.X, root.Size.Z) / 2 else 1
end

local function flatOffset(from: Vector3, to: Vector3): Vector3
	return Vector3.new(to.X - from.X, 0, to.Z - from.Z)
end

local function autoTargetEnabled(): boolean
	return State.Get({ "account", "settings", "autoTarget" }) ~= false
end

-- `engage` (default: when the target is hostile) makes the character walk into range.
function TargetController.SetTarget(model: Model?, engage: boolean?)
	if model == player.Character then
		model = nil
	end
	if model and not isAlive(model) then
		model = nil
	end
	local shouldEngage = if model == nil then false elseif engage == nil then isHostile(model) else engage
	if Fusion.peek(TargetController.Target) ~= model then
		TargetController.Target:set(model)
		highlight.Adornee = model
		highlight.Enabled = model ~= nil
		if model then
			highlight.OutlineColor = if isMonster(model) then Theme.Colors.ZoneRed else Theme.Colors.GoldBright
		end
	end
	approaching = shouldEngage
	attacking = shouldEngage
	-- Always resend: the server may have dropped the target (death, distance, a previous stop).
	Net.Send("SetTarget", if model then model:GetAttribute("EntityId") else nil, shouldEngage)
end

-- Resumes attacking the selected target (a skill was used on it).
function TargetController.Resume()
	local model = Fusion.peek(TargetController.Target)
	if model and isAlive(model) and isHostile(model) and not attacking then
		TargetController.SetTarget(model, true)
	end
end

-- True while the server auto-attacks the selected target.
function TargetController.IsAttacking(): boolean
	return attacking
end

-- Stops approaching and attacking but keeps the selection (manual movement, mobile stop).
function TargetController.Stop()
	if not attacking and not approaching then
		return
	end
	local model = Fusion.peek(TargetController.Target)
	approaching = false
	attacking = false
	Net.Send("SetTarget", if model then model:GetAttribute("EntityId") else nil, false)
end

function TargetController.Clear()
	TargetController.SetTarget(nil)
end

local function candidates(includePlayers: boolean): { Model }
	local list = {}
	local monsters = Workspace:FindFirstChild("Monsters")
	if monsters then
		for _, child in monsters:GetChildren() do
			if child:IsA("Model") and child:GetAttribute("EntityId") and isAlive(child) then
				table.insert(list, child)
			end
		end
	end
	if includePlayers then
		for _, other in Players:GetPlayers() do
			local character = other.Character
			if other ~= player and character and character:GetAttribute("EntityId") then
				table.insert(list, character)
			end
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
	for _, model in candidates(includePlayers) do
		if model ~= current and (isMonster(model) or includePlayers) then
			local offset = model:GetPivot().Position - root.Position
			local distance = offset.Magnitude
			if distance <= range and distance > 0 then
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

-- Nearest monster that is currently fighting us (AggroUserId), for auto target after a kill.
local function nearestAttacker(range: number): Model?
	local root = myRoot()
	if not root then
		return nil
	end
	local best: Model? = nil
	local bestDistance = range
	for _, model in candidates(false) do
		if model:GetAttribute("AggroUserId") == player.UserId and isHostile(model) then
			local distance = (model:GetPivot().Position - root.Position).Magnitude
			if distance <= bestDistance then
				best = model
				bestDistance = distance
			end
		end
	end
	return best
end

-- Enemy at a viewport position (GetMouseLocation coordinates, top bar included): the ray hit first, then
-- the model drawn closest to the point.
local function enemyAt(screenPosition: Vector2, hostileOnly: boolean): Model?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local ray = camera:ViewportPointToRay(screenPosition.X, screenPosition.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	if player.Character then
		table.insert(exclude, player.Character)
	end
	for _, name in { "Vaelthorn_Effects", "Vaelthorn_CombatFx", "Vaelthorn_TownDetail", "Vaelthorn_ClientDecor" } do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			table.insert(exclude, folder)
		end
	end
	params.FilterDescendantsInstances = exclude
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	local model = entityModel(hit and hit.Instance)
	if model and isAlive(model) and (not hostileOnly or isHostile(model)) then
		return model
	end

	-- Forgiving pick: placeholder models are thin, so accept a click near the drawn model. Bigger (and
	-- closer) models get a bigger click area: half their on-screen height on top of PICK_RADIUS.
	local best: Model? = nil
	local bestDistance = math.huge
	for _, candidate in candidates(true) do
		if not hostileOnly or isHostile(candidate) then
			local cframe, size = candidate:GetBoundingBox()
			local centre = camera:WorldToViewportPoint(cframe.Position)
			if centre.Z > 0 and centre.Z < 200 then
				local top = camera:WorldToViewportPoint(cframe.Position + Vector3.new(0, size.Y / 2, 0))
				local reach = PICK_RADIUS + math.min(math.abs(centre.Y - top.Y), 150)
				local distance = (Vector2.new(centre.X, centre.Y) - screenPosition).Magnitude
				if distance <= reach and distance - reach < bestDistance then
					best = candidate
					bestDistance = distance - reach
				end
			end
		end
	end
	return best
end

-- Mobile attack button: a second tap while attacking stops; otherwise attack the current target or pick
-- the nearest monster (fighting us first).
function TargetController.AttackNearest()
	local current = Fusion.peek(TargetController.Target)
	if attacking and current then
		TargetController.Stop()
		return
	end
	if current and isAlive(current) and isHostile(current) then
		TargetController.SetTarget(current, true)
		return
	end
	local found = nearestAttacker(RETARGET_RANGE) or TargetController.FindNearest(TAB_RANGE, false, false)
	if found then
		TargetController.SetTarget(found, true)
	else
		Toast.push(Text.now("combat.noTarget"), "info", 2)
	end
end

-- Enemies win over friendly players under the cursor; a click on empty ground clears the target.
local function click(screenPosition: Vector2)
	local model = enemyAt(screenPosition, true) or enemyAt(screenPosition, false)
	if model then
		TargetController.SetTarget(model)
	elseif Fusion.peek(TargetController.Target) then
		TargetController.Clear()
	end
end

-- True when a visible window or button is under the screen point (GetMouseLocation coordinates).
local function overInterface(screenPosition: Vector2): boolean
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return false
	end
	local point = screenPosition - GuiService:GetGuiInset()
	for _, object in playerGui:GetGuiObjectsAtPosition(point.X, point.Y) do
		if not object.Visible then
			continue
		end
		if object:IsA("GuiButton") or object:IsA("TextBox") or object:IsA("ScrollingFrame") then
			return true
		end
		if object.Active and object.BackgroundTransparency < 0.95 then
			return true
		end
	end
	return false
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

-- Next target after the current one died: a monster fighting us, or (holding LMB) the one near the cursor.
local function retarget()
	if holding and not Fusion.peek(Device.Touch) then
		local mouse = UserInputService:GetMouseLocation()
		local found = enemyAt(mouse, true)
		local root = myRoot()
		if found and root and (found:GetPivot().Position - root.Position).Magnitude <= HOLD_PICK_RANGE + 20 then
			TargetController.SetTarget(found, true)
			return
		end
		found = TargetController.FindNearest(HOLD_PICK_RANGE, false, true)
		if found then
			TargetController.SetTarget(found, true)
			return
		end
	end
	if autoTargetEnabled() and attacking and os.clock() - movedAt > MANUAL_GRACE then
		local found = nearestAttacker(RETARGET_RANGE)
		if found then
			TargetController.SetTarget(found, true)
			return
		end
	end
	TargetController.Clear()
end

local function approachStep()
	local target = Fusion.peek(TargetController.Target)
	if not target then
		return
	end
	if not isAlive(target) then
		retarget()
		return
	end
	if not approaching then
		return
	end
	local root = myRoot()
	local humanoid = myHumanoid()
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local targetPosition = target:GetPivot().Position
	local offset = flatOffset(root.Position, targetPosition)
	local reach = attackRange() + radiusOf(target) - 1
	if offset.Magnitude > reach then
		-- Walk to a point just inside the reach, so a moving target is followed every step.
		humanoid:MoveTo(targetPosition - offset.Unit * math.max(1, reach - 1.5))
	elseif humanoid.MoveDirection.Magnitude > 0.1 then
		humanoid:MoveTo(root.Position)
	end
end

-- While standing next to a hostile target, turn the character to face it (attacks read much better).
local function faceStep(dt: number)
	local target = Fusion.peek(TargetController.Target)
	local root = myRoot()
	local humanoid = myHumanoid()
	if not target or not root or not humanoid or humanoid.Health <= 0 or not isAlive(target) then
		return
	end
	if not isHostile(target) or humanoid.MoveDirection.Magnitude > 0.1 or humanoid.Sit then
		return
	end
	if not attacking or os.clock() - movedAt < MANUAL_GRACE then
		return
	end
	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		return -- shift lock / first person: the camera already decides where we look
	end
	local offset = flatOffset(root.Position, target:GetPivot().Position)
	if offset.Magnitude < 0.5 or offset.Magnitude > attackRange() + radiusOf(target) + Combat.rangeTolerance then
		return
	end
	local goal = CFrame.lookAt(root.Position, root.Position + offset)
	local alpha = math.clamp(dt * FACE_SPEED, 0, 1)
	root.CFrame = root.CFrame:Lerp(goal, alpha)
end

local function hoverStep()
	if Fusion.peek(Device.Touch) or UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		if Fusion.peek(TargetController.Hover) then
			TargetController.Hover:set(nil)
			hoverHighlight.Enabled = false
		end
		return
	end
	local model = enemyAt(UserInputService:GetMouseLocation(), true)
	if model == Fusion.peek(TargetController.Target) then
		model = nil
	end
	if model ~= Fusion.peek(TargetController.Hover) then
		TargetController.Hover:set(model)
		hoverHighlight.Adornee = model
		hoverHighlight.Enabled = model ~= nil
	end
end

function TargetController.Init(registry)
	local playerGui = player:WaitForChild("PlayerGui")
	highlight = Instance.new("Highlight")
	highlight.Name = "Vaelthorn_TargetHighlight"
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Enabled = false
	highlight.Parent = playerGui

	hoverHighlight = Instance.new("Highlight")
	hoverHighlight.Name = "Vaelthorn_HoverHighlight"
	hoverHighlight.FillTransparency = 0.85
	hoverHighlight.FillColor = Color3.new(1, 1, 1)
	hoverHighlight.OutlineColor = Theme.Colors.GoldBright
	hoverHighlight.OutlineTransparency = 0.45
	hoverHighlight.DepthMode = Enum.HighlightDepthMode.Occluded
	hoverHighlight.Enabled = false
	hoverHighlight.Parent = playerGui

	registry.Get("WindowManager").SetEscapeHandler(function(): boolean
		if Fusion.peek(TargetController.Target) then
			TargetController.Clear()
			return true
		end
		return false
	end)
end

function TargetController.Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			-- `processed` is also set by full-screen HUD layers; only a real window or button under the
			-- cursor blocks the attack.
			local mouse = UserInputService:GetMouseLocation()
			if processed and overInterface(mouse) then
				return
			end
			holding = true
			if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
				-- Shift lock: the crosshair is the screen centre, attack what it points at.
				local camera = Workspace.CurrentCamera
				if camera then
					click(camera.ViewportSize / 2)
				end
			else
				click(mouse)
			end
			return
		end
		if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if Keybinds.is(input.KeyCode, "target_next") then
			local found = TargetController.FindNearest(TAB_RANGE, true, true)
			if found then
				TargetController.SetTarget(found)
			end
		elseif Keybinds.is(input.KeyCode, "target_clear") then
			TargetController.Clear()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			holding = false
		end
	end)
	UserInputService.TouchTap:Connect(function(positions: { Vector2 }, processed: boolean)
		if not processed and positions[1] then
			-- Touch positions exclude the top bar inset; rays and WorldToViewportPoint include it.
			local inset = GuiService:GetGuiInset()
			click(positions[1] + inset)
		end
	end)

	Net.On("AttackRejected", function(reason: any)
		if type(reason) == "string" then
			Toast.push(Text.now(reason), "info", 2)
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

	local elapsed = 0
	local hoverElapsed = 0
	RunService.RenderStepped:Connect(function(dt)
		-- Manual movement takes over: stop walking to the target and stop the server auto-attack.
		if moveInput().Magnitude > 0.1 then
			movedAt = os.clock()
			if approaching or attacking then
				local humanoid = myHumanoid()
				local root = myRoot()
				if humanoid and root and approaching then
					humanoid:MoveTo(root.Position)
				end
				TargetController.Stop()
			end
		end
		local ok = pcall(faceStep, dt)
		if not ok then
			approaching = false
		end
		hoverElapsed += dt
		if hoverElapsed >= 0.05 then
			hoverElapsed = 0
			pcall(hoverStep)
		end
		elapsed += dt
		if elapsed >= APPROACH_INTERVAL then
			elapsed = 0
			if not pcall(approachStep) then
				approaching = false
			end
		end
	end)
end

return TargetController
