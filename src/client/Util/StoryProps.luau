--!strict
-- Props of the story (S105, story chapter IV and the finale): local models built from plain parts on the client for a
-- cutscene (Data/Cutscenes `props`) or an anchor's effect (QuestAnchorController `rite`, `thorn`): the Thorn of Vael
-- (a shaft of the Elder Tree's pale wood with silver fittings, the spearhead of cold glass with gold runes), Ilvar's
-- statue of ice (a hooded figure with an outstretched arm) and a trapper's lantern. Nothing collides, nothing is
-- clickable; only the larger pieces cast shadows. Every function draws into `model` in the frame `cf` (feet / the
-- tip on the CFrame's position, the front is its look vector).

local StoryProps = {}

local function part(
	model: Model,
	size: Vector3,
	cframe: CFrame,
	color: string,
	material: Enum.Material?,
	shape: Enum.PartType?,
	transparency: number?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cframe
	p.Color = Color3.fromHex(color)
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.CastShadow = (transparency or 0) < 0.5 and math.max(size.X, size.Y, size.Z) >= 2
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
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

-- Cylinders lie along X; this stands them along Y.
local UP = CFrame.Angles(0, 0, math.rad(90))

StoryProps.WOOD = "#B89A6A"
StoryProps.SILVER = "#C8D0D8"
StoryProps.HEAD = "#CFF6FF"
StoryProps.GOLD = "#E8C25A"
StoryProps.ICE = "#CFE8F5"

-- The Thorn of Vael with its tip at `cf` and the shaft going up along cf's up vector (tilt `cf` to drive it in).
-- 9 studs of shaft, a 2.4 stud head; 13 parts.
function StoryProps.thorn(model: Model, cf: CFrame)
	-- the head: two crossed blades of cold glass, gold runes on both faces, a faint light
	for _, r in { 0, 90 } do
		part(
			model,
			Vector3.new(0.5, 2.4, 0.12),
			cf * CFrame.Angles(0, math.rad(r), 0) * CFrame.new(0, 1.2, 0),
			StoryProps.HEAD,
			Enum.Material.Neon,
			nil,
			0.1
		)
	end
	local head = part(
		model,
		Vector3.new(0.3, 0.6, 0.3),
		cf * CFrame.new(0, 2.3, 0),
		StoryProps.HEAD,
		Enum.Material.Glass,
		nil,
		0.2
	)
	for k = 0, 2 do
		part(
			model,
			Vector3.new(0.18, 0.1, 0.16),
			cf * CFrame.new(0, 0.7 + k * 0.5, -0.08),
			StoryProps.GOLD,
			Enum.Material.Neon
		)
	end
	-- the shaft of the Elder Tree's branch and its silver fittings
	part(
		model,
		Vector3.new(9, 0.36, 0.36),
		cf * CFrame.new(0, 2.4 + 4.5, 0) * UP,
		StoryProps.WOOD,
		Enum.Material.Wood,
		Enum.PartType.Cylinder
	)
	for _, y in { 2.6, 3.2, 10.6 } do
		part(
			model,
			Vector3.new(0.22, 0.5, 0.5),
			cf * CFrame.new(0, y, 0) * UP,
			StoryProps.SILVER,
			Enum.Material.Metal,
			Enum.PartType.Cylinder
		)
	end
	part(
		model,
		Vector3.new(0.5, 0.5, 0.5),
		cf * CFrame.new(0, 11.5, 0),
		StoryProps.SILVER,
		Enum.Material.Metal,
		Enum.PartType.Ball
	)
	light(head, StoryProps.HEAD, 10, 0.9)
end

-- Ilvar turned to ice: a hooded figure with the right arm stretched out towards the front (~8 parts).
function StoryProps.iceStatue(model: Model, cf: CFrame)
	local ice, glass = Enum.Material.Ice, Enum.Material.Glass
	local t = 0.25
	part(
		model,
		Vector3.new(2.6, 2.4, 2.4),
		cf * CFrame.new(0, 1.3, 0) * UP,
		StoryProps.ICE,
		ice,
		Enum.PartType.Cylinder,
		t
	)
	part(
		model,
		Vector3.new(2.2, 1.9, 1.9),
		cf * CFrame.new(0, 3.6, 0) * UP,
		StoryProps.ICE,
		ice,
		Enum.PartType.Cylinder,
		t
	)
	part(model, Vector3.new(2.6, 0.7, 1.3), cf * CFrame.new(0, 4.6, 0), StoryProps.ICE, ice, nil, t)
	part(model, Vector3.new(1.7, 1.7, 1.7), cf * CFrame.new(0, 5.6, 0.1), StoryProps.ICE, ice, Enum.PartType.Ball, t)
	part(
		model,
		Vector3.new(1.5, 0.25, 0.9),
		cf * CFrame.new(0, 6.25, -0.45) * CFrame.Angles(math.rad(-12), 0, 0),
		StoryProps.ICE,
		ice,
		nil,
		t
	)
	-- the outstretched right arm and its open hand, the left arm folded in the sleeve
	part(
		model,
		Vector3.new(0.6, 0.6, 2.6),
		cf * CFrame.new(1, 4.7, -1.3) * CFrame.Angles(math.rad(10), 0, 0),
		StoryProps.ICE,
		ice,
		nil,
		t
	)
	part(model, Vector3.new(0.5, 0.2, 0.6), cf * CFrame.new(1, 4.95, -2.7), "#E4F4FC", glass, nil, 0.2)
	part(model, Vector3.new(0.7, 1.6, 0.6), cf * CFrame.new(-1.1, 3.9, -0.3), StoryProps.ICE, ice, nil, t)
	-- a skin of rime at the feet
	part(
		model,
		Vector3.new(0.2, 3.6, 3.6),
		cf * CFrame.new(0, 0.1, 0) * UP,
		"#EAF6FF",
		Enum.Material.Snow,
		Enum.PartType.Cylinder
	)
end

-- A trapper's lantern standing on the ground (lit: a warm flame and its light).
function StoryProps.lantern(model: Model, cf: CFrame, lit: boolean?)
	part(model, Vector3.new(0.8, 0.12, 0.8), cf * CFrame.new(0, 0.06, 0), "#3A3A40", Enum.Material.Metal)
	part(model, Vector3.new(0.7, 1, 0.7), cf * CFrame.new(0, 0.62, 0), "#E8D8B0", Enum.Material.Glass, nil, 0.4)
	part(model, Vector3.new(0.8, 0.12, 0.8), cf * CFrame.new(0, 1.18, 0), "#3A3A40", Enum.Material.Metal)
	part(model, Vector3.new(0.1, 0.5, 0.1), cf * CFrame.new(0, 1.45, 0), "#3A3A40", Enum.Material.Metal)
	if lit then
		local flame = part(
			model,
			Vector3.new(0.25, 0.4, 0.25),
			cf * CFrame.new(0, 0.6, 0),
			"#FFB46E",
			Enum.Material.Neon,
			Enum.PartType.Ball
		)
		light(flame, "#FFB46E", 9, 1.2)
	end
end

-- A prop of a cutscene by kind (Data/Cutscenes Prop: thorn, lantern) in a new model under `parent`.
function StoryProps.build(kind: string, cf: CFrame, lit: boolean?, parent: Instance): Model
	local model = Instance.new("Model")
	model.Name = `StoryProp_{kind}`
	if kind == "thorn" then
		-- driven into the ice at a slant, the tip half a stud under the ground
		StoryProps.thorn(model, cf * CFrame.new(0, -0.5, 0) * CFrame.Angles(math.rad(-20), 0, 0))
	elseif kind == "lantern" then
		StoryProps.lantern(model, cf, lit)
	end
	model.Parent = parent
	return model
end

return StoryProps
