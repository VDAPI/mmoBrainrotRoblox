--!strict
-- Casting from the hotbar (DESIGN §14.1, S05):
--   enemy skills use the current target (or pick the nearest enemy in range),
--   ally skills target the selected ally or yourself,
--   skills that aim (circles on a point, snares, cones, lines, Blink; Logic/SkillAim, owner 2026-11-10): a tap aims by
--   itself at the enemy we fight (the target, else the nearest enemy within reach, which becomes the target, else in
--   front); a healing field goes under the selected ally or our feet; Blink (an escape, owner 2026-10-31) the way the
--   player steers, else straight away from the enemy, never into the monster. Holding the key past
--   Config.Skills.holdToAim shows the preview at the cursor and the release casts there; the "Cast at cursor" setting
--   (quickCast) casts at the cursor on key press, the old way. The character turns to where a directional skill flies.
--   Review 2026-11-10: a selected ally (a living player who is not an enemy) stays selected: a tapped damage skill or a
--   skill on an enemy goes to the nearest enemy in reach without taking its place, so nothing engages and the next
--   heal still finds the ally.
-- S28: the held-key preview shows the real shape (circle at the cursor, circle around you, cone, line) and cones /
--   lines turn towards the cursor; on touch a tap aims like a tapped key and dragging a skill button aims like a MOBA
--   (release casts, back on the button cancels); a skill pressed during the global cooldown or the end of a cooldown
--   waits in a one-skill queue (Config.Skills.queueWindow) and fires as soon as it can.
-- Also owns the hotbar slots for drag & drop ("skill:<id>" from the tree, "bar:<n>" on the bar).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Classes = require(ReplicatedStorage.Shared.Data.Classes)
local Device = require(script.Parent.Parent.UI.Device)
local DragDrop = require(script.Parent.Parent.UI.DragDrop)
local EffectStack = require(ReplicatedStorage.Shared.Logic.EffectStack)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Keybinds = require(script.Parent.Parent.UI.Keybinds)
local Net = require(ReplicatedStorage.Shared.Net)
local Paths = require(ReplicatedStorage.Shared.Logic.Paths)
local SkillAim = require(ReplicatedStorage.Shared.Logic.SkillAim)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local Skills = require(ReplicatedStorage.Shared.Logic.Skills)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Components.Toast)
local UiArt = require(ReplicatedStorage.Shared.Logic.UiArt)
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

-- S57: the character as Logic/Paths reads it (class, level, path, hotbar, equipment).
local function me(): Paths.Char
	return {
		class = State.Get({ "character", "class" }) or "",
		level = State.Get({ "character", "level" }) or 1,
		path = State.Get({ "character", "path" }),
		hotbar = State.Get({ "character", "hotbar" }),
		equipment = State.Get({ "character", "equipment" }),
		ranks = State.Get({ "character", "ranks" }), -- S137: bought ranks per pool
		barPool = State.Get({ "character", "barPool" }),
	}
end

-- Rank of an own-class skill (0: not available; S137: bought in the active pool, path skills with their node).
local function rankOf(skill: SkillData.SkillDef): number
	return Paths.skillRank(me(), skill.id)
end

-- The skill as it works for the character (rank at least 1, chosen breakpoints, modify nodes).
local function effective(skill: SkillData.SkillDef, rank: number?): SkillData.SkillDef
	local c = me()
	return (Paths.effectiveFor(c, skill.id, Paths.weaponTypesOf(c.equipment), rank))
end

-- What is selected, for a tap (review 2026-11-10): a living enemy (TargetController.IsEnemy, as the server's PvP rules
-- decide: never a party or guild member), or a living ally (any other living model: an allied player), or nothing.
local function selection(): (Model?, boolean, boolean)
	local model = targetModel()
	local living = model ~= nil and model:GetAttribute("Dead") ~= true
	local enemy = living and TargetController.IsEnemy(model) == true
	return model, enemy, living and not enemy
end

-- An offset on the ground from our root to `model`.
local function offsetTo(root: BasePart, model: Model): SkillAim.Flat
	local at = model:GetPivot().Position
	return { x = at.X - root.Position.X, z = at.Z - root.Position.Z }
