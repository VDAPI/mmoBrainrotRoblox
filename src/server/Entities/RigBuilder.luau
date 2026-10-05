--!strict
-- Placeholder monster models built from Parts (ARCHITECTURE §7). Decision (S03): every monster is a Model
-- with an invisible HumanoidRootPart, an R15-type Humanoid (HipHeight keeps it standing, MoveTo walks it)
-- and decorative parts welded to the root. A real model in ReplicatedStorage.Assets.Monsters.<id> replaces
-- the placeholder automatically (it must contain a Humanoid and a HumanoidRootPart).
-- Decision (S17b): limbs are joined with Motor6Ds named "Gait_<part>" (attributes Role, Side, Phase, Amp,
-- Scale) so clients can animate them procedurally (Logic/Gait, AnimationController). Every part hangs off
-- a "core" part that is itself jointed to the root, so the whole body can bob, lean and collapse.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Monsters = require(ReplicatedStorage.Shared.Data.Monsters)

local RigBuilder = {}

type PartSpec = {
	name: string,
	size: Vector3,
	offset: Vector3, -- from the root centre, before scaling
	color: "primary" | "secondary" | "eye" | "dark",
	shape: Enum.PartType?,
	rotation: Vector3?, -- degrees
	material: Enum.Material?,
	transparency: number?,
	attach: string?, -- part this one hangs off (default: the shape's core)
	joint: JointSpec?, -- animated joint; nil = welded rigidly
}

type JointSpec = {
	role: string,
	pivot: Vector3, -- joint position as a fraction of the part size (0.5 = face)
	side: number?,
	phase: number?,
	amp: number?,
}

local EYE = Color3.fromHex("#F2E6B0")
local DARK = Color3.fromHex("#1A1A1E")

-- Core part per shape (jointed to the root as the animated "body").
local CORE: { [string]: { name: string, amp: number } } = {
	quadruped = { name = "Body", amp = 1 },
	humanoid = { name = "Torso", amp = 1 },
	spider = { name = "Thorax", amp = 1 },
	golem = { name = "Torso", amp = 1 },
	flyer = { name = "Body", amp = 1.35 },
	dragon = { name = "Body", amp = 1 },
}

-- Root size per shape (studs at scale 1); parts are positioned around its centre.
local ROOT_SIZE: { [string]: Vector3 } = {
	quadruped = Vector3.new(2, 2, 3),
	humanoid = Vector3.new(2, 2, 1),
	spider = Vector3.new(2.4, 1.4, 2.6),
	golem = Vector3.new(3, 3, 2),
	flyer = Vector3.new(2, 2, 2),
	dragon = Vector3.new(3, 2.4, 5),
}

local function legsQuad(length: number, depth: number, width: number, height: number): { PartSpec }
	local legs: { PartSpec } = {}
	-- Diagonal pairs move together (front-left with back-right).
	local phases = { 0, 0.5, 0.5, 0 }
	for i, pos in { Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) } do
		table.insert(legs, {
			name = `Leg{i}`,
			size = Vector3.new(0.55, height, 0.55),
			offset = Vector3.new(pos.X * width, depth - height / 2, pos.Z * length),
			color = "primary" :: "primary",
			joint = { role = "leg", pivot = Vector3.new(0, 0.5, 0), phase = phases[i], side = pos.X },
		})
	end
	return legs
end

