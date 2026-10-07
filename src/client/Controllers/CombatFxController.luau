--!strict
-- Draws the server's batched "CombatFx" events locally (ARCHITECTURE §7):
--   dmg    : floating damage number (white, yellow "!" crit, red when we are hit, grey "Dodge") + hit flash
--   heal   : green "+N"
--   atk    : swing (melee) or projectile (arrow / bolt) from attacker to target; S22: players play the attack
--            pose of their weapon (AnimationController.Attack) with a rarity-coloured trail on the blade, arrows
--            fly from the bow on an arc and stick in the target, crossbow bolts fly straight, wand / staff bolts
--            leave the tip in the weapon's element colour; the hit flash and the number of that attack wait for
--            the blow / the arrival (at most 0.5 s), the server's damage itself is not delayed
--   tele   : red ground telegraph that fills during the windup (circle / cone / line)
--   reward : "+EXP · +gold" above our character
-- Damage numbers can be turned off in the menu (settings.dmgNumbers); telegraphs and hits always show.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AttackPose = require(ReplicatedStorage.Shared.Logic.AttackPose)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)

local CombatFxController = {
	Name = "CombatFxController",
	Deps = { "EffectsController", "AnimationController", "MonsterViewController", "VfxController" },
}

local AnimationController: any
local MonsterView: any = nil

local player = Players.LocalPlayer

local NUMBER_SECONDS = 0.9
local POOL_SIZE = 40
local TELEGRAPH_COLOR = Color3.fromHex("#D64A3E")

local ELEMENT_COLORS: { [string]: Color3 } = {
	fire = Color3.fromHex("#FF7A1A"),
	ice = Color3.fromHex("#7FD4FF"),
	lightning = Color3.fromHex("#E8E25A"),
	poison = Color3.fromHex("#7ACB3A"),
}

local fxFolder: Folder
local guiFolder: Folder
local pool: { BillboardGui } = {}
-- Hit flashes: at most MAX_FLASHES Highlights (Roblox draws 31 at once); the least recently used is reused.
local MAX_FLASHES = 20
local flashes: { [Model]: any } = {}
local flashCount = 0
-- Seconds to hold back the next damage number / flash of an entity (its attack is still swinging / flying).
local MAX_HIT_DELAY = 0.5
local hitDelay: { [string]: number } = {}

-- Entity lookup ---------------------------------------------------------------------------------------------

local function findModel(entityId: string?): Model?
	if not entityId then
		return nil
	end
	if string.sub(entityId, 1, 1) == "p" then
		for _, other in Players:GetPlayers() do
			local character = other.Character
			if character and character:GetAttribute("EntityId") == entityId then
				return character
			end
		end
		return nil
	end
	local monsters = Workspace:FindFirstChild("Monsters")
	if monsters then
		for _, child in monsters:GetChildren() do
			if child:GetAttribute("EntityId") == entityId then
				return child :: Model
			end
		end
	end
	return nil
end

-- Top of a monster's look (S24: MonsterView.top), the bounding box for characters and as a fallback.
local function headPosition(model: Model): Vector3
	local cframe, size = model:GetBoundingBox()
	local top = if MonsterView then MonsterView.top(model) else nil
	if top then
		return Vector3.new(cframe.Position.X, top + 0.5, cframe.Position.Z)
	end
	return cframe.Position + Vector3.new(0, size.Y / 2 + 0.5, 0)
end

local function centre(model: Model): Vector3
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else model:GetPivot().Position
end

-- Floating numbers ---------------------------------------------------------------------------------------

local function newBillboard(): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "FloatingText"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(220, 60)
	gui.MaxDistance = 120
	gui.Enabled = false
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Theme.Fonts.BodyBold
	label.TextScaled = false
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	gui.Parent = guiFolder
	return gui
end

