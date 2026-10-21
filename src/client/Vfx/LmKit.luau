--!strict
-- W30 (walka-lm): shared helpers of the lm pieces (Vfx/LmHunterMage) and the ranged basic attacks (Vfx/LmShots):
-- pooled parts that fade, trails, discs of force field, tickers on the effect clock, thrown bodies under gravity, jagged
-- bolts. Everything through Vfx/Pool and Vfx/Clock (AnimLab freezes it); counts scale with the graphics level (W29).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(script.Parent.Clock)
local GraphicsLevel = require(ReplicatedStorage.Shared.Logic.GraphicsLevel)
local Library = require(script.Parent.Library)
local Pool = require(script.Parent.Pool)
local State = require(script.Parent.Parent.UI.State)
local Textures = require(script.Parent.Textures)

local kit = Library.kit
local kp = kit.kp
local tween = kit.tween

local rng = Random.new()
local WHITE = Color3.new(1, 1, 1)
local WOOD = Color3.fromHex("#6B4E32")
local NEON = Enum.Material.Neon
local FIELD = Enum.Material.ForceField

-- Parts of a piece at this graphics level: `n` on high, scaled by the level's particle share (W29), halved simple.
local function amount(n: number, simple: boolean): number
	local level = GraphicsLevel.get(State.Get({ "account", "settings", "quality" }))
	local share = level.particles * (if simple then 0.5 else 1)
	return math.max(1, math.floor(n * share + 0.5))
end

local function part(shape: string, color: Color3, size: Vector3, material: Enum.Material?, alpha: number?): BasePart
	return Pool.part(shape, color, size, material or NEON, alpha or 0.1)
end

-- Fades a part out over `seconds` (with an optional goal of its own) and gives it back to the pool.
local function fadeOut(p: BasePart, seconds: number, goal: { [string]: any }?, style: Enum.EasingStyle?)
	local g: { [string]: any } = goal or {}
	g.Transparency = 1
	tween(p, seconds, g, style or Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Pool.later(p, seconds + 0.03)
end

-- A camera-facing trail on a part (gone with the part when the pool takes it back).
local function trailOn(p: BasePart, color: Color3, width: number, life: number, key: string?): Trail
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, width / 2, 0)
	a0.Parent = p
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -width / 2, 0)
	a1.Parent = p
	local t = Instance.new("Trail")
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.FaceCamera = true
	t.Color = ColorSequence.new(color:Lerp(WHITE, 0.35), color)
	t.LightEmission = 1
	t.Lifetime = life
	t.Transparency = NumberSequence.new({ kp(0, 0.05), kp(1, 1) })
	t.WidthScale = NumberSequence.new({ kp(0, 1), kp(1, 0) })
	t.MinLength = 0.05
	Textures.trail(t, key or "trailSoft")
	t.Parent = p
	Clock.track(t)
	return t
end

-- A shape mesh on a block (an ellipsoid of a rift); its Scale tweens.
local function sphereMesh(p: BasePart, scale: Vector3): SpecialMesh
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = scale
	mesh.Parent = p
	return mesh
end