local SHAPES: { [string]: { PartSpec } } = {
	quadruped = {
		{ name = "Body", size = Vector3.new(2, 1.6, 3.6), offset = Vector3.zero, color = "primary" },
		{ name = "Belly", size = Vector3.new(1.6, 0.4, 3), offset = Vector3.new(0, -0.75, 0), color = "secondary" },
		{
			name = "Head",
			size = Vector3.new(1.4, 1.3, 1.4),
			offset = Vector3.new(0, 0.5, -2.3),
			color = "primary",
			joint = { role = "head", pivot = Vector3.new(0, -0.2, 0.5) },
		},
		{
			name = "Snout",
			size = Vector3.new(0.8, 0.6, 0.7),
			offset = Vector3.new(0, 0.25, -3.2),
			color = "secondary",
			attach = "Head",
		},
		{
			name = "EyeL",
			size = Vector3.new(0.2, 0.2, 0.1),
			offset = Vector3.new(-0.4, 0.75, -3.0),
			color = "eye",
			attach = "Head",
		},
		{
			name = "EyeR",
			size = Vector3.new(0.2, 0.2, 0.1),
			offset = Vector3.new(0.4, 0.75, -3.0),
			color = "eye",
			attach = "Head",
		},
		{
			name = "EarL",
			size = Vector3.new(0.3, 0.5, 0.2),
			offset = Vector3.new(-0.45, 1.35, -2.2),
			color = "primary",
			attach = "Head",
		},
		{
			name = "EarR",
			size = Vector3.new(0.3, 0.5, 0.2),
			offset = Vector3.new(0.45, 1.35, -2.2),
			color = "primary",
			attach = "Head",
		},
		{
			name = "Tail",
			size = Vector3.new(0.3, 0.3, 1.2),
			offset = Vector3.new(0, 0.4, 2.2),
			color = "primary",
			rotation = Vector3.new(30, 0, 0),
			joint = { role = "tail", pivot = Vector3.new(0, 0, -0.5) },
		},
	},
	humanoid = {
		{ name = "Torso", size = Vector3.new(2, 2, 1), offset = Vector3.zero, color = "primary" },
		{ name = "Belt", size = Vector3.new(2.05, 0.3, 1.05), offset = Vector3.new(0, -0.8, 0), color = "dark" },
		{
			name = "Head",
			size = Vector3.new(1.2, 1.2, 1.2),
			offset = Vector3.new(0, 1.65, 0),
			color = "secondary",
			joint = { role = "head", pivot = Vector3.new(0, -0.5, 0) },
		},
		{
			name = "EyeL",
			size = Vector3.new(0.2, 0.15, 0.1),
			offset = Vector3.new(-0.25, 1.75, -0.62),
			color = "eye",
			attach = "Head",
		},
		{
			name = "EyeR",
			size = Vector3.new(0.2, 0.15, 0.1),
			offset = Vector3.new(0.25, 1.75, -0.62),
			color = "eye",
			attach = "Head",
		},
		{
			name = "ArmL",
			size = Vector3.new(0.8, 2, 0.8),
			offset = Vector3.new(-1.45, 0, 0),
			color = "primary",
			joint = { role = "arm", pivot = Vector3.new(0, 0.4, 0), side = -1, phase = 0.5 },
		},
		{
			name = "ArmR",
			size = Vector3.new(0.8, 2, 0.8),
			offset = Vector3.new(1.45, 0, 0),
			color = "primary",
			joint = { role = "arm", pivot = Vector3.new(0, 0.4, 0), side = 1, phase = 0 },
		},
		{
			name = "LegL",
			size = Vector3.new(0.9, 2, 0.9),
			offset = Vector3.new(-0.5, -2, 0),
			color = "dark",
			joint = { role = "leg", pivot = Vector3.new(0, 0.5, 0), side = -1, phase = 0.5 },
		},
		{
			name = "LegR",
			size = Vector3.new(0.9, 2, 0.9),
			offset = Vector3.new(0.5, -2, 0),
			color = "dark",
			joint = { role = "leg", pivot = Vector3.new(0, 0.5, 0), side = 1, phase = 0 },
		},
		{
			name = "Weapon",
			size = Vector3.new(0.25, 0.25, 2.4),
			offset = Vector3.new(1.45, -0.9, -1),
			color = "dark",
			material = Enum.Material.Metal,
			attach = "ArmR",
		},
	},
	spider = {
		{ name = "Thorax", size = Vector3.new(1.6, 1.1, 1.4), offset = Vector3.new(0, 0, -0.9), color = "primary" },
		{
			name = "Abdomen",
			size = Vector3.new(2.4, 1.6, 2.6),
			offset = Vector3.new(0, 0.2, 1),
			color = "primary",
			shape = Enum.PartType.Ball,
			joint = { role = "tail", pivot = Vector3.new(0, 0, -0.5), amp = 0.3 },
		},
		{
			name = "Marking",
			size = Vector3.new(0.9, 0.2, 1.2),
			offset = Vector3.new(0, 1, 1),
			color = "secondary",
			attach = "Abdomen",
		},
		{ name = "EyeL", size = Vector3.new(0.2, 0.2, 0.1), offset = Vector3.new(-0.3, 0.2, -1.65), color = "eye" },
		{ name = "EyeR", size = Vector3.new(0.2, 0.2, 0.1), offset = Vector3.new(0.3, 0.2, -1.65), color = "eye" },
	},
	golem = {
		{
			name = "Torso",
			size = Vector3.new(3, 3, 2),
			offset = Vector3.zero,
			color = "primary",
			material = Enum.Material.Slate,
		},
		{
			name = "Core",
			size = Vector3.new(1, 1, 0.3),
			offset = Vector3.new(0, 0.3, -1.05),
			color = "secondary",
			material = Enum.Material.Neon,
		},
		{
			name = "Head",
			size = Vector3.new(1.6, 1.3, 1.5),
			offset = Vector3.new(0, 2.2, -0.2),
			color = "primary",
			material = Enum.Material.Slate,
			joint = { role = "head", pivot = Vector3.new(0, -0.5, 0) },
		},
		{
			name = "EyeL",
			size = Vector3.new(0.3, 0.2, 0.1),
			offset = Vector3.new(-0.35, 2.3, -0.98),
			color = "secondary",
			material = Enum.Material.Neon,
			attach = "Head",
		},
		{
			name = "EyeR",
			size = Vector3.new(0.3, 0.2, 0.1),
			offset = Vector3.new(0.35, 2.3, -0.98),
			color = "secondary",
			material = Enum.Material.Neon,
			attach = "Head",
		},
		{
			name = "ArmL",
			size = Vector3.new(1.2, 3, 1.2),
			offset = Vector3.new(-2.2, -0.4, 0),
			color = "primary",
			material = Enum.Material.Slate,
			joint = { role = "arm", pivot = Vector3.new(0, 0.4, 0), side = -1, phase = 0.5 },
		},
		{
			name = "ArmR",
			size = Vector3.new(1.2, 3, 1.2),
			offset = Vector3.new(2.2, -0.4, 0),
			color = "primary",
			material = Enum.Material.Slate,
			joint = { role = "arm", pivot = Vector3.new(0, 0.4, 0), side = 1, phase = 0 },
		},
		{
			name = "LegL",
			size = Vector3.new(1.2, 1.6, 1.2),
			offset = Vector3.new(-0.8, -2.3, 0),
			color = "primary",
			material = Enum.Material.Slate,
			joint = { role = "leg", pivot = Vector3.new(0, 0.5, 0), side = -1, phase = 0.5, amp = 0.6 },
		},
		{
			name = "LegR",
			size = Vector3.new(1.2, 1.6, 1.2),
			offset = Vector3.new(0.8, -2.3, 0),
			color = "primary",
			material = Enum.Material.Slate,
			joint = { role = "leg", pivot = Vector3.new(0, 0.5, 0), side = 1, phase = 0, amp = 0.6 },
		},
	},
	flyer = {
		{
			name = "Body",
			size = Vector3.new(2, 2.2, 2),
			offset = Vector3.zero,
			color = "primary",
			shape = Enum.PartType.Ball,
			transparency = 0.25,
		},
		{
			name = "Robe",
			size = Vector3.new(1.6, 2.4, 1.6),
			offset = Vector3.new(0, -1.6, 0),
			color = "primary",
			transparency = 0.45,
		},
		{
			name = "Glow",
			size = Vector3.new(1, 1, 1),
			offset = Vector3.new(0, 0.2, 0),
			color = "secondary",
			shape = Enum.PartType.Ball,
			material = Enum.Material.Neon,
		},
		{
			name = "EyeL",
			size = Vector3.new(0.25, 0.25, 0.1),
			offset = Vector3.new(-0.35, 0.35, -1.0),
			color = "eye",
			material = Enum.Material.Neon,
		},
		{
			name = "EyeR",
			size = Vector3.new(0.25, 0.25, 0.1),
			offset = Vector3.new(0.35, 0.35, -1.0),
			color = "eye",
			material = Enum.Material.Neon,
		},
	},
	dragon = {
		{ name = "Body", size = Vector3.new(2.6, 2, 4.6), offset = Vector3.zero, color = "primary" },
		{ name = "Belly", size = Vector3.new(2, 0.4, 3.8), offset = Vector3.new(0, -0.95, 0), color = "secondary" },
		{
			name = "Neck",
			size = Vector3.new(0.9, 0.9, 2),
			offset = Vector3.new(0, 1.2, -2.8),
			color = "primary",
			rotation = Vector3.new(-35, 0, 0),
		},
		{
			name = "Head",
			size = Vector3.new(1.3, 1.1, 1.8),
			offset = Vector3.new(0, 2, -3.9),
			color = "primary",
			joint = { role = "head", pivot = Vector3.new(0, -0.3, 0.5) },
		},
		{
			name = "EyeL",
			size = Vector3.new(0.2, 0.2, 0.1),
			offset = Vector3.new(-0.4, 2.25, -4.82),
			color = "eye",
			material = Enum.Material.Neon,
			attach = "Head",
		},
		{
			name = "EyeR",
			size = Vector3.new(0.2, 0.2, 0.1),
			offset = Vector3.new(0.4, 2.25, -4.82),
			color = "eye",
			material = Enum.Material.Neon,
			attach = "Head",
		},
		{
			name = "WingL",
			size = Vector3.new(4, 0.2, 2.6),
			offset = Vector3.new(-3, 1.2, -0.3),
			color = "secondary",
			rotation = Vector3.new(0, 0, 18),
			joint = { role = "wing", pivot = Vector3.new(0.5, 0, 0), side = -1 },
		},
		{
			name = "WingR",
			size = Vector3.new(4, 0.2, 2.6),
			offset = Vector3.new(3, 1.2, -0.3),
			color = "secondary",
			rotation = Vector3.new(0, 0, -18),
			joint = { role = "wing", pivot = Vector3.new(-0.5, 0, 0), side = 1 },
		},
		{
			name = "Tail",
			size = Vector3.new(0.6, 0.6, 3),
			offset = Vector3.new(0, 0.3, 3.6),
			color = "primary",
			rotation = Vector3.new(15, 0, 0),
			joint = { role = "tail", pivot = Vector3.new(0, 0, -0.5), amp = 0.6 },
		},
	},
}