local function floatText(at: Vector3, text: string, color: Color3, size: number, rise: number?)
	local gui = table.remove(pool) or newBillboard()
	local label = gui:FindFirstChild("Label") :: TextLabel
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = at + Vector3.new((math.random() - 0.5) * 1.5, 0, (math.random() - 0.5) * 1.5)
	anchor.Parent = Workspace.Terrain
	gui.Adornee = anchor
	gui.StudsOffsetWorldSpace = Vector3.zero
	label.Text = text
	label.TextColor3 = color
	label.TextSize = size
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0.3
	gui.Enabled = true
	local info = TweenInfo.new(NUMBER_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffsetWorldSpace = Vector3.new(0, rise or 3, 0) }):Play()
	TweenService:Create(
		label,
		TweenInfo.new(
			NUMBER_SECONDS * 0.5,
			Enum.EasingStyle.Quad,
			Enum.EasingDirection.In,
			0,
			false,
			NUMBER_SECONDS * 0.5
		),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	):Play()
	task.delay(NUMBER_SECONDS + 0.05, function()
		gui.Enabled = false
		(gui :: any).Adornee = nil
		anchor:Destroy()
		if #pool < POOL_SIZE then
			table.insert(pool, gui)
		else
			gui:Destroy()
		end
	end)
end

local function numbersEnabled(): boolean
	return State.Get({ "account", "settings", "dmgNumbers" }) ~= false
end

type Flash = { highlight: Highlight, used: number }

local function flashEntry(model: Model): Flash
	local existing = flashes[model]
	if existing then
		return existing
	end
	local entry: Flash? = nil
	if flashCount >= MAX_FLASHES then
		-- Reuse the least recently used Highlight instead of creating one more.
		local oldest: Model? = nil
		local oldestUsed = math.huge
		for other, e in flashes do
			if e.used < oldestUsed then
				oldest, oldestUsed = other, e.used
			end
		end
		if oldest then
			entry = flashes[oldest]
			flashes[oldest] = nil
		end
	end
	if not entry then
		local created = Instance.new("Highlight")
		created.FillColor = Color3.new(1, 1, 1)
		created.OutlineTransparency = 1
		created.FillTransparency = 1
		created.DepthMode = Enum.HighlightDepthMode.Occluded
		created.Parent = guiFolder
		flashCount += 1
		entry = { highlight = created, used = 0 }
	end
	local e = entry :: Flash
	e.highlight.Adornee = model
	flashes[model] = e
	model.Destroying:Connect(function()
		if flashes[model] == e then
			flashes[model] = nil
			e.highlight:Destroy()
			flashCount -= 1
		end
	end)
	return e
end

local function flash(model: Model, color: Color3?)
	local e = flashEntry(model)
	e.used = os.clock()
	local h = e.highlight
	h.FillColor = color or Color3.new(1, 1, 1)
	h.FillTransparency = 0.35
	TweenService:Create(h, TweenInfo.new(0.15), { FillTransparency = 1 }):Play()
end

-- Attack visuals ----------------------------------------------------------------------------------------

local function effectPart(name: string, size: Vector3, color: Color3, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = size
	if shape then
		part.Shape = shape
	end
	part.Parent = fxFolder
	return part
end

local function lowQuality(): boolean
	return State.Get({ "account", "settings", "quality" }) == "low"
end

-- Small burst at the point of impact.
local function impact(model: Model, crit: boolean)
	if lowQuality() then
		return
	end
	local at = centre(model)
	local size = if crit then 3.2 else 2
	local ball = effectPart(
		"Impact",
		Vector3.one * 0.4,
		if crit then Theme.Colors.GoldBright else Color3.new(1, 1, 1),
		Enum.PartType.Ball
	)
	ball.Transparency = 0.2
	ball.CFrame = CFrame.new(at + Vector3.new((math.random() - 0.5) * 0.8, 0.5, (math.random() - 0.5) * 0.8))
	TweenService:Create(ball, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * size,
		Transparency = 1,
	}):Play()
	Debris:AddItem(ball, 0.2)
end