end

-- The player's own steering in the world (Logic/SkillAim.steering): the raw move input (keys, stick, touch joystick)
-- turned by the camera. Not Humanoid.MoveDirection: it also follows the walk to the target and Auto Hunt (MoveTo).
local function steering(): SkillAim.Flat?
	local camera = Workspace.CurrentCamera
	if not camera then
		return nil
	end
	local input = TargetController.MoveInput()
	local look = camera.CFrame.LookVector
	-- a camera looking straight down: the top of the screen is forward
	local forward = if Vector3.new(look.X, 0, look.Z).Magnitude < 0.01 then camera.CFrame.UpVector else look
	return SkillAim.steering({ x = input.X, z = input.Z }, { x = forward.X, z = forward.Z })
end

-- Where a skill cast without a hand-picked point aims (Logic/SkillAim, owner 2026-11-10): the enemy we fight, else the
-- nearest one within reach (it becomes the target when nothing living is selected; a selected ally stays selected),
-- Blink the way the player steers, else away from the enemy, else ahead, a healing field under the selected ally or at
-- our feet, else in front. nil: the skill aims nowhere, or a cone / line has nobody to aim at (the server turns it
-- where we face).
local function autoAim(skill: SkillData.SkillDef): Vector3?
	local root = myRoot()
	if not root then
		return nil
	end
	local def = effective(skill)
	local model, enemy, ally = selection()
	local nearest: Model? = nil
	if not enemy and SkillAim.seeks(skill.type, skill.target) then
		nearest =
			TargetController.FindNearest(SkillAim.reach(def.type, def.range, def.radius, def.length), false, false)
	end
	local source = SkillAim.source({
		kind = skill.type,
		mode = skill.target,
		manual = false,
		target = enemy,
		nearest = nearest ~= nil,
		ally = ally,
	})
	if (source == "target" or source == "ally") and model then
		return model:GetPivot().Position
	elseif (source == "nearest" or source == "nearby") and nearest then
		if source == "nearest" then
			TargetController.SetTarget(nearest) -- nothing living was selected: it becomes the target
		end
		return nearest:GetPivot().Position
	elseif source == "escape" then
		-- owner 2026-10-31: an escape, never into the monster (standing in a fight we face it: faceStep, turnTo)
		local near = Config.Skills.escapeNear
		local close = if enemy then nil else TargetController.NearestEnemy(near)
		local direction = SkillAim.escape({
			steer = steering(),
			facing = { x = root.CFrame.LookVector.X, z = root.CFrame.LookVector.Z },
			enemy = if enemy and model then offsetTo(root, model) else nil,
			nearest = if close then offsetTo(root, close) else nil,
			near = near,
		})
		return root.Position + Vector3.new(direction.x, 0, direction.z) * (def.length or 15)
	elseif source == "feet" then
		return root.Position -- S74 (ROZWOJ 10.5): a banner without a target, a healing field without an ally
	elseif source == "front" and skill.target == "point" then
		return root.Position + root.CFrame.LookVector * math.min(def.range or 10, 12)
	end
	return nil
end

