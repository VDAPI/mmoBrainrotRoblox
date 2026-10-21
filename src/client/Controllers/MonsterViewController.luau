--!strict
-- Monster looks on the client (S24, ARCHITECTURE §7). The server sends only a body (invisible
-- HumanoidRootPart + Humanoid) with the attributes Look, LookScale, LookRegion and Variant; this controller
-- builds what players see inside each monster model (a Model "Look" welded to the root), so clicks,
-- Highlights and bounding boxes keep working.
--   * every monster gets a 2-3 part silhouette ("LookFar") at once;
--   * the full look (Logic/Anatomy via Util/LookBuild, or a real model from ReplicatedStorage.Assets.Monsters
--     when Data/MonsterLooks names one) is built from a queue, nearest first, at most
--     Config.MonsterLook.partsPerFrame parts per frame, within fullIn studs of the camera; past fullOut it is
--     hidden (LocalTransparencyModifier) and the silhouette shows; past drop it is destroyed;
--   * a dead monster's look fades over Config.CorpseSeconds; boss phases tint it (MonsterLooks phases);
--   * a model that streams out keeps its children (Parent = nil), so a returning model reuses its "Look".
-- API: top(model) = world Y of the top of the look (from the rig, never from the live HipHeight, which a
-- flying boss raises), Changed (BindableEvent: model) when the full look appears or goes away, IsFull(model),
-- Stats() for /lookstats.
-- S117 (DESIGN-16 §8, E7): a dead boss keeps its look for Config.MonsterLook.deathSeconds (its death pose, Logic/Gait),
-- then a clone of the look in that pose takes its place (the original goes invisible; the server removes it soon after)
-- and breaks up in the light of Data/BossMotions death.light over its seconds: a flash, smoke and sparks of its glow, the
-- parts fading. Low quality: no clone, a longer light on the original, which fades like any corpse. OnBossDeath(fn)
-- tells CombatFxController to shake the camera.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Anatomy = require(ReplicatedStorage.Shared.Logic.Anatomy)
local BossMotions = require(ReplicatedStorage.Shared.Data.BossMotions)
local Clock = require(script.Parent.Parent.Vfx.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Library = require(script.Parent.Parent.Vfx.Library)
local Pool = require(script.Parent.Parent.Vfx.Pool)
local LookBuild = require(ReplicatedStorage.Shared.Util.LookBuild)
local MonsterLooks = require(ReplicatedStorage.Shared.Data.MonsterLooks)
local State = require(script.Parent.Parent.UI.State)

local MonsterViewController = {
	Name = "MonsterViewController",
}

local LOOK = Config.MonsterLook
local changedEvent = Instance.new("BindableEvent")
MonsterViewController.Changed = changedEvent.Event

type Body = { rootHalf: number, hipHeight: number, height: number }

type View = {
	model: Model,
	root: BasePart,
	lookId: string,
	variant: string,
	scale: number,
	look: MonsterLooks.Look?,
	rig: Anatomy.Rig?, -- full rig (nil for real models)
	body: Body,
	assetName: string?, -- Assets.Monsters model to clone
	full: Model?,
	fullParts: { BasePart },
	fullShown: boolean,
	far: Model?,
	farParts: { BasePart },
	farShown: boolean,
	queued: boolean,
	distance: number,
	deadAt: number?,
	phase: number,
	connections: { RBXScriptConnection },
	bossId: string?, -- S117: a boss look gets the long death (E7)
}

local views: { [Model]: View } = {}
-- S117: who hears of a boss's death (CombatFxController: the camera shake).
local bossDeathListeners: { (model: Model, bossId: string) -> () } = {}
local dying: { [View]: boolean } = {}
local queue: { View } = {}
local rigCache: { [string]: Anatomy.Rig } = {}
local warned: { [string]: boolean } = {}

local function rigFor(
	lookId: string,
	look: MonsterLooks.Look,
	variant: string,
	scale: number,
	lod: string?
): Anatomy.Rig
	local key = `{lookId}|{variant}|{math.floor(scale * 1000 + 0.5)}|{lod or "full"}`
	local rig = rigCache[key]
	if not rig then
		rig = Anatomy.build(look :: any, { id = lookId, variant = variant, scale = scale, lod = lod :: any })
		rigCache[key] = rig
	end
	return rig
end

local function partsOf(model: Model): { BasePart }
	local parts: { BasePart } = {}
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") and item.Name ~= "LookRoot" then
			table.insert(parts, item)
		end
	end
	return parts
end

local function setShown(parts: { BasePart }, shown: boolean)
	local modifier = if shown then 0 else 1
	for _, part in parts do
		part.LocalTransparencyModifier = modifier
	end
end

-- `offset`: where the model's pivot sits relative to the root (generated looks: the root centre; real models:
-- their PrimaryPart stands on the ground, docs/MODELE.md §5).
-- W26 `body`: a real model without clips (rig "static") hangs on a Motor6D with the Gait body role instead, so
-- AnimationController bobs, leans, flinches and topples the whole model like a generated body (S159g: a model with
-- bone clips too, for the procedural gestures over its clips).
local function weldTo(model: Model, root: BasePart, offset: CFrame?, body: { scale: number, hover: boolean }?)
	local primary = model.PrimaryPart
	if not primary then
		return
	end
	local c0 = offset or CFrame.identity
	primary.Anchored = false
	model:PivotTo(root.CFrame * c0)
	if body then
		local motor = Instance.new("Motor6D")
		motor.Name = "Gait_Body"
		motor.Part0 = root
		motor.Part1 = primary
		motor.C0 = c0
		motor:SetAttribute("Role", "body")
		motor:SetAttribute("Side", 0)
		motor:SetAttribute("Phase", 0)
		motor:SetAttribute("Amp", if body.hover then 1.3 else 1)
		motor:SetAttribute("Scale", body.scale)
		motor:SetAttribute("Front", 0)
		motor.Parent = primary
		return
	end
	local weld = Instance.new("Weld")
	weld.Name = "LookWeld"
	weld.Part0 = root
	weld.Part1 = primary
	weld.C0 = c0
	weld.Parent = primary
