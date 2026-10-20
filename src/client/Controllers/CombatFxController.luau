--!strict
-- Draws the server's batched "CombatFx" events locally (ARCHITECTURE §7):
--   dmg    : floating damage number + hit flash. S29: text and style come from Logic/DamageText (our hits big
--            and white, "KRYT! 1 234" crits orange-gold with a pop, others' hits smaller and dimmer, hits on us
--            red, "Absorbed" / "Immune" / "Dodge", DoT ticks small in their element's colour); numbers of one
--            target stack upwards instead of overlapping (DamageText.newStack: at most 6, fast hits merge)
--   heal   : green "+N" (heals and heal-over-time ticks)
--   atk    : swing (melee) or projectile (arrow / bolt) from attacker to target; S22: players play the attack
--            pose of their weapon (AnimationController.Attack) with a rarity-coloured trail on the blade, arrows
--            fly from the bow on an arc and stick in the target, crossbow bolts fly straight, wand / staff bolts
--            leave the tip in the weapon's element colour; the hit flash and the number of that attack wait for
--            the blow / the arrival (at most 0.5 s), the server's damage itself is not delayed
--   tele   : red ground telegraph that fills during the windup (circle / cone / line / ring); S117: telegraphs 2.0
--            (Vfx/GroundTelegraph: from the edge to the centre, pulsing rim, flash and effect at the blow)
--            S134e: a lethal blow (`x`) dark crimson, thick-rimmed, pulsing faster at the end
--   reward : "+EXP · +gold" above our character
-- Damage numbers: setting "all / mine and received / off" (settings.dmgMode, DamageText.mode; the old
-- dmgNumbers = false counts as "off"); telegraphs and hit flashes always show. Tuning in Data/DamageNumbers.
-- S110: the attack and telegraph visuals run on the effect clock (Vfx/Clock: delays, tweens, trails, flights), so
-- AnimLab freezes them with the pose; damage numbers and floating texts stay on real time (they are not motion).
-- S111: sounds through SfxController (Data/Sfx): a basic attack's draw / swing / release on the effect clock, the
-- hit's material plus hit.crit, block, miss, a monster's attack and pain, the telegraph warning and the caster's attack
-- after the windup, the gold clink of a reward.
-- S113 (DESIGN-16 §5): a basic attack plays its combo step (AnimationController.Attack); the effects of the moment of
-- the hit (dust and smoke of a smash, the holy flash, the shot of a ranged weapon, the release sound) run once as
-- `onHit` at the server's hit time (a clip's "Hit" marker or AttackMotions.SERVER_HIT), the swing sounds at the start
-- of the blow and the weapon trail (Vfx/Library.weaponTrail basic) by the step's timing; keys from
-- AttackMotions.SFX through Logic/SfxRules.attackKeys. A basic hit (dmg without `sk`) sprays sparks by the target's
-- material (Data/HitFx, the material rule of the hit sounds; players are "armor") back towards the attacker, and the
-- struck character leans away from the blow, a generated monster turns its body away (AnimationController).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AttackMotions = require(ReplicatedStorage.Shared.Data.AttackMotions)
local AttackPose = require(ReplicatedStorage.Shared.Logic.AttackPose)
local BossMotions = require(ReplicatedStorage.Shared.Data.BossMotions)
local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local ClipFit = require(ReplicatedStorage.Shared.Logic.ClipFit)
local Config = require(ReplicatedStorage.Shared.Config)
local Cosmetics = require(ReplicatedStorage.Shared.Data.Cosmetics)
local DamageNumbers = require(ReplicatedStorage.Shared.Data.DamageNumbers)
local DamageText = require(ReplicatedStorage.Shared.Logic.DamageText)
local Format = require(ReplicatedStorage.Shared.Util.Format)
local HitFx = require(ReplicatedStorage.Shared.Data.HitFx)
local MonsterAbilities = require(ReplicatedStorage.Shared.Data.MonsterAbilities)
local MonsterLooks = require(ReplicatedStorage.Shared.Data.MonsterLooks)
local MountData = require(ReplicatedStorage.Shared.Data.Mounts)
local Net = require(ReplicatedStorage.Shared.Net)
local Sfx = require(ReplicatedStorage.Shared.Data.Sfx)
local SfxRules = require(ReplicatedStorage.Shared.Logic.SfxRules)
local SkillData = require(ReplicatedStorage.Shared.Data.Skills)
local Telegraph = require(ReplicatedStorage.Shared.Logic.Telegraph)
local FightView = require(script.Parent.Parent.UI.FightView)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local Clock = require(script.Parent.Parent.Vfx.Clock)
local GroundTelegraph = require(script.Parent.Parent.Vfx.GroundTelegraph)
local Library = require(script.Parent.Parent.Vfx.Library)
local Pool = require(script.Parent.Parent.Vfx.Pool)
local Textures = require(script.Parent.Parent.Vfx.Textures)

-- S136: colours of the 3D effects (world, not interface): the old gold and magic blue of the legacy UI palette.
local WORLD_GOLD_BRIGHT = Color3.fromHex("#E8C25A")
local WORLD_GOLD = Color3.fromHex("#C9A45C")
local WORLD_MAGIC = Color3.fromHex("#4A8FE7")

local CombatFxController = {
	Name = "CombatFxController",
	Deps = {
		"EffectsController",
		"AnimationController",
		"MonsterViewController",
		"VfxController",
		"DungeonController",
		"SfxController",
	},
}

local AnimationController: any
local SfxController: any
local MonsterView: any
local DungeonController: any = nil

local player = Players.LocalPlayer

local TELEGRAPH_COLOR = Color3.fromHex("#D64A3E")
local LETHAL_COLOR = Color3.fromHex(Config.Telegraph.lethalColor) -- S134e

local ELEMENT_COLORS: { [string]: Color3 } = {
	fire = Color3.fromHex("#FF7A1A"),
	ice = Color3.fromHex("#7FD4FF"),
	lightning = Color3.fromHex("#E8E25A"),
	poison = Color3.fromHex("#7ACB3A"),
}

-- S29: colours of the number styles (Data/DamageNumbers.styles); DoT ticks use DOT_COLORS by element.
local STYLE_COLORS: { [string]: Color3 } = {
	mine = Color3.new(1, 1, 1),
	mineCrit = Color3.fromHex("#FFA62B"),
	other = Color3.fromHex("#E4DED2"),
	otherCrit = Color3.fromHex("#F2C46A"),
	received = Color3.fromHex("#FF5A4E"),
	receivedCrit = Color3.fromHex("#FF2E22"),
	absorbed = Color3.fromHex("#A9B2BD"),
	immune = Color3.fromHex("#C9C3E6"),
	dodge = Color3.fromHex("#B8B4AA"),
	blocked = Color3.fromHex("#9FB7D9"), -- S64: cool steel, unlike dodge and absorbed
	heal = Color3.fromHex("#5BD66B"),
	hot = Color3.fromHex("#8FE39A"),
	dot = Color3.fromHex("#C9A0FF"),
}
local DOT_COLORS: { [string]: Color3 } = {
	fire = Color3.fromHex("#FF7A1A"),
	ice = Color3.fromHex("#7FD4FF"),
	lightning = Color3.fromHex("#E8E25A"),
	poison = Color3.fromHex("#7ACB3A"),
	bleed = Color3.fromHex("#D2382E"),
	holy = Color3.fromHex("#FFE8A0"),
}
local SHIELD_FLASH = Color3.fromHex("#9FC8FF")

local fxFolder: Folder
local guiFolder: Folder
-- S29: the billboards live in their own ScreenGui with ResetOnSpawn = false (they survive our respawn).
local numbersGui: ScreenGui? = nil
local pool: { BillboardGui } = {}
-- Hit flashes: at most MAX_FLASHES Highlights (Roblox draws 31 at once); the least recently used is reused.
local MAX_FLASHES = 20
local flashes: { [Model]: any } = {}
local flashCount = 0

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
	-- S96: a rider's box holds the mount too; the head of the rider is the top that counts
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") and model:FindFirstChild("VaelthornMount") then
		return head.Position + Vector3.new(0, head.Size.Y / 2 + 0.5, 0)
	end
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