-- Owner 2026-11-10: the character turns to where a directional skill flies (the server aims the area at the point or
-- the target but never turns our character; the client moves its own). Not in shift lock: the camera decides there.
local function turnTo(point: Vector3)
	local root = myRoot()
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 or humanoid.Sit then
		return
	end
	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		return
	end
	local offset = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
	if offset.Magnitude > 0.5 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + offset)
	end
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
	local facing: Vector3? = nil
	if skill.target == "enemy" then
		local model, enemy, ally = selection()
		local nearest = if enemy then nil else TargetController.FindNearest((skill.range or 10) + 4, false, false)
		local pick = SkillAim.onEnemy({
			kind = skill.type,
			mode = skill.target,
			manual = false,
			target = enemy,
			nearest = nearest ~= nil,
			ally = ally,
		})
		if pick == "nearest" then
			TargetController.SetTarget(nearest)
			model = nearest
		elseif pick == "nearby" then
			-- review 2026-11-10: this cast only (SkillService.resolveTarget takes any entity id and checks it is an
			-- enemy); the selected ally stays selected and nothing engages
			model = nearest
		elseif pick == "none" then
			report("cast.error.noTarget")
			return
		end
		targetId = if model then model:GetAttribute("EntityId") :: string? else nil
		facing = if model then model:GetPivot().Position else nil
	elseif skill.target == "ally" or skill.target == "deadAlly" then
		local model = targetModel()
		if model and model:GetAttribute("CharName") ~= nil then
			targetId = model:GetAttribute("EntityId") :: string?
		end
	elseif aim == nil and SkillAim.aims(skill.type, skill.target) then
		aim = autoAim(skill) -- a tap (owner 2026-11-10)
	end
	if SkillAim.turns(skill.type, skill.target) then
		local at = facing or aim
		if at then
			turnTo(at)
		end
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

-- Skills that can be aimed by hand and show a preview (Logic/SkillAim.previews; owner 2026-11-10: Blink too).
local function aimable(skill: SkillData.SkillDef): boolean
	return SkillAim.previews(skill.type, skill.target)
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
	local def = effective(skill)
	-- S79 Broad Rings: the aim circle grows with the areaRadius hook (as the server casts it)
	local c = me()
	local grown =
		Skills.areaRadius(def, Paths.passiveTotals(c, Paths.weaponTypesOf(c.equipment)).hooks["areaRadius"] or 0)
	if grown ~= def.radius then
		def = table.clone(def)
		def.radius = grown
	end
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
	elseif skill.type == "blink" then
		-- owner 2026-11-10: a held Blink shows the jump; the server always jumps the full length that way
		local landing = feet + dir * (def.length or 15)
		bar(feet, landing, 0.6)
		disc(landing, 2)
		previewPoint = landing + Vector3.new(0, 2.8, 0)
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

-- The skill key that is down (owner 2026-11-10): released before Config.Skills.holdToAim it is a tap (Cast aims it by
-- itself), held longer it shows the preview at the cursor and the release casts there.
local holding: { slot: number, skillId: string, since: number, token: number }? = nil
local holdToken = 0

local function onKeyUp(slot: number)
	local h = holding
	if not h or h.slot ~= slot then
		return
	end
	holding = nil
	local skill = SkillData.get(h.skillId)
	if skill and SkillAim.held(os.clock() - h.since, Config.Skills.holdToAim) then
		-- aimed by hand: where the preview stands (drawn once more, the timer may not have run yet)
		drawPreview(skill, mouseGround())
		local point = previewPoint
		hidePreview()
		SkillController.Cast(h.skillId, point)
	else
		hidePreview()
		SkillController.Cast(h.skillId, nil)
	end
end

local function onKeyDown(slot: number)
	local skillId = SkillController.SkillInSlot(slot)
	local skill = skillId and SkillData.get(skillId)
	if not skill then
		return
	end
	-- a key still down is finished first, so a quick 1, 2 casts both
	local earlier = holding
	if earlier then
		onKeyUp(earlier.slot)
	end
	local press = SkillAim.press(skill.type, skill.target, Fusion.peek(Device.Touch) == true, quickCast())
	if press == "cast" then
		SkillController.Cast(skill.id, nil)
		return
	elseif press == "cursor" then
		SkillController.Cast(skill.id, mouseGround()) -- "Cast at cursor": the old way, on key press
		return
	end
	holdToken += 1
	local token = holdToken
	holding = { slot = slot, skillId = skill.id, since = os.clock(), token = token }
	task.delay(Config.Skills.holdToAim, function()
		local h = holding
		if h and h.token == token then
			showPreview(skill)
		end
	end)
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
	local def = effective(skill)
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

