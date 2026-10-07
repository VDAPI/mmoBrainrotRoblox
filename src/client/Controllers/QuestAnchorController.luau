--!strict
-- Quest anchors on the client (S27): the invisible parts tagged "QuestAnchor" (Data/Areas questAnchors, built by the
-- map layouts) get a "[E] <action>" prompt and a small gold marker only while the character has an open `use`
-- objective with that anchor (Logic/SideQuests.usableAnchors). The server holds the interaction (QuestUse, the
-- cast bar shows it). Once used, the anchor shows its change to this player only (lit candles, a fresh fence board,
-- the net on the shore, a burning totem, ...): built from the character's quest state, so it looks the same after
-- relogging, while the quest runs and after it is handed in.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local Config = require(ReplicatedStorage.Shared.Config)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Keybinds = require(script.Parent.Parent.UI.Keybinds)
local Net = require(ReplicatedStorage.Shared.Net)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local SideQuests = require(ReplicatedStorage.Shared.Logic.SideQuests)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local Toast = require(script.Parent.Parent.UI.Components.Toast)

local QuestAnchorController = {
	Name = "QuestAnchorController",
}

local TAG = "QuestAnchor"
local scope = Fusion.scoped(Fusion)

type Anchor = {
	id: string,
	part: BasePart,
	prompt: ProximityPrompt,
	marker: BillboardGui,
	fx: Model?,
	fxKind: string?,
}

local anchors: { [string]: Anchor } = {}
local fxFolder: Folder? = nil

local function folder(): Folder
	local existing = fxFolder
	if existing and existing.Parent then
		return existing
	end
	local created = Instance.new("Folder")
	created.Name = "VaelthornQuestFx"
	created.Parent = Workspace
	fxFolder = created
	return created
end

-- Effects -----------------------------------------------------------------------------------------------------