local function numbersContainer(): ScreenGui
	local existing = numbersGui
	if existing and existing.Parent then
		return existing
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "Vaelthorn_CombatNumbers"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	numbersGui = gui
	table.clear(pool) -- the pooled billboards went with the old container
	return gui
end

local function newBillboard(): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "FloatingText"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(340, 80)
	gui.MaxDistance = DamageNumbers.maxDistance
	gui.Enabled = false
	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Theme.Fonts.Numbers
	label.TextScaled = false
	label.TextStrokeTransparency = 1
	label.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = label
	-- W28: a rounded dark outline in the number's own hue instead of the flat text stroke, and a sheen gradient
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = label
	local sheen = Instance.new("UIGradient")
	sheen.Rotation = 90
	sheen.Enabled = false
	sheen.Parent = label
	gui.Parent = numbersContainer()
	return gui
end

local function takeBillboard(): BillboardGui
	local container = numbersContainer()
	while #pool > 0 do
		local gui = table.remove(pool) :: BillboardGui
		if gui.Parent == container then
			return gui
		end
		gui:Destroy()
	end
	return newBillboard()
end

-- One number in the air.
type Live = {
	gui: BillboardGui,
	label: TextLabel,
	scale: UIScale,
	stroke: UIStroke,
	anchor: Attachment,
	tweens: { Tween },
	done: boolean,
	stackId: number?,
	target: string?,
}

type TextOptions = {
	base: number?, -- studs above the anchor at the start (stack slot)
	rise: number?, -- studs it rises
	dim: number?, -- starting transparency
	pop: number?, -- starting scale (crits)
	twitch: boolean?,
	sheen: boolean?, -- W28: light top on the glyphs (crits, heals)
	heavy: boolean?, -- W28: thicker outline (crits)
}

local stack = DamageText.newStack()
local live: { [number]: Live } = {}

local function finish(entry: Live)
	if entry.done then
		return
	end
	entry.done = true
	for _, tween in entry.tweens do
		tween:Cancel()
	end
	entry.gui.Enabled = false
	(entry.gui :: any).Adornee = nil
	entry.anchor:Destroy()
	if entry.stackId then
		live[entry.stackId] = nil
		if entry.target then
			stack:release(entry.target, entry.stackId)
		end
	end
	if #pool < DamageNumbers.poolSize and entry.gui.Parent then
		table.insert(pool, entry.gui)
	else
		entry.gui:Destroy()
	end
end

local function play(entry: Live, instance: Instance, info: TweenInfo, goal: { [string]: any })
	local tween = TweenService:Create(instance, info, goal)
	table.insert(entry.tweens, tween)
	tween:Play()
end

-- Small sideways twitch of a critical number while it pops.
local function twitch(entry: Live)
	task.spawn(function()
		local px = DamageNumbers.twitch
		for _, dx in { px, -px, px * 0.5, 0 } do
			if entry.done then
				return
			end
			entry.label.Position = UDim2.new(0.5, dx, 0.5, 0)
			task.wait(DamageNumbers.popSeconds / 4)
		end
	end)
end

local function floatText(at: Vector3, text: string, color: Color3, size: number, options: TextOptions?): Live
	local o: TextOptions = options or {}
	local gui = takeBillboard()
	local label = gui:FindFirstChild("Label") :: TextLabel
	local scale = label:FindFirstChildOfClass("UIScale") :: UIScale
	local stroke = label:FindFirstChildOfClass("UIStroke") :: UIStroke
	local sheen = label:FindFirstChildOfClass("UIGradient") :: UIGradient
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = at + Vector3.new((math.random() - 0.5) * 0.8, 0, (math.random() - 0.5) * 0.8)
	anchor.Parent = Workspace.Terrain
	local base = o.base or 0
	local dim = o.dim or 0
	local lifetime = DamageNumbers.lifetime
	local side = if math.random() < 0.5 then -1 else 1
	gui.Adornee = anchor
	gui.StudsOffsetWorldSpace = Vector3.new(0, base, 0)
	gui.StudsOffset = Vector3.zero
	label.Text = text
	label.TextColor3 = color
	label.TextSize = size
	label.TextTransparency = dim
	label.Position = UDim2.fromScale(0.5, 0.5)
	stroke.Color = color:Lerp(Color3.new(0, 0, 0), DamageNumbers.strokeDark)
	stroke.Thickness = if o.heavy then DamageNumbers.strokeCrit else DamageNumbers.stroke
	stroke.Transparency = dim
	-- the gradient multiplies the text colour: white text, the gradient carries the hue
	sheen.Enabled = o.sheen == true
	if o.sheen then
		label.TextColor3 = Color3.new(1, 1, 1)
		sheen.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), DamageNumbers.sheen), color)
	end
	scale.Scale = o.pop or DamageNumbers.popAll
	gui.Enabled = true
	local entry: Live =
		{ gui = gui, label = label, scale = scale, stroke = stroke, anchor = anchor, tweens = {}, done = false }
	play(
		entry,
		gui,
		TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffsetWorldSpace = Vector3.new(0, base + (o.rise or DamageNumbers.rise), 0) }
	)
	-- W28: a sideways drift in screen space, so fast hits fan out instead of piling into one column
	play(
		entry,
		gui,
		TweenInfo.new(lifetime, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ StudsOffset = Vector3.new(side * DamageNumbers.drift, 0, 0) }
	)
	local fade = TweenInfo.new(lifetime * 0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, lifetime * 0.5)
	play(entry, label, fade, { TextTransparency = 1 })
	play(entry, stroke, fade, { Transparency = 1 })
	-- pop in (Back: overshoots a little), then shrink while fading
	play(
		entry,
		scale,
		TweenInfo.new(DamageNumbers.popSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	)
	task.delay(DamageNumbers.popSeconds, function()
		if not entry.done then
			play(
				entry,
				scale,
				TweenInfo.new(
					lifetime * 0.5,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.In,
					0,
					false,
					lifetime * 0.5 - DamageNumbers.popSeconds
				),
				{ Scale = DamageNumbers.shrink }
			)
		end
	end)
	if o.twitch then
		twitch(entry)
	end
	task.delay(lifetime + 0.05, finish, entry)
	return entry
end

local function myEntityId(): string?
	local character = player.Character
	local id = character and character:GetAttribute("EntityId")
	return if type(id) == "string" then id else nil
end

local function numberMode(): DamageText.Mode
	return DamageText.mode(State.Get({ "account", "settings" }))
end

local function styleColor(result: DamageText.Result): Color3
	if result.style == "dot" and result.element then
		return DOT_COLORS[result.element] or STYLE_COLORS.dot
	end
	return STYLE_COLORS[result.style] or STYLE_COLORS.mine
end

-- Draws one formatted number above `model`, stacked with the other numbers of `targetId` (S29).
local function showNumber(model: Model, targetId: string, result: DamageText.Result, skill: boolean)
	local style = DamageNumbers.styles[result.style] or DamageNumbers.styles.mine
	local now = os.clock()
	local placement = stack:add(targetId, now, result.style, result.amount)
	if placement.action == "merge" then
		local entry = live[placement.id]
		if entry and not entry.done then
			entry.label.Text = DamageText.sumText(result.style, placement.sum)
			entry.scale.Scale = 1.15
			play(entry, entry.scale, TweenInfo.new(DamageNumbers.popSeconds), { Scale = 1 })
			return
		end
		-- The merged number is gone already: draw a new one.
		stack:release(targetId, placement.id)
		placement = stack:add(targetId, now, "none", result.amount)
	end
	if placement.evict then
		local old = live[placement.evict]
		if old then
			finish(old)
		end
	end
	local size = style.size + (if skill and result.style ~= "dot" then DamageNumbers.skillBonus else 0)
	local entry = floatText(headPosition(model), result.text, styleColor(result), size, {
		base = placement.slot * DamageNumbers.stackStep,
		rise = style.rise,
		dim = style.dim,
		pop = style.pop,
		twitch = result.crit,
		sheen = result.crit or result.style == "heal",
		heavy = result.crit,
	})
	entry.stackId = placement.id
	entry.target = targetId
	live[placement.id] = entry
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
	Clock.tween(h, TweenInfo.new(0.15), { FillTransparency = 1 })
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

-- Destroys an effect part after `seconds` of the effect clock (S110: instead of Debris).
local function destroyLater(instance: Instance, seconds: number)
	Clock.after(seconds, function()
		instance:Destroy()
	end)
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
		if crit then WORLD_GOLD_BRIGHT else Color3.new(1, 1, 1),
		Enum.PartType.Ball
	)
	ball.Transparency = 0.2
	ball.CFrame = CFrame.new(at + Vector3.new((math.random() - 0.5) * 0.8, 0.5, (math.random() - 0.5) * 0.8))
	Clock.tween(ball, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * size,
		Transparency = 1,
	})
	destroyLater(ball, 0.2)