-- Short camera kick when we take a heavy (critical) hit or a big skill lands nearby (S28). Scaled by the setting
-- "Camera shake" (settings.shake 0..1, default 1).
local function shake(strength: number)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local setting = State.Get({ "account", "settings", "shake" })
	strength *= if type(setting) == "number" then math.clamp(setting, 0, 1) else 1
	if not humanoid or strength <= 0.01 then
		return
	end
	task.spawn(function()
		for i = 1, 4 do
			local fade = 1 - (i - 1) / 4
			humanoid.CameraOffset =
				Vector3.new((math.random() - 0.5) * strength * fade, (math.random() - 0.5) * strength * fade, 0)
			task.wait(0.03)
		end
		humanoid.CameraOffset = Vector3.zero
	end)
end

local function swing(attacker: Model, target: Model)
	local from = centre(attacker)
	local to = centre(target)
	local direction = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if direction.Magnitude < 0.1 then
		return
	end
	local arc = effectPart("Swing", Vector3.new(4, 0.2, 0.5), Color3.new(1, 1, 1))
	arc.Transparency = 0.3
	local base = CFrame.lookAt(from, from + direction) * CFrame.new(0, 0.5, -2.2)
	arc.CFrame = base * CFrame.Angles(0, math.rad(-50), math.rad(20))
	TweenService:Create(arc, TweenInfo.new(0.15), {
		CFrame = base * CFrame.Angles(0, math.rad(50), math.rad(-20)),
		Transparency = 1,
	}):Play()
	Debris:AddItem(arc, 0.2)
end

-- Projectiles (S22): pooled parts moved every frame, homing on the target's centre; arrows fly an arc and
-- stick in the target for a moment (not on low quality), bolts fly straight, magic bolts carry a trail.
type Flight = {
	part: BasePart,
	kind: string,
	from: Vector3,
	target: Model,
	start: number,
	duration: number,
	arc: number,
	onArrive: (() -> ())?,
}

local flights: { Flight } = {}
local projectilePool: { [string]: { BasePart } } = {}

local function takeProjectile(kind: string, color: Color3?): BasePart
	local list = projectilePool[kind]
	local part = list and table.remove(list)
	if not part then
		if kind == "arrow" then
			local arrow = effectPart("Arrow", Vector3.new(0.12, 0.12, 2.4), Color3.fromHex("#8A6B4A"))
			arrow.Material = Enum.Material.Wood
			local head = effectPart("Head", Vector3.new(0.22, 0.22, 0.4), Color3.fromHex("#C9CED6"))
			head.Material = Enum.Material.Metal
			head.Anchored = false
			local fletch = effectPart("Fletching", Vector3.new(0.04, 0.32, 0.5), Color3.fromHex("#E8E2D0"))
			fletch.Material = Enum.Material.Fabric
			fletch.Anchored = false
			for _, piece in { { head, -1.3 }, { fletch, 1.0 } } :: { { any } } do
				local p = piece[1] :: BasePart
				p.CFrame = arrow.CFrame * CFrame.new(0, 0, piece[2] :: number)
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = arrow
				weld.Part1 = p
				weld.Parent = p
				p.Parent = arrow
			end
			part = arrow
		elseif kind == "bolt" then
			local bolt = effectPart("CrossbowBolt", Vector3.new(0.14, 0.14, 1.4), Color3.fromHex("#5E5E66"))
			bolt.Material = Enum.Material.Metal
			part = bolt
		else
			local orb = effectPart("MagicBolt", Vector3.new(0.8, 0.8, 0.8), Theme.Colors.Accent, Enum.PartType.Ball)
			local light = Instance.new("PointLight")
			light.Range = 8
			light.Parent = orb
			local a0 = Instance.new("Attachment")
			a0.Name = "A0"
			a0.Position = Vector3.new(0, 0.3, 0)
			a0.Parent = orb
			local a1 = Instance.new("Attachment")
			a1.Name = "A1"
			a1.Position = Vector3.new(0, -0.3, 0)
			a1.Parent = orb
			local trail = Instance.new("Trail")
			trail.Attachment0 = a0
			trail.Attachment1 = a1
			trail.Lifetime = 0.18
			trail.LightEmission = 1
			trail.Transparency = NumberSequence.new(0.2, 1)
			trail.Parent = orb
			part = orb
		end
	end
	local p = part :: BasePart
	if kind == "magic" then
		local c = color or Theme.Colors.Accent
		p.Color = c
		local light = p:FindFirstChildOfClass("PointLight")
		if light then
			light.Color = c
		end
		local trail = p:FindFirstChildOfClass("Trail")
		if trail then
			trail.Color = ColorSequence.new(c)
			trail.Enabled = not lowQuality()
		end
	end
	p.Transparency = 0
	for _, child in p:GetChildren() do
		if child:IsA("BasePart") then
			child.Transparency = 0
		end
	end
	p.Parent = fxFolder
	return p
