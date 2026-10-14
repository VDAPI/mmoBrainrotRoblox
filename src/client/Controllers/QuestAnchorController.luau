--!strict
-- Quest anchors on the client (S27): the invisible parts tagged "QuestAnchor" (Data/Areas questAnchors, built by the
-- map layouts) get a "[E] <action>" prompt and a small gold marker only while the character has an open `use`
-- objective with that anchor (Logic/SideQuests.usableAnchors). The server holds the interaction (QuestUse, the
-- cast bar shows it). Once used, the anchor shows its change to this player only (lit candles, a fresh fence board,
-- the net on the shore, a burning totem, ...): built from the character's quest state, so it looks the same after
-- relogging, while the quest runs and after it is handed in. S102: the anchors of the active story quest too (the
-- frosted crest of frostRuins). S103: an anchor with `rot` turns the effect's frame; the effects at a generator prop
-- (frostbreak, heartglow, sealbreak) are drawn in the prop's frame (Logic/DuskwoodGen/Quest.frame) and cover it.
-- S104: cageOpen, rune and chains (the Ashen Wastes and the posts of the captives in Deepforge).
-- S105: shroud, armor, shatter, snuff, oath, rite and thorn (the Frost Peaks and the Frozen Hold); the Rite Circle's
-- geometry from Logic/FrostpeakGen/Rite, the Thorn and Ilvar's statue from Util/StoryProps, the flowers of the spring
-- in Vaelthorn from Logic/TownGen/Spring.
-- S106: lamp, smoke, wreath, cage, ward and spill (the Duskwood side arcs; at the anchor's prop when it has one).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Areas = require(ReplicatedStorage.Shared.Data.Areas)
local AshenQuest = require(ReplicatedStorage.Shared.Logic.AshenGen.Quest)
local BlueprintBuild = require(ReplicatedStorage.Shared.Util.BlueprintBuild)
local Config = require(ReplicatedStorage.Shared.Config)
local DuskwoodQuest = require(ReplicatedStorage.Shared.Logic.DuskwoodGen.Quest)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Keybinds = require(script.Parent.Parent.UI.Keybinds)
local Net = require(ReplicatedStorage.Shared.Net)
local Quests = require(ReplicatedStorage.Shared.Data.Quests)
local Rite = require(ReplicatedStorage.Shared.Logic.FrostpeakGen.Rite)
local SideQuests = require(ReplicatedStorage.Shared.Logic.SideQuests)
local Sounds = require(script.Parent.Parent.UI.Sounds)
local Spring = require(ReplicatedStorage.Shared.Logic.TownGen.Spring)
local State = require(script.Parent.Parent.UI.State)
local StoryProgress = require(ReplicatedStorage.Shared.Logic.StoryProgress)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)
local StoryProps = require(script.Parent.Parent.Util.StoryProps)
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

-- S103: the frame of the thing a generator prop sits on (Logic/DuskwoodGen/Quest.frame), from the anchor's base.
local function thingFrame(base: CFrame, anchorId: string): CFrame
	local f = DuskwoodQuest.frame(anchorId)
	if not f then
		return base
	end
	return base * CFrame.new(f.x, f.y, f.z) * CFrame.Angles(math.rad(f.rx), math.rad(f.ry), math.rad(f.rz))
end

