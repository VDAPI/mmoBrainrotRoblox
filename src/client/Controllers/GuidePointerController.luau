--!strict
-- The world guide (W28; maths in Logic/GuidePointer): a clearly visible "go there" for one target at a time.
--   * a golden arrow floating over the player's head that turns towards the target,
--   * glowing chevrons on the ground from the player towards it, scrolling forward,
--   * a bobbing diamond with the distance over the target (always on top, seen through walls and terrain),
--   * an arrow at the screen's edge while the target is off screen (behind the camera: at the bottom).
-- Everything is client-only and rebuilt from scratch every frame from the character of now (no attachments on the
-- character), so respawns, teleports and map changes never leave it on an old model; a target on another map leads
-- to the next portal of the route (Logic/MapRoute), an NPC follows its streamed model or falls back to Data/Npcs.
-- It hides once the target is reached (Logic/GuidePointer.REACH) and while nothing is set. Today the tutorial sets it
-- (TutorialController, Logic/Tutorial.guide); the quest tracker's small header arrow uses the same maths.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local GuidePointer = require(ReplicatedStorage.Shared.Logic.GuidePointer)
local MapRoute = require(ReplicatedStorage.Shared.Logic.MapRoute)
local MapSketch = require(script.Parent.Parent.UI.MapSketch)
local Maps = require(ReplicatedStorage.Shared.Data.Maps)
local Npcs = require(ReplicatedStorage.Shared.Data.Npcs)
local State = require(script.Parent.Parent.UI.State)
local Text = require(script.Parent.Parent.UI.Text)
local Theme = require(script.Parent.Parent.UI.Theme)

local GuidePointerController = {
	Name = "GuidePointerController",
}

-- What to point at: a map-relative place (an NPC follows its model when streamed) or a live model (a monster).
export type Spec = {
	map: string?,
	x: number?,
	z: number?,
	npc: string?,
	model: Model?,
}

local GOLD = Color3.fromHex("#F5C842")
local GLOW = Color3.fromHex("#FFE89A")
local CHEVRONS = 7
local SPACING = 4 -- studs between two ground chevrons
local FIRST = 3.5 -- studs from the player to the first chevron
local SCROLL = 0.7 -- chevron spacings per second
local ARROW_HEIGHT = 4.6 -- studs over the root part
local MARKER_HEIGHT = 7 -- studs over the target's ground
local EDGE = 64 -- px of the screen-edge arrow
local EDGE_MARGIN = 56 -- px from the screen's edge

local player = Players.LocalPlayer
local scope = Fusion.scoped(Fusion)

local current: Spec? = nil
local currentSource: string? = nil

local folder: Folder? = nil
local arrowParts: { BasePart } = {}
local chevronParts: { { BasePart } } = {}
local markerPart: BasePart? = nil
local markerGui: BillboardGui? = nil
local distanceLabel: TextLabel? = nil
local screenGui: ScreenGui? = nil
local edgeFrame: Frame? = nil
local shown = false

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = false

local function newPart(name: string, size: Vector3, color: Color3, parent: Instance): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 1
	part.Parent = parent
	return part
end

