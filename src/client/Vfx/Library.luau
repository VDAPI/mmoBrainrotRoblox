--!strict
-- Skill visual pieces (S28): shock waves, cutting arcs, ground cracks, projectiles with tails, lightning, light
-- pillars, runes, shields, auras, area outlines, meteors, weapon trails, hand glows. Built from pooled parts (Vfx/Pool)
-- and tweens; nothing is created per frame. `simple` (far away or low graphics) skips the costly bits (trails,
-- particles, extra segments). Data/SkillVfx says which skill uses which pieces.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Pool = require(script.Parent.Pool)

local Library = {}

local function tween(
	instance: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
)
	TweenService:Create(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		goal
	):Play()
end

local function light(p: BasePart, color: Color3, range: number, brightness: number?)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness or 2
	l.Shadows = false
	l.Parent = p
	return l
end

-- Particle burst from a part (count halved on low quality).
local function emit(p: BasePart, color: Color3, count: number, options: { [string]: any }?)
	local o: { [string]: any } = options or {}
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color, o.to or color)
	e.LightEmission = o.emission or 0.8
	e.Rate = 0
	e.Lifetime = NumberRange.new(o.lifeMin or 0.3, o.lifeMax or 0.7)
	e.Speed = NumberRange.new(o.speedMin or 4, o.speedMax or 10)
	e.SpreadAngle = Vector2.new(o.spread or 180, o.spread or 180)
	e.Acceleration = o.accel or Vector3.zero
	e.Drag = o.drag or 2
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, o.size or 0.6),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.EmissionDirection = o.direction or Enum.NormalId.Top
	e.Parent = p
	local n = if o.low then math.max(1, math.floor(count * Config.Vfx.lowParticles)) else count
	e:Emit(n)
	return e
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function centre(model: Model): Vector3
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position else model:GetPivot().Position
end

-- Ground height under a point (the point itself when nothing is found).
local function ground(at: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { Pool.folder() }
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(exclude, player.Character)
		end
	end
	local monsters = workspace:FindFirstChild("Monsters")
	if monsters then
		table.insert(exclude, monsters)
	end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = false
	local hit = workspace:Raycast(at + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), params)
	return if hit then hit.Position else at - Vector3.new(0, 2.8, 0)
end
Library.ground = ground
Library.centre = centre

-- Flash -----------------------------------------------------------------------------------------------------

function Library.burst(at: Vector3, size: number, color: Color3, seconds: number?)
	local s = seconds or 0.35
	local ball = Pool.part("Ball", color, Vector3.one * math.max(0.5, size * 0.25), Enum.Material.Neon, 0.1)
	ball.CFrame = CFrame.new(at)
	tween(ball, s, { Size = Vector3.one * size, Transparency = 1 })
	Pool.later(ball, s + 0.05)
end

-- Shock wave: a ring of segments running outwards over the ground.
function Library.shockwave(at: Vector3, radius: number, color: Color3, seconds: number?, simple: boolean?)
	local s = seconds or 0.45
	local base = ground(at) + Vector3.new(0, 0.25, 0)
	local count = if simple then 10 else 20
	for i = 1, count do
		local a = (i / count) * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local seg = Pool.part("Block", color, Vector3.new(0.5, 0.35, 1.2), Enum.Material.Neon, 0.15)
		local look = CFrame.lookAt(base + dir * 0.8, base + dir * 0.8 + Vector3.new(-dir.Z, 0, dir.X))
		seg.CFrame = look
		local width = 2 * math.pi * radius / count + 0.4
		tween(seg, s, {
			CFrame = CFrame.lookAt(base + dir * radius, base + dir * radius + Vector3.new(-dir.Z, 0, dir.X)),
			Size = Vector3.new(0.3, 0.2, width),
			Transparency = 1,
		})
		Pool.later(seg, s + 0.05)
	end
	if not simple then
		local disc = Pool.part("Cylinder", color, Vector3.new(0.15, 1, 1), Enum.Material.Neon, 0.55)
		disc.CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90))
		tween(disc, s * 0.8, { Size = Vector3.new(0.15, radius * 2, radius * 2), Transparency = 1 })
		Pool.later(disc, s)
	end
end

-- Ground cracks: dark slabs with a glowing core radiating from a point.
function Library.cracks(at: Vector3, radius: number, color: Color3, seconds: number?, simple: boolean?)
	local s = seconds or 1.4
	local base = ground(at) + Vector3.new(0, 0.08, 0)
	local count = if simple then 4 else 7
	local random = Random.new()
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + random:NextNumber(-0.3, 0.3)
		local length = radius * random:NextNumber(0.55, 1)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local mid = base + dir * length / 2
		local slab =
			Pool.part("Block", Color3.fromHex("#2A2420"), Vector3.new(0.9, 0.15, length), Enum.Material.Slate, 0)
		slab.CFrame = CFrame.lookAt(mid, mid + dir) * CFrame.Angles(0, 0, random:NextNumber(-0.1, 0.1))
		local core = Pool.part("Block", color, Vector3.new(0.3, 0.18, length * 0.9), Enum.Material.Neon, 0.1)
		core.CFrame = slab.CFrame + Vector3.new(0, 0.03, 0)
		task.delay(s * 0.6, function()
			tween(slab, s * 0.4, { Transparency = 1 })
			tween(core, s * 0.4, { Transparency = 1 })
		end)
		Pool.later(slab, s + 0.05)
		Pool.later(core, s + 0.05)
	end