end

-- Short camera kick when we take a heavy (critical) hit or a big skill lands nearby (S28). Scaled by the setting
-- "Camera shake" (settings.shake 0..1, default 1); low effect quality shakes for half as long (S117).
local function shake(strength: number)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local setting = State.Get({ "account", "settings", "shake" })
	strength *= if type(setting) == "number" then math.clamp(setting, 0, 1) else 1
	if not humanoid or strength <= 0.01 then
		return
	end
	local frames = if lowQuality() then 2 else 4
	task.spawn(function()
		for i = 1, frames do
			local fade = 1 - (i - 1) / frames
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
	Clock.tween(arc, TweenInfo.new(0.15), {
		CFrame = base * CFrame.Angles(0, math.rad(50), math.rad(-20)),
		Transparency = 1,
	})
	destroyLater(arc, 0.2)
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
			-- W03: a small hot core; the colour is in the glow sprite and the textured streak (a big neon ball read as a
			-- flat blob under the bloom)
			local orb = effectPart("MagicBolt", Vector3.new(0.45, 0.45, 0.45), WORLD_MAGIC, Enum.PartType.Ball)
			local glow = Instance.new("ParticleEmitter")
			glow.Name = "Glow"
			glow.LightEmission = 1
			glow.Rate = 40
			glow.Lifetime = NumberRange.new(0.12, 0.2)
			glow.Speed = NumberRange.new(0)
			glow.Size = NumberSequence.new(1.1, 0.2)
			glow.Transparency = NumberSequence.new(0.35, 1)
			glow.LockedToPart = true
			if Textures.particle(glow, "glow") then
				glow.Parent = orb
				Clock.track(glow)
			else
				glow:Destroy()
			end
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
			trail.Lifetime = 0.22
			trail.LightEmission = 1
			trail.Transparency = NumberSequence.new(0.15, 1)
			trail.WidthScale = NumberSequence.new(1, 0)
			Textures.trail(trail, "trailSoft")
			trail.Parent = orb
			Clock.track(trail)
			part = orb
		end
	end
	local p = part :: BasePart
	if kind == "magic" then
		local c = color or WORLD_MAGIC
		p.Color = c:Lerp(Color3.new(1, 1, 1), 0.2)
		local glow = p:FindFirstChild("Glow")
		if glow and glow:IsA("ParticleEmitter") then
			glow.Color = ColorSequence.new(c)
			glow.Enabled = not lowQuality()
		end
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

-- Seconds a projectile of `kind` needs for `distance` studs (shared with the server's hit delay).
local flightTime = AttackPose.flightTime

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
		start = Clock.now(),
		duration = flightTime(kind, distance),
		arc = if kind == "arrow" then math.min(4, distance * 0.08) else 0,
		onArrive = onArrive,
	})
end

local function stepFlights()
	if #flights == 0 then
		return
	end
	local now = Clock.now()
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
				Clock.after(0.6, function()
					giveBack(kind, part)
				end)
			else
				if kind == "magic" and not lowQuality() then
					-- W03: a short textured flash and a few sparks instead of a growing neon ball
					local trail = part:FindFirstChildOfClass("Trail")
					local tint = if trail then trail.Color.Keypoints[1].Value else part.Color
					Library.impactFlash(part.Position, 1.4, tint)
					Library.sparks(part.Position, tint, { count = 5, life = { 0.12, 0.25 } })
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

-- Owner 2026-10-21 ("monster attacks are plain"): a monster's basic blow is a bold slash in front of it with sparks
-- and dust at the target; a shot is a glowing orb (or an arrow) with a trail and a flash where it lands.
local MONSTER_SLASH = Color3.fromHex("#FFE2B0")
local MONSTER_MAGIC = Color3.fromHex("#C77BFF")

local function monsterMelee(attacker: Model, target: Model)
	local from = centre(attacker)
	local to = centre(target)
	local direction = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	if direction.Magnitude < 0.1 then
		return
	end
	local simple = lowQuality()
	local reach = math.clamp(direction.Magnitude * 0.6, 2.5, 6)
	local frame = CFrame.lookAt(from, from + direction) * CFrame.new(0, 0.4, 0)
	Library.slash(frame, reach, 70, -70, MONSTER_SLASH, if math.random() < 0.5 then 25 else -25, simple)
	Clock.after(0.1, function()
		local hit = centre(target)
		Library.sparks(hit, MONSTER_SLASH, { simple = simple, dir = -direction.Unit, count = 8 })
		Library.impactFlash(hit, 1.6, MONSTER_SLASH, { simple = simple })
	end)
end

local function monsterShot(attacker: Model, target: Model, style: string)
	if style == "arrow" then
		projectile(attacker, target, style)
		return
	end
	local simple = lowQuality()
	local from = centre(attacker) + Vector3.new(0, 1, 0)
	Library.projectile(from, target, "orb", MONSTER_MAGIC, {
		simple = simple,
		size = 1.2,
		flame = true,
		onArrive = function(point: Vector3)
			Library.impactFlash(point, 2.2, MONSTER_MAGIC, { simple = simple })
			Library.sparks(point, MONSTER_MAGIC, { simple = simple, count = 8 })
		end,
	})
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

-- Small glow growing at the tip of a wand / staff during the windup.
local function charge(weapon: BasePart?, color: Color3, seconds: number)
	local at = attachmentPosition(weapon, "VaelthornTip")
	if not at or lowQuality() then
		return
	end
	-- W03: a small core that brightens and a soft glow sprite round it (the colour lives in the glow)
	local spark = effectPart("Charge", Vector3.one * 0.15, color:Lerp(Color3.new(1, 1, 1), 0.2), Enum.PartType.Ball)
	spark.CFrame = CFrame.new(at)
	spark.Transparency = 0.3
	local glow = Instance.new("ParticleEmitter")
	glow.Color = ColorSequence.new(color)
	glow.LightEmission = 1
	glow.Rate = 30
	glow.Lifetime = NumberRange.new(0.12, 0.2)
	glow.Speed = NumberRange.new(0)
	glow.Size = NumberSequence.new(0.9, 0.2)
	glow.Transparency = NumberSequence.new(0.4, 1)
	if Textures.particle(glow, "glow") then
		glow.Parent = spark
		Clock.track(glow)
	else
		glow:Destroy()
	end
	Clock.tween(spark, TweenInfo.new(seconds), { Size = Vector3.one * 0.5, Transparency = 0.1 })
	destroyLater(spark, seconds)
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
	Clock.tween(ring, TweenInfo.new(0.3), { Size = Vector3.new(0.2, 7, 7), Transparency = 1 })
	destroyLater(ring, 0.35)
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
	Clock.tween(ball, TweenInfo.new(0.25), { Size = Vector3.one * 4, Transparency = 1 })
	destroyLater(ball, 0.3)
end

local HOLY = { holystaff = true, scepter = true }
local DUST_TINT = Color3.fromHex(HitFx.smashTint) -- S113: the smoke of a smash

-- S111: the entity id of a model (the per-source cooldown of its sounds), else its name.
local function sourceOf(model: Model): string
	local id = model:GetAttribute("EntityId")
	return if type(id) == "string" then id else model.Name
