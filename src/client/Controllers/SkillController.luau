--!strict
-- Casting from the hotbar (DESIGN §14.1, S05):
--   enemy skills use the current target (or pick the nearest enemy in range),
--   ally skills target the selected ally or yourself,
--   area skills on a point: PC aims at the cursor — hold the key to see the area, release to cast
--   (or cast on key press with "quick cast"); touch aims at the target or in front of the character.
-- S28: the held-key preview shows the real shape (circle at the cursor, circle around you, cone, line) and cones /
--   lines turn towards the cursor; on touch, dragging a skill button aims like a MOBA (release casts, back on the
--   button cancels); a skill pressed during the global cooldown or the end of a cooldown waits in a one-skill queue
--   (Config.Skills.queueWindow) and fires as soon as it can.
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
local Config = require(ReplicatedStorage.Shared.Config)

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

local previewSkill: string? = nil
local previewPoint: Vector3? = nil
local pending = false
-- One queued cast (S28): fires when the cooldown / global cooldown ends.
local queued: { skillId: string, aim: Vector3?, token: number }? = nil
local queueToken = 0

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

-- Seconds until a skill can be cast again (cooldown or the global cooldown), from the replicated state.
local function waitFor(skillId: string): number
	local now = Workspace:GetServerTimeNow()
	local gcd = State.Get({ "skills", "gcd" })
	local cd = State.Get({ "skills", "cd", skillId })
	local ready = math.max(if type(gcd) == "number" then gcd else 0, if type(cd) == "number" then cd else 0)
	return ready - now
end

function SkillController.Cast(skillId: string, aimOverride: Vector3?)
	local skill = SkillData.get(skillId)
	if not skill then
		return
	end
	-- S28 queue: pressed shortly before the skill is ready (or while the last cast is on its way): fire it then.
	local remaining = waitFor(skillId)
	if pending or remaining > 0 then
		if remaining <= Config.Skills.queueWindow then
			queueToken += 1
			local token = queueToken
			queued = { skillId = skillId, aim = aimOverride, token = token }
			task.delay(math.max(0.03, remaining + 0.03), function()
				local q = queued
				if q and q.token == token then
					queued = nil
					if pending then
						task.wait(0.1)
					end
					SkillController.Cast(q.skillId, q.aim)
				end
			end)
		end
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

-- Area preview while a skill is aimed (S28): held key on PC, dragged button on touch.
local previewFolder: Folder? = nil
local previewParts: { BasePart } = {}

-- Skills that can be aimed (and show a preview).
local AIMABLE: { [string]: boolean } = { cone = true, line = true, circleSelf = true, trap = true }
local function aimable(skill: SkillData.SkillDef): boolean
	local kind: string = skill.type
	return (skill.target == "point" and kind ~= "blink") or AIMABLE[kind] == true
end

local function previewPart(i: number, shape: Enum.PartType): BasePart
	local folder = previewFolder
	if not folder or not folder.Parent then
		local created = Instance.new("Folder")
		created.Name = "Vaelthorn_SkillPreview"
		created.Parent = Workspace
		previewFolder = created
		folder = created
		table.clear(previewParts)
	end
	local part = previewParts[i]
	if not part or not part.Parent then
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Transparency = 0.55
		p.Parent = folder
		previewParts[i] = p
		part = p
	end
	local p = part :: Part
	p.Shape = shape
	p.Transparency = 0.55
	return p
end

local function hidePreview()
	previewSkill = nil
	previewPoint = nil
	local folder = previewFolder
	if folder then
		folder:Destroy()
		previewFolder = nil
	end
	table.clear(previewParts)
end

-- Draws the preview of `skill` aimed at `point` (world) from the character.
local function drawPreview(skill: SkillData.SkillDef, point: Vector3?)
	local root = myRoot()
	if not root then
		return
	end
	local level = State.Get({ "character", "skills", skill.id }) or 1
	local def = Skills.effective(skill, level)
	local color = Color3.fromHex((Classes.get(skill.class) :: any).color)
	local feet = root.Position - Vector3.new(0, 2.8, 0)
	local target = point or (root.Position + root.CFrame.LookVector * 10)
	local flat = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
	local dir = if flat.Magnitude > 0.1
		then flat.Unit
		else Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local used = 0
	local function disc(at: Vector3, radius: number)
		used += 1
		local p = previewPart(used, Enum.PartType.Cylinder)
		p.Color = color
		p.Size = Vector3.new(0.12, radius * 2, radius * 2)
		p.CFrame = CFrame.new(at + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
	end
	local function bar(a: Vector3, b: Vector3, width: number)
		used += 1
		local p = previewPart(used, Enum.PartType.Block)
		p.Color = color
		p.Size = Vector3.new(width, 0.12, math.max(0.2, (b - a).Magnitude))
		p.CFrame = CFrame.lookAt((a + b) / 2 + Vector3.new(0, 0.12, 0), b + Vector3.new(0, 0.12, 0))
	end
	if skill.type == "cone" then
		local radius = def.radius or 10
		local angle = math.rad(def.angle or 90)
		local frame = CFrame.lookAt(feet, feet + dir)
		local steps = 8
		local prev = feet
		for k = 0, steps do
			local yaw = -angle / 2 + angle * k / steps
			local edge = (frame * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -radius)).Position
			bar(prev, edge, 0.3)
			prev = edge
		end
		bar(prev, feet, 0.3)
		previewPoint = feet + dir * radius
	elseif skill.type == "line" then
		local length = def.length or 20
		local width = def.width or 4
		local frame = CFrame.lookAt(feet, feet + dir)
		used += 1
		local p = previewPart(used, Enum.PartType.Block)
		p.Color = color
		p.Size = Vector3.new(width, 0.12, length)
		p.CFrame = frame * CFrame.new(0, 0.12, -length / 2)
		previewPoint = feet + dir * length
	elseif skill.type == "circleSelf" then
		disc(feet, def.radius or 8)
		previewPoint = nil
	else
		-- point skills: the circle at the aimed point, kept within range
		local range = def.range or 30
		local offset = Vector3.new(target.X - root.Position.X, 0, target.Z - root.Position.Z)
		local at = target
		if offset.Magnitude > range then
			at = Vector3.new(root.Position.X, target.Y, root.Position.Z) + offset.Unit * range
		end
		disc(Vector3.new(at.X, if point then point.Y else feet.Y, at.Z), def.radius or 6)
		previewPoint = at
	end
	for k = used + 1, #previewParts do
		local extra = previewParts[k]
		if extra then
			extra.Transparency = 1
		end
	end
