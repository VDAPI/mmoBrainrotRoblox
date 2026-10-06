--!strict
-- Builds Roblox instances from an Anatomy rig (S24, Logic/Anatomy). Used by clients for monster looks
-- (MonsterViewController, /mobviz) and by the server and the wardrobe for pets (anchored).
--   * every part hangs off an invisible "LookRoot" (the model's PrimaryPart) at the rig's root centre;
--   * uneven balls are blocks with a Sphere SpecialMesh (Shape = Ball is always round), "cyl" is a Cylinder
--     (axis X), "wedge" a WedgePart, "corner" a CornerWedgePart;
--   * jointed pieces get a Motor6D "Gait_<name>" (attributes Role, Side, Phase, Amp, Scale) whose C0 / C1 meet
--     at the joint pivot with the root's axes, so Logic/Gait poses are in body space; the rest is welded;
--   * anchored mode (pets): everything is anchored, no joints; jointed parts carry Role / Side / Phase / Amp
--     and Pivot (LookRoot space) as attributes so the pet controller can flap and spin them by CFrame.

local LookBuild = {}

export type Piece = {
	name: string,
	shape: string,
	size: { number },
	pos: { number },
	rot: { number },
	color: string,
	material: string,
	transparency: number?,
	glow: boolean?,
	parent: string?,
	joint: { role: string, side: number?, phase: number?, amp: number?, at: { number }? }?,
	shadow: boolean?,
}

export type Rig = {
	root: { size: { number } },
	pieces: { Piece },
	fx: string?,
	sockets: { [string]: { pos: { number }, parent: string? } }?,
}

export type Options = {
	anchored: boolean?, -- pets and previews of pets
	name: string?, -- model name (default "Look")
	cframe: CFrame?, -- where the LookRoot goes (default: identity)
	scale: number?, -- written to the Scale attribute of joints (Gait amplitudes)
	fx: boolean?, -- add the rig's particle preset
	shadows: boolean?, -- false: no part casts a shadow
}

local SMALL = 0.4 -- parts below this (longest side) are not clickable

local FX: {
	[string]: {
		color: ColorSequence,
		rate: number,
		speed: number,
		size: number,
		life: number,
		light: number,
		up: number,
	},
} =
	{
		embers = {
			color = ColorSequence.new(Color3.fromHex("#FFB25A"), Color3.fromHex("#FF4A1A")),
			rate = 8,
			speed = 1.5,
			size = 0.18,
			life = 1.6,
			light = 1,
			up = 2,
		},
		frost = {
			color = ColorSequence.new(Color3.fromHex("#E4F6FF"), Color3.fromHex("#9FE0FF")),
			rate = 6,
			speed = 0.6,
			size = 0.2,
			life = 2,
			light = 0.6,
			up = -0.5,
		},
		mist = {
			color = ColorSequence.new(Color3.fromHex("#B8C8C0")),
			rate = 4,
			speed = 0.3,
			size = 1.6,
			life = 2.5,
			light = 0.1,
			up = 0.2,
		},
		spores = {
			color = ColorSequence.new(Color3.fromHex("#C9E86B"), Color3.fromHex("#8AB83A")),
			rate = 5,
			speed = 0.5,
			size = 0.14,
			life = 2.2,
			light = 0.6,
			up = 0.6,
		},
	}

local function material(name: string): Enum.Material
	local ok, value = pcall(function()
		return (Enum.Material :: any)[name]
	end)
	return if ok and value then value else Enum.Material.SmoothPlastic
end

local function partFor(piece: Piece): BasePart
	local size = Vector3.new(piece.size[1], piece.size[2], piece.size[3])
	local part: BasePart
	if piece.shape == "wedge" then
		part = Instance.new("WedgePart")
	elseif piece.shape == "corner" then
		part = Instance.new("CornerWedgePart")
	else
		local p = Instance.new("Part")
		if piece.shape == "cyl" then
			p.Shape = Enum.PartType.Cylinder
		elseif piece.shape == "ball" then
			local even = math.abs(size.X - size.Y) < 1e-3 and math.abs(size.Y - size.Z) < 1e-3
			if even then
				p.Shape = Enum.PartType.Ball
			else
				local mesh = Instance.new("SpecialMesh")
				mesh.MeshType = Enum.MeshType.Sphere
				mesh.Parent = p
			end
		end
		part = p
	end
	part.Name = piece.name
	part.Size = size
	part.Color = Color3.fromHex(piece.color)
	part.Material = material(piece.material)
	part.Transparency = piece.transparency or 0
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = not piece.glow and math.max(size.X, size.Y, size.Z) >= SMALL
	part.Massless = true
	part.Locked = true
	part.CastShadow = piece.shadow == true
	return part
end

local function addFx(root: BasePart, preset: string, scale: number)
	local spec = FX[preset]
	if not spec then
		return
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "LookFx"
	emitter.Color = spec.color
	emitter.Rate = spec.rate
	emitter.Speed = NumberRange.new(spec.speed * 0.5, spec.speed)
	emitter.Lifetime = NumberRange.new(spec.life * 0.6, spec.life)
	emitter.LightEmission = spec.light
	emitter.SpreadAngle = Vector2.new(60, 60)
	emitter.Acceleration = Vector3.new(0, spec.up, 0)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, spec.size * scale),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.Parent = root