end

-- Cutting arc: segments along an arc in front of `origin` appear in a sweep from `from` to `to` degrees (0 = straight
-- ahead, + = to the left), then fade. `tilt` rolls the arc (0 = horizontal).
function Library.slash(
	origin: CFrame,
	radius: number,
	from: number,
	to: number,
	color: Color3,
	tilt: number?,
	simple: boolean?
)
	local count = if simple then 6 else 12
	local sweep = 0.12
	local roll = CFrame.Angles(0, 0, math.rad(tilt or 0))
	for i = 0, count - 1 do
		local u = i / math.max(1, count - 1)
		local yaw = math.rad(from + (to - from) * u)
		local frame = origin * roll * CFrame.Angles(0, yaw, 0)
		local inner, outer = radius * 0.35, radius
		local seg = Pool.part("Block", color, Vector3.new(0.25, 0.25, outer - inner), Enum.Material.Neon, 1)
		seg.CFrame = frame * CFrame.new(0, 0, -(inner + outer) / 2)
		task.delay(sweep * u, function()
			seg.Transparency = 0.15
			tween(seg, 0.25, { Transparency = 1, Size = Vector3.new(0.05, 0.05, outer - inner) })
		end)
		Pool.later(seg, sweep * u + 0.3)
	end
end

-- Cone area outline / fill (Cleave-like skills without their own arc).
function Library.cone(origin: CFrame, radius: number, angle: number, color: Color3, simple: boolean?)
	local o = CFrame.new(ground(origin.Position) + Vector3.new(0, 0.2, 0)) * origin.Rotation
	Library.slash(o, radius, angle / 2, -angle / 2, color, 0, simple)
end

-- Projectile -------------------------------------------------------------------------------------------------

type Shape = "orb" | "arrow" | "shard" | "bolt" | "rock"

local function projectilePart(shape: Shape, color: Color3, size: number): BasePart
	if shape == "arrow" then
		local p = Pool.part("Block", color, Vector3.new(0.14, 0.14, 2.4 * size), Enum.Material.Neon, 0.05)
		return p
	elseif shape == "shard" then
		return Pool.part("Block", color, Vector3.new(0.45, 0.45, 1.8) * size, Enum.Material.Glass, 0.15)
	elseif shape == "bolt" then
		return Pool.part("Block", color, Vector3.new(0.3, 0.3, 2.2) * size, Enum.Material.Neon, 0)
	elseif shape == "rock" then
		return Pool.part("Ball", color, Vector3.one * 1.6 * size, Enum.Material.Basalt, 0)
	end
	return Pool.part("Ball", color, Vector3.one * size, Enum.Material.Neon, 0.05)
end

-- Flies from `from` to the target model (homing on its centre) or a point; calls onArrive at the end.
function Library.projectile(
	from: Vector3,
	target: Model | Vector3,
	shape: Shape,
	color: Color3,
	options: { size: number?, speed: number?, simple: boolean?, onArrive: ((at: Vector3) -> ())? }?
)
	local o: { size: number?, speed: number?, simple: boolean?, onArrive: ((at: Vector3) -> ())? } = options or {}
	local size = o.size or 1
	local speed = o.speed or 90
	local p = projectilePart(shape, color, size)
	p.CFrame = CFrame.new(from)
	if not o.simple then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.25 * size, 0)
		a0.Parent = p
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.25 * size, 0)
		a1.Parent = p
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(color)
		trail.LightEmission = 1
		trail.Lifetime = if shape == "arrow" then 0.12 else 0.25
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.WidthScale = NumberSequence.new(1, 0)
		trail.Parent = p
		if shape ~= "arrow" then
			light(p, color, 10, 1.5)
			local e = Instance.new("ParticleEmitter")
			e.Color = ColorSequence.new(color)
			e.LightEmission = 1
			e.Rate = 40
			e.Lifetime = NumberRange.new(0.15, 0.35)
			e.Speed = NumberRange.new(0.5, 2)
			e.Size = NumberSequence.new(0.4 * size, 0)
			e.Transparency = NumberSequence.new(0.2, 1)
			e.Parent = p
		end
	end
	local elapsed = 0
	local function goal(): Vector3
		if typeof(target) == "Vector3" then
			return target :: Vector3
		end
		local m = target :: Model
		return if m.Parent then centre(m) else from
	end
	local distance = (goal() - from).Magnitude
	local total = math.clamp(distance / speed, 0.05, 0.8)
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += dt
		local to = goal()
		local u = math.min(1, elapsed / total)
		local at = from:Lerp(to, u)
		if (to - at).Magnitude > 0.05 then
			p.CFrame = CFrame.lookAt(at, to)
		else
			p.CFrame = CFrame.new(at) * p.CFrame.Rotation
		end
		if u >= 1 then
			connection:Disconnect()
			Pool.release(p)
			if o.onArrive then
				o.onArrive(to)
			end
		end
	end)
