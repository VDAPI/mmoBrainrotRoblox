--!strict
-- Figures of story cutscenes (S102, Data/Cutscenes.FIGURES): people who are not NPCs (Ilvar) appear only for one
-- shot, built on the client from plain parts (no HumanoidDescription): a robe of two cut cylinders, shoulders, a hood
-- (a cut ball and a flat flap), a trim ring at the hem and a dark face. `fade` lets one vanish in frost: pale flakes
-- for 1.5 s and the parts fading out over the last seconds of the shot. Everything anchored, no collisions, no
-- queries. S103: a look with `crown` wears a ring of thorns on the hood (the young queen Morvane); a `ghost` figure
-- (Ilvar's projection, the queen's spirit) is half-transparent and smooth, with a cold light in its trim's colour.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CutsceneData = require(ReplicatedStorage.Shared.Data.Cutscenes)

local CutsceneFigure = {}

local function part(
	model: Model,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	shape: Enum.PartType?,
	material: Enum.Material?
): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.Fabric
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

-- S103: a ghost's parts (looks only).
local GHOST_TRANSPARENCY = 0.45
local GHOST_RANGE = 12
local GHOST_BRIGHTNESS = 1

-- A standing robed figure at `cframe` (its feet on the ground at the CFrame's position, facing its look vector).
function CutsceneFigure.build(look: string, cframe: CFrame, ghost: boolean?): Model
	local colors = CutsceneData.FIGURES[look] or CutsceneData.FIGURES.ilvar
	local robe, hood, trim = Color3.fromHex(colors.robe), Color3.fromHex(colors.hood), Color3.fromHex(colors.trim)
	local model = Instance.new("Model")
	model.Name = `CutsceneFigure_{look}`
	-- robe: a wide lower cylinder and a narrower upper one (stood upright: cylinders lie along X)
	local up = CFrame.Angles(0, 0, math.rad(90))
	part(model, Vector3.new(2.6, 2.4, 2.4), cframe * CFrame.new(0, 1.3, 0) * up, robe, Enum.PartType.Cylinder)
	part(model, Vector3.new(2.2, 1.9, 1.9), cframe * CFrame.new(0, 3.6, 0) * up, robe, Enum.PartType.Cylinder)
	-- shoulders and arms folded in the sleeves
	part(model, Vector3.new(2.6, 0.7, 1.3), cframe * CFrame.new(0, 4.6, 0), robe)
	part(model, Vector3.new(1.6, 0.6, 0.7), cframe * CFrame.new(0, 3.6, -0.75), hood)
	-- trim ring at the hem
	part(model, Vector3.new(0.2, 2.55, 2.55), cframe * CFrame.new(0, 0.25, 0) * up, trim, Enum.PartType.Cylinder)
	-- hood: a ball, a flat flap over the brow, the dark face inside
	part(model, Vector3.new(1.7, 1.7, 1.7), cframe * CFrame.new(0, 5.6, 0.1), hood, Enum.PartType.Ball)
	part(
		model,
		Vector3.new(1.5, 0.25, 0.9),
		cframe * CFrame.new(0, 6.25, -0.45) * CFrame.Angles(math.rad(-12), 0, 0),
		hood
	)
	part(
		model,
		Vector3.new(0.9, 0.95, 0.12),
		cframe * CFrame.new(0, 5.5, -0.78),
		Color3.fromHex("#101114"),
		nil,
		Enum.Material.SmoothPlastic
	)
	-- S103: a crown of thorns: a thin band and seven slanted spikes around the hood
	if colors.crown then
		local crown = Color3.fromHex(colors.crown)
		part(
			model,
			Vector3.new(0.18, 1.75, 1.75),
			cframe * CFrame.new(0, 6.2, 0.1) * up,
			crown,
			Enum.PartType.Cylinder,
			Enum.Material.Wood
		)
		for i = 0, 6 do
			local a = i / 7 * math.pi * 2
			part(
				model,
				Vector3.new(0.12, 0.7, 0.12),
				cframe
					* CFrame.new(math.cos(a) * 0.82, 6.5, 0.1 + math.sin(a) * 0.82)
					* CFrame.Angles(math.sin(a) * 0.35, 0, -math.cos(a) * 0.35),
				crown,
				nil,
				Enum.Material.Wood
			)
		end
	end
	if ghost then
		for _, child in model:GetChildren() do
			if child:IsA("BasePart") then
				child.Transparency = GHOST_TRANSPARENCY
				child.CastShadow = false
				child.Material = Enum.Material.SmoothPlastic
			end
		end
		local light = Instance.new("PointLight")
		light.Color = trim
		light.Range = GHOST_RANGE
		light.Brightness = GHOST_BRIGHTNESS
		light.Shadows = false
		light.Parent = model:FindFirstChildWhichIsA("BasePart")
	end
	return model
end

-- Frost fade: pale flakes around the figure for 1.5 s, then the parts go transparent over the last `seconds`.
-- `kind` "none" does nothing. Returns a function that stops it.
function CutsceneFigure.fade(model: Model, kind: string?, startIn: number, seconds: number): () -> ()
	if kind ~= "frost" then
		return function() end
	end
	local alive = true
	local parts: { BasePart } = {}
	local from: { number } = {} -- S103: a ghost starts half-transparent
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			table.insert(parts, child)
			table.insert(from, child.Transparency)
		end
	end
	local anchor = parts[1]
	local connection: RBXScriptConnection? = nil
	task.delay(math.max(0, startIn), function()
		if not alive or not anchor or not anchor.Parent then
			return
		end
		local emitter = Instance.new("ParticleEmitter")
		emitter.Color = ColorSequence.new(Color3.fromHex("#FFFFFF"), Color3.fromHex("#BFE3FF"))
		emitter.LightEmission = 0.4
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
		emitter.Transparency = NumberSequence.new(0.2, 1)
		emitter.Lifetime = NumberRange.new(1, 1.6)
		emitter.Rate = 60
		emitter.Speed = NumberRange.new(1, 3)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Acceleration = Vector3.new(0, -1, 0)
		emitter.Parent = anchor
		task.delay(1.5, function()
			emitter.Enabled = false
		end)
		local started = os.clock()
		connection = RunService.RenderStepped:Connect(function()
			local t = math.clamp((os.clock() - started) / math.max(seconds, 0.1), 0, 1)
			for i, p in parts do
				p.Transparency = from[i] + (1 - from[i]) * t
			end
			if t >= 1 and connection then
				connection:Disconnect()
				connection = nil
			end
		end)
	end)
	return function()
		alive = false
		if connection then
			connection:Disconnect()
			connection = nil
		end
	end
end

return CutsceneFigure