end

-- S111 / S113: the sounds of a basic attack on the effect clock (keys: Logic/SfxRules.attackKeys of the combo step):
-- `start` at 0, the swing at the start of the blow (the end of the windup; with a clip just before the hit). The
-- release plays with the hit itself (onHit in attackFx). With a clip: ClipFit.SWING_LEAD / TRAIL_AFTER.

local function attackSounds(attacker: Model, keys: SfxRules.AttackKeys, timing: AttackPose.Timing, clipped: boolean)
	local who = SfxController.WhoOf(attacker)
	local source = sourceOf(attacker)
	if keys.start then
		SfxController.After(0, keys.start, attacker, who, source)
	end
	if keys.swing then
		local at = if clipped then math.max(0, timing.hitAt - ClipFit.SWING_LEAD) else timing.windup
		SfxController.After(at, keys.swing, attacker, who, source)
	end
end

-- The rarity colour of a held weapon (attribute Accent), white without one.
local function accentOf(weapon: BasePart?): Color3
	local accent = weapon and weapon:GetAttribute("Accent")
	return if typeof(accent) == "Color3" then accent else Color3.new(1, 1, 1)
end

-- S113: the basic attack's weapon trail (Vfx/Library.weaponTrail basic): the step's window, or the default one
-- (windup - 0.02 .. windup + strike + 0.04); with a clip from the start until just after the hit. None on low quality.
local function attackTrail(
	attacker: Model,
	weapon: BasePart,
	motion: string,
	timing: AttackPose.Timing,
	clipped: boolean
)
	if lowQuality() then
		return
	end
	local step = AttackPose.step(motion, timing.step)
	local from, to
	if clipped then
		from, to = 0, timing.hitAt + ClipFit.TRAIL_AFTER
	elseif step.trail then
		local k = if step.windup > 0 then timing.windup / step.windup else 1
		from, to = step.trail.from * k, step.trail.to * k
	else
		from, to = math.max(0, timing.windup - 0.02), timing.windup + timing.strike + 0.04
	end
	Library.weaponTrail(attacker, accentOf(weapon), from, to, {
		basic = true,
		base = AttackMotions.TRAIL.baseByMotion[motion] or AttackMotions.TRAIL.base,
	})
end

-- A character's basic attack (S22): the pose and the weapon effects. FIX 2026-10-09: the server sends the damage
-- when the blow lands or the shot arrives (AttackPose.hitDelay), so numbers are no longer held back here. S113: the
-- combo step and the effects of the hit's moment as onHit; `target` nil in previews (no target effects, no shot);
-- `step` forces a combo step (AnimLab).
local function attackFx(
	attacker: Model,
	target: Model?,
	weaponType: string?,
	melee: boolean,
	element: string?,
	step: number?
)
	local weapon = weaponOf(attacker)
	local motion = AttackPose.motionFor(weaponType)
	-- the event's style decides (a weaponless Hunter / Mage shoots too: motion "unarmed", kind "magic")
	local ranged = not melee
	local kind = if motion == "bow" then "arrow" elseif motion == "crossbow" then "bolt" else "magic"
	local color = ELEMENT_COLORS[element or ""] or WORLD_MAGIC
	local release: string? = nil
	local function onHit()
		if release then
			SfxController.Play(release, attacker, SfxController.WhoOf(attacker), sourceOf(attacker))
		end
		if not target or not target.Parent or not attacker.Parent then
			return
		end
		if ranged then
			-- arrows from the bow's grip, bolts and magic from the tip, at the release moment
			local from = attachmentPosition(
				weaponOf(attacker),
				if kind == "arrow" then "VaelthornGrip" else "VaelthornTip"
			) or centre(attacker) + Vector3.new(0, 0.8, 0)
			launch(kind, from, target, color, nil)
			return
		end
		if motion == "smash" then
			dust(target)
			if not lowQuality() then
				Library.smokePuff(centre(target), HitFx.puffSize, DUST_TINT)
			end
		end
		if weaponType and HOLY[weaponType] then
			holyFlash(target)
		end
	end
	local timing, clipped = AnimationController.Attack(attacker, weaponType, nil, onHit, step)
	local keys = SfxRules.attackKeys(motion, timing.step)
	release = keys.release
	attackSounds(attacker, keys, timing, clipped)
	if ranged or AttackPose.projectile(motion) then
		if kind == "magic" and AttackPose.projectile(motion) then
			charge(weapon, color, timing.hitAt)
		end
		return
	end
	if motion == "unarmed" or not weapon then
		if target then
			Clock.after(timing.hitAt * 0.7, swing, attacker, target)
		end
	else
		attackTrail(attacker, weapon, motion, timing, clipped)
	end
end

local function playerAttack(attacker: Model, target: Model, event: { [string]: any })
	local camera = Workspace.CurrentCamera
	if camera and (centre(attacker) - camera.CFrame.Position).Magnitude > Config.EffectRadius then
		return
	end
	local weaponType = if type(event.w) == "string" then event.w else nil
	attackFx(attacker, target, weaponType, event.st == "melee", if type(event.el) == "string" then event.el else nil)
end

-- S113 hit sparks ----------------------------------------------------------------------------------------------

-- The hit material of a model: a monster's (SfxController.Mob: look, family, else flesh), a player's HitFx.player.
local function materialOf(model: Model): string
	local info = SfxController.Mob(model)
	if info then
		return info.material
	end
	return if model:GetAttribute("MonsterId") ~= nil then HitFx.default else HitFx.player
end

-- Sparks of a basic hit by the target's material, sprayed back towards the attacker and up from the target's surface
-- on the attacker's side; a gold flash on a critical. Returns false when the texture is missing (the caller keeps
-- the old impact burst).
local function hitSparks(model: Model, from: Vector3?, material: string, crit: boolean): boolean
	local spark = HitFx.byMaterial[material] or HitFx.byMaterial[HitFx.default]
	if not Textures.id(spark.key) then
		return false
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local middle = centre(model)
	local radius = if root and root:IsA("BasePart") then math.max(root.Size.X, root.Size.Z) / 2 else 1
	local away = if from then Vector3.new(middle.X - from.X, 0, middle.Z - from.Z) else Vector3.zero
	local d = if away.Magnitude > 0.05 then away.Unit else Vector3.zero
	local at = middle - d * HitFx.surface * radius + Vector3.new(0, 0.4, 0)
	local dir = (-d + Vector3.new(0, 0.6, 0)).Unit
	local simple = lowQuality()
	local count = spark.count * (if crit then HitFx.crit.countMul else 1)
	Library.sparks(at, Color3.fromHex(spark.color), {
		key = spark.key,
		dir = dir,
		count = math.max(1, math.floor(count + 0.5)),
		simple = simple,
		speed = spark.speed,
		life = spark.life,
		gravity = spark.gravity,
	})
	if crit then
		Library.impactFlash(at, HitFx.flashSize * HitFx.crit.flashScale, WORLD_GOLD_BRIGHT, { simple = simple })
	elseif spark.flash then
		Library.impactFlash(at, HitFx.flashSize, Color3.new(1, 1, 1), { simple = simple })
	end
	if spark.puff and not simple then
		Library.smokePuff(at, HitFx.puffSize, Color3.fromHex(spark.color))
	end
	return true
end

-- Telegraphs -----------------------------------------------------------------------------------------------------
-- S117 (telegraphs 2.0, Vfx/GroundTelegraph + Logic/Telegraph): the area fills from its edge to its centre in step with
-- the caster's gather (both start in this frame with the same clamped windup), flashes at the blow and fades; the
-- warning sounds once per attack (the areas of one attack share its id `a`), the blow plays the attack's sound and
-- effect on every area (an Elite II by its shape and element, a boss by Data/BossMotions) and shakes the camera of
-- players near a boss (Config.Telegraph.shakeRange).