end

local function giveBack(kind: string, part: BasePart)
	part.Parent = nil
	local trail = part:FindFirstChildOfClass("Trail")
	if trail then
		trail.Enabled = false
	end
	local list = projectilePool[kind]
	if not list then
		list = {}
		projectilePool[kind] = list
	end
	if #list < 24 then
		table.insert(list, part)
	else
		part:Destroy()
	end
end

-- Seconds a projectile of `kind` needs for `distance` studs.
local function flightTime(kind: string, distance: number): number
	local speed = if kind == "bolt" then 150 elseif kind == "arrow" then 110 else 85
	return math.clamp(distance / speed, 0.06, 0.4)
end

local function launch(kind: string, from: Vector3, target: Model, color: Color3?, onArrive: (() -> ())?)
	local to = centre(target)
	local distance = (to - from).Magnitude
	if distance < 0.5 then
		if onArrive then
			onArrive()
		end
		return
	end
	local part = takeProjectile(kind, color)
	part.CFrame = CFrame.lookAt(from, to)
	table.insert(flights, {
		part = part,
		kind = kind,
		from = from,
		target = target,
		start = os.clock(),
		duration = flightTime(kind, distance),
		arc = if kind == "arrow" then math.min(4, distance * 0.08) else 0,
		onArrive = onArrive,
	})
end

local function stepFlights()
	if #flights == 0 then
		return
	end
	local now = os.clock()
	for i = #flights, 1, -1 do
		local f = flights[i]
		local to = if f.target.Parent then centre(f.target) else f.part.Position
		local t = math.clamp((now - f.start) / f.duration, 0, 1)
		local function at(k: number): Vector3
			return f.from:Lerp(to, k) + Vector3.new(0, f.arc * 4 * k * (1 - k), 0)
		end
		local position = at(t)
		local ahead = at(math.min(1, t + 0.05))
		if (ahead - position).Magnitude > 1e-3 then
			f.part.CFrame = CFrame.lookAt(position, ahead)
		else
			f.part.CFrame = CFrame.new(position) * f.part.CFrame.Rotation
		end
		if t >= 1 then
			table.remove(flights, i)
			if f.onArrive then
				task.spawn(f.onArrive)
			end
			local part, kind = f.part, f.kind
			if kind == "arrow" and not lowQuality() and f.target.Parent then
				-- Stuck in the target for a moment, then gone.
				part.CFrame = part.CFrame * CFrame.new(0, 0, -0.6)
				task.delay(0.6, function()
					giveBack(kind, part)
				end)
			else
				if kind == "magic" and not lowQuality() then
					local burst = effectPart("Burst", Vector3.one * 0.6, part.Color, Enum.PartType.Ball)
					burst.CFrame = part.CFrame
					burst.Transparency = 0.2
					TweenService:Create(burst, TweenInfo.new(0.18), { Size = Vector3.one * 2.4, Transparency = 1 })
						:Play()
					Debris:AddItem(burst, 0.2)
				end
				giveBack(kind, part)
			end
		end
	end
end

-- Old monster projectiles (no weapon in hand): from the chest.
local function projectile(attacker: Model, target: Model, style: string)
	local from = centre(attacker) + Vector3.new(0, 0.8, 0)
	launch(if style == "arrow" then "arrow" else "magic", from, target, nil, nil)