end

-- Lightning: a zigzag of short segments between two points, flickering for a few frames.
function Library.lightning(a: Vector3, b: Vector3, color: Color3, width: number?, simple: boolean?)
	local pieces = if simple then 4 else 8
	local random = Random.new()
	local points = { a }
	local dir = b - a
	local side = if math.abs(dir.Unit.Y) > 0.9 then Vector3.xAxis else dir:Cross(Vector3.yAxis).Unit
	for i = 1, pieces - 1 do
		local u = i / pieces
		local offset = side * random:NextNumber(-1, 1) * 1.2 + Vector3.new(0, random:NextNumber(-0.8, 0.8), 0)
		table.insert(points, a + dir * u + offset)
	end
	table.insert(points, b)
	for flicker = 0, 1 do
		task.delay(flicker * 0.06, function()
			for i = 1, #points - 1 do
				local p, q = points[i], points[i + 1]
				local seg = Pool.part(
					"Block",
					color,
					Vector3.new(width or 0.3, width or 0.3, (q - p).Magnitude),
					Enum.Material.Neon,
					0
				)
				seg.CFrame = CFrame.lookAt((p + q) / 2, q)
				tween(seg, 0.18, { Transparency = 1 })
				Pool.later(seg, 0.2)
			end
		end)
	end
end

-- Light pillar rising from the ground.
function Library.pillar(at: Vector3, radius: number, height: number, color: Color3, seconds: number?)
	local s = seconds or 0.6
	local base = ground(at)
	local col = Pool.part("Cylinder", color, Vector3.new(0.5, radius * 2, radius * 2), Enum.Material.Neon, 0.35)
	col.CFrame = CFrame.new(base + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
	tween(col, s * 0.35, {
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
	task.delay(s * 0.35, function()
		tween(col, s * 0.65, { Transparency = 1, Size = Vector3.new(height, radius * 0.4, radius * 0.4) })
	end)
	light(col, color, radius * 4 + 6, 2.5)
	Pool.later(col, s + 0.05)
end

-- Rune: a glowing circle on the ground with a turning pattern, for `seconds`.
function Library.rune(at: Vector3, radius: number, color: Color3, seconds: number, simple: boolean?)
	local base = ground(at) + Vector3.new(0, 0.12, 0)
	local disc = Pool.part("Cylinder", color, Vector3.new(0.1, radius * 2, radius * 2), Enum.Material.Neon, 0.75)
	disc.CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90))
	local spokes: { BasePart } = {}
	local count = if simple then 3 else 6
	for i = 1, count do
		local spoke = Pool.part("Block", color, Vector3.new(0.25, 0.14, radius * 1.8), Enum.Material.Neon, 0.25)
		table.insert(spokes, spoke)
		spoke.CFrame = CFrame.new(base + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, i / count * math.pi, 0)
	end
	local angle = 0
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt: number)
		angle += dt * 1.2
		for i, spoke in spokes do
			spoke.CFrame = CFrame.new(base + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, angle + i / count * math.pi, 0)
		end
		if os.clock() - started >= seconds then
			connection:Disconnect()
			tween(disc, 0.3, { Transparency = 1 })
			Pool.later(disc, 0.35)
			for _, spoke in spokes do
				tween(spoke, 0.3, { Transparency = 1 })
				Pool.later(spoke, 0.35)
			end
		end
	end)
end

-- Weld a pooled part to a character's root (shields, auras).
local function attach(model: Model, p: BasePart): boolean
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		Pool.release(p)
		return false
	end
	p.Anchored = false
	p.Massless = true
	p.CFrame = root.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = p
	weld.Parent = p
	return true
end

local function detachLater(p: BasePart, seconds: number)
	task.delay(seconds, function()
		if p.Parent then
			tween(p, 0.3, { Transparency = 1 })
			task.delay(0.32, function()
				p.Anchored = true
				Pool.release(p)
			end)
		end
	end)
end

-- Shield bubble (ForceField material, no Highlight).
function Library.shield(model: Model, color: Color3, seconds: number)
	local bubble = Pool.part("Ball", color, Vector3.one * 7.5, Enum.Material.ForceField, 0.1)
	if attach(model, bubble) then
		detachLater(bubble, math.max(0.4, seconds))
	end
end