end

-- Model of the rig (not parented). PrimaryPart = LookRoot.
function LookBuild.build(rig: Rig, opts: Options?): Model
	local o: Options = opts or {}
	local anchored = o.anchored == true
	local at = o.cframe or CFrame.identity
	local model = Instance.new("Model")
	model.Name = o.name or "Look"
	local root = Instance.new("Part")
	root.Name = "LookRoot"
	root.Size = Vector3.new(rig.root.size[1], rig.root.size[2], rig.root.size[3])
	root.Transparency = 1
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Massless = true
	root.Locked = true
	root.CastShadow = false
	root.Anchored = anchored
	root.CFrame = at
	root.Parent = model
	model.PrimaryPart = root

	local built: { [string]: BasePart } = {}
	-- Anchored mode: joint attributes per piece name, inherited by unjointed children so they move rigidly
	-- with the jointed piece they hang from.
	local moves: { [string]: { [string]: any } } = {}
	for _, piece in rig.pieces do
		local part = partFor(piece)
		if o.shadows == false then
			part.CastShadow = false
		end
		local cf = at
			* CFrame.new(piece.pos[1], piece.pos[2], piece.pos[3])
			* CFrame.Angles(math.rad(piece.rot[1]), math.rad(piece.rot[2]), math.rad(piece.rot[3]))
		part.CFrame = cf
		part.Anchored = anchored
		if anchored then
			-- Pets never take clicks or camera rays.
			part.CanQuery = false
		end
		local parent = (piece.parent and built[piece.parent]) or root
		local joint = piece.joint
		if joint then
			local pivotPos = joint.at or piece.pos
			if anchored then
				moves[piece.name] = {
					Role = joint.role,
					Side = joint.side or 0,
					Phase = joint.phase or 0,
					Amp = joint.amp or 1,
					Pivot = Vector3.new(pivotPos[1], pivotPos[2], pivotPos[3]),
				}
			else
				local pivot = at * CFrame.new(pivotPos[1], pivotPos[2], pivotPos[3])
				local motor = Instance.new("Motor6D")
				motor.Name = `Gait_{piece.name}`
				motor.Part0 = parent
				motor.Part1 = part
				motor.C0 = parent.CFrame:ToObjectSpace(pivot)
				motor.C1 = cf:ToObjectSpace(pivot)
				motor:SetAttribute("Role", joint.role)
				motor:SetAttribute("Side", joint.side or 0)
				motor:SetAttribute("Phase", joint.phase or 0)
				motor:SetAttribute("Amp", joint.amp or 1)
				motor:SetAttribute("Scale", o.scale or 1)
				motor.Parent = part
			end
		elseif not anchored then
			local weld = Instance.new("Weld")
			weld.Part0 = parent
			weld.Part1 = part
			weld.C0 = parent.CFrame:ToObjectSpace(cf)
			weld.Parent = part
		end
		if anchored and not joint and piece.parent and moves[piece.parent] then
			moves[piece.name] = moves[piece.parent]
		end
		local attributes: { [string]: any } = moves[piece.name] or {}
		for key, value in attributes do
			part:SetAttribute(key, value)
		end
		built[piece.name] = part
		part.Parent = model
	end
	if o.fx and rig.fx then
		addFx(root, rig.fx, o.scale or 1)
	end
	local sockets: { [string]: { pos: { number }, parent: string? } } = rig.sockets or {}
	for name, socket in sockets do
		local attachment = Instance.new("Attachment")
		attachment.Name = name
		attachment.Position = Vector3.new(socket.pos[1], socket.pos[2], socket.pos[3])
		attachment.Parent = root
	end
	return model
end

-- Number of parts LookBuild.build makes for a rig (build queues count with it).
function LookBuild.count(rig: Rig): number
	return #rig.pieces + 1
end

-- Colours a built look towards `tint` by `amount` (0 restores the rig's colours); `glow` recolours Neon parts.
function LookBuild.tint(model: Model, rig: Rig, tint: string?, amount: number, glow: string?)
	local target = if tint then Color3.fromHex(tint) else nil
	local glowColor = if glow then Color3.fromHex(glow) else nil
	for _, piece in rig.pieces do
		local part = model:FindFirstChild(piece.name)
		if part and part:IsA("BasePart") then
			local base = Color3.fromHex(piece.color)
			if glowColor and part.Material == Enum.Material.Neon then
				part.Color = glowColor
			elseif target and amount > 0 then
				part.Color = base:Lerp(target, amount)
			else
				part.Color = base
			end
		end
	end
end

-- Strips scripts from a cloned asset (backdoor protection); returns how many were removed.
function LookBuild.stripScripts(model: Instance): number
	local removed = 0
	for _, item in model:GetDescendants() do
		if item:IsA("LuaSourceContainer") then
			item:Destroy()
			removed += 1
		end
	end
	return removed
end

return LookBuild