end

local function groundOffset(body: { rootHalf: number, hipHeight: number }): CFrame
	return CFrame.new(0, -(body.rootHalf + body.hipHeight), 0)
end

-- W26: a variant's colour over its base's model (Data/MonsterAssetVariants). Tripo textures are multiplied by it
-- (SurfaceAppearance.Color, the way hair colours tint, AvatarBuild); a textured MeshPart without a SurfaceAppearance
-- gets one over its texture when the engine allows it (else it keeps its texture as it is); untextured parts take the
-- product as their Color.
local function multiply(a: Color3, b: Color3): Color3
	return Color3.new(a.R * b.R, a.G * b.G, a.B * b.B)
end

local function recolor(model: Model, color: Color3)
	for _, item in model:GetDescendants() do
		if item:IsA("SurfaceAppearance") then
			pcall(function()
				(item :: any).Color = color
			end)
		elseif item:IsA("MeshPart") then
			if item.TextureID == "" then
				item.Color = multiply(item.Color, color)
			elseif not item:FindFirstChildOfClass("SurfaceAppearance") then
				local surface = Instance.new("SurfaceAppearance")
				local ok = pcall(function()
					(surface :: any).ColorMap = item.TextureID;
					(surface :: any).Color = color
				end)
				-- only when the texture really moved over (a SurfaceAppearance without it would blank the part)
				if ok and (surface :: any).ColorMap == item.TextureID then
					surface.Parent = item
				else
					surface:Destroy()
				end
			end
		elseif item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" then
			item.Color = multiply(item.Color, color)
		end
	end
end