local function unlockedActive(skillId: string): boolean
	local skill = SkillData.get(skillId)
	return skill ~= nil and skill.type ~= "passive" and rankOf(skill) > 0
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
			elseif kind == "skill" and unlockedActive(rest) then
				SkillController.Cast(rest, nil)
			end
		end,
		hasItem = function(slotId: string): boolean
			local kind, rest = parse(slotId)
			if kind == "bar" then
				return SkillController.SkillInSlot(tonumber(rest) :: number) ~= nil
			end
			return kind == "skill" and unlockedActive(rest)
		end,
	})
	UIController.AddDragVisual(function(slotId: string): any
		local kind, rest = parse(slotId)
		local skillId = if kind == "bar"
			then SkillController.SkillInSlot(tonumber(rest) :: number)
			elseif kind == "skill" then rest
			else nil
		local skill = skillId and SkillData.get(skillId)
		if skill then
			local class = Classes.get(skill.class)
			return {
				glyph = skill.glyph,
				color = if class then class.color else nil,
				art = UiArt.skill(skill.id),
			}
		end
		return nil
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
	-- A key let go while the window is not focused never reports it: the held skill is dropped, not cast.
	UserInputService.WindowFocusReleased:Connect(function()
		if holding then
			holding = nil
			hidePreview()
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

-- S80 (ROZWOJ 12.5): Arcane Charges of our own character (stacks of "arcaneCharge" in the Effects attribute).
function SkillController.ArcaneCharges(): number
	local character = player.Character
	if not character then
		return 0
	end
	return EffectStack.stacksOf(character:GetAttribute("Effects"), "arcaneCharge", Workspace:GetServerTimeNow())
end

-- The resource a cast of this skill takes now, as the server counts it (rank, breakpoints and nodes, the S62 item
-- saving, the S76 / S79 / S80 cost hooks, Arcane Charges; a beam: the mana of one tick), and the resource
-- (nil: free). Owner 2026-10-21: the cost badge of a skill slot (Logic/SkillCostBadge) shows it too.
function SkillController.Cost(skillId: string): (number, string?)
	local skill = SkillData.get(skillId)
	if not skill then
		return 0, nil
	end
	local rank = math.max(1, rankOf(skill))
	local def = effective(skill, rank)
	local c = me()
	local mods: Skills.CostMods = {
		costReduce = State.Get({ "derived", "values", "costReduce" }) or 0, -- S62 item saving
		hooks = Paths.passiveTotals(c, Paths.weaponTypesOf(c.equipment)).hooks, -- S76 / S79 / S80 cost hooks
		charges = SkillController.ArcaneCharges(), -- S80
	}
	local cost = Skills.cost(def, rank, State.Get({ "character", "level" }) or 1, skill.class, mods)
	if def.type == "beam" then
		-- S80: a beam needs the mana of one tick (Skills.drain, as the server counts it)
		cost = Skills.drain(def, rank, State.Get({ "derived", "values", "maxMana" }) or 0, mods)
	end
	return cost, skill.resource
end

-- For the UI: can the current level / resources / range allow this skill now?
-- (enough resource, in range, weapon fits: S57 the path weapon of a path skill, S143 the skill's own weapon; S142: the
-- Mage's element is the pool)
function SkillController.Usable(skillId: string): (boolean, boolean, boolean)
	local skill = SkillData.get(skillId)
	if not skill then
		return false, false, true
	end
	local def = effective(skill, math.max(1, rankOf(skill)))
	local c = me()
	local cost = SkillController.Cost(skillId)
	local current = if skill.resource then State.Get({ "character", skill.resource }) or 0 else math.huge
	local enoughResource = current >= cost
	local inRange = skill.target ~= "enemy" or SkillController.TargetDistance() <= (def.range or 10) + 2
	-- S143: a base skill with its own weapon (Shield Bash: a shield) too
	local pathOk = (skill.path == nil and skill.weapon == nil)
		or Paths.skillUsable(c, skill.id, Paths.weaponTypesOf(c.equipment))
	return enoughResource, inRange, pathOk
end

-- Theme colour of a skill's class (for icons).
function SkillController.Color(skillId: string): Color3
	local skill = SkillData.get(skillId)
	local class = skill and Classes.get(skill.class)
	return if class then Color3.fromHex(class.color) else Theme.Iron.Heading
end

return SkillController