-- Spider legs, quadruped and dragon legs are generated (symmetrical).
do
	local quadruped = SHAPES.quadruped :: { PartSpec }
	local dragon = SHAPES.dragon :: { PartSpec }
	local spider = SHAPES.spider :: { PartSpec }
	for _, leg in legsQuad(1.3, -0.8, 0.75, 1.4) do
		table.insert(quadruped, leg)
	end
	for _, leg in legsQuad(1.6, -0.9, 1.0, 1.4) do
		table.insert(dragon, leg)
	end
	for side = -1, 1, 2 do
		for i = 1, 4 do
			local z = -1.4 + (i - 1) * 0.75
			table.insert(spider, {
				name = `Leg{side}{i}`,
				size = Vector3.new(2.4, 0.25, 0.25),
				offset = Vector3.new(side * 1.6, -0.35, z - 0.4),
				color = "dark",
				rotation = Vector3.new(0, (i - 2.5) * -12 * side, side * -32),
				joint = {
					role = "spiderLeg",
					pivot = Vector3.new(-side * 0.5, 0, 0),
					side = side,
					phase = ((i + (if side > 0 then 1 else 0)) % 2) * 0.5,
				},
			})
		end
	end
end

local function colorFor(spec: PartSpec, def: Monsters.MonsterDef): Color3
	if spec.color == "primary" then
		return Color3.fromHex(def.colors.primary)
	elseif spec.color == "secondary" then
		return Color3.fromHex(def.colors.secondary)
	elseif spec.color == "eye" then
		return EYE
	end
	return DARK