-- Real model from Assets.Monsters: scripts stripped, Humanoid replaced by an AnimationController + Animator,
-- scaled once; its PrimaryPart stands on the ground under the root (docs/MODELE.md §5, docs/ASSETS.md).
local function cloneAsset(lookId: string, look: MonsterLooks.Look?, scale: number, region: number?): Model?
	local asset = look and look.asset
	if not asset then
		return nil
	end
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Monsters")
	local template = folder and folder:FindFirstChild(asset.model)
	if not template or not template:IsA("Model") then
		-- W26: a variant whose base model is missing quietly keeps its generated look
		if not warned[lookId] and not asset.variant then
			warned[lookId] = true
			warn(`[MonsterView] Assets.Monsters.{asset.model} not found; {lookId} uses the generator`)
		end
		return nil
	end
	local model = template:Clone()
	if LookBuild.stripScripts(model) > 0 and not warned[`scripts:{lookId}`] then
		warned[`scripts:{lookId}`] = true
		warn(`[MonsterView] removed scripts from Assets.Monsters.{asset.model}`)
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:Destroy()
	end
	local controller = model:FindFirstChildOfClass("AnimationController")
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Parent = model
	end
	if not (controller :: AnimationController):FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = controller
	end
	if not model.PrimaryPart then
		model.PrimaryPart = (
			model:FindFirstChild("HumanoidRootPart") or model:FindFirstChildWhichIsA("BasePart", true)
		) :: BasePart?
	end
	if not model.PrimaryPart then
		model:Destroy()
		return nil
	end
	-- W26: `visual` grows the drawn model only (its pivot stands at the feet, so it still stands on the ground)
	local factor = scale * (asset.scale or 1) * (asset.visual or 1)
	if math.abs(factor - 1) > 1e-3 then
		model:ScaleTo(model:GetScale() * factor)
	end
	for _, item in model:GetDescendants() do
		if item:IsA("BasePart") then
			item.Anchored = false
			item.CanCollide = false
			item.CanTouch = false
			item.Massless = true
			if item.Name == "HumanoidRootPart" then
				item.Transparency = 1
				item.CanQuery = false
			end
		end
	end
	model.Name = "Look"
	if asset.tint and region then
		local regionLook = MonsterLooks.REGIONS[MonsterLooks.REGION_BY_NUMBER[region] or ""]
		if regionLook and regionLook.amount > 0 then
			local tint = Color3.fromHex(regionLook.tint)
			for _, item in model:GetDescendants() do
				if item:IsA("BasePart") then
					item.Color = item.Color:Lerp(tint, regionLook.amount)
				end
			end
		end
	end
	if asset.color then
		recolor(model, Color3.fromHex(asset.color))
	end
	return model
end

local function applyPhase(view: View)
	local full = view.full
	local look = view.look
	if not full or not view.rig or not look then
		return
	end
	local phase = look.phases and look.phases[view.phase]
	if phase then
		LookBuild.tint(full, view.rig :: any, phase.tint, phase.amount, phase.glow)
	elseif view.phase >= 1 then
		LookBuild.tint(full, view.rig :: any, nil, 0, nil)
	end
end

local function buildFull(view: View)
	local model: Model? = nil
	local offset: CFrame? = nil
	local cloned = false
	if view.assetName then
		local region = view.model:GetAttribute("LookRegion")
		model = cloneAsset(view.lookId, view.look, view.scale, if type(region) == "number" then region else nil)
		if model then
			offset = groundOffset(view.body)
			cloned = true
		end
	end
	if not model then
		local rig = view.rig
		if not rig and view.look then
			rig = rigFor(view.lookId, view.look, view.variant, view.scale)
			view.rig = rig
		end
		if not rig then
			return
		end
		model = LookBuild.build(rig :: any, { name = "Look", cframe = view.root.CFrame, scale = view.scale, fx = true })
		if view.assetName then
			-- The model is missing: the generated look stands on the ground the server sized for the model.
			offset = groundOffset(view.body) * CFrame.new(0, rig.root.size[2] / 2 + rig.hipHeight, 0)
			view.body.height = rig.height
		end
	end
	local look = model :: Model
	local asset = view.look and view.look.asset
	-- S159g: a model with bone clips hangs on the body motor too (the gestures and roars move the whole body on it,
	-- client/Anim/BoneOverlay); it stays at rest while the clips play alone
	local body = if view.assetName
			and asset
			and asset.rig == "static"
			and look:GetAttribute("Hover") ~= nil
		then { scale = view.scale, hover = (tonumber(look:GetAttribute("Hover")) or 0) > 0 }
		elseif cloned and asset and asset.rig == "bones" then { scale = view.scale, hover = false }
		else nil
	weldTo(look, view.root, offset, body)
	look.Parent = view.model
	view.full = look
	view.fullParts = partsOf(look)
	view.fullShown = true
	applyPhase(view)
	changedEvent:Fire(view.model)
end

local function destroyFull(view: View)
	if view.full then
		view.full:Destroy()
		view.full = nil
		view.fullParts = {}
		view.fullShown = false
		changedEvent:Fire(view.model)
	end
end

local function buildFar(view: View)
	if view.far or not view.look then
		return
	end
	local rig = rigFor(view.lookId, view.look, view.variant, view.scale, "far")
	local far = LookBuild.build(rig :: any, { name = "LookFar", cframe = view.root.CFrame, shadows = false })
	-- Real models: the silhouette (from the generator) stands on the ground the server sized for the model.
	weldTo(
		far,
		view.root,
		if view.assetName then groundOffset(view.body) * CFrame.new(0, rig.root.size[2] / 2 + rig.hipHeight, 0) else nil
	)
	far.Parent = view.model
	view.far = far
	view.farParts = partsOf(far)
	view.farShown = true