-- Builds (or rebuilds, when something removed it) the world parts and the screen arrow.
local function ensure(): Folder
	local existing = folder
	if existing and existing.Parent == Workspace and markerPart and markerPart.Parent == existing then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local root = Instance.new("Folder")
	root.Name = "VaelthornGuide"
	-- the arrow: a shaft and a two-piece head, front = -Z
	table.clear(arrowParts)
	table.insert(arrowParts, newPart("Shaft", Vector3.new(0.65, 0.4, 3), GOLD, root))
	table.insert(arrowParts, newPart("HeadL", Vector3.new(0.65, 0.42, 2.2), GLOW, root))
	table.insert(arrowParts, newPart("HeadR", Vector3.new(0.65, 0.42, 2.2), GLOW, root))
	-- the ground chevrons: two bars each, a ">" lying flat
	table.clear(chevronParts)
	for i = 1, CHEVRONS do
		table.insert(chevronParts, {
			newPart(`Chevron{i}L`, Vector3.new(0.5, 0.12, 2), GOLD, root),
			newPart(`Chevron{i}R`, Vector3.new(0.5, 0.12, 2), GOLD, root),
		})
	end
	-- the marker over the target: an invisible anchor with an always-on-top billboard
	local anchor = newPart("Marker", Vector3.new(0.2, 0.2, 0.2), GOLD, root)
	local gui = Instance.new("BillboardGui")
	gui.Name = "GuideMarker"
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 100000
	gui.Size = UDim2.fromOffset(110, 92)
	gui.Adornee = anchor
	gui.Enabled = false
	local diamond = Instance.new("Frame")
	diamond.Name = "Diamond"
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Position = UDim2.new(0.5, 0, 0, 24)
	diamond.Size = UDim2.fromOffset(30, 30)
	diamond.Rotation = 45
	diamond.BackgroundColor3 = GOLD
	diamond.BorderSizePixel = 0
	diamond.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.Shade
	stroke.Thickness = 2.5
	stroke.Parent = diamond
	local inner = Instance.new("Frame")
	inner.AnchorPoint = Vector2.new(0.5, 0.5)
	inner.Position = UDim2.fromScale(0.5, 0.5)
	inner.Size = UDim2.fromScale(0.45, 0.45)
	inner.BackgroundColor3 = GLOW
	inner.BorderSizePixel = 0
	inner.Parent = diamond
	local label = Instance.new("TextLabel")
	label.Name = "Distance"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.fromScale(0.5, 1)
	label.Size = UDim2.new(1, 0, 0, 30)
	label.BackgroundTransparency = 1
	label.FontFace = Theme.Fonts.BodyBold
	label.TextSize = 22
	label.TextColor3 = GLOW
	label.TextStrokeColor3 = Theme.Shade
	label.TextStrokeTransparency = 0.1
	label.Text = ""
	label.Parent = gui
	gui.Parent = anchor
	markerPart, markerGui, distanceLabel = anchor, gui, label
	root.Parent = Workspace
	folder = root
	return root
end

local function ensureScreen(): Frame?
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return nil
	end
	local existing = edgeFrame
	if existing and screenGui and screenGui.Parent == playerGui then
		return existing
	end
	if screenGui then
		screenGui:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "VaelthornGuide"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- viewport pixels = layer pixels (Camera:WorldToViewportPoint)
	gui.DisplayOrder = 4
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local frame = Instance.new("Frame")
	frame.Name = "EdgeArrow"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Size = UDim2.fromOffset(EDGE, EDGE)
	frame.BackgroundColor3 = Theme.Shade
	frame.BackgroundTransparency = 0.35
	frame.Visible = false
	frame.Active = false
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = frame
	local ring = Instance.new("UIStroke")
	ring.Color = GOLD
	ring.Thickness = 2
	ring.Parent = frame
	local glyph = Instance.new("TextLabel")
	glyph.Name = "Glyph"
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.46)
	glyph.Size = UDim2.fromScale(0.8, 0.8)
	glyph.BackgroundTransparency = 1
	glyph.Text = "▲"
	glyph.TextScaled = true
	glyph.FontFace = Theme.Fonts.BodyBold
	glyph.TextColor3 = GLOW
	glyph.TextStrokeColor3 = Theme.Shade
	glyph.TextStrokeTransparency = 0.2
	glyph.Parent = frame
	gui.Parent = playerGui
	screenGui, edgeFrame = gui, frame
	return frame
end

local function hideAll()
	if not shown then
		return
	end
	shown = false
	for _, part in arrowParts do
		part.Transparency = 1
	end
	for _, pair in chevronParts do
		pair[1].Transparency = 1
		pair[2].Transparency = 1
	end
	if markerGui then
		markerGui.Enabled = false
	end
	if edgeFrame then
		edgeFrame.Visible = false
	end