-- Aura: particles rising around a character for `seconds`.
function Library.aura(model: Model, color: Color3, seconds: number, simple: boolean?)
	local holder = Pool.part("Block", color, Vector3.new(3, 5, 3), Enum.Material.Neon, 1)
	if not attach(model, holder) then
		return
	end
	if not simple then
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(color)
		e.LightEmission = 0.9
		e.Rate = 14
		e.Lifetime = NumberRange.new(0.6, 1.1)
		e.Speed = NumberRange.new(1.5, 3)
		e.SpreadAngle = Vector2.new(20, 20)
		e.Size = NumberSequence.new(0.35, 0)
		e.Transparency = NumberSequence.new(0.2, 1)
		e.Parent = holder
		light(holder, color, 8, 0.8)
	end
	detachLater(holder, math.max(0.5, seconds))
end

-- Rising sparkles around a character (heals).
function Library.sparkle(model: Model, color: Color3, simple: boolean?)
	local at = centre(model)
	local count = if simple then 4 else 8
	for i = 1, count do
		local a = i / count * math.pi * 2
		local spark = Pool.part("Ball", color, Vector3.one * 0.4, Enum.Material.Neon, 0.1)
		spark.CFrame = CFrame.new(at + Vector3.new(math.cos(a) * 1.6, -1.5, math.sin(a) * 1.6))
		tween(spark, 0.8, { CFrame = spark.CFrame + Vector3.new(0, 4.5, 0), Transparency = 1 })
		Pool.later(spark, 0.85)
	end
end

-- Area outline flashed where the blow lands (circle / cone / line), so the player sees what was hit.
function Library.telegraph(kind: "circle" | "cone" | "line", at: CFrame, a: number, b: number?, color: Color3)
	local base = ground(at.Position) + Vector3.new(0, 0.15, 0)
	local frame = CFrame.new(base) * at.Rotation
	local count = 16
	local function seg(p: Vector3, q: Vector3)
		local part =
			Pool.part("Block", color, Vector3.new(0.25, 0.1, (q - p).Magnitude + 0.2), Enum.Material.Neon, 0.25)
		part.CFrame = CFrame.lookAt((p + q) / 2, q)
		tween(part, 0.5, { Transparency = 1 })
		Pool.later(part, 0.55)
	end
	if kind == "circle" then
		for i = 0, count - 1 do
			local a0, a1 = i / count * math.pi * 2, (i + 1) / count * math.pi * 2
			seg(
				base + Vector3.new(math.cos(a0), 0, math.sin(a0)) * a,
				base + Vector3.new(math.cos(a1), 0, math.sin(a1)) * a
			)
		end
	elseif kind == "cone" then
		local half = math.rad((b or 90) / 2)
		local steps = 8
		local prev = frame.Position
		for i = 0, steps do
			local yaw = -half + 2 * half * i / steps
			local p = (frame * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -a)).Position
			seg(prev, p)
			prev = p
		end
		seg(prev, frame.Position)
	else
		local w = (b or 4) / 2
		local corners = {
			(frame * CFrame.new(-w, 0, 0)).Position,
			(frame * CFrame.new(-w, 0, -a)).Position,
			(frame * CFrame.new(w, 0, -a)).Position,
			(frame * CFrame.new(w, 0, 0)).Position,
		}
		for i = 1, 4 do
			seg(corners[i], corners[i % 4 + 1])
		end
	end
end