end

-- Weapon helpers (S22) ------------------------------------------------------------------------------------

local function weaponOf(model: Model): BasePart?
	local part = model:FindFirstChild("VaelthornWeapon")
	return if part and part:IsA("BasePart") then part else nil
end

local function attachmentPosition(weapon: BasePart?, name: string): Vector3?
	local a = weapon and weapon:FindFirstChild(name)
	return if a and a:IsA("Attachment") then a.WorldPosition else nil
end

-- Blade trail between the grip and the tip, in the weapon's rarity colour, during the strike phase.
local function weaponTrail(weapon: BasePart, timing: AttackPose.Timing)
	if lowQuality() then
		return
	end
	local trail = weapon:FindFirstChild("VaelthornTrail") :: Trail?
	if not trail then
		local grip = weapon:FindFirstChild("VaelthornGrip")
		local tip = weapon:FindFirstChild("VaelthornTip")
		if not grip or not tip or not grip:IsA("Attachment") or not tip:IsA("Attachment") then
			return
		end
		local created = Instance.new("Trail")
		created.Name = "VaelthornTrail"
		created.Attachment0 = grip
		created.Attachment1 = tip
		created.Lifetime = 0.16
		created.MinLength = 0.05
		created.LightEmission = 0.7
		created.Transparency = NumberSequence.new(0.25, 1)
		local accent = weapon:GetAttribute("Accent")
		created.Color = ColorSequence.new(if typeof(accent) == "Color3" then accent else Color3.new(1, 1, 1))
		created.Enabled = false
		created.Parent = weapon
		trail = created
	end
	local t = trail :: Trail
	task.delay(math.max(0, timing.windup - 0.02), function()
		if t.Parent then
			t.Enabled = true
		end
	end)
	task.delay(timing.windup + timing.strike + 0.04, function()
		if t.Parent then
			t.Enabled = false
		end
	end)
end

-- Small glow growing at the tip of a wand / staff during the windup.
local function charge(weapon: BasePart?, color: Color3, seconds: number)
	local at = attachmentPosition(weapon, "VaelthornTip")
	if not at or lowQuality() then
		return
	end
	local spark = effectPart("Charge", Vector3.one * 0.2, color, Enum.PartType.Ball)
	spark.CFrame = CFrame.new(at)
	spark.Transparency = 0.3
	TweenService:Create(spark, TweenInfo.new(seconds), { Size = Vector3.one * 0.9, Transparency = 0.1 }):Play()
	Debris:AddItem(spark, seconds)
end

-- Dust ring at the target (hammer / mace blows).
local function dust(target: Model)
	if lowQuality() then
		return
	end
	local at = centre(target) - Vector3.new(0, 2.5, 0)
	local ring = effectPart("Dust", Vector3.new(0.2, 1, 1), Color3.fromHex("#B8A888"), Enum.PartType.Cylinder)
	ring.Material = Enum.Material.SmoothPlastic
	ring.Transparency = 0.35
	ring.CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
	TweenService:Create(ring, TweenInfo.new(0.3), { Size = Vector3.new(0.2, 7, 7), Transparency = 1 }):Play()
	Debris:AddItem(ring, 0.35)
end

-- Bright flash at the target (priest weapons).
local function holyFlash(target: Model)
	if lowQuality() then
		return
	end
	local ball = effectPart("Holy", Vector3.one * 0.6, Color3.fromHex("#FFF2B8"), Enum.PartType.Ball)
	ball.CFrame = CFrame.new(centre(target))
	ball.Transparency = 0.1
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex("#FFE8A0")
	light.Range = 14
	light.Brightness = 3
	light.Parent = ball
	TweenService:Create(ball, TweenInfo.new(0.25), { Size = Vector3.one * 4, Transparency = 1 }):Play()
	Debris:AddItem(ball, 0.3)
end

local HOLY = { holystaff = true, scepter = true }

