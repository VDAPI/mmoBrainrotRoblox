--!strict
-- S134d: the look of an Invasion zone (WorldEventService): a dark red-purple rift over the centre, a glowing ground
-- ring on the zone's edge, braziers with violet fire and broken war banners inside, smoke. Built from Parts when the
-- Invasion starts, destroyed when it ends. Nothing collides, nothing is queryable (monster steering and the floor
-- rays look through it), nothing fires touch events; no blood.

local Workspace = game:GetService("Workspace")

local InvasionCamp = {}

local RIFT = Color3.fromHex("#7A1E5A")
local RIFT_CORE = Color3.fromHex("#E04A8A")
local RING = Color3.fromHex("#A8306E")
local IRON = Color3.fromHex("#2E2A30")
local WOOD = Color3.fromHex("#3A2C22")
local CLOTH = Color3.fromHex("#5A1630")
local FLAME = Color3.fromHex("#C04AE0")
local FLAME_2 = Color3.fromHex("#E0567A")

local RING_SEGMENTS = 40
local BRAZIERS = 6
local BANNERS = 4

-- `floorAt(dx, dz)` = the ground under the centre + (dx, 0, dz) in world space.
export type FloorAt = (dx: number, dz: number) -> Vector3

local function part(model: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = model
	return p
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
end

local function smoke(parent: BasePart, size: number, opacity: number)
	local s = Instance.new("Smoke")
	s.Color = Color3.fromHex("#2A1A2E")
	s.Opacity = opacity
	s.RiseVelocity = 3
	s.Size = size
	s.Parent = parent
end

local function rift(model: Model, at: Vector3)
	local base = CFrame.new(at)
	-- a cracked stone ring on the ground
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		part(model, {
			Name = "RiftStone",
			Size = Vector3.new(3.2, 0.8 + (i % 3) * 0.4, 1.6),
			CFrame = base * CFrame.Angles(0, -a, 0) * CFrame.new(0, 0.3, -6) * CFrame.Angles(0.15 * (i % 2), 0, 0),
			Color = IRON,
			Material = Enum.Material.Slate,
		})
	end
	-- the tear: a tall thin glowing slab and a fainter halo turned across it
	local tear = part(model, {
		Name = "RiftTear",
		Size = Vector3.new(0.6, 13, 4.5),
		CFrame = base * CFrame.new(0, 7.5, 0) * CFrame.Angles(0, 0, 0.12),
		Color = RIFT_CORE,
		Material = Enum.Material.Neon,
		Transparency = 0.15,
	})
	part(model, {
		Name = "RiftHalo",
		Size = Vector3.new(0.4, 16, 8),
		CFrame = base * CFrame.new(0, 8, 0) * CFrame.Angles(0, math.rad(35), -0.08),
		Color = RIFT,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
	})
	part(model, {
		Name = "RiftPool",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, 9, 9),
		CFrame = base * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = RIFT,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
	})
	light(tear, RIFT_CORE, 40, 3)
	smoke(tear, 12, 0.18)
	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(RIFT_CORE, RIFT)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.5, 0)
	sparks.Lifetime = NumberRange.new(1.2, 2.2)
	sparks.Rate = 14
	sparks.Speed = NumberRange.new(2, 5)
	sparks.SpreadAngle = Vector2.new(30, 30)
	sparks.Parent = tear
end

local function ring(model: Model, radius: number, floorAt: FloorAt)
	local points: { Vector3 } = {}
	for i = 0, RING_SEGMENTS - 1 do
		local a = i / RING_SEGMENTS * math.pi * 2
		table.insert(points, floorAt(math.cos(a) * radius, math.sin(a) * radius))
	end
	for i, a in points do
		local b = points[i % #points + 1]
		local length = (b - a).Magnitude
		if length > 0.1 then
			part(model, {
				Name = "ZoneEdge",
				Size = Vector3.new(1.4, 0.2, length + 0.6),
				CFrame = CFrame.lookAt((a + b) / 2 + Vector3.new(0, 0.12, 0), b + Vector3.new(0, 0.12, 0)),
				Color = RING,
				Material = Enum.Material.Neon,
				Transparency = 0.25,
			})
		end
	end
end

local function brazier(model: Model, at: Vector3)
	local base = CFrame.new(at)
	part(model, {
		Name = "BrazierFoot",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3, 1.4, 1.4),
		CFrame = base * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = IRON,
		Material = Enum.Material.Metal,
	})
	local bowl = part(model, {
		Name = "BrazierBowl",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.8, 3.2, 3.2),
		CFrame = base * CFrame.new(0, 3.3, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = IRON,
		Material = Enum.Material.Metal,
	})
	local coals = part(model, {
		Name = "BrazierCoals",
		Size = Vector3.new(2, 0.4, 2),
		CFrame = base * CFrame.new(0, 3.8, 0),
		Color = FLAME,
		Material = Enum.Material.Neon,
	})
	local fire = Instance.new("Fire")
	fire.Color = FLAME
	fire.SecondaryColor = FLAME_2
	fire.Size = 4
	fire.Heat = 7
	fire.Parent = coals
	light(bowl, FLAME, 22, 1.8)
end

local function banner(model: Model, at: Vector3, yaw: number, tilt: number)
	local base = CFrame.new(at) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(tilt, 0, tilt * 0.5)
	part(model, {
		Name = "BannerPole",
		Size = Vector3.new(0.5, 9, 0.5),
		CFrame = base * CFrame.new(0, 4.3, 0),
		Color = WOOD,
		Material = Enum.Material.Wood,
	})
	part(model, {
		Name = "BannerBar",
		Size = Vector3.new(3.4, 0.35, 0.35),
		CFrame = base * CFrame.new(0, 8.2, 0),
		Color = WOOD,
		Material = Enum.Material.Wood,
	})
	-- the torn cloth: two uneven strips
	part(model, {
		Name = "BannerCloth",
		Size = Vector3.new(1.5, 4.2, 0.12),
		CFrame = base * CFrame.new(-0.8, 6, 0.1),
		Color = CLOTH,
		Material = Enum.Material.Fabric,
	})
	part(model, {
		Name = "BannerCloth",
		Size = Vector3.new(1.4, 2.8, 0.12),
		CFrame = base * CFrame.new(0.8, 6.7, 0.1) * CFrame.Angles(0, 0, 0.08),
		Color = CLOTH,
		Material = Enum.Material.Fabric,
	})
end

-- Builds the camp of a zone `radius` studs wide around `centre`; returns the model (parented to Workspace).
function InvasionCamp.build(name: string, centre: Vector3, radius: number, floorAt: FloorAt, seed: number): Model
	local random = Random.new(seed)
	local model = Instance.new("Model")
	model.Name = name
	rift(model, centre)
	ring(model, radius, floorAt)
	local turn = random:NextNumber() * math.pi * 2
	for i = 1, BRAZIERS do
		local a = turn + i / BRAZIERS * math.pi * 2
		local r = radius * (if i % 2 == 0 then 0.35 else 0.62)
		brazier(model, floorAt(math.cos(a) * r, math.sin(a) * r))
	end
	for i = 1, BANNERS do
		local a = turn + (i + 0.5) / BANNERS * math.pi * 2
		local r = radius * 0.82
		banner(
			model,
			floorAt(math.cos(a) * r, math.sin(a) * r),
			-a + random:NextNumber() * 0.6,
			(random:NextNumber() - 0.5) * 0.5
		)
	end
	model.Parent = Workspace
	return model
end

return InvasionCamp