-- Meteor: a burning rock falls on the point, then the impact.
function Library.meteor(at: Vector3, radius: number, delay: number, color: Color3, simple: boolean?)
	local landing = ground(at)
	local rock = Pool.part(
		"Ball",
		Color3.fromHex("#3A2A22"),
		Vector3.one * math.clamp(radius * 0.4, 1.5, 4),
		Enum.Material.Basalt,
		0
	)
	rock.CFrame = CFrame.new(landing + Vector3.new(-16, 42, -8))
	if not simple then
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(color, Color3.fromHex("#3A2A22"))
		e.LightEmission = 1
		e.Rate = 70
		e.Lifetime = NumberRange.new(0.3, 0.6)
		e.Size = NumberSequence.new(2.2, 0)
		e.Transparency = NumberSequence.new(0.1, 1)
		e.Parent = rock
		light(rock, color, 16, 2)
	end
	tween(rock, math.max(0.2, delay), { CFrame = CFrame.new(landing) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(math.max(0.2, delay), function()
		Pool.release(rock)
		Library.burst(landing + Vector3.new(0, 1, 0), radius * 1.2, color, 0.4)
		Library.shockwave(landing, radius, color, 0.45, simple)
		if not simple then
			Library.cracks(landing, radius * 0.8, color, 1.6, simple)
		end
	end)
end

-- A straight beam (heals reaching the target, charge streak).
function Library.beam(a: Vector3, b: Vector3, color: Color3, width: number?, seconds: number?)
	local s = seconds or 0.3
	local p =
		Pool.part("Block", color, Vector3.new(width or 0.35, width or 0.35, (b - a).Magnitude), Enum.Material.Neon, 0.1)
	p.CFrame = CFrame.lookAt((a + b) / 2, b)
	tween(p, s, { Transparency = 1, Size = Vector3.new(0.05, 0.05, (b - a).Magnitude) })
	Pool.later(p, s + 0.05)
end

-- S76 (ROZWOJ 11.3): the aiming line of castTime, from the caster's left hand (or 1.5 studs above its centre) to the
-- target's centre or the point, kept in place every frame for `seconds`. Returns a function that takes it down at
-- once. Nothing without a target and a point. One part, so the simple version is the same.
function Library.aimLine(caster: Model, target: Model?, point: Vector3?, color: Color3, seconds: number): () -> ()
	if not target and not point then
		return function() end
	end
	local p = Pool.part("Block", color, Vector3.new(0.15, 0.15, 1), Enum.Material.Neon, 0.2)
	local connection: RBXScriptConnection? = nil
	local done = false
	local function stop()
		if done then
			return
		end
		done = true
		if connection then
			connection:Disconnect()
		end
		Pool.release(p)
	end
	local function place()
		local hand = caster:FindFirstChild("LeftHand", true)
		local from = if hand and hand:IsA("BasePart") then hand.Position else centre(caster) + Vector3.new(0, 1.5, 0)
		local to = if target and target.Parent then centre(target) else point
		if not caster.Parent or not to then
			stop()
			return
		end
		local length = (to - from).Magnitude
		if length < 0.1 then
			return
		end
		p.Size = Vector3.new(0.15, 0.15, length)
		p.CFrame = CFrame.lookAt((from + to) / 2, to)
	end
	local ends = os.clock() + seconds
	place()
	connection = RunService.Heartbeat:Connect(function()
		if os.clock() >= ends then
			stop()
			return
		end
		place()
	end)
	return stop
end

-- S65: Run Through streak: a short thin beam from a to b and a small flash at b (only the beam when simple).
function Library.lineBeam(a: Vector3, b: Vector3, color: Color3, simple: boolean?)
	if (b - a).Magnitude < 0.1 then
		return
	end
	Library.beam(a, b, color, 0.15, 0.15)
	if not simple then
		Library.burst(b, 1.2, color, 0.2)
	end
end

-- S65: Runic Seal: a lasting rune under a character's feet that follows it and turns slowly. Returns the cleanup.
function Library.sealRune(model: Model, color: Color3, simple: boolean?): () -> ()
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return function() end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local drop = root.Size.Y / 2 + (if humanoid then humanoid.HipHeight else 2) - 0.08
	local radius = 2.6
	local disc = Pool.part("Cylinder", color, Vector3.new(0.1, radius * 2, radius * 2), Enum.Material.Neon, 0.8)
	local spokes: { BasePart } = {}
	local count = if simple then 3 else 6
	for _ = 1, count do
		table.insert(spokes, Pool.part("Block", color, Vector3.new(0.2, 0.12, radius * 1.8), Enum.Material.Neon, 0.35))
	end
	local angle = 0
	local connection = RunService.Heartbeat:Connect(function(dt: number)
		if not root.Parent then
			return
		end
		angle += dt * 0.8
		local base = root.Position - Vector3.new(0, drop, 0)
		disc.CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90))
		for i, spoke in spokes do
			spoke.CFrame = CFrame.new(base + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, angle + i / count * math.pi, 0)
		end
	end)
	local done = false
	return function()
		if done then
			return
		end
		done = true
		connection:Disconnect()
		tween(disc, 0.3, { Transparency = 1 })
		Pool.later(disc, 0.35)
		for _, spoke in spokes do
			tween(spoke, 0.3, { Transparency = 1 })
			Pool.later(spoke, 0.35)
		end
	end
end

-- Afterimages along a dash.
function Library.dash(a: Vector3, b: Vector3, color: Color3, simple: boolean?)
	local count = if simple then 2 else 5
	for i = 1, count do
		local u = i / (count + 1)
		local ghost = Pool.part("Block", color, Vector3.new(2, 4.5, 0.8), Enum.Material.Neon, 0.55)
		ghost.CFrame = CFrame.lookAt(a:Lerp(b, u), b)
		tween(ghost, 0.35 + u * 0.2, { Transparency = 1 })
		Pool.later(ghost, 0.6)
	end
	Library.beam(a, b, color, 0.6, 0.35)
end

-- Dust puff at the feet (landings, slams).
function Library.dust(at: Vector3, size: number, low: boolean?)
	local holder = Pool.part("Block", Color3.new(1, 1, 1), Vector3.one, Enum.Material.Neon, 1)
	holder.CFrame = CFrame.new(ground(at) + Vector3.new(0, 0.3, 0))
	emit(holder, Color3.fromHex("#B8AA90"), math.floor(10 * size), {
		emission = 0,
		spread = 70,
		speedMin = 3,
		speedMax = 8 * size,
		size = 1.4 * size,
		lifeMin = 0.4,
		lifeMax = 0.9,
		accel = Vector3.new(0, -4, 0),
		low = low,
	})
	Pool.later(holder, 1.2)
end