-- A flat disc lying on the ground (a Cylinder's axis is X: turned to stand up).
local function discFrame(at: Vector3): CFrame
	return CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
end

-- A disc facing along `dir` (its round faces look at the shot).
local function facingDisc(at: Vector3, dir: Vector3): CFrame
	return kit.facingFrame(at, dir) * CFrame.Angles(0, math.pi / 2, 0)
end

local function unitOr(v: Vector3, fallback: Vector3): Vector3
	return if v.Magnitude > 1e-3 then v.Unit else fallback
end

-- A ticker over `seconds` (u = 0..1), stopped early when `alive` says no; `done` once at the end.
local function over(seconds: number, step: (u: number, t: number) -> (), done: (() -> ())?)
	local started = Clock.now()
	kit.animate(function(now: number): boolean
		local t = now - started
		local u = if seconds > 0 then math.clamp(t / seconds, 0, 1) else 1
		step(u, t)
		if u >= 1 then
			if done then
				done()
			end
			return true
		end
		return false
	end)
end

-- Ballistic bodies: thrown parts falling under `gravity`, bouncing once off their floor, faded at the end of `life`.
export type Body = {
	p: BasePart,
	pos: Vector3,
	vel: Vector3,
	rot: CFrame,
	spin: Vector3,
	floor: number,
	life: number,
	bounce: number,
	done: boolean?,
	fading: boolean?,
	landed: boolean?,
}

local function ballistic(bodies: { Body }, gravity: number, onLand: ((b: Body) -> ())?)
	local started = Clock.now()
	local last = started
	kit.animate(function(now: number): boolean
		local dt = math.min(now - last, 0.05)
		last = now
		local alive = false
		for _, b in bodies do
			if not b.done then
				local age = now - started
				if age >= b.life then
					b.done = true
					Pool.release(b.p)
				else
					alive = true
					b.vel -= Vector3.new(0, gravity * dt, 0)
					b.pos += b.vel * dt
					if b.pos.Y < b.floor then
						b.pos = Vector3.new(b.pos.X, b.floor, b.pos.Z)
						if not b.landed then
							b.landed = true
							if onLand then
								onLand(b)
							end
						end
						if b.bounce > 0 and b.vel.Y < -3 then
							b.vel = Vector3.new(b.vel.X * 0.5, -b.vel.Y * b.bounce, b.vel.Z * 0.5)
							b.bounce = 0
						else
							b.vel = Vector3.zero
							b.spin = Vector3.zero
						end
					end
					b.rot *= CFrame.Angles(b.spin.X * dt, b.spin.Y * dt, b.spin.Z * dt)
					b.p.CFrame = CFrame.new(b.pos) * b.rot
					if not b.fading and age >= b.life - 0.3 then
						b.fading = true
						tween(b.p, 0.3, { Transparency = 1 })
					end
				end
			end
		end
		return not alive
	end)
end

local function randomRot(): CFrame
	return CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28))
end

local function spinVec(speed: number): Vector3
	return Vector3.new(rng:NextNumber(-speed, speed), rng:NextNumber(-speed, speed), rng:NextNumber(-speed, speed))
end

-- A shock disc (force field: a rippling ring of light) growing from `from` to `to` studs across in `seconds`.
local function shockDisc(frame: CFrame, from: number, to: number, color: Color3, seconds: number, thick: number?)
	local w = thick or 0.12
	local disc = part("Cylinder", color, Vector3.new(w, from, from), FIELD, 0)
	disc.CFrame = frame
	fadeOut(disc, seconds, { Size = Vector3.new(w, to, to) }, Enum.EasingStyle.Quad)
	return disc
end

-- A jagged path of `pieces` points from a to b (sideways jitter `jag`).
local function jagged(a: Vector3, b: Vector3, pieces: number, jag: number): { Vector3 }
	local dir = b - a
	local side = if math.abs(unitOr(dir, Vector3.yAxis).Y) > 0.9
		then Vector3.xAxis
		else unitOr(dir:Cross(Vector3.yAxis), Vector3.xAxis)
	local up = unitOr(side:Cross(dir), Vector3.yAxis)
	local points = { a }
	for i = 1, pieces - 1 do
		local u = i / pieces
		local taper = math.sin(u * math.pi)
		table.insert(points, a + dir * u + (side * rng:NextNumber(-1, 1) + up * rng:NextNumber(-1, 1)) * jag * taper)
	end
	table.insert(points, b)
	return points
end