-- S106: where a side quest prop stands (Logic/DuskwoodGen/Quest.SIDE_OFFSET along the anchor's +Z); the anchor
-- itself when it has no prop (it stands at an existing build).
local function sideSpot(base: CFrame, anchorId: string): CFrame
	if DuskwoodQuest.kindOf(anchorId) then
		return base * CFrame.new(0, 0, DuskwoodQuest.SIDE_OFFSET)
	end
	return base
end

-- S107: where an Ashen side quest prop stands (Logic/AshenGen/Quest.SIDE_OFFSET along the anchor's +Z); the anchor
-- itself when it has none (it stands by an existing build).
local function ashSpot(base: CFrame, anchorId: string): CFrame
	if AshenQuest.kindOf(anchorId) then
		return base * CFrame.new(0, 0, AshenQuest.SIDE_OFFSET)
	end
	return base
end

local function at(point: { x: number, y: number, z: number }): CFrame
	return CFrame.new(point.x, point.y, point.z)
end

-- S105: the top of whatever solid stands at `point` (a ray from a little over `fromY` down; effects and the player
-- ignored), e.g. the chapel's altar in the Frozen Hold.
local function surfaceY(point: Vector3, fromY: number): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local skip: { Instance } = { folder() }
	local character = Players.LocalPlayer.Character
	if character then
		table.insert(skip, character)
	end
	params.FilterDescendantsInstances = skip
	local hit = Workspace:Raycast(Vector3.new(point.X, fromY + 12, point.Z), Vector3.new(0, -30, 0), params)
	return if hit then hit.Position.Y else nil
end

-- S105: the rite broken (voiceOfWinter): dark cracks down the inner faces of the six monoliths and shards of the
-- ring scattered on the snow (Logic/FrostpeakGen/Rite; the circle's middle is 9 studs behind the anchor summit_rite)
local function brokenRite(model: Model, base: CFrame)
	local centre = base * CFrame.new(0, 0, 9)
	for k, st in Rite.stones() do
		local stone = centre * CFrame.new(st.x, 0, st.z) * CFrame.Angles(0, math.rad(st.yaw), 0)
		for m = 0, 1 do
			part(
				model,
				Vector3.new(0.12, 3.2 + m, 0.06),
				stone
					* CFrame.new(-0.4 + m * 0.7, 2.6 + m * 1.6, Rite.STONE.d / 2 + 0.06)
					* CFrame.Angles(0, 0, math.rad(if (k + m) % 2 == 0 then 14 else -11)),
				"#1E2228",
				Enum.Material.Slate
			)
		end
		part(
			model,
			Vector3.new(0.9, 0.5, 0.7),
			stone * CFrame.new(0.5, 0.25, -1.4) * CFrame.Angles(0, k, math.rad(20)),
			"#BFE6F7",
			Enum.Material.Ice
		).Transparency =
			0.3
	end
end

-- S105: the world's own flames and glows near `points` (TownFx parts whose Fx is one of `kinds`, from the server shell
-- or the client detail, now or built later) put out on this client while `model` lives: the part hidden, its
-- emitters and lights (TownFxController's flames too) off; all restored when the effect goes.
local function quench(model: Model, points: { Vector3 }, radius: number, kinds: { [string]: boolean })
	local parts: { [BasePart]: boolean } = {}
	local saved: { [Instance]: boolean } = {}
	local connections: { RBXScriptConnection } = {}
	local function off(child: Instance)
		if (child:IsA("ParticleEmitter") or child:IsA("Light")) and saved[child] == nil then
			saved[child] = (child :: any).Enabled;
			(child :: any).Enabled = false
		end
	end
	local function take(instance: Instance)
		if not instance:IsA("BasePart") or parts[instance] or not model.Parent then
			return
		end
		local fx = instance:GetAttribute("Fx")
		if type(fx) ~= "string" or not kinds[fx] then
			return
		end
		local near = false
		for _, point in points do
			if (instance.Position - point).Magnitude <= radius then
				near = true
				break
			end
		end
		if not near then
			return
		end
		parts[instance] = true
		instance.LocalTransparencyModifier = 1
		for _, child in instance:GetChildren() do
			off(child)
		end
		table.insert(connections, instance.ChildAdded:Connect(off))
	end
	-- the model is parented right after its builder runs
	task.defer(function()
		for _, instance in CollectionService:GetTagged(BlueprintBuild.FX_TAG) do
			take(instance)
		end
	end)
	table.insert(
		connections,
		CollectionService:GetInstanceAddedSignal(BlueprintBuild.FX_TAG):Connect(function(instance)
			task.defer(take, instance)
		end)
	)
	model.Destroying:Connect(function()
		for _, connection in connections do
			connection:Disconnect()
		end
		for p in parts do
			p.LocalTransparencyModifier = 0
		end
		for child, enabled in saved do
			(child :: any).Enabled = enabled
		end
	end)
end

-- Builds the "done" look of an anchor around `base` (the ground under it, facing the anchor's yaw).
local BUILDERS: { [string]: (model: Model, base: CFrame, anchorId: string) -> () } = {
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
	mark = function(model, base, anchorId)
		-- S107: on the face of the cracked column of ash_columns_sample (Logic/AshenGen/Quest columnStump)
		local at = if AshenQuest.kindOf(anchorId) == "columnStump"
			then ashSpot(base, anchorId) * CFrame.new(0, 1.4, -0.66)
			else base * CFrame.new(0, 1.6, 0)
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
	tracks = function(model, base, anchorId)
		-- S107: driven into the stone heap of ash_wyvern_lookout (Logic/AshenGen/Quest stoneHeap)
		local foot = if AshenQuest.kindOf(anchorId) then ashSpot(base, anchorId) * CFrame.new(0, 1, 0) else base
		part(
			model,
			Vector3.new(0.22, 4, 0.22),
			foot * CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.rad(6)),
			"#6B5038",
			Enum.Material.Wood
		)
		part(model, Vector3.new(0.9, 0.7, 0.05), foot * CFrame.new(0.5, 3.6, 0), "#A3282A", Enum.Material.Fabric)
	end,
	-- S96: where the wild stallion was calmed: a stake, a coil of cut halter rope and a patch of trampled grass
	halter = function(model, base)
		part(
			model,
			Vector3.new(2.6, 0.3, 0.3),
			base * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, math.rad(90)),
			"#6B5038",
			Enum.Material.Wood,
			Enum.PartType.Cylinder
		)
		part(
			model,
			Vector3.new(0.25, 0.9, 0.9),
			base * CFrame.new(0.55, 0.15, 0.3) * CFrame.Angles(0, 0, math.rad(90)),
			"#8A6A44",
			Enum.Material.Fabric,
			Enum.PartType.Cylinder
		)
		part(
			model,
			Vector3.new(1.6, 0.1, 0.1),
			base * CFrame.new(0.3, 0.9, 0.1) * CFrame.Angles(0, math.rad(30), math.rad(-35)),
			"#8A6A44",
			Enum.Material.Fabric
		)
		part(
			model,
			Vector3.new(4.5, 0.08, 3.2),
			base * CFrame.new(0.4, 0.04, 0.6) * CFrame.Angles(0, math.rad(20), 0),
			"#6E5B3A",
			Enum.Material.Ground
		)
	end,
	-- S102: rime crust and a frosted crest on the tower ruins (story quest frostRuins): thin ice slabs around the
	-- anchor, an upright crest plate with a white snowflake and a dark thorn across it, a faint cold light
	frost = function(model, base)
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2 + 0.4
			local d = 0.8 + (i % 3) * 0.6
			local ice = part(
				model,
				Vector3.new(1.2 + (i % 2) * 0.6, 0.08, 0.9 + (i % 3) * 0.3),
				base * CFrame.new(math.cos(a) * d, 0.05, math.sin(a) * d) * CFrame.Angles(0, a * 1.7, math.rad(4)),
				"#CFE6F5",
				Enum.Material.Ice
			)
			ice.Transparency = 0.25 + (i % 3) * 0.06
		end
		local crest =
			part(model, Vector3.new(0.2, 1.6, 1.6), base * CFrame.new(0, 1.3, 0), "#CFE6F5", Enum.Material.Glass)
		crest.Transparency = 0.3
		local flake =
			part(model, Vector3.new(0.06, 1, 0.16), base * CFrame.new(-0.13, 1.3, 0), "#FFFFFF", Enum.Material.Neon)
		part(
			model,
			Vector3.new(0.06, 1, 0.16),
			flake.CFrame * CFrame.Angles(math.rad(60), 0, 0),
			"#FFFFFF",
			Enum.Material.Neon
		)
		part(
			model,
			Vector3.new(0.06, 1, 0.16),
			flake.CFrame * CFrame.Angles(math.rad(-60), 0, 0),
			"#FFFFFF",
			Enum.Material.Neon
		)
		part(
			model,
			Vector3.new(0.07, 1.5, 0.08),
			base * CFrame.new(-0.16, 1.3, 0) * CFrame.Angles(math.rad(45), 0, 0),
			"#2A2A30",
			Enum.Material.Slate
		)
		light(crest, "#BFE3FF", 6, 0.8)
	end,
	-- S103: the frost rune on the menhir cracked in two darkened halves over the bare stone, rime scattered on the
	-- ground before it, the stone's silver light back (moonstone)
	frostbreak = function(model, base, anchorId)
		local rune = thingFrame(base, anchorId) * at(DuskwoodQuest.RUNE)
		part(model, Vector3.new(2.7, 3.3, 0.05), rune * CFrame.new(0, 0, -0.05), "#6E6C6A", Enum.Material.Slate)
		for _, side in { -1, 1 } do
			for k, angle in { 0, 60 } do
				part(
					model,
					Vector3.new(0.16, 1, 0.05),
					rune
						* CFrame.new(side * (0.35 + k * 0.15), side * 0.1 - k * 0.2, -0.1)
						* CFrame.Angles(0, 0, math.rad(side * (angle + 12))),
					"#5A6A7A",
					Enum.Material.SmoothPlastic
				)
			end
		end
		for i = 1, 5 do
			local a = i * 1.3
			local lump = part(
				model,
				Vector3.new(0.5 + (i % 2) * 0.3, 0.35, 0.5),
				base * CFrame.new(math.cos(a) * 1.8, 0.15, 1.6 + math.sin(a) * 0.9),
				"#EAF6FF",
				Enum.Material.Ice,
				Enum.PartType.Ball
			)
			lump.Transparency = 0.2
		end
		local glow = part(model, Vector3.new(0.2, 0.2, 0.2), rune * CFrame.new(0, 0, -1.5), "#CFE0FF")
		glow.Transparency = 1
		light(glow, "#CFE0FF", 10, 1)
	end,
	-- S103: the ice shard gone from the Elder Tree's crack: bark over where it was, a warm golden glow in the crack and
	-- a puddle of melt water at the player's feet (elderHeart)
	heartglow = function(model, base, anchorId)
		local shard = thingFrame(base, anchorId) * at(DuskwoodQuest.SHARD)
		part(model, Vector3.new(1.8, 3.8, 1.4), shard * CFrame.new(0, 0, 0.1), "#3A2E24", Enum.Material.Wood)
		local gold =
			part(model, Vector3.new(1, 4, 0.1), shard * CFrame.new(-0.2, 0, -0.65), "#E8C25A", Enum.Material.Neon)
		local puddle = part(
			model,
			Vector3.new(0.08, 3.2, 3.2),
			base * CFrame.new(0.2, 0.04, 2.6) * CFrame.Angles(0, 0, math.rad(90)),
			"#6A8AA0",
			Enum.Material.Glass,
			Enum.PartType.Cylinder
		)
		puddle.Transparency = 0.3
		light(gold, "#E8C25A", 14, 1.4)
	end,
	-- S103: the cult's seal shattered: the niche bare again, violet shards and a torn chain on the ground (cryptGate)
	sealbreak = function(model, base, anchorId)
		local seal = thingFrame(base, anchorId) * at(DuskwoodQuest.SEAL)
		part(model, Vector3.new(3.4, 3.4, 0.05), seal * CFrame.new(0, 0, -0.08), "#6E2F2A", Enum.Material.Sandstone)
		part(model, Vector3.new(2.6, 2.6, 0.05), seal * CFrame.new(0, 0, -0.12), "#08080A", Enum.Material.SmoothPlastic)
		for i = 1, 5 do
			local shard = part(
				model,
				Vector3.new(0.5 + (i % 3) * 0.2, 0.12, 0.35),
				base * CFrame.new(-1.2 + i * 0.5, 0.08, 2.2 + (i % 2) * 0.8) * CFrame.Angles(0, i * 1.1, math.rad(8)),
				"#7A4AA0",
				Enum.Material.Neon
			)
			shard.Transparency = 0.15
		end
		for k = 0, 3 do
			part(
				model,
				Vector3.new(0.5, 0.12, 0.25),
				base * CFrame.new(1.6 + k * 0.42, 0.08, 1.4 + k * 0.2) * CFrame.Angles(0, math.rad(k * 35), 0),
				"#4A4A4E",
				Enum.Material.Metal
			)
		end
		part(model, Vector3.new(0.12, 1.4, 0.12), seal * CFrame.new(1.4, 1.9, 0.4), "#4A4A4E", Enum.Material.Metal)
	end,
	-- S104: the door of an orc cage torn off its hinges and leant on the ground at 70 degrees, a broken padlock beside
	-- it; the bones stay inside the cage (warcampCages)
	cageOpen = function(model, base)
		local door = base * CFrame.new(0, 0, 0.6) * CFrame.Angles(math.rad(-20), 0, 0)
		part(model, Vector3.new(4.4, 4.4, 0.3), door * CFrame.new(0, 2.1, 0), "#5A4632", Enum.Material.Wood)
		for i = -1, 1 do
			part(
				model,
				Vector3.new(0.22, 4.6, 0.22),
				door * CFrame.new(i * 1.4, 2.1, -0.25),
				"#3A3A40",
				Enum.Material.Metal
			)
		end
		local lock = base * CFrame.new(1.6, 0.15, -1.2) * CFrame.Angles(0, math.rad(35), 0)
		part(model, Vector3.new(0.7, 0.5, 0.25), lock, "#3A3A40", Enum.Material.Metal)
		part(
			model,
			Vector3.new(0.12, 0.6, 0.12),
			lock * CFrame.new(0.5, 0.05, 0.2) * CFrame.Angles(0, 0, math.rad(70)),
			"#3A3A40",
			Enum.Material.Metal
		)
	end,
	-- S104: a slate with a glowing blue rune and its light (emberCores at the Sleeping Colossus; S107 uses it too)
	rune = function(model, base)
		local slate = part(model, Vector3.new(2, 0.2, 2), base * CFrame.new(0, 0.1, 0), "#3A3630", Enum.Material.Slate)
		local top = base * CFrame.new(0, 0.23, 0)
		for _, r in { 35, -35 } do
			part(
				model,
				Vector3.new(1.6, 0.06, 0.16),
				top * CFrame.Angles(0, math.rad(r), 0),
				"#7FC8FF",
				Enum.Material.Neon
			)
		end
		part(model, Vector3.new(0.9, 0.06, 0.16), top * CFrame.new(0, 0, 0.55), "#7FC8FF", Enum.Material.Neon)
		light(slate, "#7FC8FF", 8, 1.2)
	end,
	-- S104: two open shackles on the ground (one broken in halves) and a run of links from the captive's post
	-- (forgeChains in Deepforge)
	chains = function(model, base)
		part(
			model,
			Vector3.new(0.3, 1.1, 1.1),
			base * CFrame.new(-0.9, 0.15, 0.8) * CFrame.Angles(0, 0, math.rad(90)),
			"#3A3A40",
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
		for _, side in { -1, 1 } do
			part(
				model,
				Vector3.new(0.3, 0.55, 1.1),
				base * CFrame.new(0.9 + side * 0.45, 0.15, 0.9) * CFrame.Angles(0, math.rad(side * 25), 0),
				"#3A3A40",
				Enum.Material.Metal
			)
		end
		for k = 0, 4 do
			part(
				model,
				Vector3.new(0.35, 0.18, 0.55),
				base
					* CFrame.new(0.2 - k * 0.25, 0.1 + (4 - k) * 0.35, -0.6 - k * 0.1)
					* CFrame.Angles(math.rad(k * 40), 0, 0),
				"#3A3A40",
				Enum.Material.Metal
			)
		end
	end,
	-- S105: a tent cloth stretched over the fallen climbers, weighed down with stones, and a cairn with an ice axe on
	-- its top (harpyRocks at the climbers' camp)
	shroud = function(model, base)
		local cloth = base * CFrame.new(-0.6, 0.35, 1.6) * CFrame.Angles(0, math.rad(8), 0)
		part(model, Vector3.new(2.4, 0.5, 5.2), cloth, "#8A7A5E", Enum.Material.Fabric)
		part(model, Vector3.new(2.6, 0.12, 5.4), cloth * CFrame.new(0, 0.28, 0), "#A89A7A", Enum.Material.Fabric)
		for k = 0, 3 do
			local side = if k % 2 == 0 then -1 else 1
			part(
				model,
				Vector3.new(0.6, 0.45, 0.6),
				cloth * CFrame.new(side * 1.3, 0.2, -2 + k * 1.3),
				"#6E6A64",
				Enum.Material.Slate,
				Enum.PartType.Ball
			)
		end
		local cairn = base * CFrame.new(2.4, 0, -0.6)
		for k, s in { 1.6, 1.3, 1, 0.7 } do
			part(
				model,
				Vector3.new(s, 0.6, s),
				cairn * CFrame.new(0, 0.3 + (k - 1) * 0.55, 0) * CFrame.Angles(0, k * 0.7, 0),
				"#7A766E",
				Enum.Material.Slate
			)
		end
		part(
			model,
			Vector3.new(0.16, 2.4, 0.16),
			cairn * CFrame.new(0, 3, 0) * CFrame.Angles(0, 0, math.rad(8)),
			"#6B5038",
			Enum.Material.Wood
		)
		part(model, Vector3.new(1.2, 0.18, 0.12), cairn * CFrame.new(0.15, 4.1, 0), "#9FB6C9", Enum.Material.Metal)
	end,
	-- S105: the order's armour laid in a row on the snow, a pennant of the Ice Guard planted over it (mammothTundra)
	armor = function(model, base)
		for k = 0, 3 do
			local at = base * CFrame.new(-2.4 + k * 1.6, 0, 1.4) * CFrame.Angles(0, math.rad(k * 6 - 9), 0)
			part(model, Vector3.new(1.3, 0.5, 1.8), at * CFrame.new(0, 0.25, 0), "#9FB6C9", Enum.Material.Metal)
			part(
				model,
				Vector3.new(0.9, 0.9, 0.9),
				at * CFrame.new(0, 0.4, -1.3),
				"#8E9CA8",
				Enum.Material.Metal,
				Enum.PartType.Ball
			)
			part(model, Vector3.new(0.5, 0.18, 0.5), at * CFrame.new(0, 0.55, 0.1), "#2F3A4A", Enum.Material.Fabric)
		end
		local pole = base * CFrame.new(2.8, 0, 0.4)
		part(model, Vector3.new(0.2, 5, 0.2), pole * CFrame.new(0, 2.5, 0), "#4A4E56", Enum.Material.Metal)
		part(model, Vector3.new(1.6, 1.1, 0.08), pole * CFrame.new(0.9, 4.3, 0), "#2F3A4A", Enum.Material.Fabric)
		part(model, Vector3.new(1.6, 0.18, 0.1), pole * CFrame.new(0.9, 3.7, 0), "#B8D0E0", Enum.Material.Metal)
		part(model, Vector3.new(0.4, 0.4, 0.1), pole * CFrame.new(0.9, 4.35, -0.06), "#B8D0E0", Enum.Material.Neon)
	end,
	-- S105: a crystal broken: shards of grey glass on the ground, a dead cluster fallen over, a short flash when first
	-- built (frozenLake, oathWords' Frost Flower, wyrmSpire); on the obelisk its glowing rune is covered too
	shatter = function(model, base, anchorId)
		for k = 1, 7 do
			local a = k * 0.9
			local d = 1.2 + (k % 3) * 0.7
			local shard = part(
				model,
				Vector3.new(0.35 + (k % 2) * 0.25, 0.9 + (k % 3) * 0.4, 0.3),
				base
					* CFrame.new(math.cos(a) * d, 0.25, 1.4 + math.sin(a) * d)
					* CFrame.Angles(math.rad(70 + k * 4), k * 0.8, math.rad(k * 11)),
				"#8A949C",
				Enum.Material.Glass
			)
			shard.Transparency = 0.25
		end
		for k = 0, 2 do
			part(
				model,
				Vector3.new(0.9, 3.2 - k * 0.6, 0.9),
				base * CFrame.new(-1.6 + k * 0.6, 0.45, 2.6) * CFrame.Angles(math.rad(80), math.rad(k * 25), 0),
				"#6E7880",
				Enum.Material.Glass
			).Transparency =
				0.2
		end
		if anchorId == "wyrm_obelisk" then
			-- the rune on the obelisk's front (Logic/FrostpeakGen/Wyrm obelisk: 5 studs behind the anchor)
			part(model, Vector3.new(1.4, 4.2, 0.12), base * CFrame.new(0, 11, 3.38), "#4A4E56", Enum.Material.Slate)
		end
		local flash = part(
			model,
			Vector3.new(2.6, 2.6, 2.6),
			base * CFrame.new(0, 1.4, 2),
			"#E8F8FF",
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		flash.Transparency = 0.3
		task.delay(0.35, function()
			if flash.Parent then
				flash:Destroy()
			end
		end)
	end,
	-- S105: blue fires put out (dragonTemple): the brazier's flame and light off and black embers in its bowl, the
	-- colossus's glowing eyes off behind dark lids, thin smoke for a few seconds after the change
	snuff = function(model, base, anchorId)
		local embers: { CFrame } = {}
		if anchorId == "temple_altars" then
			-- the brazier in the middle of the altars (Temple altars: bowl at +3.2, fire at +3.8, its light above)
			local brazier = base * CFrame.new(2.2, 3.8, 5.6)
			table.insert(embers, brazier)
			quench(model, { brazier.Position }, 4, { fire = true })
		elseif anchorId == "temple_colossus" then
			-- the colossus's eyes (Props.dragonStatue at scale 1.6, 8 studs behind the sanctuary's middle)
			local eyes: { Vector3 } = {}
			for _, side in { -1, 1 } do
				local eye = base * CFrame.new(side * 1.28, 15.56, 1.1)
				table.insert(eyes, eye.Position)
				part(model, Vector3.new(1, 0.8, 0.4), eye, "#2A2E36", Enum.Material.Slate)
			end
			quench(model, eyes, 2.5, { glow = true })
		end
		table.insert(embers, base * CFrame.new(0, 0.2, 1.2))
		for i, cf in embers do
			part(
				model,
				Vector3.new(0.75, 2.4, 2.4),
				cf * CFrame.Angles(0, 0, math.rad(90)),
				"#1A1716",
				Enum.Material.Slate,
				Enum.PartType.Cylinder
			)
			for k = 0, 3 do
				part(
					model,
					Vector3.new(0.3, 0.2, 0.3),
					cf * CFrame.new(math.cos(k * 1.6) * 0.6, 0.42, math.sin(k * 1.6) * 0.6),
					"#3A1A10",
					Enum.Material.Neon
				).Transparency =
					0.5
			end
			if i == 1 then
				local holder = part(model, Vector3.new(0.2, 0.2, 0.2), cf * CFrame.new(0, 0.6, 0), "#000000")
				holder.Transparency = 1
				local smoke = Instance.new("Smoke")
				smoke.Opacity = 0.08
				smoke.RiseVelocity = 3
				smoke.Size = 1.2
				smoke.Color = Color3.fromHex("#8A8A8A")
				smoke.Parent = holder
				task.delay(6, function()
					if smoke.Parent then
						smoke.Enabled = false
					end
				end)
			end
		end
	end,
	-- S105: the oath sworn (oathWords): the block of ice on the chapel's altar split in two halves, the order's sword
	-- glowing gold and blue, a faint light (the altar 7 studs behind the anchor, its top found by a ray)
	oath = function(model, base)
		local altar = base * CFrame.new(0, 0, -7)
		local top = surfaceY(altar.Position, base.Position.Y) or (base.Position.Y + 5)
		local block = CFrame.new(altar.Position.X, top + 3, altar.Position.Z)
		for _, side in { -1, 1 } do
			part(
				model,
				Vector3.new(1.3, 6.2, 2.6),
				block * CFrame.new(side * 1, -0.2, 0) * CFrame.Angles(0, 0, math.rad(side * 9)),
				"#BFE8FF",
				Enum.Material.Glass
			).Transparency =
				0.35
		end
		local blade = part(model, Vector3.new(0.44, 5.2, 0.24), block, "#E8C25A", Enum.Material.Neon)
		part(model, Vector3.new(0.12, 4.6, 0.26), block * CFrame.new(0, -0.1, 0), "#9FE0FF", Enum.Material.Neon)
		part(model, Vector3.new(2, 0.45, 0.45), block * CFrame.new(0, 1.4, 0), "#C8D0D8", Enum.Material.Metal)
		light(blade, "#E8C25A", 12, 0.8)
	end,
	-- S105: the broken rite (voiceOfWinter) while the scene of the same name waits (riteKind)
	riteBare = function(model, base)
		brokenRite(model, base)
	end,
	-- S105: the broken rite and Ilvar's statue of ice by the altar, the arm stretched out (the scene's figure turned
	-- to ice)
	rite = function(model, base)
		brokenRite(model, base)
		StoryProps.iceStatue(model, base * CFrame.new(0, 0, 9) * CFrame.new(3.4, 0, 0.5))
	end,
	-- S105: the Thorn of Vael in the Heart of Winter (firstSpring): the shaft leaning out towards the player, a gold
	-- glow over the crystal's blue, a ring of melted snow with grass and the flowers of the spring in Vaelthorn
	-- (Logic/TownGen/Spring.FLOWERS); the circle's middle is 4 studs behind the anchor summit_thorn
	thorn = function(model, base)
		local centre = base * CFrame.new(0, 0, 4)
		local heart = centre * CFrame.new(0, Rite.heartY(), 0)
		StoryProps.thorn(model, heart * CFrame.new(0, 0, -0.6) * CFrame.Angles(math.rad(-35), 0, 0))
		local glow = part(model, Vector3.new(4, 4, 4), heart, StoryProps.GOLD, Enum.Material.Neon, Enum.PartType.Ball)
		glow.Transparency = 0.55
		light(glow, StoryProps.GOLD, 22, 1.4)
		part(
			model,
			Vector3.new(0.1, 13, 13),
			centre * CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.rad(90)),
			"#6E9A4A",
			Enum.Material.LeafyGrass,
			Enum.PartType.Cylinder
		)
		for k = 1, 16 do
			local a = k * 2.4
			local d = 3 + (k % 4) * 0.8
			local at = centre * CFrame.new(math.cos(a) * d, 0, math.sin(a) * d)
			part(model, Vector3.new(0.12, 0.5, 0.12), at * CFrame.new(0, 0.3, 0), "#5E8A4A", Enum.Material.Grass)
			part(
				model,
				Vector3.new(0.55, 0.55, 0.55),
				at * CFrame.new(0, 0.62, 0),
				Spring.FLOWERS[(k - 1) % #Spring.FLOWERS + 1],
				Enum.Material.SmoothPlastic,
				Enum.PartType.Ball
			)
		end
	end,

	-- S106: Duskwood side arcs
	-- a road lantern set up again on its stump: a new post, the arm and the cage with a cold blue flame (darkLanterns)
	lamp = function(model, base, anchorId)
		local at = sideSpot(base, anchorId)
		part(model, Vector3.new(0.45, 5, 0.45), at * CFrame.new(0, 2.5, 0), "#5A4632", Enum.Material.Wood)
		part(model, Vector3.new(1.5, 0.25, 0.25), at * CFrame.new(0.6, 4.9, 0), "#2E2A28", Enum.Material.Metal)
		local cage =
			part(model, Vector3.new(0.9, 1.1, 0.9), at * CFrame.new(1.2, 4.15, 0), "#3A3E44", Enum.Material.Metal)
		cage.Transparency = 0.5
		local flame = part(
			model,
			Vector3.new(0.45, 0.6, 0.45),
			at * CFrame.new(1.2, 4.15, 0),
			"#7FB8FF",
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		light(flame, "#7FB8FF", 16, 1.5)
	end,
	-- a smudge pot smoking under the hive, an ember glowing in it (smokedHives)
	smoke = function(model, base, anchorId)
		local at = sideSpot(base, anchorId) * CFrame.new(0.9, 0, -1.2)
		part(
			model,
			Vector3.new(0.7, 0.8, 0.8),
			at * CFrame.new(0, 0.35, 0) * CFrame.Angles(0, 0, math.rad(90)),
			"#8A5A3A",
			Enum.Material.Slate,
			Enum.PartType.Cylinder
		)
		local ember = part(
			model,
			Vector3.new(0.4, 0.4, 0.4),
			at * CFrame.new(0, 0.75, 0),
			"#FF8A3A",
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		local smoke = Instance.new("Smoke")
		smoke.Color = Color3.fromHex("#C8C4BC")
		smoke.Opacity = 0.25
		smoke.RiseVelocity = 3
		smoke.Size = 1.2
		smoke.Parent = ember
		light(ember, "#FF8A3A", 6, 0.8)
	end,
	-- a heather wreath on the cleaned grave and one lit candle beside it (nameless)
	wreath = function(model, base)
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			part(
				model,
				Vector3.new(0.45, 0.35, 0.45),
				base * CFrame.new(math.cos(a) * 0.6, 0.2, 0.8 + math.sin(a) * 0.6),
				if i % 2 == 0 then "#8A4A7A" else "#6A3A62",
				Enum.Material.Grass,
				Enum.PartType.Ball
			)
		end
		part(
			model,
			Vector3.new(0.6, 0.28, 0.28),
			base * CFrame.new(1.3, 0.3, 0.4) * CFrame.Angles(0, 0, math.rad(90)),
			"#EADFC4",
			Enum.Material.SmoothPlastic,
			Enum.PartType.Cylinder
		)
		local flame = part(
			model,
			Vector3.new(0.18, 0.3, 0.18),
			base * CFrame.new(1.3, 0.75, 0.4),
			"#FFB347",
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		light(flame, "#FFB347", 10, 1.2)
	end,
	-- the cage's door swung open by 70 degrees on its hinge, the rope that tied it cut on the ground (cultCages)
	cage = function(model, base)
		local hinge = base * CFrame.new(-1.1, 1.25, -2)
		local door = hinge * CFrame.Angles(0, math.rad(70), 0) * CFrame.new(1.1, 0, 0)
		local frame = part(model, Vector3.new(2.2, 2.4, 0.12), door, "#2E2A28", Enum.Material.Metal)
		frame.Transparency = 0.6
		for _, x in { -0.6, 0, 0.6 } do
			part(model, Vector3.new(0.12, 2.4, 0.14), door * CFrame.new(x, 0, 0), "#3A3632", Enum.Material.Metal)
		end
		for k = 0, 1 do
			part(
				model,
				Vector3.new(1, 0.1, 0.1),
				base * CFrame.new(0.3 + k * 0.8, 0.06, -0.9 + k * 0.3) * CFrame.Angles(0, math.rad(25 + k * 50), 0),
				"#8A7A58",
				Enum.Material.Fabric
			)
		end
	end,
	-- the hex charm burnt to a pile of ash and a small white ward board with the temple's sign on a stake (hexCharms)
	ward = function(model, base, anchorId)
		local at = sideSpot(base, anchorId) * CFrame.new(0.6, 0, -0.9)
		part(model, Vector3.new(0.18, 1.6, 0.18), at * CFrame.new(0, 0.8, 0), "#6B5038", Enum.Material.Wood)
		local board = part(
			model,
			Vector3.new(0.9, 0.65, 0.08),
			at * CFrame.new(0, 1.6, 0),
			"#EDEBE4",
			Enum.Material.SmoothPlastic
		)
		for _, r in { 0, 90 } do
			part(
				model,
				Vector3.new(0.08, 0.45, 0.04),
				board.CFrame * CFrame.new(0, 0, -0.06) * CFrame.Angles(0, 0, math.rad(r)),
				"#5A4A3A",
				Enum.Material.SmoothPlastic
			)
		end
		part(
			model,
			Vector3.new(1.4, 0.18, 1),
			at * CFrame.new(-0.9, 0.06, 0.2),
			"#3A3634",
			Enum.Material.Slate,
			Enum.PartType.Ball
		)
	end,
	-- the witches' cauldron knocked on its side, its mouth to the player, the green brew soaking into the mud
	-- (witchCauldron; the cauldron stands 3 studs behind the anchor, Logic/DuskwoodGen/Witch)
	spill = function(model, base)
		local pot = base * CFrame.new(0, 1.5, -3)
		part(
			model,
			Vector3.new(4.3, 3.7, 4.3),
			pot * CFrame.Angles(math.rad(75), 0, 0),
			"#24221F",
			Enum.Material.Metal,
			Enum.PartType.Ball
		)
		part(
			model,
			Vector3.new(0.1, 2.8, 2.8),
			pot * CFrame.new(0, 0.2, 2) * CFrame.Angles(0, math.rad(90), 0),
			"#0E0E0C",
			Enum.Material.SmoothPlastic,
			Enum.PartType.Cylinder
		)
		local puddle = part(
			model,
			Vector3.new(0.08, 4.6, 3.4),
			base * CFrame.new(0, 0.05, -0.4) * CFrame.Angles(0, math.rad(90), math.rad(90)),
			"#5AE07A",
			Enum.Material.Glass,
			Enum.PartType.Cylinder
		)
		puddle.Transparency = 0.25
		for i = 1, 3 do
			part(
				model,
				Vector3.new(0.7, 0.12, 0.5),
				base * CFrame.new(-1.6 + i * 0.8, 0.06, 1.2 + (i % 2) * 0.4) * CFrame.Angles(0, i, 0),
				"#3E8A4A",
				Enum.Material.Glass
			)
		end
	end,
	-- S107 (the Ashen side arcs) -------------------------------------------------------------------------------------
	-- a basalt warning cairn with a red rag on a stick, raised from the loose lumps of its prop (glands)
	cairn = function(model, base, anchorId)
		local spot = ashSpot(base, anchorId)
		local y = 0
		for k, s in { 1.4, 1.1, 0.85, 0.6 } do
			local h = s * 0.5
			part(
				model,
				Vector3.new(s, h, s * 0.85),
				spot * CFrame.new(0, y + h / 2, 0) * CFrame.Angles(0, k * 0.6, math.rad((k % 2) * 4 - 2)),
				"#2E2A28",
				Enum.Material.Slate
			)
			y += h
		end
		part(model, Vector3.new(0.15, 1, 0.15), spot * CFrame.new(0, y + 0.45, 0), "#6B5038", Enum.Material.Wood)
		part(model, Vector3.new(0.8, 0.5, 0.05), spot * CFrame.new(0.42, y + 0.7, 0), "#A3282A", Enum.Material.Fabric)
	end,
	-- the well dug out: a ring of six stones round dark water with a glint, a wooden bucket beside it (wells); the
	-- water lies above the prop's sand mound (top at 0.35, Logic/AshenGen/Quest buriedWell), which stays in the map
	water = function(model, base, anchorId)
		local spot = ashSpot(base, anchorId)
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			part(
				model,
				Vector3.new(0.9, 0.6, 0.7),
				spot * CFrame.new(math.cos(a) * 1.6, 0.3, math.sin(a) * 1.6) * CFrame.Angles(0, -a, 0),
				"#3A3630",
				Enum.Material.Slate
			)
		end
		local pool = part(
			model,
			Vector3.new(0.15, 3, 3),
			spot * CFrame.new(0, 0.42, 0) * CFrame.Angles(0, 0, math.rad(90)),
			"#24414E",
			Enum.Material.Glass,
			Enum.PartType.Cylinder
		)
		pool.Transparency = 0.2
		part(
			model,
			Vector3.new(0.1, 0.6, 0.6),
			spot * CFrame.new(0.4, 0.5, -0.3) * CFrame.Angles(0, 0, math.rad(90)),
			"#7FB8D8",
			Enum.Material.Neon,
			Enum.PartType.Cylinder
		)
		part(
			model,
			Vector3.new(0.8, 0.75, 0.75),
			spot * CFrame.new(2.5, 0.4, 0.4) * CFrame.Angles(0, 0, math.rad(90)),
			"#7A5A3A",
			Enum.Material.WoodPlanks,
			Enum.PartType.Cylinder
		)
	end,
	-- three clay bowls of smouldering herbs on a flat stone, smoke from the middle one (rite at the Hot Spring; altar
	-- on the top of the east courtyard's altar, 6 studs along the anchor's +Z, Necropolis courtyardEast)
	incense = function(model, base, anchorId)
		local spot = ashSpot(base, anchorId)
		if anchorId == "ash_courtyard_altar" then
			local p = (base * CFrame.new(0, 0, 6)).Position
			local top = surfaceY(p, p.Y + 3)
			if top then
				spot = CFrame.new(p.X, top, p.Z) * base.Rotation
			end
		end
		part(model, Vector3.new(2.2, 0.25, 1.4), spot * CFrame.new(0, 0.12, 0), "#5A5650", Enum.Material.Slate)
		for k = -1, 1 do
			local bowl = spot * CFrame.new(k * 0.65, 0.4, 0)
			part(
				model,
				Vector3.new(0.3, 0.8, 0.8),
				bowl * CFrame.Angles(0, 0, math.rad(90)),
				"#6B5038",
				Enum.Material.Slate,
				Enum.PartType.Cylinder
			)
			local ember = part(
				model,
				Vector3.new(0.2, 0.2, 0.2),
				bowl * CFrame.new(0, 0.16, 0),
				"#FF8A3A",
				Enum.Material.Neon,
				Enum.PartType.Ball
			)
			if k == 0 then
				local smoke = Instance.new("Smoke")
				smoke.Color = Color3.fromHex("#B8A878")
				smoke.Opacity = 0.2
				smoke.RiseVelocity = 3
				smoke.Size = 0.8
				smoke.Parent = ember
				light(ember, "#FF9A4A", 10, 1)
			end
		end
	end,
	-- the war drum's skin slashed: a flap of hide hanging at 40 degrees against the dais, a smaller one on the ground
	-- and the broken drumstick (drum; the dais's near corner is about 5 / 5 studs from the anchor, Warcamp warDrum)
	drum = function(model, base)
		local corner = base * CFrame.new(4.2, 0, 4.2) * CFrame.Angles(0, math.rad(45), 0)
		part(
			model,
			Vector3.new(2.6, 0.1, 1.6),
			corner * CFrame.new(0, 1, -0.4) * CFrame.Angles(math.rad(40), 0, 0),
			"#5A3A2A",
			Enum.Material.Fabric
		)
		part(
			model,
			Vector3.new(1.4, 0.08, 1),
			base * CFrame.new(1.6, 0.05, 1.2) * CFrame.Angles(0, math.rad(30), 0),
			"#5A3A2A",
			Enum.Material.Fabric
		)
		for k = 0, 1 do
			part(
				model,
				Vector3.new(0.25, 1, 0.25),
				base
					* CFrame.new(0.6 + k * 0.7, 0.13, -0.6 + k * 0.4)
					* CFrame.Angles(0, math.rad(20 + k * 70), math.rad(90)),
				"#6B5038",
				Enum.Material.Wood
			)
		end
	end,
	-- the polished shield on a stake by the basilisk's pit, tilted and turned to face the pit (mirror)
	mirror = function(model, base, anchorId)
		local data = Areas.anchorById(anchorId)
		local sites = Areas.byMap.ashen.sites
		local den = if sites then sites.basiliskDen else nil
		local stake = base * CFrame.new(0, 1.5, 0)
		part(model, Vector3.new(0.3, 3, 0.3), stake, "#6B5038", Enum.Material.Wood)
		local top = (base * CFrame.new(0, 2.4, 0)).Position
		local target = top + (base * CFrame.new(0, 0, -4)).Position - base.Position
		if data and den then
			target = top + Vector3.new(den.x - data.x, 0, den.z - data.z)
		end
		local shield = part(
			model,
			Vector3.new(0.15, 2.2, 2.2),
			CFrame.lookAt(top, Vector3.new(target.X, top.Y, target.Z))
				* CFrame.new(0, 0, -0.2)
				* CFrame.Angles(math.rad(-15), 0, 0)
				* CFrame.Angles(0, math.rad(90), 0),
			"#C9A45C",
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
		shield.Reflectance = 0.5
	end,
}

-- S105: while voiceOfWinter runs, Ilvar's statue waits for the scene of the same name (its figure stands on that
-- spot and turns to ice at the end); after the scene or the hand-in it stays.
local function riteKind(quests: any): string
	local scenes = if type(quests) == "table" then quests.scenes else nil
	if (type(scenes) == "table" and scenes.voiceOfWinter == true) or StoryProgress.isDone(quests, "voiceOfWinter") then
		return "rite"
	end
	return "riteBare"
end

local function groundUnder(anchor: Anchor): CFrame
	local data = Areas.anchorById(anchor.id)
	local lift = if data and data.y then data.y else 2
	-- S103: the anchor's yaw (the frame of a generator prop)
	local yaw = if data and data.rot then math.rad(data.rot) else 0
	return CFrame.new(anchor.part.Position - Vector3.new(0, lift, 0)) * CFrame.Angles(0, yaw, 0)
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
	builder(model, groundUnder(anchor), anchor.id)
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
		-- S102: an anchor of the active story quest
		local quest: Quests.MainQuest | Quests.SideQuest | nil = if target
			then (if target.main then Quests.Main.get(target.quest) else Quests.npcQuest(target.quest))
			else nil
		local objective = if quest and target then quest.objectives[target.index] else nil
		anchor.prompt.Enabled = objective ~= nil
		anchor.marker.Enabled = objective ~= nil
		if quest and objective then
			anchor.prompt.ActionText = Text.now(objective.action or "quest.use.default")
			anchor.prompt.ObjectText = Text.now(`quest.{quest.id}.title`)
		end
		local kind = done[id]
		setFx(anchor, if kind == "rite" then riteKind(quests) else kind)
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