end

local function track(model: Instance)
	if not model:IsA("Model") or views[model] then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local lookId = model:GetAttribute("Look")
	if not root or not root:IsA("BasePart") or type(lookId) ~= "string" then
		return
	end
	local variant = model:GetAttribute("Variant")
	local scale = model:GetAttribute("LookScale")
	local region = model:GetAttribute("LookRegion")
	local look = MonsterLooks.get(lookId, if type(region) == "number" then region else nil)
	local v = if type(variant) == "string" then variant else "normal"
	local s = if type(scale) == "number" then scale else 1
	local body: Body
	local assetName: string? = nil
	if look and look.asset then
		local asset = look.asset
		local k = s * (asset.scale or 1)
		body = {
			rootHalf = asset.rootSize[2] * k / 2,
			hipHeight = asset.hipHeight * k,
			height = asset.height * k * (asset.visual or 1),
		}
		assetName = asset.model
	elseif look then
		local rig = rigFor(lookId, look, v, s)
		body = { rootHalf = rig.root.size[2] / 2, hipHeight = rig.hipHeight, height = rig.height }
	else
		body = { rootHalf = root.Size.Y / 2, hipHeight = 2, height = root.Size.Y + 2 }
	end
	local view: View = {
		model = model,
		root = root,
		lookId = lookId,
		variant = v,
		scale = s,
		look = look,
		rig = nil,
		body = body,
		assetName = assetName,
		full = nil,
		fullParts = {},
		fullShown = false,
		far = nil,
		farParts = {},
		farShown = false,
		queued = false,
		distance = math.huge,
		deadAt = nil,
		phase = (model:GetAttribute("Phase") :: number?) or 1,
		connections = {},
		bossId = if v == "boss" and BossMotions.get(lookId) then lookId else nil,
	}
	views[model] = view
	-- Streamed back in: reuse what this client already built.
	local existing = model:FindFirstChild("Look")
	if existing and existing:IsA("Model") then
		view.full = existing
		view.fullParts = partsOf(existing)
		view.fullShown = true
		if look and not look.asset then
			view.rig = rigFor(lookId, look, v, s)
		end
		changedEvent:Fire(model)
	end
	local far = model:FindFirstChild("LookFar")
	if far and far:IsA("Model") then
		view.far = far
		view.farParts = partsOf(far)
		view.farShown = true
	else
		buildFar(view)
	end
	table.insert(
		view.connections,
		model:GetAttributeChangedSignal("Phase"):Connect(function()
			view.phase = (model:GetAttribute("Phase") :: number?) or 1
			applyPhase(view)
		end)
	)
	local function onDead()
		if model:GetAttribute("Dead") == true and not view.deadAt then
			view.deadAt = os.clock()
			dying[view] = true
			if view.bossId then
				for _, fn in bossDeathListeners do
					task.spawn(fn, model, view.bossId)
				end
			end
			for _, holder in { view.full, view.far } do
				if holder then
					for _, item in holder:GetDescendants() do
						if item:IsA("ParticleEmitter") then
							item.Enabled = false
						end
					end
				end
			end
		end
	end
	table.insert(view.connections, model:GetAttributeChangedSignal("Dead"):Connect(onDead))
	onDead()
end

local function untrack(model: Instance)
	local view = views[model :: Model]
	if view then
		views[model :: Model] = nil
		dying[view] = nil
		for _, connection in view.connections do
			connection:Disconnect()
		end
		local index = table.find(queue, view)
		if index then
			table.remove(queue, index)
		end
	end
end

local function lowQuality(): boolean
	return State.Get({ "account", "settings", "quality" }) == "low"
end

-- Every checkEvery seconds: distances, LOD decisions and the build queue.
local function check()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local low = lowQuality()
	local fullIn = if low then LOOK.fullInLow else LOOK.fullIn
	local fullOut = if low then LOOK.fullOutLow else LOOK.fullOut
	for model, view in views do
		if not model.Parent then
			untrack(model)
			continue
		end
		local d = (view.root.Position - eye).Magnitude
		view.distance = d
		if view.deadAt then
			continue
		end
		if d <= fullIn then
			if view.full then
				if not view.fullShown then
					view.fullShown = true
					setShown(view.fullParts, true)
					changedEvent:Fire(model)
				end
			elseif not view.queued then
				view.queued = true
				table.insert(queue, view)
			end
		elseif d > LOOK.drop then
			destroyFull(view)
		elseif d > fullOut and view.full and view.fullShown then
			view.fullShown = false
			setShown(view.fullParts, false)
			changedEvent:Fire(model)
		end
		local wantFar = not (view.full and view.fullShown)
		if view.far and wantFar ~= view.farShown then
			view.farShown = wantFar
			setShown(view.farParts, wantFar)
		end
	end
	table.sort(queue, function(a, b)
		return a.distance < b.distance
	end)