-- Glowing hand(s) or weapon for `seconds` (charging a spell, holy weapons).
function Library.glow(
	model: Model,
	hand: "r" | "l" | "both" | "weapon",
	color: Color3,
	seconds: number,
	simple: boolean?
)
	local names: { string } = if hand == "weapon"
		then { "VaelthornWeapon" }
		elseif hand == "both" then { "RightHand", "LeftHand" }
		elseif hand == "l" then { "LeftHand" }
		else { "RightHand" }
	for _, name in names do
		local part = model:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			local orb = Pool.part("Ball", color, Vector3.one * 0.8, Enum.Material.Neon, 0.3)
			orb.Anchored = false
			orb.Massless = true
			orb.CFrame = part.CFrame
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = part
			weld.Part1 = orb
			weld.Parent = orb
			light(orb, color, 8, 1.5)
			if not simple then
				local e = Instance.new("ParticleEmitter")
				e.Color = ColorSequence.new(color)
				e.LightEmission = 1
				e.Rate = 24
				e.Lifetime = NumberRange.new(0.2, 0.4)
				e.Speed = NumberRange.new(0.5, 1.5)
				e.Size = NumberSequence.new(0.35, 0)
				e.Transparency = NumberSequence.new(0.2, 1)
				e.Parent = orb
			end
			tween(orb, seconds, { Size = Vector3.one * 1.6 })
			detachLater(orb, seconds)
		end
	end
end

-- Weapon trail between the grip and the tip of the held weapon, from..to seconds after now.
function Library.weaponTrail(model: Model, color: Color3, from: number, to: number)
	local weapon = model:FindFirstChild("VaelthornWeapon")
	if not weapon or not weapon:IsA("BasePart") then
		return
	end
	local grip = weapon:FindFirstChild("VaelthornGrip")
	local tip = weapon:FindFirstChild("VaelthornTip")
	if not grip or not tip or not grip:IsA("Attachment") or not tip:IsA("Attachment") then
		return
	end
	local trail = weapon:FindFirstChild("VaelthornSkillTrail") :: Trail?
	if not trail then
		local created = Instance.new("Trail")
		created.Name = "VaelthornSkillTrail"
		created.Attachment0 = grip
		created.Attachment1 = tip
		created.Lifetime = 0.22
		created.MinLength = 0.05
		created.LightEmission = 0.9
		created.Transparency = NumberSequence.new(0.15, 1)
		created.Enabled = false
		created.Parent = weapon
		trail = created
	end
	local t = trail :: Trail
	t.Color = ColorSequence.new(color)
	task.delay(math.max(0, from), function()
		if t.Parent then
			t.Enabled = true
		end
	end)
	task.delay(math.max(from + 0.05, to), function()
		if t.Parent then
			t.Enabled = false
		end
	end)
end

-- Lasting area of a breakpoint (cracks, burning ground, frost) for `seconds`.
function Library.lingering(at: Vector3, radius: number, kind: string, color: Color3, seconds: number, simple: boolean?)
	if kind == "cracks" then
		Library.cracks(at, radius, color, seconds, simple)
		return
	end
	local base = ground(at) + Vector3.new(0, 0.1, 0)
	local tint = if kind == "frost"
		then Color3.fromHex("#BFEFFF")
		elseif kind == "burn" then Color3.fromHex("#FF6A1A")
		else color
	local disc = Pool.part(
		"Cylinder",
		tint,
		Vector3.new(0.12, radius * 2, radius * 2),
		if kind == "frost" then Enum.Material.Glass else Enum.Material.Neon,
		0.6
	)
	disc.CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90))
	if not simple then
		local e = Instance.new("ParticleEmitter")
		e.Color = ColorSequence.new(tint)
		e.LightEmission = if kind == "frost" then 0.3 else 1
		e.Rate = math.clamp(radius * 4, 10, 40)
		e.Lifetime = NumberRange.new(0.4, 0.9)
		e.Speed = NumberRange.new(1, if kind == "frost" then 1.5 else 4)
		e.SpreadAngle = Vector2.new(15, 15)
		e.Size = NumberSequence.new(if kind == "frost" then 0.5 else 1, 0)
		e.Transparency = NumberSequence.new(0.2, 1)
		e.Shape = Enum.ParticleEmitterShape.Cylinder
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.EmissionDirection = Enum.NormalId.Right -- the disc is rolled: its +X points up
		e.Parent = disc
		light(disc, tint, radius * 2 + 4, 1)
	end
	task.delay(seconds, function()
		tween(disc, 0.4, { Transparency = 1 })
	end)
	Pool.later(disc, seconds + 0.45)
end

