--!strict
-- 3D preview of the world map card (S25): one ViewportFrame shared by every card. NPCs are clones of their
-- model in Workspace.World.Npcs (Persistent since S25, scripts, prompts and plates stripped); monsters, elites
-- and bosses come from MonsterViewController.BuildPreview (S24). A model is built when a card opens and kept
-- in a small cache (the last few, detached) so going back and forth is instant; the cache dies with the
-- window. A slow turn of the camera (no rebuilds), off on low graphics quality. The build time goes to the
-- Output ("[WorldMap] preview ...", first build and from the cache).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Bosses = require(ReplicatedStorage.Shared.Data.Bosses)
local Combat = require(ReplicatedStorage.Shared.Data.Combat)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local MonsterLooks = require(ReplicatedStorage.Shared.Data.MonsterLooks)
local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)
local State = require(script.Parent.Parent.Parent.State)
local Theme = require(script.Parent.Parent.Parent.Theme)

type Scope = Fusion.Scope<typeof(Fusion)>

export type Spec = {
	kind: "npc" | "monster" | "boss" | "glyph",
	id: string,
	variant: string?,
	glyph: string?,
	color: Color3?,
}

-- MonsterViewController.BuildPreview
export type BuildLook = (lookId: string, look: any, variant: string, scale: number, cframe: CFrame) -> (Model, any)

type Entry = { key: string, model: Model, height: number, width: number, front: number }

local CACHE_SIZE = 5
local FOV = 34
local TURN_SPEED = 0.45 -- radians per second

local Preview = {}

export type Api = {
	frame: ViewportFrame,
	show: (spec: Spec?) -> (),
	destroy: () -> (),
}

local STRIP = { "Script", "LocalScript", "ModuleScript", "ProximityPrompt", "BillboardGui", "Sound", "ClickDetector" }

local function npcModel(id: string): (Model?, number)
	local world = Workspace:FindFirstChild("World")
	local folder = world and world:FindFirstChild("Npcs")
	local source = folder and folder:FindFirstChild(id)
	if not source or not source:IsA("Model") then
		return nil, 0
	end
	local wasArchivable = source.Archivable
	source.Archivable = true
	local clone = source:Clone()
	source.Archivable = wasArchivable
	if not clone then
		return nil, 0
	end
	for _, item in clone:GetDescendants() do
		for _, class in STRIP do
			if item:IsA(class) then
				item:Destroy()
				break
			end
		end
	end
	local humanoid = clone:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	for _, part in clone:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end
	local look = clone:GetPivot().LookVector
	return clone, math.atan2(look.X, look.Z)
end

-- Moves the model so its bounding box stands on y = 0 around the origin; returns height and width.
local function standOnOrigin(model: Model): (number, number)
	local box, size = model:GetBoundingBox()
	local shift = Vector3.new(-box.Position.X, size.Y / 2 - box.Position.Y, -box.Position.Z)
	model:PivotTo(model:GetPivot() + shift)
	return size.Y, math.max(size.X, size.Z)
end