-- A player's basic attack (S22): the pose, the weapon effects and the delay of its hit.
local function playerAttack(attacker: Model, target: Model, event: { [string]: any })
	local camera = Workspace.CurrentCamera
	if camera and (centre(attacker) - camera.CFrame.Position).Magnitude > Config.EffectRadius then
		return
	end
	local weaponType = if type(event.w) == "string" then event.w else nil
	local timing = AnimationController.Attack(attacker, weaponType)
	local weapon = weaponOf(attacker)
	local motion = AttackPose.motionFor(weaponType)
	local targetId = event.t :: string
	if event.st == "melee" then
		hitDelay[targetId] = timing.hitAt
		if motion == "unarmed" or not weapon then
			task.delay(timing.hitAt * 0.7, swing, attacker, target)
		else
			weaponTrail(weapon, timing)
			if motion == "smash" then
				task.delay(timing.hitAt, dust, target)
			end
		end
		if weaponType and HOLY[weaponType] then
			task.delay(timing.hitAt, holyFlash, target)
		end
		return
	end
	-- Ranged: arrows from the bow's grip, bolts and magic from the tip, at the release moment.
	local kind = if motion == "bow" then "arrow" elseif motion == "crossbow" then "bolt" else "magic"
	local color = ELEMENT_COLORS[event.el or ""] or Theme.Colors.Accent
	if kind == "magic" then
		charge(weapon, color, timing.hitAt)
	end
	local from0 = attachmentPosition(weapon, if kind == "arrow" then "VaelthornGrip" else "VaelthornTip")
		or centre(attacker) + Vector3.new(0, 0.8, 0)
	hitDelay[targetId] = timing.hitAt + flightTime(kind, (centre(target) - from0).Magnitude)
	task.delay(timing.hitAt, function()
		if not attacker.Parent or not target.Parent then
			return
		end
		local from = attachmentPosition(weaponOf(attacker), if kind == "arrow" then "VaelthornGrip" else "VaelthornTip")
			or centre(attacker) + Vector3.new(0, 0.8, 0)
		launch(kind, from, target, color, nil)
	end)
end

-- Telegraphs -----------------------------------------------------------------------------------------------

local function groundDisc(name: string, radius: number, at: CFrame, transparency: number): Part
	local disc = effectPart(name, Vector3.new(0.12, radius * 2, radius * 2), TELEGRAPH_COLOR, Enum.PartType.Cylinder)
	disc.Material = Enum.Material.SmoothPlastic
	disc.Transparency = transparency
	disc.CFrame = at * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90))
	return disc
end

