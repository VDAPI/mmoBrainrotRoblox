--!strict
-- Casting from the hotbar (DESIGN §14.1, S05):
--   enemy skills use the current target (or pick the nearest enemy in range),
--   ally skills target the selected ally or yourself,
--   area skills on a point: PC aims at the cursor — hold the key to see the area, release to cast
--   (or cast on key press with "quick cast"); touch aims at the target or in front of the character.
-- Also owns the hotbar slots for drag & drop ("skill:<id>" from the tree, "bar:<n>" on the bar).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Device = require(script.Parent.Parent.UI.Device)
local DragDrop = require(script.Parent.Parent.UI.DragDrop)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Keybinds = require(script.Parent.Parent.UI.Keybinds)
local Net = require(ReplicatedStorage.Shared.Net)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local Skills = require(ReplicatedStorage.Shared.Logic.Skills)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Components.Toast)

local SkillController = {
	Name = "SkillController",
	Deps = { "TargetController", "UIController" },
}

local TargetController: any
local player = Players.LocalPlayer

-- Hotbar slot of a key press (rebindable, S17: actions skill_1 .. skill_10).
local function slotFor(keyCode: Enum.KeyCode): number?
	local action = Keybinds.actionFor(keyCode)
	local slot = if action then string.match(action, "^skill_(%d+)$") else nil
	return if slot then tonumber(slot) else nil
end

-- Silent errors (spamming a key on cooldown should not flood toasts).
local QUIET: { [string]: boolean } = { ["cast.error.cooldown"] = true }

local preview: Part? = nil
local previewSkill: string? = nil
local pending = false

local function parse(slotId: string): (string, string)
	local kind, rest = string.match(slotId, "^(%a+):(.+)$")
	return kind or "", rest or ""
end

function SkillController.SkillInSlot(slot: number): string?
	return State.Get({ "character", "hotbar", tostring(slot) })
end

local function myRoot(): BasePart?
	local character = player.Character
	return if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

-- Ground point under the mouse (ignores characters, monsters and effects).
local function mouseGround(): Vector3?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local world = Workspace:FindFirstChild("World")
	params.FilterDescendantsInstances = if world then { world, Workspace.Terrain } else { Workspace.Terrain }
	local hit = Workspace:Raycast(ray.Origin, ray.Direction * 600, params)
	return if hit then hit.Position else nil
end

local function targetModel(): Model?
	local model = Fusion.peek(TargetController.Target)
	return if model and model.Parent then model else nil
end

-- Distance to the current target for range display (math.huge without a target).
function SkillController.TargetDistance(): number
	local root = myRoot()
	local model = targetModel()
	if not root or not model then
		return math.huge
	end
	return (model:GetPivot().Position - root.Position).Magnitude
end

local function aimPoint(skill: SkillData.SkillDef): Vector3?
	local root = myRoot()
	if not root then
		return nil
	end
	if not Fusion.peek(Device.Touch) then
		local point = mouseGround()
		if point then
			return point
		end
	end
	local model = targetModel()
	if model and model:GetAttribute("MonsterId") then
		return model:GetPivot().Position
	end
	local forward = math.min(skill.range or 10, 12)
	if skill.type == "blink" then
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local move = if humanoid then humanoid.MoveDirection else Vector3.zero
		local direction = if move.Magnitude > 0.1 then move.Unit else root.CFrame.LookVector
		return root.Position + direction * (skill.length or 15)
	end
	return root.Position + root.CFrame.LookVector * forward
end

local function report(err: string?)
	if err and not QUIET[err] then
		Sounds.play("error")
		Toast.push(Text.now(err), "error", 2)
	end
end

function SkillController.Cast(skillId: string, aimOverride: Vector3?)
	local skill = SkillData.get(skillId)
	if not skill or pending then
		return
	end
	local targetId: string? = nil
	local aim: Vector3? = aimOverride
	if skill.target == "enemy" then
		local model = targetModel()
		local isEnemy = model ~= nil and model:GetAttribute("Dead") ~= true
		if not isEnemy then
			local found = TargetController.FindNearest((skill.range or 10) + 4, false, false)
			if found then
				TargetController.SetTarget(found)
				model = found
			else
				report("cast.error.noTarget")
				return
			end
		end
		targetId = if model then model:GetAttribute("EntityId") :: string? else nil
	elseif skill.target == "ally" or skill.target == "deadAlly" then
		local model = targetModel()
		if model and model:GetAttribute("CharName") ~= nil then
			targetId = model:GetAttribute("EntityId") :: string?
		end
	elseif skill.target == "point" and aim == nil then
		aim = aimPoint(skill)
	end
	pending = true
	task.spawn(function()
		local ok, err = Net.Invoke("CastSkill", skillId, targetId, aim)
		pending = false
		if not ok then
			report(err)
		elseif skill.target == "enemy" then
			-- A skill on the target resumes the auto-attack stopped by manual movement (S18).
			TargetController.Resume()
		end
	end)
end

function SkillController.CastSlot(slot: number)
	local skillId = SkillController.SkillInSlot(slot)
	if skillId then
		SkillController.Cast(skillId, nil)
	end
end

-- Area preview while a point skill's key is held (PC).
local function showPreview(skill: SkillData.SkillDef)
	if not preview then
		local part = Instance.new("Part")
		part.Name = "Vaelthorn_SkillPreview"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Shape = Enum.PartType.Cylinder
		part.Material = Enum.Material.Neon
		part.Transparency = 0.7
		part.Parent = Workspace
		preview = part
	end
	local radius = skill.radius or 6
	local part = preview :: Part
	part.Color = Color3.fromHex((Classes.get(skill.class) :: any).color)
	part.Size = Vector3.new(0.15, radius * 2, radius * 2)
	previewSkill = skill.id