end

local function drainQueue()
	local budget = LOOK.partsPerFrame
	while budget > 0 and #queue > 0 do
		local view = table.remove(queue, 1) :: View
		view.queued = false
		if view.model.Parent and views[view.model] == view and not view.full and not view.deadAt then
			local count = if view.rig then LookBuild.count(view.rig :: any) else 40
			buildFull(view)
			budget -= count
			if view.far and view.farShown then
				view.farShown = false
				setShown(view.farParts, false)
			end
		end
	end
end

-- S117 (E7): the clone of a dead boss's look, anchored in the pose it died in, breaking up in light.
local function bossClone(view: View)
	local full = view.full
	local def = BossMotions.get(view.bossId :: string)
	if not full or not def then
		return
	end
	local copy = full:Clone()
	local from = full:GetDescendants()
	local into = copy:GetDescendants()
	local parts: { BasePart } = {}
	for i, item in into do
		local source = from[i]
		if item:IsA("BasePart") and source and source:IsA("BasePart") then
			item.Anchored = true
			item.CanCollide = false
			item.CanQuery = false
			item.CanTouch = false
			item.CFrame = source.CFrame
			item.LocalTransparencyModifier = 0
			table.insert(parts, item)
		elseif item:IsA("JointInstance") or item:IsA("Constraint") or item:IsA("WeldConstraint") then
			item:Destroy()
		elseif item:IsA("ParticleEmitter") then
			item.Enabled = false
		end
	end
	copy.Name = "BossDeath"
	copy.Parent = Pool.folder()
	setShown(view.fullParts, false)
	setShown(view.farParts, false)
	local seconds = def.death.seconds or LOOK.bossDeathSeconds
	local color = Color3.fromHex(def.death.light)
	local primary = copy.PrimaryPart or parts[1]
	if primary and Pool.takeLight() then
		local light = Instance.new("PointLight")
		light.Color = color
		light.Range = 30
		light.Brightness = 0
		light.Parent = primary
		Clock.tween(light, TweenInfo.new(0.3), { Brightness = 6 })
		Clock.after(0.3, function()
			Clock.tween(light, TweenInfo.new(1.2), { Brightness = 0 })
		end)
		Clock.after(1.55, function()
			light:Destroy()
			Pool.dropLight()
		end)
	end
	local centre = if primary then primary.Position else view.root.Position
	local size = math.clamp(view.body.height * 0.3, 1.5, 4)
	for i = 0, 2 do
		Clock.after(seconds * 0.25 * i, function()
			Library.smokePuff(centre, size, color)
			Library.sparks(centre + Vector3.new(0, size * 0.5, 0), color, { count = 14, dir = Vector3.yAxis })
		end)
	end
	for _, part in parts do
		Clock.tween(part, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 })
	end
	Clock.after(seconds + 0.1, function()
		copy:Destroy()
	end)
end

-- S117 (E7), low quality: a longer light of the death colour on the original (no clone).
local function bossLight(view: View)
	local def = BossMotions.get(view.bossId :: string)
	if not def or not Pool.takeLight() then
		return
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex(def.death.light)
	light.Range = 24
	light.Brightness = 4
	light.Parent = view.root
	Clock.tween(light, TweenInfo.new(Config.CorpseSeconds), { Brightness = 0 })
	Clock.after(Config.CorpseSeconds, function()
		light:Destroy()
		Pool.dropLight()
	end)
end

-- Dead monsters fade over CorpseSeconds (the server destroys them right after). S117: a boss holds its death pose
-- for deathSeconds, then its clone takes over (bossClone).
local bossDone: { [View]: boolean } = setmetatable({} :: any, { __mode = "k" })

local function stepDeaths(now: number)
	for view in dying do
		local since = now - (view.deadAt :: number)
		if view.bossId and not bossDone[view] then
			if since < LOOK.deathSeconds then
				continue
			end
			bossDone[view] = true
			if not lowQuality() and view.full and view.fullShown then
				dying[view] = nil
				bossClone(view)
				continue
			end
			bossLight(view)
		end
		local t = math.clamp(since / Config.CorpseSeconds, 0, 1)
		local fade = t * t
		local parts: { BasePart } = if view.full and view.fullShown then view.fullParts else view.farParts
		for _, part in parts do
			part.LocalTransparencyModifier = fade
		end
		if t >= 1 then
			dying[view] = nil
		end
	end