local function telegraph(event: { [string]: any })
	local area = event.cf :: CFrame
	local windup = math.clamp(tonumber(event.t) or 1, 0.2, 5)
	local color = ELEMENT_COLORS[event.el or ""] or TELEGRAPH_COLOR
	local parts: { BasePart } = {}
	local info = TweenInfo.new(windup, Enum.EasingStyle.Linear)

	if event.sh == "circle" then
		local radius = tonumber(event.r) or 8
		local outline = groundDisc("TelegraphOuter", radius, area, 0.7)
		local fill = groundDisc("TelegraphFill", 0.05, area, 0.45)
		outline.Color = color
		fill.Color = color
		TweenService:Create(fill, info, { Size = Vector3.new(0.14, radius * 2, radius * 2) }):Play()
		table.insert(parts, outline)
		table.insert(parts, fill)
	elseif event.sh == "cone" then
		local radius = tonumber(event.r) or 10
		local angle = math.rad(tonumber(event.an) or 90)
		local slices = 9
		for i = 0, slices - 1 do
			local yaw = -angle / 2 + angle * (i + 0.5) / slices
			local width = 2 * radius * math.tan(angle / slices / 2) + 0.2
			local slice = effectPart("TelegraphCone", Vector3.new(width, 0.12, radius), color)
			slice.Material = Enum.Material.SmoothPlastic
			slice.Transparency = 0.7
			slice.CFrame = area * CFrame.Angles(0, -yaw, 0) * CFrame.new(0, 0.15, -radius / 2)
			local fill = effectPart("TelegraphConeFill", Vector3.new(width * 0.95, 0.14, 0.05), color)
			fill.Material = Enum.Material.SmoothPlastic
			fill.Transparency = 0.45
			fill.CFrame = area * CFrame.Angles(0, -yaw, 0) * CFrame.new(0, 0.16, 0)
			TweenService:Create(fill, info, {
				Size = Vector3.new(width * 0.95, 0.14, radius),
				CFrame = area * CFrame.Angles(0, -yaw, 0) * CFrame.new(0, 0.16, -radius / 2),
			}):Play()
			table.insert(parts, slice)
			table.insert(parts, fill)
		end
	elseif event.sh == "ring" then
		-- Ring with a safe centre (bosses): red outer disc filling up, green safe zone in the middle.
		local radius = tonumber(event.r) or 20
		local inner = tonumber(event.ir) or 5
		local outline = groundDisc("TelegraphOuter", radius, area, 0.7)
		local fill = groundDisc("TelegraphFill", inner, area, 0.45)
		local safe = groundDisc("TelegraphSafe", inner, area, 0.35)
		outline.Color = color
		fill.Color = color
		safe.Color = Theme.Colors.Success
		safe.CFrame = safe.CFrame + Vector3.new(0, 0.05, 0)
		TweenService:Create(fill, info, { Size = Vector3.new(0.14, radius * 2, radius * 2) }):Play()
		table.insert(parts, outline)
		table.insert(parts, fill)
		table.insert(parts, safe)
	elseif event.sh == "line" then
		local length = tonumber(event.l) or 15
		local width = tonumber(event.w) or 5
		local outline = effectPart("TelegraphLine", Vector3.new(width, 0.12, length), color)
		outline.Material = Enum.Material.SmoothPlastic
		outline.Transparency = 0.7
		outline.CFrame = area * CFrame.new(0, 0.15, -length / 2)
		local fill = effectPart("TelegraphLineFill", Vector3.new(width * 0.95, 0.14, 0.05), color)
		fill.Material = Enum.Material.SmoothPlastic
		fill.Transparency = 0.45
		fill.CFrame = area * CFrame.new(0, 0.16, 0)
		TweenService:Create(fill, info, {
			Size = Vector3.new(width * 0.95, 0.14, length),
			CFrame = area * CFrame.new(0, 0.16, -length / 2),
		}):Play()
		table.insert(parts, outline)
		table.insert(parts, fill)
	end

	task.delay(windup, function()
		for _, part in parts do
			TweenService:Create(part, TweenInfo.new(0.2), { Transparency = 1 }):Play()
			Debris:AddItem(part, 0.25)
		end
	end)
end

-- Dispatcher ---------------------------------------------------------------------------------------------

-- S28: the name of a skill shows once per cast (its first hit within NAME_EVERY seconds).
local NAME_EVERY = 1.2
local namedAt: { [string]: number } = {}

local function onDamage(event: { [string]: any })
	local model = findModel(event.e)
	if not model then
		return
	end
	local isMe = model == player.Character
	if event.d then
		if numbersEnabled() then
			floatText(headPosition(model), Text.now("combat.dodge"), Theme.Colors.TextMuted, 22)
		end
		return
	end
	local amount = tonumber(event.a) or 0
	if amount <= 0 then
		return
	end
	local skill = if type(event.sk) == "string" then SkillData.get(event.sk) else nil
	-- A critical skill hit flashes gold (S28).
	flash(model, if skill and event.c then Theme.Colors.GoldBright else nil)
	impact(model, event.c == true)
	AnimationController.MonsterHit(model)
	if model:GetAttribute("MonsterId") == nil then
		AnimationController.CharacterHit(model)
	end
	if isMe and event.c then
		shake(0.35)
	end
	if numbersEnabled() then
		local text = Format.number(amount)
		local color = Color3.new(1, 1, 1)
		local size = 26
		if isMe then
			color = Theme.Colors.DangerHover
		elseif event.c then
			color = Theme.Colors.GoldBright
		end
		if skill then
			size += 6 -- skill numbers are bigger than basic attacks
		end
		if event.c then
			text ..= "!"
			size += 10
		end
		floatText(headPosition(model), text, color, size)
		if skill and not isMe then
			local key = `{event.by or "?"}:{skill.id}`
			local now = os.clock()
			if now - (namedAt[key] or 0) > NAME_EVERY then
				namedAt[key] = now
				floatText(
					headPosition(model) + Vector3.new(0, 1.2, 0),
					Text.now(skill.nameKey),
					Theme.Colors.Gold,
					18,
					3.5
				)
			end
		end
	end