end

local function showPreview(skill: SkillData.SkillDef)
	previewSkill = skill.id
	drawPreview(skill, mouseGround())
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
	if aimable(skill) and not quickCast() and not Fusion.peek(Device.Touch) then
		showPreview(skill)
		return
	end
	-- Quick cast: cones and lines still turn towards the cursor.
	local aim = if (skill.type == "cone" or skill.type == "line") and not Fusion.peek(Device.Touch)
		then mouseGround()
		else nil
	SkillController.Cast(skill.id, aim)
end

local function onKeyUp(slot: number)
	local skillId = SkillController.SkillInSlot(slot)
	if skillId and skillId == previewSkill then
		local point = previewPoint
		hidePreview()
		SkillController.Cast(skillId, point)
	end
end

-- Touch aiming (S28): the dragged skill button aims; `drag` is the finger offset from the button in pixels.
local AIM_DRAG = 26 -- pixels before a drag starts aiming
local AIM_FULL = 150 -- pixels for the full range

function SkillController.AimStart(slot: number): boolean
	local skillId = SkillController.SkillInSlot(slot)
	local skill = skillId and SkillData.get(skillId)
	return skill ~= nil and aimable(skill)
end

function SkillController.AimMove(slot: number, drag: Vector2): boolean
	local skillId = SkillController.SkillInSlot(slot)
	local skill = skillId and SkillData.get(skillId)
	local root = myRoot()
	local camera = Workspace.CurrentCamera
	if not skill or not root or not camera or drag.Magnitude < AIM_DRAG then
		if previewSkill then
			hidePreview()
		end
		return false
	end
	local forward = Vector3.new(camera.CFrame.LookVector.X, 0, camera.CFrame.LookVector.Z)
	local right = Vector3.new(camera.CFrame.RightVector.X, 0, camera.CFrame.RightVector.Z)
	if forward.Magnitude < 0.01 then
		return false
	end
	local dir = (right.Unit * drag.X - forward.Unit * drag.Y)
	if dir.Magnitude < 0.01 then
		return false
	end
	local level = State.Get({ "character", "skills", skill.id }) or 1
	local def = Skills.effective(skill, level)
	local reach = def.range or def.length or def.radius or 10
	local distance = math.clamp(drag.Magnitude / AIM_FULL, 0.15, 1) * reach
	previewSkill = skill.id
	drawPreview(skill, root.Position + dir.Unit * distance)
	return true
end

-- Ends a touch aim: `cast` false = cancelled (the finger came back to the button).
function SkillController.AimEnd(slot: number, cast: boolean)
	local skillId = SkillController.SkillInSlot(slot)
	local point = previewPoint
	local was = previewSkill
	hidePreview()
	if cast and skillId and was == skillId then
		SkillController.Cast(skillId, point)
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
	-- Keep the PC preview under the cursor (touch previews follow the finger, AimMove).
	game:GetService("RunService").RenderStepped:Connect(function()
		if previewSkill and not Fusion.peek(Device.Touch) then
			local skill = SkillData.get(previewSkill)
			if skill then
				drawPreview(skill, mouseGround())
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
	local level = math.max(1, State.Get({ "character", "skills", skillId }) or 0)
	local def = Skills.effective(skill, level)
	local cost = Skills.scaled(def, def.cost, level)
	local current = if skill.resource then State.Get({ "character", skill.resource }) or 0 else math.huge
	local enoughResource = current >= cost
	local inRange = skill.target ~= "enemy" or SkillController.TargetDistance() <= (def.range or 10) + 2
	return enoughResource, inRange, Skills.elementAllowed(skill, SkillController.WeaponElement())
end

-- Theme colour of a skill's class (for icons).
function SkillController.Color(skillId: string): Color3
	local skill = SkillData.get(skillId)
	local class = skill and Classes.get(skill.class)
	return if class then Color3.fromHex(class.color) else Theme.Colors.Gold
end

return SkillController