local TELE_GROUP = 0.1 -- seconds: telegraphs of one caster and attack within this are one attack (count, "all")
local BOSS_DEATH_SHAKE = 0.5 -- the camera shake when a boss dies (E7)
local METEOR_FALL = 0.45 -- seconds a boss meteor falls (it lands at the hit)
local BOLT_FLIGHT = 0.25 -- seconds a boss bolt flies from the hand (it arrives at the hit)
local ICE = Color3.fromHex("#BDE9FF")

-- The last start of each caster's attack (sound and pose once per attack).
local teleGroups: { [string]: number } = {}

local function groupKey(event: { [string]: any }): string
	return `{tostring(event.e)}:{tostring(event.a)}`
end

-- True for the first telegraph of an attack, false for its other areas.
local function firstOfGroup(event: { [string]: any }): boolean
	local key = groupKey(event)
	local now = Clock.now()
	local last = teleGroups[key]
	if last and now - last < TELE_GROUP then
		return false
	end
	teleGroups[key] = now
	for other, at in teleGroups do
		if now - at >= TELE_GROUP then
			teleGroups[other] = nil
		end
	end
	return true
end

-- What the event's attack is: the boss motion (nil for Elite II), the boss id, the magic kind.
local function attackInfo(event: { [string]: any }, caster: Model?): (BossMotions.BossAttackMotion?, string?, boolean)
	local a = if type(event.a) == "string" then event.a else nil
	local bossId: string? = nil
	if caster then
		local id = caster:GetAttribute("MonsterId") or caster:GetAttribute("PreviewMonsterId")
		if type(id) == "string" and Bosses.get(id) then
			bossId = id
		end
	end
	if bossId and a then
		local boss = Bosses.get(bossId)
		local magic = false
		if boss then
			for _, attack in boss.attacks do
				if attack.id == a then
					magic = attack.damageKind == "magic"
				end
			end
		end
		return BossMotions.attack(bossId, a), bossId, magic
	end
	local ability = if a then MonsterAbilities.get(a) else nil
	if ability then
		return nil, nil, ability.damageKind == "magic"
	end
	-- without an id (an old server): an element on a round area reads as a spell
	return nil, nil, false
end

local function playerRoot(): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- A boss's camera shake: `strength` at the point, fading to nothing at Config.Telegraph.shakeRange studs.
local function shakeNear(at: Vector3, strength: number)
	local root = playerRoot()
	if not root or strength <= 0 then
		return
	end
	local d = (root.Position - at).Magnitude
	local k = 1 - d / Config.Telegraph.shakeRange
	if k > 0 then
		shake(strength * k)
	end
end

-- The effect of a boss attack on one area at the blow (Data/BossMotions impact).
local function bossImpact(
	motion: BossMotions.BossAttackMotion,
	event: { [string]: any },
	color: Color3,
	simple: boolean
)
	local area = event.cf :: CFrame
	local at = area.Position
	local r = tonumber(event.r) or 8
	local impact = motion.impact or "none"
	if impact == "slash" then
		if event.sh == "cone" then
			Library.cone(area, r, tonumber(event.an) or 90, color, simple)
		elseif event.sh == "line" then
			local l = tonumber(event.l) or 15
			Library.dash(at + Vector3.new(0, 1, 0), (area * CFrame.new(0, 1, -l)).Position, color, simple)
		else
			Library.slash(area * CFrame.new(0, 1, 0), r, 60, -60, color, 0, simple)
		end
	elseif impact == "shockwave" then
		Library.impactFlash(at + Vector3.new(0, 1, 0), 4, color, { simple = simple })
		Library.shockwave(at, r, color, 0.45, simple)
	elseif impact == "cracks" then
		Library.cracks(at, r * 0.7, color, 1.4, simple)
	elseif impact == "ringWave" then
		Library.ringWave(at, r, color, { simple = simple })
	elseif impact == "pillar" then
		if event.sh == "line" then
			local l = tonumber(event.l) or 15
			local count = if simple then 2 else 4
			for i = 1, count do
				Library.pillar((area * CFrame.new(0, 0, -l * (i - 0.5) / count)).Position, 2, 8, color, 0.6)
			end
		else
			Library.pillar(at, math.min(r, 4), 9, color, 0.6)
		end
	elseif impact == "breath" then
		Library.cone(area, r, tonumber(event.an) or 60, color, simple)
		if not simple then
			Library.sparks(at + area.LookVector * (r * 0.5) + Vector3.new(0, 1, 0), color, {
				key = "iceShard",
				dir = area.LookVector,
				count = 10,
			})
		end
	elseif impact == "rune" then
		Library.magicCircle(at, r, color, 0.8, { simple = simple })
	end
	-- meteor and bolt start before the blow (scheduleBossImpact); they land / arrive at it
	if motion.cracks then
		Library.cracks(at, r * 0.6, color, 1.6, simple)
	end
end

-- A caster killed in its windup (Dead, or its model gone) lands no blow: the server drops the cast. A caster that has not
-- streamed in (nil) still gets its effects.
local function casterGone(caster: Model?): boolean
	return caster ~= nil and (caster.Parent == nil or caster:GetAttribute("Dead") == true)
end

-- Meteors and bolts of a boss: they must land at the server's hit, so they start before the end of the windup.
local function scheduleBossImpact(
	motion: BossMotions.BossAttackMotion,
	event: { [string]: any },
	caster: Model?,
	windup: number,
	color: Color3,
	simple: boolean
)
	local area = event.cf :: CFrame
	local at = area.Position
	local r = tonumber(event.r) or 8
	if motion.impact == "meteor" then
		local fall = math.min(METEOR_FALL, windup)
		local tint = if event.el == "ice" then ICE else color
		Clock.after(windup - fall, function()
			if casterGone(caster) then
				return
			end
			Library.meteor(at, r, fall, tint, simple)
		end)
	elseif motion.impact == "bolt" and caster then
		local flight = math.min(BOLT_FLIGHT, windup)
		Clock.after(windup - flight, function()
			if casterGone(caster) then
				return
			end
			local from = centre(caster) + Vector3.new(0, 1.5, 0)
			Library.projectile(from, at + Vector3.new(0, 1, 0), "orb", color, {
				simple = simple,
				time = flight,
				onArrive = function(point: Vector3)
					Library.impactFlash(point, 3, color, { simple = simple })
				end,
			})
		end)
	end
end

-- Owner 2026-10-21: the size of a caster for its charge-up (1 a man, up to 3 a big boss).
local function casterSize(caster: Model): number
	local ok, size = pcall(function()
		local _, s = caster:GetBoundingBox()
		return s
	end)
	if not ok or typeof(size) ~= "Vector3" then
		return 1
	end
	return math.clamp(math.max(size.X, size.Y, size.Z) / 5, 0.8, 4.5)
end

-- The effect of an Elite II ability at the blow (D5): by shape, in the element's colour, a flash in the middle.
local function eliteImpact(event: { [string]: any }, color: Color3, simple: boolean)
	local area = event.cf :: CFrame
	local at = area.Position
	local r = tonumber(event.r) or 8
	if event.sh == "cone" then
		Library.cone(area, r, tonumber(event.an) or 90, color, simple)
	elseif event.sh == "line" then
		local l = tonumber(event.l) or 15
		Library.dash(at + Vector3.new(0, 1, 0), (area * CFrame.new(0, 1, -l)).Position, color, simple)
	elseif event.sh == "ring" then
		Library.ringWave(at, r, color, { simple = simple })
	else
		Library.shockwave(at, r, color, 0.45, simple)
		Library.impactFlash(at + Vector3.new(0, 1, 0), math.clamp(r * 0.4, 2, 5), color, { simple = simple })
	end
end

-- S111 / S117: the warning at the area (louder when we stand in it) once per attack.
local function warnSound(event: { [string]: any }, area: CFrame)
	local who: SfxRules.Who = "other"
	local root = playerRoot()
	if root then
		local localPos = area:PointToObjectSpace(root.Position)
		local inside = Telegraph.contains(event.sh, {
			r = tonumber(event.r),
			ir = tonumber(event.ir),
			an = tonumber(event.an),
			l = tonumber(event.l),
			w = tonumber(event.w),
		}, localPos.X, localPos.Z, localPos.Y)
		if inside then
			who = "party"
		end
	end
	SfxController.Play("telegraph.warn", area.Position, who, if type(event.e) == "string" then event.e else nil)