-- S74 War Banner (ROZWOJ 10.5): the pole, the cloth and the finial from `pieces` (WeaponLooks.BANNER, frame origin at
-- the foot of the pole, +Y up) placed on `anchor`, and the circle on the ground: a faint disc and a Neon rim of
-- segments. One Heartbeat loop waves the cloth and pulses the rim (not when simple). Returns the stop function.
function Library.banner(anchor: BasePart, pieces: { any }, radius: number, color: Color3, simple: boolean?): () -> ()
	local origin = CFrame.new(anchor.Position)
	local parts: { BasePart } = {}
	local cloth: BasePart? = nil
	local clothFrame = CFrame.identity
	for _, piece in pieces do
		local size = Vector3.new(piece.size[1], piece.size[2], piece.size[3])
		local material = (Enum.Material :: any)[piece.material] or Enum.Material.SmoothPlastic
		local p = Pool.part(piece.shape, Color3.fromHex(piece.color), size, material, piece.transparency or 0)
		local frame = CFrame.new(piece.pos[1], piece.pos[2], piece.pos[3])
		p.CFrame = origin * frame
		table.insert(parts, p)
		if piece.name == "Cloth" then
			cloth, clothFrame = p, frame
		end
	end
	local base = ground(anchor.Position) + Vector3.new(0, 0.1, 0)
	local disc = Pool.part("Cylinder", color, Vector3.new(0.1, radius * 2, radius * 2), Enum.Material.Neon, 0.85)
	disc.CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90))
	local rim: { BasePart } = {}
	local count = if simple then 12 else 24
	local length = 2 * math.pi * radius / count + 0.2
	for i = 1, count do
		local a = i / count * math.pi * 2
		local at = base + Vector3.new(math.cos(a) * radius, 0.05, math.sin(a) * radius)
		local segment = Pool.part("Block", color, Vector3.new(0.3, 0.15, length), Enum.Material.Neon, 0.3)
		segment.CFrame = CFrame.lookAt(at, at + Vector3.new(-math.sin(a), 0, math.cos(a)))
		table.insert(rim, segment)
	end
	local connection: RBXScriptConnection? = nil
	if not simple then
		local started = os.clock()
		connection = RunService.Heartbeat:Connect(function()
			local t = os.clock() - started
			local c = cloth
			if c then
				-- the free edge sways around the pole side (a gentle wave, no physics)
				local sway = math.sin(t * 2.2) * math.rad(8)
				local pivot = CFrame.new(0, clothFrame.Position.Y, 0)
				c.CFrame = origin * pivot * CFrame.Angles(0, sway, 0) * pivot:Inverse() * clothFrame
			end
			local glow = 0.3 + 0.2 * (0.5 + 0.5 * math.sin(t * 3))
			for _, segment in rim do
				segment.Transparency = glow
			end
		end)
	end
	local stopped = false
	return function()
		if stopped then
			return
		end
		stopped = true
		if connection then
			connection:Disconnect()
		end
		for _, p in parts do
			tween(p, 0.4, { Transparency = 1 })
			Pool.later(p, 0.45)
		end
		tween(disc, 0.4, { Transparency = 1 })
		Pool.later(disc, 0.45)
		for _, segment in rim do
			tween(segment, 0.4, { Transparency = 1 })
			Pool.later(segment, 0.45)
		end
	end
end

-- S74: a thin line from `a` to `b` (roots) for `seconds`, gone early when either model disappears (Intercept).
function Library.tether(a: Model, b: Model, color: Color3, seconds: number)
	local rootA = a:FindFirstChild("HumanoidRootPart") :: BasePart?
	local rootB = b:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not rootA or not rootB then
		return
	end
	local from = Instance.new("Attachment")
	from.Parent = rootA
	local to = Instance.new("Attachment")
	to.Parent = rootB
	local beam = Instance.new("Beam")
	beam.Attachment0 = from
	beam.Attachment1 = to
	beam.Color = ColorSequence.new(color)
	beam.Width0 = 0.15
	beam.Width1 = 0.15
	beam.LightEmission = 1
	beam.FaceCamera = true
	beam.Transparency = NumberSequence.new(0.2)
	beam.Parent = rootA
	local function clear()
		beam:Destroy()
		from:Destroy()
		to:Destroy()
	end
	local ending = os.clock() + math.max(0.3, seconds)
	task.spawn(function()
		while os.clock() < ending and rootA.Parent and rootB.Parent and beam.Parent do
			task.wait(0.2)
		end
		clear()
	end)
end

-- S77: the Falcon (Scout). A bird of three pooled parts (a body and two wedge wings) circling over its hunter;
-- `strike` flies to the target and back with a small claw slash and a burst, a dive starts high above the target,
-- faster and bigger. Not a character: no collisions, no queries. Ends on `stop`, when the hunter's model leaves,
-- or when `keep` runs out (no event from the server).
export type Falcon = {
	keep: (seconds: number) -> (),
	strike: (target: Model?, dive: boolean) -> (),
	stop: () -> (),
	alive: () -> boolean,
}

local FALCON_RADIUS = 4
local FALCON_HEIGHT = 8
local FALCON_SPEED = 1.4 -- rad/s around the hunter
local FALCON_FLAP = math.rad(25)

type Leg = { from: Vector3, to: () -> Vector3?, start: number, dur: number, done: (() -> ())? }