end

local function rootPart(): BasePart?
	local character = player.Character
	local part = character and character:FindFirstChild("HumanoidRootPart")
	return if part and part:IsA("BasePart") then part else nil
end

-- Ground height under (x, z): a ray down `length` studs from `topY`.
local function groundY(x: number, z: number, topY: number, length: number): number?
	local ignore: { Instance } = {}
	if folder then
		table.insert(ignore, folder)
	end
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local monsters = Workspace:FindFirstChild("Monsters")
	if monsters then
		table.insert(ignore, monsters)
	end
	rayParams.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(Vector3.new(x, topY, z), Vector3.new(0, -length, 0), rayParams)
	return if hit then hit.Position.Y else nil
end

-- The world point to head for now (on this map), its reach radius, or nil.
local function resolve(spec: Spec, from: Vector3): (Vector3?, number)
	local model = spec.model
	if model then
		if model.Parent and model:GetAttribute("Dead") ~= true then
			return model:GetPivot().Position, GuidePointer.REACH.monster
		end
		return nil, 0
	end
	local mapId = State.Get({ "character", "location", "map" })
	local here = Maps.get(if type(mapId) == "string" then mapId else "")
	if not here or not spec.map then
		return nil, 0
	end
	local offset = Vector3.new(here.offset.x, here.offset.y, here.offset.z)
	if spec.map ~= here.id then
		local exit = MapRoute.nextExit(here.id, spec.map, MapSketch.isBuilt)
		if not exit then
			return nil, 0
		end
		local y = groundY(offset.X + exit.x, offset.Z + exit.z, from.Y + 80, 300) or from.Y
		return Vector3.new(offset.X + exit.x, y, offset.Z + exit.z), GuidePointer.REACH.place
	end
	if spec.npc then
		local world = Workspace:FindFirstChild("World")
		local npcs = world and world:FindFirstChild("Npcs")
		local npcModel = npcs and npcs:FindFirstChild(spec.npc)
		if npcModel and npcModel:IsA("Model") then
			return npcModel:GetPivot().Position, GuidePointer.REACH.npc
		end
		local def = Npcs.get(spec.npc)
		if def and def.map == here.id then
			local x, z = offset.X + def.position.x, offset.Z + def.position.z
			return Vector3.new(x, groundY(x, z, from.Y + 80, 300) or from.Y, z), GuidePointer.REACH.npc
		end
	end
	if spec.x and spec.z then
		local x, z = offset.X + spec.x, offset.Z + spec.z
		return Vector3.new(x, groundY(x, z, from.Y + 80, 300) or from.Y, z), GuidePointer.REACH.place
	end
	return nil, 0
end

local lastGoal: Vector3? = nil
local lastRadius = 0
local resolvedAt = -math.huge
local RESOLVE_EVERY = 0.25 -- seconds between two resolutions of a place (raycasts); models follow every frame