end

-- S134 (bosses 2.0): the boss mechanics of a "tele" event (field `m`) -----------------------------------------------

local MECHANIC_COLORS: { [string]: Color3 } = {
	split = Color3.fromHex(Config.Telegraph.mechanicColors.split),
	mark = Color3.fromHex(Config.Telegraph.mechanicColors.mark),
}
-- The marked players' purple glow: a few pooled Highlights (Roblox draws 31 at once).
local MARK_GLOWS = 4
local markGlows: { { highlight: Highlight, untilAt: number } } = {}

local function markGlow(model: Model, seconds: number)
	local root = playerRoot()
	local own = model == player.Character
	local markRoot = model:FindFirstChild("HumanoidRootPart")
	if not own then
		if not root or not markRoot or not markRoot:IsA("BasePart") then
			return
		end
		if (markRoot.Position - root.Position).Magnitude > Config.Telegraph.markRange then
			return
		end
	end
	local now = Clock.now()
	local slot: { highlight: Highlight, untilAt: number }? = nil
	for _, glow in markGlows do
		if glow.highlight.Adornee == model or glow.untilAt <= now then
			slot = glow
			break
		end
	end
	if not slot then
		if #markGlows >= MARK_GLOWS then
			return
		end
		local created = Instance.new("Highlight")
		created.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		created.Parent = guiFolder
		local fresh = { highlight = created, untilAt = 0 }
		table.insert(markGlows, fresh)
		slot = fresh
	end
	local glow = slot :: { highlight: Highlight, untilAt: number }
	local h = glow.highlight
	h.Adornee = model
	h.FillColor = MECHANIC_COLORS.mark
	h.OutlineColor = MECHANIC_COLORS.mark
	h.FillTransparency = 0.6
	h.OutlineTransparency = 0.1
	h.Enabled = true
	glow.untilAt = now + seconds
	Clock.after(seconds, function()
		if glow.untilAt <= Clock.now() + 0.01 and h.Adornee == model then
			h.Enabled = false
			h.Adornee = nil
		end
	end)
end

-- A cancelled mark: its glow goes at once.
local function markUnglow(model: Model)
	for _, glow in markGlows do
		if glow.highlight.Adornee == model then
			glow.untilAt = 0
			glow.highlight.Enabled = false
			glow.highlight.Adornee = nil
		end
	end
end

-- The key of a mark's telegraph (its caster, attack and marked entity; the server's "teleCancel" names the same
-- three). S149: with the marked entity in the key, one cancelled mark of a multi-mark attack leaves the others.
local function markKey(event: { [string]: any }): string?
	if type(event.e) == "string" and type(event.a) == "string" then
		return if type(event.f) == "string" then `{event.e}|{event.a}|{event.f}` else `{event.e}|{event.a}`
	end
	return nil
end

-- The "Together" label over a split circle for its windup.
local function splitTag(area: CFrame, windup: number)
	local anchor = Instance.new("Part")
	anchor.Name = "SplitTag"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = area * CFrame.new(0, Config.Telegraph.tagHeight, 0)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 48)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 250
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = Text.now("boss.mechanic.split.tag")
	label.FontFace = Theme.Fonts.Display
	label.TextScaled = true
	label.TextColor3 = MECHANIC_COLORS.split
	label.TextStrokeTransparency = 0.2
	label.Parent = gui
	anchor.Parent = guiFolder
	Clock.after(windup + 0.3, function()
		anchor:Destroy()
	end)
end