end

local function hidePreview()
	previewSkill = nil
	if preview then
		preview:Destroy()
		preview = nil
	end
end

local function quickCast(): boolean
	return State.Get({ "account", "settings", "quickCast" }) == true
end

local function onKeyDown(slot: number)
	local skillId = SkillController.SkillInSlot(slot)
	local skill = skillId and SkillData.get(skillId)
	if not skill then
		return
	end
	if skill.target == "point" and skill.type ~= "blink" and not quickCast() and not Fusion.peek(Device.Touch) then
		showPreview(skill)
		return
	end
	SkillController.Cast(skill.id, nil)
end

local function onKeyUp(slot: number)
	local skillId = SkillController.SkillInSlot(slot)
	if skillId and skillId == previewSkill then
		local skill = SkillData.get(skillId)
		local point = if preview then preview.Position else nil
		hidePreview()
		if skill then
			SkillController.Cast(skillId, point)
		end
	end
end

-- Drag & drop: skills from the tree onto the bar, between bar slots; right-click clears a slot.
local function setSlot(slot: number, skillId: string?)
	task.spawn(function()
		local ok, err = Net.Invoke("SetHotbar", slot, skillId)
		if not ok then
			report(err)
		end
	end)
end

function SkillController.ClearSlot(slot: number)
	setSlot(slot, nil)
end

local function onDrop(from: string, to: string)
	local fromKind, fromRest = parse(from)
	local toKind, toRest = parse(to)
	if toKind ~= "bar" then
		return
	end
	local toSlot = tonumber(toRest) :: number
	if fromKind == "skill" then
		setSlot(toSlot, fromRest)
	elseif fromKind == "bar" then
		local fromSlot = tonumber(fromRest) :: number
		local moving = SkillController.SkillInSlot(fromSlot)
		local swapped = SkillController.SkillInSlot(toSlot)
		if moving then
			setSlot(toSlot, moving)
			setSlot(fromSlot, swapped)
		end
	end
end

local function learned(skillId: string): boolean
	local level = State.Get({ "character", "skills", skillId })
	local skill = SkillData.get(skillId)
	return type(level) == "number" and level > 0 and skill ~= nil and skill.type ~= "passive"
end

function SkillController.Init(registry)
	TargetController = registry.Get("TargetController")
	local UIController = registry.Get("UIController")
	DragDrop.AddHandlers({
		owns = function(slotId: string): boolean
			local kind = parse(slotId)
			return kind == "skill" or kind == "bar"
		end,
		drop = onDrop,
		activate = function(slotId: string)
			local kind, rest = parse(slotId)
			if kind == "bar" then
				SkillController.CastSlot(tonumber(rest) :: number)
			elseif kind == "skill" and learned(rest) then
				SkillController.Cast(rest, nil)
			end
		end,
		hasItem = function(slotId: string): boolean
			local kind, rest = parse(slotId)
			if kind == "bar" then
				return SkillController.SkillInSlot(tonumber(rest) :: number) ~= nil
			end
			return kind == "skill" and learned(rest)
		end,
	})
	UIController.AddDragVisual(function(slotId: string): (string?, string?)
		local kind, rest = parse(slotId)
		local skillId = if kind == "bar"
			then SkillController.SkillInSlot(tonumber(rest) :: number)
			elseif kind == "skill" then rest
			else nil
		local skill = skillId and SkillData.get(skillId)
		if skill then
			local class = Classes.get(skill.class)
			return skill.glyph, if class then class.color else nil
		end
		return nil, nil
	end)
end

function SkillController.Start()
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or State.Get({ "session", "phase" }) ~= "playing" then
			return
		end
		local slot = slotFor(input.KeyCode)
		if slot then
			onKeyDown(slot)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		local slot = slotFor(input.KeyCode)
		if slot then
			onKeyUp(slot)
		end
	end)
	-- Keep the preview under the cursor.
	game:GetService("RunService").RenderStepped:Connect(function()
		local part = preview
		if part and previewSkill then
			local skill = SkillData.get(previewSkill)
			local root = myRoot()
			local point = mouseGround()
			if skill and root and point then
				local offset = point - root.Position
				local range = skill.range or 30
				if Vector3.new(offset.X, 0, offset.Z).Magnitude > range then
					local flat = Vector3.new(offset.X, 0, offset.Z).Unit * range
					point = Vector3.new(root.Position.X + flat.X, point.Y, root.Position.Z + flat.Z)
				end
				part.CFrame = CFrame.new(point + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
			end
		end
	end)
end

-- For the UI: can the current level / resources / range allow this skill now?
-- Element of the equipped weapon (mage weapons, S18).
function SkillController.WeaponElement(): string?
	local weapon = State.Get({ "derived", "weapon" })
	return if type(weapon) == "table" then weapon.element else nil
end

-- (enough resource, in range, weapon element fits)
function SkillController.Usable(skillId: string): (boolean, boolean, boolean)
	local skill = SkillData.get(skillId)
	if not skill then
		return false, false, true
	end
	local level = State.Get({ "character", "skills", skillId }) or 0
	local cost = Skills.scaled(skill, skill.cost, math.max(1, level))
	local current = if skill.resource then State.Get({ "character", skill.resource }) or 0 else math.huge
	local enoughResource = current >= cost
	local inRange = skill.target ~= "enemy" or SkillController.TargetDistance() <= (skill.range or 10) + 2
	return enoughResource, inRange, Skills.elementAllowed(skill, SkillController.WeaponElement())
end

-- Theme colour of a skill's class (for icons).
function SkillController.Color(skillId: string): Color3
	local skill = SkillData.get(skillId)
	local class = skill and Classes.get(skill.class)
	return if class then Color3.fromHex(class.color) else Theme.Colors.Gold
end

return SkillController