local function part(
	model: Model,
	size: Vector3,
	cframe: CFrame,
	color: string,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cframe
	p.Color = Color3.fromHex(color)
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

local function light(at: BasePart, color: string, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = Color3.fromHex(color)
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = at
end

-- Builds the "done" look of an anchor around `base` (the ground under it, facing the anchor's yaw).
local BUILDERS: { [string]: (model: Model, base: CFrame) -> () } = {
	candles = function(model, base)
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			local at = base * CFrame.new(math.cos(a) * 1.1, 0, math.sin(a) * 0.7)
			local h = 0.5 + (i % 3) * 0.2
			part(
				model,
				Vector3.new(h, 0.28, 0.28),
				at * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
				"#EADFC4",
				Enum.Material.SmoothPlastic,
				Enum.PartType.Cylinder
			)
			local flame = part(
				model,
				Vector3.new(0.18, 0.3, 0.18),
				at * CFrame.new(0, h + 0.15, 0),
				"#FFB347",
				Enum.Material.Neon,
				Enum.PartType.Ball
			)
			if i == 1 then
				light(flame, "#FFB347", 12, 1.6)
			end
		end
	end,
	plank = function(model, base)
		for _, y in { 1.1, 2.1 } do
			part(model, Vector3.new(6.5, 0.55, 0.22), base * CFrame.new(0, y, 0), "#C9A06A", Enum.Material.WoodPlanks)
		end
		part(model, Vector3.new(0.45, 2.8, 0.45), base * CFrame.new(3.1, 1.4, 0), "#B08A58", Enum.Material.Wood)
	end,
	net = function(model, base)
		part(
			model,
			Vector3.new(4.5, 0.35, 3.2),
			base * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(4)),
			"#4A4236",
			Enum.Material.Fabric
		)
		for i = 1, 4 do
			part(
				model,
				Vector3.new(1.1, 0.25, 0.4),
				base * CFrame.new(-1.5 + i * 0.7, 0.5, (i % 2) * 0.6 - 0.3) * CFrame.Angles(0, i, 0),
				"#B8C0C8",
				Enum.Material.SmoothPlastic
			)
		end
		part(
			model,
			Vector3.new(0.25, 0.25, 5),
			base * CFrame.new(2.6, 0.4, 0) * CFrame.Angles(math.rad(8), 0, 0),
			"#6B5038",
			Enum.Material.Wood
		)
	end,
	mark = function(model, base)
		local at = base * CFrame.new(0, 1.6, 0)
		for _, r in { 45, -45 } do
			part(
				model,
				Vector3.new(0.18, 1.6, 0.06),
				at * CFrame.Angles(0, 0, math.rad(r)),
				"#F2EFE6",
				Enum.Material.SmoothPlastic
			)
		end
	end,
	search = function(model, base)
		part(
			model,
			Vector3.new(3.4, 0.6, 2.6),
			base * CFrame.new(0, 0.2, 0),
			"#2A2622",
			Enum.Material.Slate,
			Enum.PartType.Cylinder
		)
		local chest = base * CFrame.new(1.4, 0.45, 0.4) * CFrame.Angles(0, math.rad(20), 0)
		part(model, Vector3.new(1.4, 0.8, 0.9), chest, "#3A2A1A", Enum.Material.Wood)
		part(
			model,
			Vector3.new(1.4, 0.15, 0.9),
			chest * CFrame.new(0, 0.55, -0.4) * CFrame.Angles(math.rad(-70), 0, 0),
			"#2E2116",
			Enum.Material.Wood
		)
	end,
	crate = function(model, base)
		part(model, Vector3.new(2.4, 1.6, 2), base * CFrame.new(0, 0.8, 0), "#7A5A3A", Enum.Material.WoodPlanks)
		part(
			model,
			Vector3.new(2.4, 0.2, 2),
			base * CFrame.new(-1.4, 0.15, 0.6) * CFrame.Angles(0, math.rad(30), 0),
			"#7A5A3A",
			Enum.Material.WoodPlanks
		)
		for i, color in { "#8E3B2E", "#3E5A7A", "#C9A45C" } do
			part(
				model,
				Vector3.new(1.8, 0.55, 0.55),
				base * CFrame.new(1.2 + i * 0.3, 0.3, -0.8 + i * 0.6) * CFrame.Angles(0, math.rad(i * 25), math.rad(90)),
				color,
				Enum.Material.Fabric,
				Enum.PartType.Cylinder
			)
		end
	end,
	seal = function(model, base)
		for i, r in { 12, -10, 4 } do
			part(
				model,
				Vector3.new(5.5, 0.5, 0.25),
				base * CFrame.new(0, 0.8 + i * 1.1, 0) * CFrame.Angles(0, 0, math.rad(r)),
				"#C9A06A",
				Enum.Material.WoodPlanks
			)
		end
	end,
	fire = function(model, base)
		local core = part(
			model,
			Vector3.new(1.2, 1.2, 1.2),
			base * CFrame.new(0, 3, 0),
			"#FF7A1A",
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		core.Transparency = 0.4
		local fire = Instance.new("Fire")
		fire.Size = 7
		fire.Heat = 12
		fire.Parent = core
		local smoke = Instance.new("Smoke")
		smoke.Opacity = 0.15
		smoke.RiseVelocity = 6
		smoke.Parent = core
		light(core, "#FF8A3A", 24, 2)
	end,
	tracks = function(model, base)
		part(
			model,
			Vector3.new(0.22, 4, 0.22),
			base * CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.rad(6)),
			"#6B5038",
			Enum.Material.Wood
		)
		part(model, Vector3.new(0.9, 0.7, 0.05), base * CFrame.new(0.5, 3.6, 0), "#A3282A", Enum.Material.Fabric)
	end,
}

local function groundUnder(anchor: Anchor): CFrame
	local data = Areas.anchorById(anchor.id)
	local lift = if data and data.y then data.y else 2
	return CFrame.new(anchor.part.Position - Vector3.new(0, lift, 0))
end

local function setFx(anchor: Anchor, kind: string?)
	if anchor.fxKind == kind then
		return
	end
	if anchor.fx then
		anchor.fx:Destroy()
		anchor.fx = nil
	end
	anchor.fxKind = kind
	local builder = if kind then BUILDERS[kind] else nil
	if not builder then
		return
	end
	local model = Instance.new("Model")
	model.Name = `QuestFx_{anchor.id}`
	builder(model, groundUnder(anchor))
	model.Parent = folder()
	anchor.fx = model
end

-- Prompts --------------------------------------------------------------------------------------------------------

local function refresh()
	local quests = State.Get({ "character", "quests" })
	local usable = SideQuests.usableAnchors(quests)
	local done = SideQuests.doneAnchors(quests)
	for id, anchor in anchors do
		local target = usable[id]
		local quest = target and Quests.Side.get(target.quest)
		local objective = quest and quest.objectives[target.index]
		anchor.prompt.Enabled = objective ~= nil
		anchor.marker.Enabled = objective ~= nil
		if quest and objective then
			anchor.prompt.ActionText = Text.now(objective.action or "quest.use.default")
			anchor.prompt.ObjectText = Text.now(`quest.{quest.id}.title`)
		end
		setFx(anchor, done[id])
	end
end

local function register(instance: Instance)
	local id = instance:GetAttribute("AnchorId")
	if not instance:IsA("BasePart") or type(id) ~= "string" then
		return
	end
	local existing = anchors[id]
	if existing and existing.part == instance then
		return
	end
	if existing then
		existing.prompt:Destroy()
		existing.marker:Destroy()
		if existing.fx then
			existing.fx:Destroy()
		end
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "VaelthornQuestUse"
	Keybinds.bindPrompt(prompt, "interact")
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = Config.SideQuest.useRange
	prompt.Enabled = false
	prompt.Parent = instance
	prompt.Triggered:Connect(function()
		task.spawn(function()
			local ok, err = Net.Invoke("QuestUse", id)
			if ok then
				Sounds.play("click")
			elseif err then
				Sounds.play("error")
				Toast.push(Text.now(err), "error", 2)
			end
		end)
	end)
	local marker = Instance.new("BillboardGui")
	marker.Name = "VaelthornQuestMarker"
	marker.Size = UDim2.fromOffset(34, 34)
	marker.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	marker.MaxDistance = 90
	marker.LightInfluence = 0
	marker.AlwaysOnTop = false
	marker.Enabled = false
	marker.Adornee = instance
	local glyph = Instance.new("TextLabel")
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.BackgroundTransparency = 1
	glyph.Text = "✦"
	glyph.TextScaled = true
	glyph.FontFace = Theme.Fonts.BodyBold
	glyph.TextColor3 = Theme.Colors.GoldBright
	glyph.TextStrokeTransparency = 0.3
	glyph.Parent = marker
	marker.Parent = instance
	anchors[id] = { id = id, part = instance, prompt = prompt, marker = marker, fx = nil, fxKind = nil }
	instance.AncestryChanged:Connect(function(_, parent)
		local current = anchors[id]
		if parent == nil and current and current.part == instance then
			if current.fx then
				current.fx:Destroy()
			end
			anchors[id] = nil
		end
	end)
	refresh()
end

function QuestAnchorController.Start()
	for _, instance in CollectionService:GetTagged(TAG) do
		task.spawn(register, instance)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(instance)
		task.defer(register, instance)
	end)
	scope:Observer(State.Value({ "character", "quests" })):onChange(refresh)
	scope:Observer(Text.Lang):onChange(refresh)
	refresh()
end

return QuestAnchorController