-- One "tele" event (or an AnimLab preview): the ground telegraph, the warning, the blow's sound, effect and shake.
local function telegraph(event: { [string]: any }, caster: Model?)
	local area = event.cf
	if typeof(area) ~= "CFrame" or type(event.sh) ~= "string" then
		return
	end
	local shape = event.sh :: string
	if shape ~= "circle" and shape ~= "cone" and shape ~= "line" and shape ~= "ring" then
		return
	end
	local windup = Telegraph.windup(tonumber(event.t))
	local color = ELEMENT_COLORS[event.el or ""] or TELEGRAPH_COLOR
	local motion, bossId, magic = attackInfo(event, caster)
	-- S134: the boss mechanics: a channel has no area (the boss only poses), a split is golden with its label, a mark
	-- is purple, follows the marked character and makes it glow, a big blow to dodge has a thicker rim
	local mechanic = if type(event.m) == "string" then event.m else nil
	if mechanic == "channel" then
		SfxController.Play("boss.mechanic.channel", area.Position, "party")
		return
	end
	local follow: Model? = nil
	local key: string? = nil
	-- S134e: a lethal blow (an Elite II's Crushing Blow, field `x`): dark crimson, the thick rim, a faster pulse
	local lethal = event.x == true
	if lethal then
		color = LETHAL_COLOR
	end
	if mechanic == "split" then
		color = MECHANIC_COLORS.split
		splitTag(area, windup)
		SfxController.Play("boss.mechanic.split", area.Position, "party")
	elseif mechanic == "mark" then
		color = MECHANIC_COLORS.mark
		follow = findModel(if type(event.f) == "string" then event.f else nil)
		key = markKey(event)
		if follow then
			markGlow(follow, windup)
		end
		SfxController.Play("boss.mechanic.mark", if follow then follow else area.Position, "party")
	end
	local first = firstOfGroup(event)
	local low = lowQuality()
	local camera = Workspace.CurrentCamera
	local far = camera ~= nil and (area.Position - camera.CFrame.Position).Magnitude > Config.Vfx.simpleBeyond * 2
	local simpleFx = low or far
	if first then
		warnSound(event, area)
	end
	if motion then
		scheduleBossImpact(motion, event, caster, windup, color, simpleFx)
	end
	-- owner 2026-10-21: the blow gathers on the caster, the danger area comes alive and a spell or a thrown blow flies
	-- in as a volley that lands with the flash
	if first and caster and mechanic ~= "split" then
		Library.charge(caster, color, windup, casterSize(caster), simpleFx)
	end
	local reach = tonumber(event.r) or tonumber(event.l) or 6
	Library.dangerMotes(area.Position, if shape == "line" then math.min(reach, 8) else reach, color, windup, simpleFx)
	local impactKind = if motion then motion.impact else nil
	local flies = impactKind ~= "meteor" and impactKind ~= "bolt" and impactKind ~= "breath" and impactKind ~= "slash"
	if caster and flies and (shape == "circle" or shape == "ring") and windup >= 0.6 and reach >= 4 then
		local from = centre(caster) + Vector3.new(0, 2, 0)
		local far = (Vector3.new(area.Position.X, from.Y, area.Position.Z) - from).Magnitude
		if magic or far > reach + 2 then
			local count = math.clamp(math.floor(reach / 2.5), 3, if motion then 8 else 5)
			Library.volley(from, area.Position, reach, count, windup, color, if magic then "orb" else "rock", simpleFx)
		end
	end
	GroundTelegraph.start({
		shape = shape :: any,
		dims = {
			r = tonumber(event.r),
			ir = tonumber(event.ir),
			an = tonumber(event.an),
			l = tonumber(event.l),
			w = tonumber(event.w),
		},
		area = area,
		windup = windup,
		color = color,
		magic = magic,
		low = low,
		follow = follow,
		rimWidth = if mechanic == "avoid" or lethal then Config.Telegraph.rimWidthAvoid else nil,
		key = key,
		pulseFast = if lethal then Config.Telegraph.pulseLethal else nil,
		onBlow = function()
			if casterGone(caster) then
				return
			end
			-- S134: a mark blasts where the marked character stands now
			local blow = event
			local followRoot = follow and follow:FindFirstChild("HumanoidRootPart")
			if followRoot and followRoot:IsA("BasePart") then
				blow = table.clone(event)
				local p = followRoot.Position
				blow.cf = CFrame.new(p.X, area.Position.Y, p.Z)
			end
			if motion then
				bossImpact(motion, blow, color, simpleFx)
			else
				eliteImpact(event, color, simpleFx)
			end
			-- owner 2026-10-21: every blow throws something up: debris and dust for a physical one, the element's blast
			-- for a spell
			if not simpleFx then
				local blowAt = (blow.cf :: CFrame).Position
				local big = math.clamp((tonumber(event.r) or 6) / 6, 0.6, 1.8)
				if magic then
					local el = event.el
					if el == "fire" then
						Library.fireBlast(blowAt + Vector3.new(0, 1, 0), 2.5 * big, color, {})
					elseif el == "ice" then
						Library.frostBlast(blowAt + Vector3.new(0, 1, 0), 2.5 * big, color, {})
					elseif el == "lightning" then
						Library.arcBurst(blowAt + Vector3.new(0, 1, 0), 2.5 * big, color, {})
					else
						Library.holyBurst(blowAt + Vector3.new(0, 1, 0), 2.2 * big, color, {})
					end
				else
					Library.rockBurst(blowAt, math.min(tonumber(event.r) or 6, 8), big, color, {})
				end
				Library.dust(blowAt, 2 * big, false)
			end
			if not first then
				return
			end
			if motion then
				shakeNear(area.Position, motion.shake or 0)
			end
			local info = if caster then SfxController.Mob(caster) else nil
			if caster and info then
				local key = if motion and motion.sound
					then motion.sound
					elseif bossId then `boss.{bossId}.attack`
					else `mob.{info.family}.attack`
				SfxController.Play(key, caster, SfxController.WhoOf(caster), sourceOf(caster))
			end
		end,
	})
end

-- S134: a boss mark gone before its blast ("teleCancel"): its circle and glow stop, no blow.
local function cancelMark(event: { [string]: any })
	local key = markKey(event)
	if key then
		-- without the marked entity (gone already) every mark of this caster and attack goes, as before S149
		GroundTelegraph.cancel(key, type(event.f) ~= "string")
	end
	local follow = findModel(if type(event.f) == "string" then event.f else nil)
	if follow then
		markUnglow(follow)
	end
end

-- S134: an unbroken channel lands on everyone ("blow", no ground telegraph): the attack's effect and shake at the
-- boss and its sound.
local function channelBlow(event: { [string]: any })
	if typeof(event.cf) ~= "CFrame" then
		return
	end
	local caster = findModel(event.e)
	if casterGone(caster) then
		return
	end
	local motion, bossId = attackInfo(event, caster)
	if not motion then
		return
	end
	local area = event.cf :: CFrame
	local color = ELEMENT_COLORS[event.el or ""] or TELEGRAPH_COLOR
	local camera = Workspace.CurrentCamera
	local far = camera ~= nil and (area.Position - camera.CFrame.Position).Magnitude > Config.Vfx.simpleBeyond * 2
	bossImpact(motion, event, color, lowQuality() or far)
	shakeNear(area.Position, motion.shake or 0)
	if caster and bossId then
		local key = motion.sound or `boss.{bossId}.attack`
		SfxController.Play(key, caster, SfxController.WhoOf(caster), sourceOf(caster))
	end
end

-- S117 (E4): a boss's new phase: the camera of players near it shakes (Data/BossMotions roar), its aura flashes in the
-- look's glow for Config.MonsterLook.phaseLight s.
local function onRoar(model: Model, bossId: string?)
	local def = if bossId then BossMotions.get(bossId) else nil
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	if def then
		shakeNear(root.Position, def.roar.shake)
	end
	if lowQuality() or not Pool.takeLight() then
		return
	end
	local lookId = model:GetAttribute("Look") or bossId
	local look = if type(lookId) == "string" then MonsterLooks.get(lookId) else nil
	local boss = if bossId then Bosses.get(bossId) else nil
	local hex = (look and look.glow) or (boss and boss.look.aura) or "#FFD27A"
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex(hex)
	light.Range = 24
	light.Brightness = 0
	light.Parent = root
	local seconds = Config.MonsterLook.phaseLight
	Clock.tween(light, TweenInfo.new(seconds * 0.3), { Brightness = 5 })
	Clock.after(seconds * 0.3, function()
		Clock.tween(light, TweenInfo.new(seconds * 0.7), { Brightness = 0 })
	end)
	Clock.after(seconds + 0.05, function()
		light:Destroy()
		Pool.dropLight()
	end)
end

-- Dispatcher ---------------------------------------------------------------------------------------------

-- S28: the name of a skill shows once per cast (its first hit within NAME_EVERY seconds).
local NAME_EVERY = 1.2
local namedAt: { [string]: number } = {}

-- S111: the sound of a hit: the target's material (monster family / look; S113: players HitFx.player; a material
-- without a sound falls back to hit.flesh) plus hit.crit on a
-- critical, the pain of a monster that survived (bosses roar only on phases); blocked -> block, a dodge or a miss ->
-- miss, absorbed / immune -> a quieter block. DoT ticks and heals are silent. The priority is the higher of the
-- target's and the attacker's (a hit on us is ours).
local ABSORBED_VOLUME = 0.6

local function hitSounds(model: Model, event: { [string]: any }, result: DamageText.Result)
	local attackerId = if type(event.s) == "string" then event.s elseif type(event.by) == "string" then event.by else nil
	local who = SfxController.Higher(SfxController.WhoOf(model), SfxController.WhoOf(findModel(attackerId)))
	if result.amount > 0 and not event.dot then
		local info = SfxController.Mob(model)
		SfxController.Play(SfxRules.hitKey(materialOf(model), Sfx.playable), model, who)
		if event.c then
			SfxController.Play("hit.crit", model, who)
		end
		if info and not info.boss and model:GetAttribute("Dead") ~= true then
			SfxController.Play(`mob.{info.family}.hurt`, model, who, sourceOf(model))
		end
	elseif result.style == "blocked" then
		SfxController.Play("block", model, who)
	elseif result.style == "dodge" then
		SfxController.Play("miss", model, who)
	elseif result.style == "absorbed" or result.style == "immune" then
		SfxController.Play("block", model, who, nil, ABSORBED_VOLUME)
	end
end

local function onDamage(event: { [string]: any })
	local model = findModel(event.e)
	if not model then
		return
	end
	local isMe = model == player.Character
	local me = myEntityId()
	local result = DamageText.format(event, me)
	local amount = result.amount
	local skill = if type(event.sk) == "string" then SkillData.get(event.sk) else nil
	hitSounds(model, event, result)
	-- DoT ticks get no flash or hit reaction, just the small number.
	if amount > 0 and not event.dot then
		-- A critical skill hit flashes gold (S28).
		flash(model, if skill and event.c then WORLD_GOLD_BRIGHT else nil)
		-- S113: the attacker's position turns the reaction away from the blow and aims the sparks of a basic hit
		local attacker = findModel(if type(event.s) == "string" then event.s else nil)
		local from = if attacker then centre(attacker) else nil
		local camera = Workspace.CurrentCamera
		local near = not camera or (centre(model) - camera.CFrame.Position).Magnitude <= Config.EffectRadius
		local sparked = false
		if event.sk == nil and near then
			sparked = hitSparks(model, from, materialOf(model), event.c == true)
		end
		if not sparked then
			impact(model, event.c == true)
		end
		AnimationController.MonsterHit(model, from)
		if model:GetAttribute("MonsterId") == nil then
			AnimationController.CharacterHit(model, from, event.c == true)
		end
		if isMe and event.c then
			shake(0.35)
		end
	elseif event.ab or event.im then
		flash(model, SHIELD_FLASH)
	end
	if result.style == "none" or type(event.e) ~= "string" then
		return
	end
	if not DamageText.visible(event, me, numberMode()) then
		return
	end
	showNumber(model, event.e, result, skill ~= nil)
	if skill and amount > 0 and not isMe then
		local key = `{event.s or event.by or "?"}:{skill.id}`
		local now = os.clock()
		if now - (namedAt[key] or 0) > NAME_EVERY then
			namedAt[key] = now
			floatText(
				headPosition(model) + Vector3.new(0, 1.2, 0),
				Text.now(skill.nameKey),
				WORLD_GOLD,
				18,
				{ base = DamageNumbers.maxPerTarget * DamageNumbers.stackStep * 0.5, rise = 3.5 }
			)
		end
	end