end

local function handle(event: { [string]: any })
	local kind = event.k
	if kind == "dmg" then
		-- The number of a player's attack waits for its blow / arrival (S22).
		local wait = if type(event.e) == "string" then hitDelay[event.e] else nil
		if wait then
			hitDelay[event.e] = nil
			task.delay(math.min(wait, MAX_HIT_DELAY), onDamage, event)
		else
			onDamage(event)
		end
	elseif kind == "heal" then
		local model = findModel(event.e)
		if model and numbersEnabled() then
			floatText(headPosition(model), `+{Format.number(tonumber(event.a) or 0)}`, Theme.Colors.Success, 24)
		end
	elseif kind == "atk" then
		local attacker = findModel(event.s)
		local target = findModel(event.t)
		if attacker and target then
			if attacker:GetAttribute("MonsterId") ~= nil then
				AnimationController.MonsterAttack(attacker, nil, true)
				if event.st == "melee" then
					swing(attacker, target)
				else
					projectile(attacker, target, event.st)
				end
			else
				playerAttack(attacker, target, event)
			end
			if attacker == player.Character or target == player.Character then
				Sounds.play("hit")
			end
		end
	elseif kind == "tele" then
		telegraph(event)
		local caster = findModel(event.e)
		if caster then
			AnimationController.MonsterAttack(caster, tonumber(event.t))
		end
	elseif kind == "reward" then
		local character = player.Character
		if character then
			local text = Text.now(
				"combat.reward",
				{ exp = Format.number(event.exp or 0), gold = Format.number(event.gold or 0) }
			)
			floatText(headPosition(character) + Vector3.new(0, 1, 0), text, Theme.Colors.Gold, 22, 4)
		end
	end
end

function CombatFxController.Init(registry)
	MonsterView = registry.Get("MonsterViewController")
	AnimationController = registry.Get("AnimationController")
	registry.Get("VfxController").SetShake(shake)
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "Vaelthorn_CombatFx"
	fxFolder.Parent = Workspace
	guiFolder = Instance.new("Folder")
	guiFolder.Name = "Vaelthorn_CombatGui"
	guiFolder.Parent = player:WaitForChild("PlayerGui")
	for _ = 1, 12 do
		table.insert(pool, newBillboard())
	end
end

-- Admin /anim (S22): plays a weapon's attack on our own character (no target, no damage).
function CombatFxController.PreviewAttack(weaponType: string?)
	local character = player.Character
	if not character then
		return
	end
	local timing = AnimationController.Attack(character, weaponType)
	local weapon = weaponOf(character)
	local motion = AttackPose.motionFor(weaponType)
	if weapon and not AttackPose.timing(motion).ranged and motion ~= "unarmed" then
		weaponTrail(weapon, timing)
	end
end

function CombatFxController.Start()
	RunService.Heartbeat:Connect(function()
		local ok, err = pcall(function()
			stepFlights()
		end)
		if not ok then
			warn(`[CombatFxController] {err}`)
			table.clear(flights)
		end
	end)
	Net.On("CombatFx", function(batch: any)
		if type(batch) ~= "table" then
			return
		end
		for _, event in batch do
			if type(event) == "table" then
				local ok = pcall(handle, event)
				if not ok then
					continue
				end
			end
		end
	end)
end

return CombatFxController