end

local function newPart(name: string, size: Vector3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CastShadow = true
	return part
end

local function aura(root: BasePart, color: Color3, rate: number)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Aura"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.8
	emitter.Rate = rate
	emitter.Lifetime = NumberRange.new(0.8, 1.4)
	emitter.Speed = NumberRange.new(1, 2.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	emitter.Parent = root
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 12
	light.Brightness = 1.2
	light.Parent = root
end

local function configureHumanoid(humanoid: Humanoid)
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.AutoJumpEnabled = false
	humanoid.MaxHealth = 1e9
	humanoid.Health = 1e9
	for _, state in
		{
			Enum.HumanoidStateType.Climbing,
			Enum.HumanoidStateType.Swimming,
			Enum.HumanoidStateType.FallingDown,
			Enum.HumanoidStateType.Ragdoll,
			Enum.HumanoidStateType.Seated,
			Enum.HumanoidStateType.Dead,
			Enum.HumanoidStateType.Jumping,
		}
	do
		humanoid:SetStateEnabled(state, false)
	end
end

local function fromAsset(def: Monsters.MonsterDef, scale: number): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = assets and assets:FindFirstChild("Monsters")
	local template = folder and folder:FindFirstChild(def.id)
	if not template or not template:IsA("Model") then
		return nil
	end
	local model = template:Clone()
	if not model:FindFirstChildOfClass("Humanoid") or not model:FindFirstChild("HumanoidRootPart") then
		warn(`[RigBuilder] Assets.Monsters.{def.id} needs a Humanoid and a HumanoidRootPart; using a placeholder`)
		model:Destroy()
		return nil
	end
	if scale ~= 1 then
		model:ScaleTo(model:GetScale() * scale)
	end
	return model
end

-- Builds the model for a monster kind at `scale` (kind size x variant scale). Not parented.
function RigBuilder.build(def: Monsters.MonsterDef, variant: string, variantScale: number): Model
	local scale = def.size * variantScale
	local model: Model
	local asset = fromAsset(def, variantScale)
	if asset then
		model = asset
		model.Name = def.id
	else
		model = Instance.new("Model")
		model.Name = def.id
		local rootSize = (ROOT_SIZE[def.shape] or ROOT_SIZE.humanoid) * scale
		local root = newPart("HumanoidRootPart", rootSize)
		root.Transparency = 1
		root.Massless = false
		-- The root is the only colliding part, so the humanoid always has something to stand with.
		root.CanCollide = true
		root.Parent = model
		model.PrimaryPart = root

		local lowest = rootSize.Y / 2
		local core = CORE[def.shape] or CORE.humanoid
		-- Rest pose of every built part relative to the root, for joint offsets.
		local built: { [string]: { part: BasePart, rel: CFrame } } = {}
		for _, spec in SHAPES[def.shape] or SHAPES.humanoid do
			local size = spec.size * scale
			local part = newPart(spec.name, size)
			part.Color = colorFor(spec, def)
			part.Material = spec.material or Enum.Material.SmoothPlastic
			part.Transparency = spec.transparency or 0
			if spec.shape then
				part.Shape = spec.shape
			end
			local rot = spec.rotation or Vector3.zero
			local rel = CFrame.new(spec.offset * scale)
				* CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
			part.CFrame = root.CFrame * rel

			local isCore = spec.name == core.name
			local parentName = if isCore then nil else spec.attach or core.name
			local parent = parentName and built[parentName]
			local parentPart: BasePart = if parent then parent.part else root
			local parentRel = if parent then parent.rel else CFrame.identity
			local joint: JointSpec? = if isCore
				then { role = "body", pivot = Vector3.new(0, -0.5, 0), amp = core.amp }
				else spec.joint
			if joint then
				local motor = Instance.new("Motor6D")
				motor.Name = `Gait_{spec.name}`
				motor.Part0 = parentPart
				motor.Part1 = part
				motor.C1 = CFrame.new(joint.pivot * size)
				motor.C0 = parentRel:Inverse() * rel * motor.C1
				motor:SetAttribute("Role", joint.role)
				motor:SetAttribute("Side", joint.side or 0)
				motor:SetAttribute("Phase", joint.phase or 0)
				motor:SetAttribute("Amp", joint.amp or 1)
				motor:SetAttribute("Scale", scale)
				motor.Parent = part
			else
				local weld = Instance.new("Weld")
				weld.Part0 = parentPart
				weld.Part1 = part
				weld.C0 = parentRel:Inverse() * rel
				weld.Parent = part
			end
			built[spec.name] = { part = part, rel = rel }
			part.Parent = model
			lowest = math.max(lowest, -(spec.offset.Y * scale) + spec.size.Y * scale / 2)
		end

		local humanoid = Instance.new("Humanoid")
		configureHumanoid(humanoid)
		-- Flyers hover; everything else stands on its lowest part.
		local hover = if def.shape == "flyer" then 2.5 * scale else 0
		humanoid.HipHeight = math.max(0.1, lowest - rootSize.Y / 2 + hover)
		humanoid.Parent = model
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	configureHumanoid(humanoid)
	humanoid.WalkSpeed = def.moveSpeed
	-- Stream the whole model at once so clients never see half a monster.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	if variant == "elite" then
		aura(root, Color3.fromHex("#D64A3E"), 6)
	elseif variant == "elite2" then
		aura(root, Color3.fromHex("#B455FF"), 14)
	elseif variant == "boss" then
		aura(root, Color3.fromHex(def.colors.secondary), 24)
	end
	return model
end

return RigBuilder