end

-- Preview of a look (/mobviz): the full look of `lookId` (a real model when there is one) with its LookRoot
-- anchored at `cframe`, joints live; returns the model, the rig numbers and whether it is a real model.
function MonsterViewController.BuildPreview(
	lookId: string,
	look: MonsterLooks.Look,
	variant: string,
	scale: number,
	cframe: CFrame
): (Model, {
	rootHalf: number,
	hipHeight: number,
	height: number,
	width: number,
	parts: number,
	real: boolean,
})
	local real = cloneAsset(lookId, look, scale, nil)
	if real then
		local primary = real.PrimaryPart :: BasePart
		local asset = look.asset :: any
		local k = scale * (asset.scale or 1)
		real:PivotTo(cframe * groundOffset({ rootHalf = asset.rootSize[2] * k / 2, hipHeight = asset.hipHeight * k }))
		primary.Anchored = true
		local _, size = real:GetBoundingBox()
		return real,
			{
				rootHalf = asset.rootSize[2] * k / 2,
				hipHeight = asset.hipHeight * k,
				height = asset.height * k,
				width = math.max(size.X, size.Z),
				parts = #partsOf(real),
				real = true,
			}
	end
	local rig = Anatomy.build(look :: any, { id = lookId, variant = variant, scale = scale })
	local model = LookBuild.build(rig :: any, { name = `Preview_{lookId}`, cframe = cframe, scale = scale, fx = true });
	(model.PrimaryPart :: BasePart).Anchored = true
	local width = 0
	for _, piece in rig.pieces do
		width = math.max(width, math.abs(piece.pos[1]) * 2 + piece.size[1], math.abs(piece.pos[3]) * 2 + piece.size[3])
	end
	return model,
		{
			rootHalf = rig.root.size[2] / 2,
			hipHeight = rig.hipHeight,
			height = rig.height,
			width = width,
			parts = #rig.pieces,
			real = false,
		}
end

-- World Y of the top of the look (name plates, damage numbers), or nil for untracked models.
function MonsterViewController.top(model: Model): number?
	local view = views[model]
	if not view then
		return nil
	end
	local body = view.body
	return view.root.Position.Y - body.rootHalf - body.hipHeight + body.height
end

-- S117: `fn(model, bossId)` runs when a boss dies (the start of its long death).
function MonsterViewController.OnBossDeath(fn: (model: Model, bossId: string) -> ())
	table.insert(bossDeathListeners, fn)
end

function MonsterViewController.IsFull(model: Model): boolean
	local view = views[model]
	return view ~= nil and view.full ~= nil and view.fullShown
end

-- Distance of the monster from the camera at the last check (math.huge if unknown).
function MonsterViewController.Distance(model: Model): number
	local view = views[model]
	return if view then view.distance else math.huge
end

-- Rig of a generated full look (nil for real models and untracked monsters).
function MonsterViewController.RigOf(model: Model): Anatomy.Rig?
	local view = views[model]
	return if view and not view.assetName then view.rig else nil
end

-- Counts for /lookstats.
function MonsterViewController.Stats(): {
	tracked: number,
	full: number,
	hidden: number,
	far: number,
	parts: number,
	queued: number,
}
	local out = { tracked = 0, full = 0, hidden = 0, far = 0, parts = 0, queued = #queue }
	for _, view in views do
		out.tracked += 1
		if view.full then
			if view.fullShown then
				out.full += 1
				out.parts += #view.fullParts
			else
				out.hidden += 1
			end
		end
		if view.far and view.farShown then
			out.far += 1
			out.parts += #view.farParts
		end
	end
	return out
end

function MonsterViewController.Start()
	task.spawn(function()
		local folder = Workspace:WaitForChild("Monsters", 60)
		if not folder then
			return
		end
		for _, child in folder:GetChildren() do
			task.defer(track, child)
		end
		folder.ChildAdded:Connect(function(child)
			-- Atomic streaming delivers the whole model at once; one frame lets attributes settle.
			task.defer(track, child)
		end)
		folder.ChildRemoved:Connect(untrack)
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= LOOK.checkEvery then
			acc = 0
			check()
		end
		drainQueue()
		stepDeaths(os.clock())
	end)
end

return MonsterViewController