end

local function onHeal(event: { [string]: any })
	local model = findModel(event.e)
	if not model or type(event.e) ~= "string" then
		return
	end
	local me = myEntityId()
	local result = DamageText.format(event, me)
	if result.style == "none" or not DamageText.visible(event, me, numberMode()) then
		return
	end
	showNumber(model, event.e, result, false)
end

-- S65: flashes of item traits: "arc" (Elemental Spark jump) and "runThrough" (Run Through streak), s -> t.
local RUN_THROUGH_COLOR = Color3.fromHex("#E8E4D8")

local function modelCentre(model: Model): Vector3?
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else nil
end

local function traitFx(event: { [string]: any })
	local from = findModel(event.s)
	local to = findModel(event.t)
	local a = from and modelCentre(from)
	local b = to and modelCentre(to)
	if not a or not b then
		return
	end
	local simple = State.Get({ "account", "settings", "quality" }) == "low"
	if event.v == "arc" then
		Library.lightning(a, b, ELEMENT_COLORS.lightning, 0.3, simple)
	elseif event.v == "runThrough" then
		Library.lineBeam(a, b, RUN_THROUGH_COLOR, simple)
	end
end

local function handle(event: { [string]: any })
	local kind = event.k
	if kind == "dmg" then
		onDamage(event)
	elseif kind == "heal" then
		onHeal(event)
	elseif kind == "atk" then
		local attacker = findModel(event.s)
		local target = findModel(event.t)
		if attacker and target then
			if attacker:GetAttribute("MonsterId") ~= nil then
				AnimationController.MonsterAttack(attacker, nil, true)
				if event.st == "melee" then
					monsterMelee(attacker, target)
				else
					monsterShot(attacker, target, event.st)
				end
				-- S111: the family's attack sound at once (a basic monster attack lands with the event)
				local info = SfxController.Mob(attacker)
				if info then
					local who = SfxController.Higher(SfxController.WhoOf(attacker), SfxController.WhoOf(target))
					SfxController.Play(`mob.{info.family}.attack`, attacker, who, sourceOf(attacker))
				end
			else
				playerAttack(attacker, target, event)
			end
		end
	elseif kind == "trait" then
		traitFx(event)
	elseif kind == "tele" then
		-- S117: the telegraph and the caster's gather start in this frame with the same windup (pose by the id `a`)
		local caster = findModel(event.e)
		telegraph(event, caster)
		if caster then
			AnimationController.MonsterAttack(
				caster,
				tonumber(event.cw) or tonumber(event.t), -- S134: a mark's gesture is shorter than its circle
				false,
				if type(event.a) == "string" then event.a else nil,
				if typeof(event.cf) == "CFrame" then event.cf else nil
			)
		end
	elseif kind == "teleCancel" then
		cancelMark(event) -- S134
	elseif kind == "blow" then
		channelBlow(event) -- S134
	elseif kind == "reward" then
		local character = player.Character
		-- S111: the gold of the reward clinks once
		if (tonumber(event.gold) or 0) > 0 then
			SfxController.Ui("ui.coin")
		end
		if character then
			-- S109: a reward without EXP (contracts 1-3, firstSpring) shows the gold alone
			local exp = tonumber(event.exp) or 0
			local text = Text.now(
				if exp > 0 then "combat.reward" else "combat.rewardGold",
				{ exp = Format.number(exp), gold = Format.number(event.gold or 0) }
			)
			-- S134k: the Hunter's Marks of handed in hunting contracts
			local marks = tonumber(event.marks) or 0
			if marks > 0 then
				text ..= "  " .. Text.now("combat.rewardMarks", { n = Format.number(marks) })
			end
			floatText(headPosition(character) + Vector3.new(0, 1, 0), text, WORLD_GOLD, 22, { rise = 4 })
		end
		-- Boss kill (S30): the reward card with the personal roll and the grind progress.
		if type(event.boss) == "string" then
			DungeonController.ShowReward({
				boss = event.boss,
				exp = tonumber(event.exp),
				gold = tonumber(event.gold),
				gotLeg = event.gotLeg == true,
				gotMyth = event.gotMyth == true,
				leg = tonumber(event.leg),
				myth = tonumber(event.myth),
				runs = tonumber(event.runs),
				dailyRuns = tonumber(event.dailyRuns),
				luckMul = tonumber(event.luckMul),
				luckFrom = if type(event.luckFrom) == "string" then event.luckFrom else nil,
				upgraded = event.upgraded == true,
				extra = event.extra == true,
				summary = FightView.rows(event.sum),
				fight = FightView.header(event.fs), -- S134f: time, deaths, dodged blows
				drop = FightView.drop(event.drop), -- S134f: the party loot
				-- S97: the personal mount roll (ids checked against the data)
				mount = if type(event.mount) == "string" and MountData.get(event.mount) then event.mount else nil,
				mountSkin = if type(event.mountSkin) == "string" and Cosmetics.get(event.mountSkin)
					then event.mountSkin
					else nil,
			})
		end
	end
end

function CombatFxController.Init(registry)
	DungeonController = registry.Get("DungeonController")
	MonsterView = registry.Get("MonsterViewController")
	AnimationController = registry.Get("AnimationController")
	SfxController = registry.Get("SfxController")
	registry.Get("VfxController").SetShake(shake)
	AnimationController.OnRoar(onRoar) -- S117
	-- S117 (E7): a boss's death shakes the camera of players near it
	MonsterView.OnBossDeath(function(model: Model)
		local root = model:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			shakeNear(root.Position, BOSS_DEATH_SHAKE)
		end
	end)
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

-- Admin /anim (S22): plays a weapon's attack on our own character (no target, no damage). S110: `model` (an AnimLab
-- mannequin) instead of our character. S113: calls within AttackMotions.COMBO_WINDOW play the combo; `step` forces a
-- step (AnimLab `attack <type> <step>`); `target` (the AnimLab target) gets the hit's effects and the shot.
function CombatFxController.PreviewAttack(weaponType: string?, model: Model?, step: number?, target: Model?)
	local character = model or player.Character
	if not character then
		return
	end
	local motion = AttackPose.motionFor(weaponType)
	attackFx(character, target, weaponType, AttackPose.projectile(motion) == nil, nil, step)
end

-- S113 AnimLab `hit <material> [crit]`: the sparks, the sound and the reaction of a basic hit on `target` struck from
-- `from`, as if a dmg event arrived (no number).
function CombatFxController.PreviewHit(target: Model, from: Vector3, material: string, crit: boolean)
	local who = SfxController.WhoOf(target)
	SfxController.Play(SfxRules.hitKey(material, Sfx.playable), target, who)
	if crit then
		SfxController.Play("hit.crit", target, who)
	end
	flash(target, nil)
	if not hitSparks(target, from, material, crit) then
		impact(target, crit)
	end
	AnimationController.MonsterHit(target, from)
	if target:GetAttribute("MonsterId") == nil then
		AnimationController.CharacterHit(target, from, crit)
	end
end

-- S110 AnimLab: the ground telegraph of a "tele" event (boss / Elite II attacks) without the server. S111: with its
-- sounds (`caster`: the stage's boss, attribute PreviewMonsterId).
function CombatFxController.PreviewTelegraph(event: { [string]: any }, caster: Model?)
	telegraph(event, caster)
end

local WARN_EVERY = 2
local warnedAt = -math.huge

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
				local ok, err = pcall(function()
					handle(event)
				end)
				if not ok then
					-- S29: never silent; at most one warning per WARN_EVERY seconds so a broken event cannot flood.
					local now = os.clock()
					if now - warnedAt >= WARN_EVERY then
						warnedAt = now
						warn(`[CombatFxController] {tostring(event.k)} event failed: {err}`)
					end
				end
			end
		end
	end)
end

return CombatFxController