local function render()
	local spec = current
	local root = rootPart()
	local camera = Workspace.CurrentCamera
	if not spec or not root or not camera then
		hideAll()
		return
	end
	local now = os.clock()
	local goal: Vector3?, radius = lastGoal, lastRadius
	if spec.model or now - resolvedAt >= RESOLVE_EVERY or not goal then
		goal, radius = resolve(spec, root.Position)
		lastGoal, lastRadius, resolvedAt = goal, radius, now
	end
	if not goal then
		hideAll()
		return
	end
	local from = root.Position
	local distance = GuidePointer.flat(from.X, from.Z, goal.X, goal.Z)
	if GuidePointer.reached(distance, radius) then
		hideAll()
		return
	end
	ensure()
	shown = true
	local dx, dz = goal.X - from.X, goal.Z - from.Z
	local yaw = GuidePointer.yaw(dx, dz)
	local turn = CFrame.Angles(0, yaw, 0)
	local dir = Vector3.new(dx, 0, dz).Unit

	-- the floating arrow over the head
	local at = from + Vector3.new(0, ARROW_HEIGHT + GuidePointer.bob(now, 0.25, 1.6), 0)
	local base = CFrame.new(at) * turn
	arrowParts[1].CFrame = base * CFrame.new(0, 0, 0.7)
	arrowParts[2].CFrame = base * CFrame.new(-0.58, 0, -1.05) * CFrame.Angles(0, math.rad(-38), 0)
	arrowParts[3].CFrame = base * CFrame.new(0.58, 0, -1.05) * CFrame.Angles(0, math.rad(38), 0)
	for _, part in arrowParts do
		part.Transparency = 0.05
	end

	-- the chevrons on the ground
	local phase = (now * SCROLL) % 1
	local spots = GuidePointer.chevrons(distance, FIRST, SPACING, CHEVRONS, phase)
	for i, pair in chevronParts do
		local along = spots[i]
		if along then
			local p = from + dir * along
			local y = groundY(p.X, p.Z, from.Y + 4 + math.min(along * 0.5, 16), 50) or (from.Y - 2.8)
			local c = CFrame.new(p.X, y + 0.15, p.Z) * turn
			pair[1].CFrame = c * CFrame.new(-0.6, 0, 0.4) * CFrame.Angles(0, math.rad(-35), 0)
			pair[2].CFrame = c * CFrame.new(0.6, 0, 0.4) * CFrame.Angles(0, math.rad(35), 0)
			local fade = GuidePointer.fade(i, #spots, phase)
			pair[1].Transparency = fade
			pair[2].Transparency = fade
		else
			pair[1].Transparency = 1
			pair[2].Transparency = 1
		end
	end

	-- the diamond over the target
	local marker = markerPart :: BasePart
	local markerAt = goal + Vector3.new(0, MARKER_HEIGHT + GuidePointer.bob(now, 0.6, 1.8), 0)
	marker.CFrame = CFrame.new(markerAt)
	local gui = markerGui :: BillboardGui
	gui.Enabled = true
	local label = distanceLabel :: TextLabel
	local text = Text.now("guide.distance", { n = GuidePointer.meters(distance) })
	if label.Text ~= text then
		label.Text = text
	end

	-- the arrow at the screen's edge
	local edge = ensureScreen()
	if edge then
		local view = camera.ViewportSize
		local projected = camera:WorldToViewportPoint(markerAt)
		local spot = GuidePointer.edge(projected.X, projected.Y, projected.Z, view.X, view.Y, EDGE_MARGIN)
		edge.Visible = not spot.onScreen
		if not spot.onScreen then
			edge.Position = UDim2.fromOffset(spot.x, spot.y)
			edge.Rotation = spot.rotation
		end
	end
end

-- Points the guide at `spec` for `source` (nil clears it when that source set it). Safe to call every tick: an
-- equal spec keeps the cached resolution.
function GuidePointerController.Set(source: string, spec: Spec?)
	if spec == nil then
		if currentSource == source then
			current, currentSource, lastGoal = nil, nil, nil
		end
		return
	end
	local old = current
	local same = old ~= nil
		and currentSource == source
		and old.map == spec.map
		and old.x == spec.x
		and old.z == spec.z
		and old.npc == spec.npc
		and old.model == spec.model
	if not same then
		lastGoal = nil
	end
	current, currentSource = spec, source
end

function GuidePointerController.Start()
	RunService.RenderStepped:Connect(function()
		local ok, err = pcall(render :: any)
		if not ok then
			warn("[Guide] " .. tostring(err))
			hideAll()
		end
	end)
	-- a new character (respawn, teleport, character switch): the next frame follows it; the cached place recomputes
	player.CharacterAdded:Connect(function()
		lastGoal = nil
	end)
	scope:Observer(State.Value({ "character", "location", "map" })):onChange(function()
		lastGoal = nil
	end)
end

return GuidePointerController