-- Neon segments along a path, fading in `seconds`; `glow` adds a wide pale sheath on each segment.
local function segments(points: { Vector3 }, color: Color3, width: number, seconds: number, glow: boolean)
	for i = 1, #points - 1 do
		local p, q = points[i], points[i + 1]
		local length = (q - p).Magnitude
		if length > 0.05 then
			local frame = CFrame.lookAt((p + q) / 2, q)
			local core = part("Block", color:Lerp(WHITE, 0.55), Vector3.new(width, width, length + width), NEON, 0)
			core.CFrame = frame
			fadeOut(core, seconds)
			if glow then
				local sheath = part("Block", color, Vector3.new(width * 3, width * 3, length + width * 2), NEON, 0.65)
				sheath.CFrame = frame
				fadeOut(sheath, seconds * 0.8)
			end
		end
	end
end

-- A bolt with forks from a to b: two flickers (one simple), forks off the middle of the main path.
local function forkBolt(a: Vector3, b: Vector3, color: Color3, width: number, simple: boolean, forks: number?)
	local length = (b - a).Magnitude
	if length < 0.2 then
		return
	end
	local pieces = math.clamp(math.floor(length / 2.2), 4, 14)
	local flickers = if simple then 1 else 2
	for flicker = 1, flickers do
		Clock.after((flicker - 1) * 0.06, function()
			local main = jagged(a, b, if simple then math.max(3, pieces // 2) else pieces, math.min(2.2, length * 0.09))
			segments(main, color, width, 0.14, not simple)
			if simple then
				return
			end
			for _ = 1, forks or 2 do
				local from = main[rng:NextInteger(2, math.max(2, #main - 1))]
				local away = unitOr((b - a):Cross(Vector3.yAxis), Vector3.xAxis) * rng:NextNumber(-1, 1)
					+ Vector3.new(0, rng:NextNumber(-0.6, 0.3), 0)
				local to = from + (unitOr(b - a, Vector3.yAxis) * 0.5 + away) * length * rng:NextNumber(0.18, 0.32)
				segments(jagged(from, to, 4, length * 0.04), color, width * 0.55, 0.11, false)
			end
		end)
	end
end

-- A small arrow of plain parts (wood shaft, a bright head, two vanes), nose along -Z.
local function arrowModel(color: Color3, size: number): BasePart
	local length = 2.2 * size
	local shaft = part("Block", WOOD, Vector3.new(0.1, 0.1, length), Enum.Material.Wood, 0)
	local function piece(s: Vector3, offset: CFrame, c: Color3, material: Enum.Material)
		local p = Instance.new("Part")
		p.Size = s
		p.Color = c
		p.Material = material
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Massless = true
		p.Anchored = false
		p.CFrame = shaft.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = shaft
		weld.Part1 = p
		weld.Parent = p
		p.Parent = shaft
	end
	piece(
		Vector3.new(0.22, 0.08, 0.45) * size,
		CFrame.new(0, 0, -length / 2 - 0.18 * size),
		color:Lerp(WHITE, 0.3),
		NEON
	)
	for _, roll in { 0, math.pi / 2 } do
		piece(
			Vector3.new(0.3, 0.03, 0.42) * size,
			CFrame.new(0, 0, length / 2 - 0.22 * size) * CFrame.Angles(0, 0, roll),
			color,
			Enum.Material.SmoothPlastic
		)
	end
	return shaft
end

return {
	WHITE = WHITE,
	WOOD = WOOD,
	STEEL = Color3.fromHex("#5E5E66"),
	ROCK = Color3.fromHex("#3A2E28"),
	ICE = Color3.fromHex("#CFF2FF"),
	SHADOW = Color3.fromHex("#14100C"),
	NEON = NEON,
	FIELD = FIELD,
	GLASS = Enum.Material.Glass,
	rng = rng,
	amount = amount,
	part = part,
	fadeOut = fadeOut,
	trailOn = trailOn,
	sphereMesh = sphereMesh,
	discFrame = discFrame,
	facingDisc = facingDisc,
	unitOr = unitOr,
	over = over,
	ballistic = ballistic,
	randomRot = randomRot,
	spinVec = spinVec,
	shockDisc = shockDisc,
	jagged = jagged,
	segments = segments,
	forkBolt = forkBolt,
	arrowModel = arrowModel,
}