-- `portrait` (S27, NPC dialogs): head and shoulders from the front, no turning.
function Preview.new(scope: Scope, buildLook: BuildLook?, options: { portrait: boolean? }?): Api
	local portrait = options ~= nil and options.portrait == true
	local viewport = scope:New("ViewportFrame")({
		Name = "Preview",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Background,
		BackgroundTransparency = 0,
		Ambient = Color3.fromRGB(150, 145, 140),
		LightColor = Color3.fromRGB(255, 240, 220),
		LightDirection = Vector3.new(-1, -1.2, -0.8),
	}) :: ViewportFrame
	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local glyph = Instance.new("TextLabel")
	glyph.Name = "Glyph"
	glyph.Size = UDim2.fromScale(1, 1)
	glyph.BackgroundTransparency = 1
	glyph.FontFace = Theme.Fonts.BodyBold
	glyph.TextScaled = true
	glyph.TextStrokeTransparency = 0.3
	glyph.Visible = false
	glyph.ZIndex = viewport.ZIndex + 1
	local glyphSize = Instance.new("UITextSizeConstraint")
	glyphSize.MaxTextSize = 96
	glyphSize.Parent = glyph
	glyph.Parent = viewport

	local entries: { Entry } = {}
	local current: Entry? = nil
	local angle = 0
	local quality = State.Value({ "account", "settings", "quality" })

	local function place()
		local entry = current
		if not entry then
			return
		end
		local focus = Vector3.new(0, entry.height * (if portrait then 0.8 else 0.5), 0)
		local extent = if portrait then entry.height * 0.42 else math.max(entry.height, entry.width * 0.85)
		local distance = (extent * 0.5) / math.tan(math.rad(FOV / 2)) * 1.3 + entry.width * 0.25
		local a = entry.front + angle
		local rise = entry.height * (if portrait then 0.04 else 0.18)
		local eye = focus + Vector3.new(math.sin(a) * distance, rise, math.cos(a) * distance)
		camera.CFrame = CFrame.lookAt(eye, focus)
	end

	local function build(spec: Spec): Entry?
		if spec.kind == "npc" then
			local model, front = npcModel(spec.id)
			if not model then
				return nil
			end
			local height, width = standOnOrigin(model)
			return { key = "", model = model, height = height, width = width, front = front }
		end
		if not buildLook then
			return nil
		end
		local look, scale, variant = nil, 1, spec.variant or "normal"
		if spec.kind == "boss" then
			local boss = Bosses.get(spec.id)
			look = boss and MonsterLooks.get(boss.id)
			scale = if boss then boss.look.size else 1
			variant = "boss"
		else
			local def = Monsters.get(spec.id)
			look = def and MonsterLooks.get(def.id, def.region)
			local mods = (Combat.variants :: any)[variant] or Combat.variants.normal
			scale = (if def then def.size else 1) * mods.scale
		end
		if not look then
			return nil
		end
		local ok, model, info = pcall(buildLook, spec.id, look, variant, scale, CFrame.new())
		if not ok or not model then
			warn(`[WorldMap] preview {spec.id} failed: {model}`)
			return nil
		end
		model:PivotTo(model:GetPivot() + Vector3.new(0, info.rootHalf + info.hipHeight, 0))
		-- Looks face -Z: the camera starts in front of them.
		return { key = "", model = model, height = info.height, width = info.width, front = math.pi }
	end

	local function show(spec: Spec?)
		local wanted = if spec and spec.kind ~= "glyph" then `{spec.kind}:{spec.id}:{spec.variant or ""}` else nil
		if wanted and current and current.key == wanted then
			return -- the same model is already shown (a card refresh)
		end
		if current then
			current.model.Parent = nil
			current = nil
		end
		glyph.Visible = false
		if not spec then
			return
		end
		if spec.kind == "glyph" then
			glyph.Text = spec.glyph or "?"
			glyph.TextColor3 = spec.color or Theme.Colors.Parchment
			glyph.Visible = true
			return
		end
		local key = `{spec.kind}:{spec.id}:{spec.variant or ""}`
		local started = os.clock()
		local found: Entry? = nil
		for i, entry in entries do
			if entry.key == key then
				found = entry
				table.remove(entries, i)
				break
			end
		end
		local source = "cache"
		if not found then
			found = build(spec)
			source = "first"
			if found then
				found.key = key
			end
		end
		if not found then
			glyph.Text = spec.glyph or "?"
			glyph.TextColor3 = spec.color or Theme.Colors.Parchment
			glyph.Visible = true
			return
		end
		table.insert(entries, 1, found)
		while #entries > CACHE_SIZE do
			local old = table.remove(entries) :: Entry
			old.model:Destroy()
		end
		found.model.Parent = viewport
		current = found
		angle = if portrait then 0 elseif Fusion.peek(quality) == "low" then 0.5 else 0
		place()
		print(`[WorldMap] preview {key}: {string.format("%.1f", (os.clock() - started) * 1000)} ms ({source})`)
	end

	table.insert(
		scope,
		RunService.RenderStepped:Connect(function(dt: number)
			if current and viewport.Visible and not portrait and Fusion.peek(quality) ~= "low" then
				angle += dt * TURN_SPEED
				place()
			end
		end)
	)

	local function destroy()
		for _, entry in entries do
			entry.model:Destroy()
		end
		table.clear(entries)
		current = nil
	end
	table.insert(scope, destroy)

	return { frame = viewport, show = show, destroy = destroy }
end

return Preview