function Library.falcon(caster: Model, color: Color3, simple: boolean): Falcon?
	if not Pool.take() then
		return nil
	end
	local dark = color:Lerp(Color3.new(0, 0, 0), 0.35)
	local body = Pool.part("Block", dark, Vector3.new(0.45, 0.4, 1.2), Enum.Material.SmoothPlastic, 0)
	local wings = {
		Pool.part("Wedge", color, Vector3.new(0.1, 0.45, 1.3), Enum.Material.SmoothPlastic, 0),
		Pool.part("Wedge", color, Vector3.new(0.1, 0.45, 1.3), Enum.Material.SmoothPlastic, 0),
	}
	local born = os.clock()
	local keepUntil = born + 2
	local legs: { Leg } = {}
	local leaving: { from: Vector3, start: number }? = nil
	local finished = false
	local position = centre(caster) + Vector3.new(FALCON_RADIUS, FALCON_HEIGHT, 0)
	local heading = Vector3.new(0, 0, -1)
	local connection: RBXScriptConnection? = nil

	local function circlePoint(t: number): Vector3?
		if not caster.Parent then
			return nil
		end
		local a = (t - born) * FALCON_SPEED
		return centre(caster) + Vector3.new(math.cos(a) * FALCON_RADIUS, FALCON_HEIGHT, math.sin(a) * FALCON_RADIUS)
	end

	local function release()
		if finished then
			return
		end
		finished = true
		if connection then
			connection:Disconnect()
		end
		Pool.release(body)
		for _, wing in wings do
			Pool.release(wing)
		end
		Pool.done()
	end

	local function leave()
		if not leaving and not finished then
			leaving = { from = position, start = os.clock() }
			table.clear(legs)
		end
	end

	local function place(t: number)
		local look = if heading.Magnitude > 0.01 then heading.Unit else Vector3.new(0, 0, -1)
		local frame = CFrame.lookAt(position, position + look)
		body.CFrame = frame
		local flap = if simple then 0 else FALCON_FLAP * math.sin(12 * t)
		for i, wing in wings do
			local side = if i == 1 then -1 else 1
			wing.CFrame = frame
				* CFrame.new(side * 0.2, 0.05, 0)
				* CFrame.Angles(0, 0, side * flap)
				* CFrame.new(side * 0.65, 0, 0)
				* CFrame.Angles(0, side * math.pi / 2, 0)
				* CFrame.Angles(0, 0, math.pi / 2)
		end
	end

	connection = RunService.Heartbeat:Connect(function()
		local t = os.clock()
		local nextPosition: Vector3? = nil
		local away = leaving
		if away then
			local u = math.clamp((t - away.start) / 0.4, 0, 1)
			nextPosition = away.from + Vector3.new(6 * u, 10 * u, 6 * u)
			if u >= 1 then
				release()
				return
			end
		elseif not caster.Parent or t >= keepUntil then
			leave()
			return
		else
			local leg = legs[1]
			if leg then
				local to = leg.to()
				local u = math.clamp((t - leg.start) / leg.dur, 0, 1)
				if to then
					nextPosition = leg.from:Lerp(to, u)
				end
				if u >= 1 or not to then
					table.remove(legs, 1)
					local after = legs[1]
					if after then
						after.from = nextPosition or position
						after.start = t
					end
					if leg.done then
						leg.done()
					end
				end
			else
				nextPosition = circlePoint(t)
			end
		end
		if nextPosition then
			local delta = nextPosition - position
			if delta.Magnitude > 0.01 then
				heading = delta
			end
			position = nextPosition
		end
		place(t)
	end)
	place(born)

	local falcon: Falcon = {
		keep = function(seconds: number)
			keepUntil = math.max(keepUntil, os.clock() + seconds)
		end,
		strike = function(target: Model?, dive: boolean)
			if finished or leaving or not target or not target.Parent then
				return
			end
			local function at(): Vector3?
				return if target.Parent then centre(target) + Vector3.new(0, 1, 0) else nil
			end
			local now = os.clock()
			table.clear(legs)
			local start = position
			if dive then
				local above = at()
				if above then
					start = above + Vector3.new(0, 14, 0)
					position = start
				end
			end
			table.insert(legs, {
				from = start,
				to = at,
				start = now,
				dur = if dive then 0.18 else 0.22,
				done = function()
					local hit = at()
					if not hit then
						return
					end
					local look = if heading.Magnitude > 0.01 then heading.Unit else Vector3.new(0, 0, -1)
					Library.slash(CFrame.lookAt(hit, hit + look), 2, 60, -60, color, 30, simple)
					Library.burst(hit, 3, color)
					if dive then
						Library.burst(hit, 6, color)
						Library.shockwave(hit, 3, color, 0.35, simple)
					end
				end,
			})
			table.insert(legs, {
				from = start,
				to = function(): Vector3?
					return circlePoint(os.clock())
				end,
				start = now,
				dur = 0.35,
			})
		end,
		stop = leave,
		alive = function(): boolean
			return not finished and leaving == nil
		end,
	}
	return falcon
end

-- Helpers for the controller
Library.flat = flat

return Library
