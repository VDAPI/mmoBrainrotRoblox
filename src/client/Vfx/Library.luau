--!strict
-- Skill visual pieces (S28): shock waves, cutting arcs, ground cracks, projectiles with tails, lightning, light
-- pillars, runes, shields, auras, area outlines, meteors, weapon trails, hand glows. Built from pooled parts (Vfx/Pool)
-- and tweens; nothing is created per frame. `simple` (far away or low graphics) skips the costly bits (trails,
-- particles, extra segments). Data/SkillVfx says which skill uses which pieces. S110: every delay, tween, emitter, trail
-- and loop runs on the effect clock (Vfx/Clock), so AnimLab can freeze an effect at any moment.
-- S112 (DESIGN-16 §4, docs/ANIMACJE.md "Tekstury efektów"): textures from Data/VfxTextures (Vfx/Textures) on the old
-- pieces and six new ones (impactFlash, sparks, groundDecal, smokePuff, magicCircle, ringWave). Every piece keeps its
-- old look as the fallback when Textures.id(key) is nil (no id, `tex off`, an image that did not load, the skills-window
-- ViewportFrame). Textured layers live on pooled holders (Pool.holder) within the device limits of Config.Vfx:
--   layer                          PC, near              simple (far / low)      low quality
--   textured particles             full (<= maxBurst)    half                    half (lowParticles)
--   flipbooks                      yes                   yes (one particle)      yes, half the particles
--   Trail (projectiles, weapons)   yes                   no                      no
--   Beam (rays, arcs)              yes                   yes, Segments 1         yes
--   Decal / ground images          yes                   yes                     yes
--   PointLight of the new pieces   yes (<= maxLights)    no                      no
--   old part segments by a texture as each piece says                           none
-- Glowing circles on the ground (magicCircle, ringWave, rune) are an unlit image on a flat part's top face (any turn
-- of a round image is right); a cutting arc is a flat Beam (double-sided) running forwards from the blow's origin.
-- S115 (Hunter and Mage): projectile options (trail texture, flight cap, fixed time, lob, arrows stuck in the ground),
-- a thrown "snare" shape, `snare` (a trap lying on the ground, plain parts), `stormCloud` (smoke puffs over a circle),
-- `meteor` with `bare` (the falling rock only), the falcon reaching its target 0.06 s after the strike event (the core
-- plays in VfxController with the event) and the aiming line pulsing faster as the aim runs out.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AttackMotions = require(ReplicatedStorage.Shared.Data.AttackMotions)
local Clock = require(script.Parent.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Pool = require(script.Parent.Pool)
local State = require(script.Parent.Parent.UI.State)
local Textures = require(script.Parent.Textures)

local Library = {}

-- Options of the new pieces (S112).
export type FxOpts = {
	simple: boolean?, -- far away or low quality (the table in the header)
	key: string?, -- texture key override (Data/VfxTextures)
	dir: Vector3?, -- main direction (sparks: away from the blow)
	count: number?, -- particles (before the halving)
	seconds: number?,
	spin: number?, -- rad/s (circles)
	yaw: number?, -- fixed rotation in radians (decals); random when nil
	speed: { number }?, -- S113 sparks: { min, max } studs/s (default 10..22)
	life: { number }?, -- S113 sparks: { min, max } seconds (default 0.18..0.4)
	gravity: number?, -- S113 sparks: studs/s² down (default 40)
	follow: BasePart?, -- S115 magicCircle: the circle moves with this part (a channel cast while walking)
}

local rng = Random.new()
local DUST_COLOR = Color3.fromHex("#B8AA90")
local DIE_COLOR = Color3.fromHex("#F2EAD8") -- S114: the dice of Roll of the Dice
local CRACK_DARK = Color3.fromHex("#2A2420")
-- The ring of the `ring` texture lies at 0.44 of its width: a ring wave of radius r ends 2.2 r wide.
local RING_END = 2.2
-- Which side of a cutting arc's flat Beam carries the texture's leading edge (+V). Flip to -1 if a slash in AnimLab
-- shows its bright edge where the blade starts instead of where it ends.
local SLASH_SIDE = 1
local SURFACE_LIFT = 0.1 -- studs a ground image floats over the ground
-- W05: the painted swoosh that replaces each old arc, and the keys that are swooshes (a glint, no neon edges)
local BOLD_ARC: { [string]: string } = { slashWide = "slashBold", slashNarrow = "slashBoldNarrow" }
local BOLD_KEYS: { [string]: boolean } = { slashBold = true, slashBoldNarrow = true }

local function tween(
	instance: Instance,
	seconds: number,
	goal: { [string]: any },
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?
)
	Clock.tween(
		instance,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out),
		goal
	)
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

local function kp(t: number, v: number, envelope: number?): NumberSequenceKeypoint
	return NumberSequenceKeypoint.new(t, v, envelope or 0)
end

local function lowQuality(): boolean
	return State.Get({ "account", "settings", "quality" }) == "low"
end

-- Particles of one Emit after the halving (simple or low quality) and the device cap (Config.Vfx.maxBurst).
local function particleCount(count: number, reduced: boolean?): number
	local n = count
	if reduced or lowQuality() then
		n *= Config.Vfx.lowParticles
	end
	local cap = if Pool.isTouch() then Config.Vfx.maxBurst.touch else Config.Vfx.maxBurst.desktop
	return math.max(1, math.floor(math.min(n, cap)))
end

-- One Heartbeat connection for every running animation of the new pieces (spinning circles, beam fades); a ticker
-- gets Clock.now() and returns true when it is finished. Nothing runs while the effect clock is frozen.
type Ticker = (now: number) -> boolean
local tickers: { Ticker } = {}
local tickConnection: RBXScriptConnection? = nil

local function animate(fn: Ticker)
	table.insert(tickers, fn)
	if tickConnection then
		return
	end
	tickConnection = RunService.Heartbeat:Connect(function()
		if Clock.frozen() then
			return
		end
		local now = Clock.now()
		for i = #tickers, 1, -1 do
			local ok, finished = pcall(tickers[i], now)
			if not ok then
				warn(`[Vfx.Library] {tostring(finished)}`)
			end
			if not ok or finished then
				table.remove(tickers, i)
			end
		end
		local connection = tickConnection
		if #tickers == 0 and connection then
			connection:Disconnect()
			tickConnection = nil
		end
	end)
end

-- A Beam's transparency from `from` to `to` over `seconds` (NumberSequence does not tween).
local function fadeBeam(beam: Beam, from: number, to: number, seconds: number)
	local started = Clock.now()
	beam.Transparency = NumberSequence.new(from)
	animate(function(now: number): boolean
		local u = if seconds > 0 then math.clamp((now - started) / seconds, 0, 1) else 1
		beam.Transparency = NumberSequence.new(from + (to - from) * u)
		return u >= 1
	end)
end

-- The beam of a beam holder set up for one use (every property a previous use may have changed).
local function setupBeam(holder: BasePart, color: Color3, width: number, faceCamera: boolean, simple: boolean?): Beam?
	local beam = Pool.child(holder)
	if not beam or not beam:IsA("Beam") then
		Pool.releaseHolder(holder)
		return nil
	end
	beam.Color = ColorSequence.new(color)
	beam.Width0 = width
	beam.Width1 = width
	beam.FaceCamera = faceCamera
	beam.Segments = if simple then 1 else 10
	beam.CurveSize0 = 0
	beam.CurveSize1 = 0
	beam.ZOffset = 0
	beam.Brightness = 1 -- W05: the swoosh raises it on its pooled beams
	beam.Transparency = NumberSequence.new(1)
	return beam
end

local function attachments(holder: BasePart): (Attachment, Attachment)
	return holder:FindFirstChild("A0") :: Attachment, holder:FindFirstChild("A1") :: Attachment
end

-- A PointLight on `p` for `seconds` when the device's light budget allows (Pool.takeLight).
local function flashLight(p: BasePart, color: Color3, range: number, brightness: number, seconds: number)
	if not Pool.takeLight() then
		return
	end
	local l = light(p, color, range, brightness)
	Clock.after(seconds, function()
		l:Destroy()
		Pool.dropLight()
	end)
end

-- The CFrame at `at` whose front (-Z) looks along `dir` (straight up / down handled).
local function facingFrame(at: Vector3, dir: Vector3): CFrame
	if math.abs(dir.Unit.Y) > 0.98 then
		return CFrame.new(at) * CFrame.Angles(if dir.Y > 0 then math.pi / 2 else -math.pi / 2, 0, 0)
	end
	return CFrame.lookAt(at, at + dir)
end

-- Emits from an emitter holder (Pool.holder("emitter", key)) placed by the caller, sets every property of the use
-- from `o` (colour, size, speed, life, direction, orientation), puts the texture on (Vfx/Textures; without it the
-- default particle with LightEmission o.emission or 0.8), halves the count by the header's table and gives the
-- holder back after the longest life. The only place that sets up a textured burst.
local function burstFrom(holder: BasePart, key: string, color: Color3, count: number, o: { [string]: any })
	local e = Pool.child(holder)
	if not e or not e:IsA("ParticleEmitter") then
		Pool.releaseHolder(holder)
		return
	end
	local lifeMin: number = o.lifeMin or 0.3
	local lifeMax: number = o.lifeMax or 0.7
	holder.Size = o.area or Vector3.new(0.2, 0.2, 0.2) -- particles start anywhere in the holder's box
	e.Color = ColorSequence.new(color, o.to or color)
	e.Lifetime = NumberRange.new(lifeMin, lifeMax)
	e.Speed = NumberRange.new(o.speedMin or 0, o.speedMax or o.speedMin or 0)
	e.SpreadAngle = Vector2.new(o.spread or 180, o.spread or 180)
	e.Acceleration = o.accel or Vector3.zero
	e.Drag = o.drag or 0
	e.Size = o.sizeSeq or NumberSequence.new({ kp(0, o.size or 0.6), kp(1, o.sizeEnd or 0) })
	e.Transparency = o.transparency or NumberSequence.new({ kp(0, 0.1), kp(1, 1) })
	e.EmissionDirection = o.direction or Enum.NormalId.Top
	e.Orientation = if o.orient == "parallel"
		then Enum.ParticleOrientation.VelocityParallel
		else Enum.ParticleOrientation.FacingCamera
	e.Squash = NumberSequence.new(o.squash or 0)
	e.Rotation = o.rotation or NumberRange.new(0)
	e.RotSpeed = o.rotSpeed or NumberRange.new(0)
	e.ZOffset = o.zOffset or 0
	e.Brightness = o.brightness or 1
	e.LockedToPart = false
	e.TimeScale = if Clock.frozen() then 0 else 1
	if not Textures.particle(e, key, o.emission) then
		Textures.plainParticle(e)
		e.LightEmission = o.emission or 0.8
	end
	e:Emit(if o.exact then count else particleCount(count, o.simple))
	Pool.holderLater(holder, lifeMax + 0.1)
end

-- An emitter holder of `key` at `frame`, nil without its texture (the caller keeps the old look) or past the limit.
local function textured(key: string, frame: CFrame): BasePart?
	if not Textures.id(key) then
		return nil
	end
	local holder = Pool.holder("emitter", key)
	if holder then
		holder.CFrame = frame
	end
	return holder
end

-- Particle burst from a part (count halved on low quality). S112: `o.texture` (a Data/VfxTextures key) emits from a
-- textured holder at the part instead (`o.orient = "parallel"`, `o.squash`), the old emitter without it.
local function emit(p: BasePart, color: Color3, count: number, options: { [string]: any }?)
	local o: { [string]: any } = options or {}
	local key = o.texture
	if type(key) == "string" then
		local holder = textured(key, p.CFrame)
		if holder then
			burstFrom(holder, key, color, count, {
				to = o.to,
				emission = o.emission,
				lifeMin = o.lifeMin,
				lifeMax = o.lifeMax,
				speedMin = o.speedMin or 4,
				speedMax = o.speedMax or 10,
				spread = o.spread,
				accel = o.accel,
				drag = o.drag or 2,
				size = o.size,
				direction = o.direction,
				orient = o.orient,
				squash = o.squash,
				simple = o.low,
			})
			return
		end
	end
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
	Clock.track(e)
	local n = if o.low then math.max(1, math.floor(count * Config.Vfx.lowParticles)) else count
	e:Emit(n)
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

local function ball(at: Vector3, size: number, color: Color3, s: number)
	local orb = Pool.part("Ball", color, Vector3.one * math.max(0.5, size * 0.25), Enum.Material.Neon, 0.1)
	orb.CFrame = CFrame.new(at)
	tween(orb, s, { Size = Vector3.one * size, Transparency = 1 })
	Pool.later(orb, s + 0.05)
end

-- S112 E1: the core of a hit (0.05-0.1 s): a star flash and a soft glow from textured holders, a short light; without
-- the texture a neon ball growing 0.3 -> size in 0.08 s.
function Library.impactFlash(at: Vector3, size: number, color: Color3, opts: FxOpts?)
	local o: FxOpts = opts or {}
	local key = o.key or "star"
	local star = textured(key, CFrame.new(at))
	if not star then
		local orb = Pool.part("Ball", color, Vector3.one * math.max(0.3, size * 0.3), Enum.Material.Neon, 0.05)
		orb.CFrame = CFrame.new(at)
		tween(orb, 0.08, { Size = Vector3.one * size, Transparency = 1 })
		Pool.later(orb, 0.12)
		return
	end
	burstFrom(star, key, color, 1, {
		exact = true,
		lifeMin = 0.08,
		lifeMax = 0.08,
		sizeSeq = NumberSequence.new({ kp(0, size * 0.6), kp(1, size * 1.15) }),
		transparency = NumberSequence.new({ kp(0, 0), kp(0.6, 0.2), kp(1, 1) }),
		rotation = NumberRange.new(0, 360),
		zOffset = 1,
		emission = 1,
	})
	local glow = textured("glow", CFrame.new(at))
	if glow then
		burstFrom(glow, "glow", color, 1, {
			exact = true,
			lifeMin = 0.12,
			lifeMax = 0.12,
			sizeSeq = NumberSequence.new(size * 1.6),
			transparency = NumberSequence.new({ kp(0, 0.35), kp(1, 1) }),
			emission = 1,
		})
	end
	if not o.simple and not lowQuality() then
		flashLight(star, color, size * 3, 3, 0.1)
	end
end

-- S112: with the star texture the core is impactFlash and the neon ball is smaller and shorter (none on low quality).
-- `simple` (far away) passes on to impactFlash: no PointLight (the header table).
function Library.burst(at: Vector3, size: number, color: Color3, seconds: number?, simple: boolean?)
	local s = seconds or 0.35
	if Textures.id("star") then
		Library.impactFlash(at, size * 0.5, color, { simple = simple })
		if not lowQuality() then
			ball(at, size * 0.6, color, s * 0.6)
		end
		return
	end
	ball(at, size, color, s)
end

-- A ground image (a holder "surface") of `key`, `size` studs wide, at `frame`, tinted and still hidden; nil without the
-- texture or past the limit.
local function surfaceAt(key: string, frame: CFrame, size: number, color: Color3): (BasePart?, ImageLabel?)
	if not Textures.id(key) then
		return nil, nil
	end
	local holder = Pool.holder("surface", key)
	if not holder then
		return nil, nil
	end
	local gui = Pool.child(holder)
	local image = gui and gui:FindFirstChild("Image")
	if not image or not image:IsA("ImageLabel") then
		Pool.releaseHolder(holder)
		return nil, nil
	end
	holder.Size = Vector3.new(size, 0.05, size)
	holder.CFrame = frame
	image.ImageColor3 = color
	image.ImageTransparency = 1
	return holder, image
end

-- The textured ring of a shock wave: grows from 0.3 r to RING_END r wide in `seconds`, fading. False without it.
local function ringSurface(at: Vector3, radius: number, color: Color3, seconds: number, key: string?): boolean
	local base = ground(at) + Vector3.new(0, SURFACE_LIFT + 0.02, 0)
	local holder, image = surfaceAt(key or "ring", CFrame.new(base), radius * 0.3, color)
	if not holder or not image then
		return false
	end
	image.ImageTransparency = 0.1
	local final = radius * RING_END
	tween(holder, seconds, { Size = Vector3.new(final, 0.05, final) })
	tween(image, seconds, { ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Pool.holderLater(holder, seconds + 0.05)
	return true
end

-- Shock wave: a ring of segments running outwards over the ground. S112: with the ring texture the textured ring and
-- 10 segments (none on low quality), no disc.
function Library.shockwave(at: Vector3, radius: number, color: Color3, seconds: number?, simple: boolean?)
	local s = seconds or 0.45
	local ringed = ringSurface(at, radius, color, s)
	if ringed and lowQuality() then
		return
	end
	local base = ground(at) + Vector3.new(0, 0.25, 0)
	local count = if simple or ringed then 10 else 20
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
	if not simple and not ringed then
		local disc = Pool.part("Cylinder", color, Vector3.new(0.15, 1, 1), Enum.Material.Neon, 0.55)
		disc.CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90))
		tween(disc, s * 0.8, { Size = Vector3.new(0.15, radius * 2, radius * 2), Transparency = 1 })
		Pool.later(disc, s)
	end
end

-- S112 E3: dark marks on the ground (cracks; later scorch marks and telegraph cracks, S117). A decal holder
-- radius * 2 wide on the ground, turned by opts.yaw or at random, Decal.Color3 = color (dark: the caller picks it),
-- 1 -> 0.1 transparent in 0.06 s, held, gone over the last Config.Vfx.decalFade s. Returns a function that takes it
-- down at once. Past maxDecals the oldest mark goes out at once and the new one appears. Without the texture: the old
-- part cracks for "cracks", nothing for other keys (a new layer, not a replacement).
local decalQueue: { () -> () } = {} -- stop functions of the live marks, oldest first

local crackParts: (Vector3, number, Color3, number?, boolean?) -> ()

function Library.groundDecal(
	at: Vector3,
	radius: number,
	key: string,
	color: Color3,
	seconds: number,
	opts: FxOpts?
): () -> ()
	local o: FxOpts = opts or {}
	if not Textures.id(key) then
		if key == "cracks" then
			crackParts(at, radius / 1.05, color, seconds, o.simple)
		end
		return function() end
	end
	local holder = Pool.holder("decal", key)
	local oldest = if not holder then decalQueue[1] else nil
	if oldest then
		oldest() -- takes itself out of the queue
		holder = Pool.holder("decal", key)
	end
	if not holder then
		return function() end
	end
	local part = holder :: BasePart
	local decal = Pool.child(part)
	if not decal or not decal:IsA("Decal") then
		Pool.releaseHolder(part)
		return function() end
	end
	part.Size = Vector3.new(radius * 2, 0.05, radius * 2)
	part.CFrame = CFrame.new(ground(at) + Vector3.new(0, 0.06, 0))
		* CFrame.Angles(0, o.yaw or rng:NextNumber(0, math.pi * 2), 0)
	decal.Color3 = color
	decal.Transparency = 1
	tween(decal, 0.06, { Transparency = 0.1 })
	local done = false
	local stop: () -> ()
	stop = function()
		if done then
			return
		end
		done = true
		local i = table.find(decalQueue, stop)
		if i then
			table.remove(decalQueue, i)
		end
		Pool.releaseHolder(part)
	end
	table.insert(decalQueue, stop)
	local fade = Config.Vfx.decalFade
	Clock.after(math.max(0.06, seconds - fade), function()
		if not done then
			tween(decal, fade, { Transparency = 1 })
		end
	end)
	Clock.after(seconds + 0.05, stop)
	return stop
end

-- The tint of the cracks texture: dark rock with a touch of the skill's colour (skills, AnimLab, Library.cracks).
function Library.crackTint(color: Color3): Color3
	return CRACK_DARK:Lerp(color, 0.2)
end

-- Ground cracks: dark slabs with a glowing core radiating from a point. S112: with the cracks texture a dark decal
-- radius * 2.1 wide and two Slate slabs for depth (only the decal when simple, no neon core).
function Library.cracks(at: Vector3, radius: number, color: Color3, seconds: number?, simple: boolean?)
	local s = seconds or 1.4
	if not Textures.id("cracks") then
		crackParts(at, radius, color, s, simple)
		return
	end
	Library.groundDecal(at, radius * 1.05, "cracks", Library.crackTint(color), s, { simple = simple })
	if simple or lowQuality() then
		return
	end
	local base = ground(at) + Vector3.new(0, 0.05, 0)
	for i = 1, 2 do
		local a = rng:NextNumber(0, math.pi * 2) + i * math.pi
		local length = radius * rng:NextNumber(0.5, 0.8)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local mid = base + dir * length / 2
		local slab = Pool.part("Block", CRACK_DARK, Vector3.new(0.7, 0.12, length), Enum.Material.Slate, 0)
		slab.CFrame = CFrame.lookAt(mid, mid + dir) * CFrame.Angles(0, 0, rng:NextNumber(-0.1, 0.1))
		Clock.after(s * 0.6, function()
			tween(slab, s * 0.4, { Transparency = 1 })
		end)
		Pool.later(slab, s + 0.05)
	end
end

crackParts = function(at: Vector3, radius: number, color: Color3, seconds: number?, simple: boolean?)
	local s = seconds or 1.4
	local base = ground(at) + Vector3.new(0, 0.08, 0)
	local count = if simple then 4 else 7
	local random = Random.new()
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + random:NextNumber(-0.3, 0.3)
		local length = radius * random:NextNumber(0.55, 1)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local mid = base + dir * length / 2
		local slab = Pool.part("Block", CRACK_DARK, Vector3.new(0.9, 0.15, length), Enum.Material.Slate, 0)
		slab.CFrame = CFrame.lookAt(mid, mid + dir) * CFrame.Angles(0, 0, random:NextNumber(-0.1, 0.1))
		local core = Pool.part("Block", color, Vector3.new(0.3, 0.18, length * 0.9), Enum.Material.Neon, 0.1)
		core.CFrame = slab.CFrame + Vector3.new(0, 0.03, 0)
		Clock.after(s * 0.6, function()
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
	simple: boolean?,
	textureKey: string?
)
	local count = if simple then 6 else 12
	local sweep = 0.12
	local roll = CFrame.Angles(0, 0, math.rad(tilt or 0))
	-- S112: a flat Beam with the arc texture in the arc's plane (slashWide from 120 degrees, else slashNarrow), the
	-- beam running forwards from the origin through the middle of the arc; it appears over the sweep and fades in 0.25 s.
	-- Beside it every second segment (an edge), none on low quality. S114: `textureKey` picks the arc (SkillVfx.tex).
	-- W05: the painted swoosh (slashBold / slashBoldNarrow) by default; the old ribbed arcs stay for an explicit key
	local wide = math.abs(from - to) >= 120
	local key = textureKey or BOLD_ARC[if wide then "slashWide" else "slashNarrow"] or "slashWide"
	if not textureKey and not Textures.id(key) then
		key = if wide then "slashWide" else "slashNarrow"
	end
	local holder = if Textures.id(key) then Pool.holder("beam", key) else nil
	local beam = if holder then setupBeam(holder, color, radius * 2, false, simple) else nil
	if holder and beam then
		local a0, a1 = attachments(holder)
		-- the texture's leading edge is at +V: a sweep to the left (from < to) turns the plane over
		local side = if from >= to then SLASH_SIDE else -SLASH_SIDE
		local frame = origin
			* roll
			* CFrame.Angles(0, math.rad((from + to) / 2), 0)
			* CFrame.Angles(0, 0, if side > 0 then 0 else math.pi)
		holder.CFrame = frame
		a0.CFrame = CFrame.new(0, 0, radius)
		a1.CFrame = CFrame.new(0, 0, -radius)
		beam.LightEmission = 1
		local bold = BOLD_KEYS[key] == true
		-- W05: the body darker than the edge (the colour carries it, the glint the heat), a longer fade
		if bold then
			beam.Color = ColorSequence.new(color:Lerp(Color3.new(0, 0, 0), 0.08))
			beam.Brightness = 1.4
		end
		fadeBeam(beam, 1, 0.05, sweep)
		Clock.after(sweep + 0.04, fadeBeam, beam, 0.05, 1, if bold then 0.32 else 0.25)
		Pool.holderLater(holder, sweep + 0.4)
		-- W05: a glint: the same arc a little smaller and whiter, flashing over the leading edge as the blade passes
		if bold and not simple and not lowQuality() then
			local glintHolder = Pool.holder("beam", key)
			local glint = if glintHolder
				then setupBeam(glintHolder, color:Lerp(Color3.new(1, 1, 1), 0.55), radius * 1.9, false, simple)
				else nil
			if glintHolder and glint then
				local g0, g1 = attachments(glintHolder)
				glintHolder.CFrame = frame * CFrame.new(0, 0.05, 0)
				g0.CFrame = CFrame.new(0, 0, radius * 0.95)
				g1.CFrame = CFrame.new(0, 0, -radius * 0.95)
				glint.LightEmission = 1
				glint.Brightness = 2
				fadeBeam(glint, 1, 0.1, sweep * 0.8)
				Clock.after(sweep * 0.8, fadeBeam, glint, 0.1, 1, 0.12)
				Pool.holderLater(glintHolder, sweep + 0.2)
			end
		end
		if bold or lowQuality() then
			return
		end
	end
	for i = 0, count - 1, if beam then 2 else 1 do
		local u = i / math.max(1, count - 1)
		local yaw = math.rad(from + (to - from) * u)
		local frame = origin * roll * CFrame.Angles(0, yaw, 0)
		local inner, outer = radius * 0.35, radius
		local seg = Pool.part("Block", color, Vector3.new(0.25, 0.25, outer - inner), Enum.Material.Neon, 1)
		seg.CFrame = frame * CFrame.new(0, 0, -(inner + outer) / 2)
		Clock.after(sweep * u, function()
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

type Shape = "orb" | "arrow" | "shard" | "bolt" | "rock" | "die" | "snare"

-- W06: an arrow is a wooden shaft with a glowing head of the skill's colour and two small vanes at the tail (pieces
-- welded to the pooled shaft, gone with it when the pool takes it back); `simple` keeps the bare glowing stick.
local ARROW_WOOD = Color3.fromHex("#6B4E32")
local function arrowPiece(shaft: BasePart, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material)
	local piece = Instance.new("Part")
	piece.Size = size
	piece.Color = color
	piece.Material = material
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CastShadow = false
	piece.Massless = true
	piece.Anchored = false
	piece.CFrame = shaft.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = shaft
	weld.Part1 = piece
	weld.Parent = piece
	piece.Parent = shaft
end

local function arrowPart(color: Color3, size: number, simple: boolean?): BasePart
	if simple then
		return Pool.part("Block", color, Vector3.new(0.14, 0.14, 2.4 * size), Enum.Material.Neon, 0.05)
	end
	local length = 2.2 * size
	local shaft =
		Pool.part("Block", ARROW_WOOD, Vector3.new(0.09, 0.09, length) * math.max(1, size), Enum.Material.Wood, 0)
	local head = color:Lerp(Color3.new(1, 1, 1), 0.25)
	arrowPiece(
		shaft,
		Vector3.new(0.22, 0.08, 0.5) * size,
		CFrame.new(0, 0, -length / 2 - 0.2 * size),
		head,
		Enum.Material.Neon
	)
	for _, roll in { 0, math.pi / 2 } do
		arrowPiece(
			shaft,
			Vector3.new(0.3, 0.03, 0.45) * size,
			CFrame.new(0, 0, length / 2 - 0.25 * size) * CFrame.Angles(0, 0, roll),
			color,
			Enum.Material.SmoothPlastic
		)
	end
	return shaft
end

local function projectilePart(shape: Shape, color: Color3, size: number, simple: boolean?): BasePart
	if shape == "arrow" then
		return arrowPart(color, size, simple)
	elseif shape == "shard" then
		return Pool.part("Block", color, Vector3.new(0.45, 0.45, 1.8) * size, Enum.Material.Glass, 0.15)
	elseif shape == "bolt" then
		return Pool.part("Block", color, Vector3.new(0.3, 0.3, 2.2) * size, Enum.Material.Neon, 0)
	elseif shape == "rock" then
		return Pool.part("Ball", color, Vector3.one * 1.6 * size, Enum.Material.Basalt, 0)
	elseif shape == "die" then
		-- S114: a small ivory die (Roll of the Dice) with a glowing edge of the skill's colour
		-- (a pooled part loses its children when released, so the edge is made per throw)
		local die = Pool.part("Block", DIE_COLOR, Vector3.one * 1.6 * size, Enum.Material.SmoothPlastic, 0)
		local edge = Instance.new("SelectionBox")
		edge.LineThickness = 0.04
		edge.Color3 = color
		edge.Adornee = die
		edge.Parent = die
		return die
	elseif shape == "snare" then
		-- S115: a thrown snare (a flat dark net with the trap's colour), turning in flight
		return Pool.part(
			"Block",
			color:Lerp(Color3.fromHex("#2A2420"), 0.5),
			Vector3.new(1.1, 0.12, 1.1) * size,
			Enum.Material.Metal,
			0
		)
	end
	return Pool.part("Ball", color, Vector3.one * size, Enum.Material.Neon, 0.05)
end

-- Options of a projectile. S115: `trail` = the trail's texture key (default trailSoft), `maxTime` = the cap of the
-- flight (default 0.8; Offense.projectile's 0.6 for the shots of projectile skills), `time` = a fixed flight time
-- (thrown snares land at the motion's hit), `arc` = the height of a lob, `stick` = seconds the arrow stays stuck where
-- it lands (Arrow Rain).
export type ProjectileOpts = {
	size: number?,
	speed: number?,
	simple: boolean?,
	onArrive: ((at: Vector3) -> ())?,
	trail: string?,
	maxTime: number?,
	time: number?,
	arc: number?,
	stick: number?,
	flame: boolean?, -- W03: a fire projectile sheds flames (the "fire" texture) behind its core
}

-- Flies from `from` to the target model (homing on its centre) or a point; calls onArrive at the end.
function Library.projectile(
	from: Vector3,
	target: Model | Vector3,
	shape: Shape,
	color: Color3,
	options: ProjectileOpts?
)
	local o: ProjectileOpts = options or {}
	local size = o.size or 1
	local speed = o.speed or 90
	local p = projectilePart(shape, color, size, o.simple)
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
		trail.Lifetime = if shape == "arrow" then 0.14 else 0.25
		trail.Transparency = NumberSequence.new(0.2, 1)
		trail.WidthScale = NumberSequence.new(1, 0)
		Textures.trail(trail, o.trail or "trailSoft") -- S112; S115: the skill's own streak (SkillVfx tex.projectile)
		trail.Parent = p
		Clock.track(trail)
		if shape ~= "arrow" and shape ~= "snare" then
			light(p, color, 10, 1.5)
			local e = Instance.new("ParticleEmitter")
			e.Color = ColorSequence.new(color)
			e.LightEmission = 1
			e.Rate = 40
			e.Lifetime = NumberRange.new(0.15, 0.35)
			e.Speed = NumberRange.new(0.5, 2)
			e.Size = NumberSequence.new(0.4 * size, 0)
			e.Transparency = NumberSequence.new(0.2, 1)
			-- S112: a soft glow instead of the default particle; a shard sheds ice shards
			if shape == "shard" and Textures.particle(e, "iceShard") then
				e.Rate = 6
				e.Lifetime = NumberRange.new(0.3, 0.5)
				e.Size = NumberSequence.new(0.5 * size, 0.2 * size)
				e.Rotation = NumberRange.new(0, 360)
				e.RotSpeed = NumberRange.new(-120, 120)
			else
				Textures.particle(e, "glow")
			end
			e.Parent = p
			Clock.track(e)
			-- W03: a fire orb trails tongues of flame, white-hot at the core, deep red as they die
			if o.flame then
				local f = Instance.new("ParticleEmitter")
				f.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, color:Lerp(Color3.new(1, 1, 1), 0.55)),
					ColorSequenceKeypoint.new(0.4, color),
					ColorSequenceKeypoint.new(1, color:Lerp(Color3.new(0.2, 0, 0), 0.6)),
				})
				f.LightEmission = 1
				f.Rate = 60
				f.Lifetime = NumberRange.new(0.22, 0.4)
				f.Speed = NumberRange.new(0.5, 1.5)
				f.SpreadAngle = Vector2.new(180, 180)
				f.Rotation = NumberRange.new(0, 360)
				f.RotSpeed = NumberRange.new(-180, 180)
				f.Size = NumberSequence.new({ kp(0, 1.3 * size), kp(0.5, 1.0 * size), kp(1, 0.1) })
				f.Transparency = NumberSequence.new({ kp(0, 0.05), kp(0.6, 0.35), kp(1, 1) })
				if Textures.particle(f, "fire") then
					f.Parent = p
					Clock.track(f)
				else
					f:Destroy()
				end
			end
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
	local total = o.time or math.clamp(distance / speed, 0.05, o.maxTime or 0.8)
	local arc = o.arc or 0
	local spinning = shape == "snare"
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt: number)
		elapsed += Clock.dt(dt)
		local to = goal()
		local u = math.min(1, elapsed / total)
		local at = from:Lerp(to, u) + Vector3.new(0, arc * 4 * u * (1 - u), 0)
		if spinning then
			p.CFrame = CFrame.new(at) * CFrame.Angles(0, elapsed * 14, 0.3)
		elseif (to - at).Magnitude > 0.05 then
			p.CFrame = CFrame.lookAt(at, to)
		else
			p.CFrame = CFrame.new(at) * p.CFrame.Rotation
		end
		if u >= 1 then
			connection:Disconnect()
			if o.stick and o.stick > 0 then
				-- S115: the arrow stays stuck in the ground a moment, its trail gone
				for _, child in p:GetChildren() do
					if child:IsA("Trail") then
						child.Enabled = false
					end
				end
				tween(p, o.stick, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
				Pool.later(p, o.stick + 0.02)
			else
				Pool.release(p)
			end
			if o.onArrive then
				o.onArrive(to)
			end
		end
	end)
end

-- Lightning: a zigzag of short segments between two points, flickering for a few frames.
function Library.lightning(a: Vector3, b: Vector3, color: Color3, width: number?, simple: boolean?)
	-- S112: one camera-facing Beam with the scrolling lightning texture on the straight line a -> b; the second flicker
	-- bends it by a random curve
	local length = (b - a).Magnitude
	local holder = if Textures.id("beamLightning") and length > 0.1 then Pool.holder("beam", "beamLightning") else nil
	local w = (width or 0.3) * 4
	local beam = if holder then setupBeam(holder, color, w, true, true) else nil
	if holder and beam then
		local a0, a1 = attachments(holder)
		holder.CFrame = CFrame.lookAt(a, b)
		a0.CFrame = CFrame.new()
		a1.CFrame = CFrame.new(0, 0, -length)
		Textures.beam(beam, "beamLightning", { speed = 6, length = w * 2 })
		beam.Transparency = NumberSequence.new(0)
		Clock.after(0.06, function()
			beam.CurveSize0 = rng:NextNumber(-1.2, 1.2)
			beam.CurveSize1 = rng:NextNumber(-1.2, 1.2)
			fadeBeam(beam, 0, 1, 0.18)
		end)
		Pool.holderLater(holder, 0.26)
		return
	end
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
		Clock.after(flicker * 0.06, function()
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
	-- S112: a camera-facing Beam of holy light rising in the column's axis; the cylinder more transparent beside it
	local holder = if Textures.id("beamHoly") then Pool.holder("beam", "beamHoly") else nil
	local beam = if holder then setupBeam(holder, color, radius * 2.4, true, true) else nil
	if holder and beam then
		local a0, a1 = attachments(holder)
		holder.CFrame = CFrame.new(base)
		a0.CFrame = CFrame.new()
		a1.CFrame = CFrame.new(0, height, 0)
		Textures.beam(beam, "beamHoly", { speed = 3, length = radius * 4 })
		fadeBeam(beam, 1, 0.1, s * 0.35)
		Clock.after(s * 0.35, fadeBeam, beam, 0.1, 1, s * 0.65)
		Pool.holderLater(holder, s + 0.05)
	end
	local col = Pool.part(
		"Cylinder",
		color,
		Vector3.new(0.5, radius * 2, radius * 2),
		Enum.Material.Neon,
		if beam then 0.55 else 0.35
	)
	col.CFrame = CFrame.new(base + Vector3.new(0, 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90))
	tween(col, s * 0.35, {
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
	Clock.after(s * 0.35, function()
		tween(col, s * 0.65, { Transparency = 1, Size = Vector3.new(height, radius * 0.4, radius * 0.4) })
	end)
	light(col, color, radius * 4 + 6, 2.5)
	Pool.later(col, s + 0.05)
end

-- S112: a textured circle lying on the ground (`key`, radius), turning at `spin` rad/s on the shared loop, shown in
-- 0.15 s and fading over Config.Vfx.decalFade after `seconds`. Returns its stop function, nil without the texture.
local function circleSurface(
	at: Vector3,
	radius: number,
	color: Color3,
	seconds: number,
	key: string,
	spin: number,
	follow: BasePart?
): (() -> ())?
	local base = ground(at) + Vector3.new(0, SURFACE_LIFT, 0)
	-- S115: a followed circle keeps its offset under the part (no raycast per frame)
	local offset = if follow then base - follow.Position else nil
	local holder, image = surfaceAt(key, CFrame.new(base), radius * 2, color)
	if not holder or not image then
		return nil
	end
	local part, label = holder :: BasePart, image :: ImageLabel
	tween(label, 0.15, { ImageTransparency = 0.15 })
	local started = Clock.now()
	local turn = rng:NextNumber(0, math.pi * 2)
	local done = false
	local function finish()
		if done then
			return
		end
		done = true
		local fade = Config.Vfx.decalFade
		tween(label, fade, { ImageTransparency = 1 })
		Pool.holderLater(part, fade + 0.05)
	end
	animate(function(now: number): boolean
		if done then
			return true
		end
		if follow and offset and follow.Parent then
			base = follow.Position + offset
		end
		part.CFrame = CFrame.new(base) * CFrame.Angles(0, turn + (now - started) * spin, 0)
		if now - started >= seconds then
			finish()
			return true
		end
		return false
	end)
	return finish
end

local runeParts: (Vector3, number, Color3, number, boolean?) -> ()

-- Rune: a glowing circle on the ground with a turning pattern, for `seconds`. S112: the textured circle of `key`
-- (a class rune, Data/VfxTextures.RUNE_OF_CLASS; default magicCircle) turning at 1.2 rad/s like the old spokes.
function Library.rune(at: Vector3, radius: number, color: Color3, seconds: number, simple: boolean?, key: string?)
	if not circleSurface(at, radius, color, seconds, key or "magicCircle", 1.2) then
		runeParts(at, radius, color, seconds, simple)
	end
end

-- S112 E5: the body of magic and heal effects (later magic telegraphs, S117): a textured circle of opts.key (default
-- magicCircle) lying on the ground, turning at opts.spin (default Config.Vfx.spinStep), gone after `seconds`
-- (S115: moving with opts.follow). Returns its stop function. Without the texture: the old rune (no stop: it ends by
-- itself, in place).
function Library.magicCircle(at: Vector3, radius: number, color: Color3, seconds: number, opts: FxOpts?): () -> ()
	local o: FxOpts = opts or {}
	local stop =
		circleSurface(at, radius, color, seconds, o.key or "magicCircle", o.spin or Config.Vfx.spinStep, o.follow)
	if stop then
		return stop
	end
	runeParts(at, radius, color, seconds, o.simple)
	return function() end
end

-- S112 E6: the body of a shock wave: the textured ring growing from 0.3 r to RING_END r in opts.seconds (default
-- 0.4 s), fading. Without the texture: the simple old shock wave.
function Library.ringWave(at: Vector3, radius: number, color: Color3, opts: FxOpts?)
	local o: FxOpts = opts or {}
	if not ringSurface(at, radius, color, o.seconds or 0.4, o.key) then
		Library.shockwave(at, radius, color, 0.45, true)
	end
end

-- S115: a snare of the Trapper lying on the ground for `seconds`: a dark iron plate with teeth of the trap's colour
-- around it (`key` = "iceShard": ice crystals instead of teeth). Returns the function that takes it away at once (the
-- trap sprang). Plain parts, no emitters; the simple version has half the teeth.
local SNARE_PLATE = Color3.fromHex("#3A3530")
function Library.snare(at: Vector3, color: Color3, seconds: number, simple: boolean?, key: string?): () -> ()
	local base = ground(at) + Vector3.new(0, 0.1, 0)
	local parts: { BasePart } = {}
	local plate = Pool.part("Cylinder", SNARE_PLATE, Vector3.new(0.2, 1.9, 1.9), Enum.Material.Metal, 0)
	plate.CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90))
	table.insert(parts, plate)
	local crystal = key == "iceShard"
	local teeth = if simple then 4 else 8
	for i = 1, teeth do
		local a = i / teeth * math.pi * 2
		local tooth = if crystal
			then Pool.part("Block", color, Vector3.new(0.28, 0.9, 0.28), Enum.Material.Glass, 0.15)
			else Pool.part("Wedge", color, Vector3.new(0.14, 0.5, 0.34), Enum.Material.Metal, 0)
		local spot = base + Vector3.new(math.cos(a) * 0.85, if crystal then 0.4 else 0.25, math.sin(a) * 0.85)
		-- teeth lean inwards over the plate, crystals stand tilted outwards
		tooth.CFrame = CFrame.lookAt(spot, base + Vector3.new(0, 0.25, 0))
			* CFrame.Angles(math.rad(if crystal then -20 else 25), 0, 0)
		table.insert(parts, tooth)
	end
	local done = false
	local function stop()
		if done then
			return
		end
		done = true
		for _, part in parts do
			tween(part, 0.25, { Transparency = 1 })
			Pool.later(part, 0.3)
		end
	end
	Clock.after(math.max(0.5, seconds), stop)
	return stop
end

-- S115: a dark storm cloud hanging Config.Vfx.cloudHeight studs over the circle for `seconds` (Thunderstorm): puffs of
-- the smoke flipbook every 0.5 s across 1.4 r; without the texture one dark disc fading out.
local CLOUD_DARK = Color3.fromHex("#2E3038")
local CLOUD_EVERY = 0.5
function Library.stormCloud(at: Vector3, radius: number, color: Color3, seconds: number, simple: boolean?)
	local base = ground(at) + Vector3.new(0, Config.Vfx.cloudHeight, 0)
	local tint = CLOUD_DARK:Lerp(color, 0.15)
	if not Textures.id("smoke") then
		local disc =
			Pool.part("Cylinder", tint, Vector3.new(1.2, radius * 1.6, radius * 1.6), Enum.Material.SmoothPlastic, 0.45)
		disc.CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90))
		Clock.after(seconds, function()
			tween(disc, 0.5, { Transparency = 1 })
		end)
		Pool.later(disc, seconds + 0.55)
		return
	end
	for i = 0, math.floor(seconds / CLOUD_EVERY) do
		Clock.after(i * CLOUD_EVERY, function()
			local holder = textured("smoke", CFrame.new(base))
			if not holder then
				return
			end
			burstFrom(holder, "smoke", tint, if simple then 2 else 4, {
				simple = simple,
				area = Vector3.new(radius * 1.4, 0.8, radius * 1.4),
				speedMin = 0.2,
				speedMax = 0.8,
				lifeMin = 1.2,
				lifeMax = 1.5,
				rotation = NumberRange.new(0, 360),
				rotSpeed = NumberRange.new(-12, 12),
				sizeSeq = NumberSequence.new({ kp(0, radius * 0.45), kp(1, radius * 0.7) }),
				transparency = NumberSequence.new({ kp(0, 0.7), kp(0.3, 0.3), kp(1, 1) }),
				emission = 0,
			})
		end)
	end
end

runeParts = function(at: Vector3, radius: number, color: Color3, seconds: number, simple: boolean?)
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
	local started = Clock.now()
	local connection: RBXScriptConnection
	connection = RunService.Heartbeat:Connect(function(dt: number)
		angle += Clock.dt(dt) * 1.2
		for i, spoke in spokes do
			spoke.CFrame = CFrame.new(base + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, angle + i / count * math.pi, 0)
		end
		if Clock.now() - started >= seconds then
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
	Clock.after(seconds, function()
		if p.Parent then
			tween(p, 0.3, { Transparency = 1 })
			Clock.after(0.32, function()
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

-- Aura: particles rising around a character for `seconds`. S114: `key` = the particle texture (default glow; e.g.
-- "smoke" for a dark cloud around the body, SkillVfx.tex).
function Library.aura(model: Model, color: Color3, seconds: number, simple: boolean?, key: string?)
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
		local texture = key or "glow"
		if texture ~= "glow" then
			e.Lifetime = NumberRange.new(1, 1.4) -- S114: before the texture (a flipbook plays over the particle's life)
		end
		if Textures.particle(e, texture, if texture == "glow" then nil else 0) then
			if texture == "glow" then -- S112: soft glows, a little bigger than the old dots
				e.Size = NumberSequence.new(0.7, 0)
			else
				-- S114: a cloud (smoke) around the body: fewer, bigger, slower particles, lit by the scene
				e.Rate = 6
				e.Speed = NumberRange.new(0.6, 1.2)
				e.Size = NumberSequence.new({ kp(0, 1.2), kp(1, 2.6) })
				e.Transparency = NumberSequence.new({ kp(0, 0.45), kp(1, 1) })
				e.Rotation = NumberRange.new(0, 360)
			end
		end
		e.Parent = holder
		Clock.track(e)
		light(holder, color, 8, 0.8)
	end
	detachLater(holder, math.max(0.5, seconds))
end

-- Rising sparkles around a character (heals). S112: star particles rising from the feet instead of the balls.
function Library.sparkle(model: Model, color: Color3, simple: boolean?)
	local at = centre(model)
	local stars = textured("star", CFrame.new(at - Vector3.new(0, 1.5, 0)))
	if stars then
		burstFrom(stars, "star", color, 8, {
			simple = simple,
			spread = 25,
			speedMin = 4,
			speedMax = 6,
			drag = 1,
			lifeMin = 0.6,
			lifeMax = 0.9,
			size = 0.7,
			area = Vector3.new(3.2, 0.2, 3.2),
			rotation = NumberRange.new(0, 360),
			rotSpeed = NumberRange.new(-90, 90),
			emission = 1,
		})
		return
	end
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
		-- W03: the soft ring texture (its band sits at 0.44 of the image) instead of 16 neon segments; it settles
		-- onto the radius and fades
		local holder, image = surfaceAt("ring", CFrame.new(base), a / 0.44 * 1.08, color)
		if holder and image then
			image.ImageTransparency = 0.2
			tween(holder, 0.18, { Size = Vector3.new(a / 0.44, 0.05, a / 0.44) })
			tween(image, 0.5, { ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			Pool.holderLater(holder, 0.55)
			return
		end
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

-- Meteor: a burning rock falls on the point, then the impact. S115: `bare` = only the falling rock (the skill's entry
-- lists its own landing pieces, SkillVfx landsAfter).
function Library.meteor(at: Vector3, radius: number, delay: number, color: Color3, simple: boolean?, bare: boolean?)
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
		if Textures.particle(e, "fire") then -- S112: a burning tail of looping flames
			e.Rate = 40
			e.Size = NumberSequence.new({ kp(0, 2.6), kp(1, 1) })
			e.Rotation = NumberRange.new(0, 360)
		end
		e.Parent = rock
		Clock.track(e)
		light(rock, color, 16, 2)
	end
	-- S115: a fall shorter than 0.2 s (a wave's rock) starts lower, so it still reads as a fall
	local fall = if bare then math.max(0.08, delay) else math.max(0.2, delay)
	if fall < 0.2 then
		rock.CFrame = CFrame.new(landing + Vector3.new(-6, 16, -3))
	end
	tween(rock, fall, { CFrame = CFrame.new(landing) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Clock.after(fall, function()
		Pool.release(rock)
		if bare then
			return
		end
		Library.smokePuff(landing, math.clamp(radius * 0.4, 1, 3), DUST_COLOR, { simple = simple }) -- S112
		Library.burst(landing + Vector3.new(0, 1, 0), radius * 1.2, color, 0.4, simple)
		Library.shockwave(landing, radius, color, 0.45, simple)
		if not simple then
			Library.cracks(landing, radius * 0.8, color, 1.6, simple)
		end
	end)
end

-- A straight beam (heals reaching the target, charge streak). S112: a camera-facing Beam with the texture of
-- opts.key (default beamHoly) flowing from a to b, narrowing as it fades.
function Library.beam(a: Vector3, b: Vector3, color: Color3, width: number?, seconds: number?, opts: { key: string? }?)
	local s = seconds or 0.3
	local key = if opts and opts.key then opts.key else "beamHoly"
	local length = (b - a).Magnitude
	local holder = if Textures.id(key) and length > 0.1 then Pool.holder("beam", key) else nil
	local w = (width or 0.35) * 3
	local ray = if holder then setupBeam(holder, color, w, true, true) else nil
	if holder and ray then
		local a0, a1 = attachments(holder)
		holder.CFrame = CFrame.lookAt(a, b)
		a0.CFrame = CFrame.new()
		a1.CFrame = CFrame.new(0, 0, -length)
		Textures.beam(ray, key, { speed = 8, length = w * 2 })
		fadeBeam(ray, 0.05, 1, s)
		local started = Clock.now()
		animate(function(now: number): boolean
			local u = math.clamp((now - started) / s, 0, 1)
			ray.Width0 = w * (1 - 0.8 * u)
			ray.Width1 = ray.Width0
			return u >= 1
		end)
		Pool.holderLater(holder, s + 0.05)
		return
	end
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
	local started = Clock.now()
	local ends = started + seconds
	local phase = 0
	local last = started
	place()
	connection = RunService.Heartbeat:Connect(function()
		local now = Clock.now()
		if now >= ends then
			stop()
			return
		end
		-- S115: the line pulses faster as the aim runs out (6 -> 22 rad/s)
		local u = math.clamp((now - started) / math.max(0.1, seconds), 0, 1)
		phase += (now - last) * (6 + 16 * u * u)
		last = now
		p.Transparency = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(phase))
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
		angle += Clock.dt(dt) * 0.8
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

-- S80 (ROZWOJ 12.5): Arcane Charges, `count` small glowing orbs circling the chest of a character (one turn in about
-- 2 s). Returns the cleanup.
local ORBIT_RADIUS = 2.2
local ORBIT_TURN = 2
local ORBIT_SIZE = 0.35
function Library.orbit(model: Model, count: number, color: Color3, simple: boolean?): () -> ()
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root or count <= 0 then
		return function() end
	end
	local orbs: { BasePart } = {}
	for _ = 1, count do
		local orb = Pool.part("Ball", color, Vector3.one * ORBIT_SIZE, Enum.Material.Neon, 0.1)
		if not simple then
			light(orb, color, 4, 0.6)
			-- S112 D1: a soft glow halo carried by the orb (the neon ball alone without the texture)
			local e = Instance.new("ParticleEmitter")
			if Textures.particle(e, "glow") then
				e.Color = ColorSequence.new(color)
				e.LockedToPart = true
				e.Rate = 10
				e.Lifetime = NumberRange.new(0.25, 0.35)
				e.Speed = NumberRange.new(0)
				e.Size = NumberSequence.new(ORBIT_SIZE * 3, ORBIT_SIZE * 2)
				e.Transparency = NumberSequence.new(0.4, 1)
				e.Parent = orb
				Clock.track(e)
			else
				e:Destroy()
			end
		end
		table.insert(orbs, orb)
	end
	local angle = 0
	local connection = RunService.Heartbeat:Connect(function(dt: number)
		if not root.Parent then
			return
		end
		angle += Clock.dt(dt) * math.pi * 2 / ORBIT_TURN
		local centreAt = root.Position + Vector3.new(0, 0.6, 0)
		for i, orb in orbs do
			local a = angle + (i - 1) / count * math.pi * 2
			orb.CFrame = CFrame.new(centreAt + Vector3.new(math.cos(a) * ORBIT_RADIUS, 0, math.sin(a) * ORBIT_RADIUS))
		end
	end)
	local done = false
	return function()
		if done then
			return
		end
		done = true
		connection:Disconnect()
		for _, orb in orbs do
			tween(orb, 0.25, { Transparency = 1 })
			Pool.later(orb, 0.3)
		end
	end
end

-- Afterimages along a dash. S114: `key` = the texture of the streak along the ground (default beamHoly).
function Library.dash(a: Vector3, b: Vector3, color: Color3, simple: boolean?, key: string?)
	local count = if simple then 2 else 5
	for i = 1, count do
		local u = i / (count + 1)
		local ghost = Pool.part("Block", color, Vector3.new(2, 4.5, 0.8), Enum.Material.Neon, 0.55)
		ghost.CFrame = CFrame.lookAt(a:Lerp(b, u), b)
		tween(ghost, 0.35 + u * 0.2, { Transparency = 1 })
		Pool.later(ghost, 0.6)
	end
	Library.beam(a, b, color, 0.6, 0.35, if key then { key = key } else nil)
end

-- Dust puff at the feet (landings, slams).
local function dustParts(at: Vector3, size: number, low: boolean?)
	local holder = Pool.part("Block", Color3.new(1, 1, 1), Vector3.one, Enum.Material.Neon, 1)
	holder.CFrame = CFrame.new(ground(at) + Vector3.new(0, 0.3, 0))
	emit(holder, DUST_COLOR, math.floor(10 * size), {
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

-- S112 E4: smoke or dust rising and spreading (a trail layer): 3-5 particles of the smoke flipbook (the whole
-- sequence over a particle's life), lit by the scene. Without the texture: the old dust.
function Library.smokePuff(at: Vector3, size: number, color: Color3, opts: FxOpts?)
	local o: FxOpts = opts or {}
	local holder = textured(o.key or "smoke", CFrame.new(ground(at) + Vector3.new(0, 0.6 * size, 0)))
	if not holder then
		dustParts(at, size, o.simple)
		return
	end
	burstFrom(holder, o.key or "smoke", color, o.count or rng:NextInteger(3, 5), {
		simple = o.simple,
		spread = 60,
		speedMin = 1,
		speedMax = 3,
		accel = Vector3.new(0, 1.5, 0),
		drag = 0.5,
		lifeMin = 0.9,
		lifeMax = 1.3,
		rotation = NumberRange.new(0, 360),
		rotSpeed = NumberRange.new(-30, 30),
		sizeSeq = NumberSequence.new({ kp(0, 0.6 * size), kp(1, 2.2 * size) }),
		transparency = NumberSequence.new({ kp(0, 0.3), kp(1, 1) }),
		area = Vector3.new(size, 0.2, size),
		emission = 0,
	})
end

-- W03: the body of a fire spell's blow: a ball of flame bursting outwards (white-hot heart, orange, dying deep red),
-- dark smoke rolling up after it and embers thrown out in arcs. Without the fire texture a plain burst.
function Library.fireBlast(at: Vector3, size: number, color: Color3, opts: FxOpts?)
	local o: FxOpts = opts or {}
	local fire = textured("fire", CFrame.new(at + Vector3.new(0, 0.6 * size, 0)))
	if not fire then
		Library.burst(at, size * 2, color, 0.4, o.simple)
		return
	end
	-- gold-orange to deep red (anything paler turns white under the bloom and reads as steam)
	burstFrom(fire, "fire", color:Lerp(Color3.fromHex("#FFC24A"), 0.35), 16, {
		simple = o.simple,
		to = color:Lerp(Color3.fromHex("#5A0A04"), 0.6),
		spread = 180,
		speedMin = 3 * size,
		speedMax = 9 * size,
		drag = 6,
		accel = Vector3.new(0, 6, 0),
		lifeMin = 0.35,
		lifeMax = 0.6,
		rotation = NumberRange.new(0, 360),
		rotSpeed = NumberRange.new(-90, 90),
		sizeSeq = NumberSequence.new({ kp(0, 1.2 * size), kp(0.35, 3.2 * size), kp(1, 0.8 * size) }),
		transparency = NumberSequence.new({ kp(0, 0.1), kp(0.55, 0.3), kp(1, 1) }),
		area = Vector3.one * size,
		emission = 0.7,
		brightness = 0.8,
	})
	local smoke = textured("smoke", CFrame.new(at + Vector3.new(0, 1.2 * size, 0)))
	if smoke then
		burstFrom(smoke, "smoke", Color3.fromHex("#2E2826"), 6, {
			simple = o.simple,
			to = Color3.fromHex("#6A625C"),
			spread = 70,
			speedMin = 2,
			speedMax = 5,
			accel = Vector3.new(0, 4, 0),
			drag = 1,
			lifeMin = 1,
			lifeMax = 1.6,
			rotation = NumberRange.new(0, 360),
			rotSpeed = NumberRange.new(-40, 40),
			sizeSeq = NumberSequence.new({ kp(0, 1.4 * size), kp(1, 4.2 * size) }),
			transparency = NumberSequence.new({ kp(0, 1), kp(0.15, 0.35), kp(1, 1) }),
			area = Vector3.one * size,
			emission = 0,
		})
	end
	local embers = textured("spark", CFrame.new(at + Vector3.new(0, 0.5, 0)))
	if embers then
		burstFrom(embers, "spark", color:Lerp(Color3.new(1, 1, 1), 0.3), 18, {
			simple = o.simple,
			to = color,
			spread = 75,
			speedMin = 14,
			speedMax = 28,
			accel = Vector3.new(0, -35, 0),
			drag = 1.5,
			lifeMin = 0.4,
			lifeMax = 0.9,
			orient = "parallel",
			sizeSeq = NumberSequence.new({ kp(0, 0.22), kp(1, 0.06) }),
			transparency = NumberSequence.new({ kp(0, 0), kp(0.8, 0.2), kp(1, 1) }),
		})
	end
end

-- W04: the body of an ice spell's blow, the frost twin of fireBlast: shards of ice thrown outwards and falling, a
-- cold mist rolling low (barely lit) and a few sharp glints. Without the ice texture a plain burst.
function Library.frostBlast(at: Vector3, size: number, color: Color3, opts: FxOpts?)
	local o: FxOpts = opts or {}
	local shards = textured("iceShard", CFrame.new(at + Vector3.new(0, 0.6 * size, 0)))
	if not shards then
		Library.burst(at, size * 2, color, 0.4, o.simple)
		return
	end
	burstFrom(shards, "iceShard", color:Lerp(Color3.new(1, 1, 1), 0.35), 14, {
		simple = o.simple,
		to = color,
		spread = 80,
		speedMin = 8 * size,
		speedMax = 18 * size,
		drag = 2,
		accel = Vector3.new(0, -30, 0),
		lifeMin = 0.45,
		lifeMax = 0.8,
		rotation = NumberRange.new(0, 360),
		rotSpeed = NumberRange.new(-240, 240),
		sizeSeq = NumberSequence.new({ kp(0, 0.7 * size), kp(1, 0.4 * size) }),
		transparency = NumberSequence.new({ kp(0, 0), kp(0.75, 0.15), kp(1, 1) }),
		area = Vector3.one * 0.6 * size,
		emission = 0.4,
	})
	local mist = textured("smoke", CFrame.new(ground(at) + Vector3.new(0, 0.5 * size, 0)))
	if mist then
		burstFrom(mist, "smoke", color:Lerp(Color3.new(1, 1, 1), 0.6), 6, {
			simple = o.simple,
			to = color,
			spread = 85,
			speedMin = 3,
			speedMax = 7,
			drag = 3,
			accel = Vector3.new(0, 0.5, 0),
			lifeMin = 0.9,
			lifeMax = 1.4,
			rotation = NumberRange.new(0, 360),
			rotSpeed = NumberRange.new(-30, 30),
			sizeSeq = NumberSequence.new({ kp(0, 1.6 * size), kp(1, 4 * size) }),
			transparency = NumberSequence.new({ kp(0, 1), kp(0.2, 0.45), kp(1, 1) }),
			area = Vector3.new(size, 0.2, size),
			emission = 0.25,
		})
	end
	local glints = textured("star", CFrame.new(at + Vector3.new(0, 0.8 * size, 0)))
	if glints then
		burstFrom(glints, "star", Color3.new(1, 1, 1), 5, {
			simple = o.simple,
			to = color,
			spread = 180,
			speedMin = 2,
			speedMax = 6,
			drag = 4,
			lifeMin = 0.25,
			lifeMax = 0.5,
			rotation = NumberRange.new(0, 360),
			sizeSeq = NumberSequence.new({ kp(0, 0.2), kp(0.3, 0.9 * size), kp(1, 0) }),
			area = Vector3.one * 1.5 * size,
			emission = 1,
		})
	end
end

-- W04: the body of a lightning spell's blow: two short arcs crackling out from the point to the ground round it,
-- with a spray of white-hot sparks (the lightning twin of fireBlast / frostBlast).
function Library.arcBurst(at: Vector3, size: number, color: Color3, opts: FxOpts?)
	local o: FxOpts = opts or {}
	local count = if o.simple then 1 else 2 -- Config.Vfx.perCast.beams: a skill may hold 3 beams at once
	local from = at + Vector3.new(0, 0.6 * size, 0)
	for i = 1, count do
		local ang = (i / count + rng:NextNumber(-0.1, 0.1)) * math.pi * 2
		local reach = rng:NextNumber(2.5, 4.5) * size
		local to = ground(at + Vector3.new(math.cos(ang) * reach, 0, math.sin(ang) * reach)) + Vector3.new(0, 0.1, 0)
		Clock.after((i - 1) * 0.03, function()
			Library.lightning(from, to, color:Lerp(Color3.new(1, 1, 1), 0.35), 0.15 * size, o.simple)
		end)
	end
	local sparks = textured("spark", CFrame.new(from))
	if sparks then
		burstFrom(sparks, "spark", Color3.new(1, 1, 1), 14, {
			simple = o.simple,
			to = color,
			spread = 180,
			speedMin = 12,
			speedMax = 26,
			drag = 3,
			accel = Vector3.new(0, -20, 0),
			lifeMin = 0.15,
			lifeMax = 0.35,
			orient = "parallel",
			sizeSeq = NumberSequence.new({ kp(0, 0.18), kp(1, 0.04) }),
			transparency = NumberSequence.new({ kp(0, 0), kp(1, 1) }),
			emission = 1,
		})
	end
end

-- W05: the body of a blow into the ground: rock chips thrown up and falling back, a ring of dust rolling outwards
-- over `radius` and a low cloud at the centre. `color` tints the dust a little (the class colour); the chips stay stone.
local ROCK = Color3.fromHex("#5E5246")
function Library.rockBurst(at: Vector3, radius: number, size: number, color: Color3, opts: FxOpts?)
	local o: FxOpts = opts or {}
	local base = ground(at)
	local dustTint = DUST_COLOR:Lerp(color, 0.12)
	local chips = textured("debris", CFrame.new(base + Vector3.new(0, 0.4, 0)))
	if chips then
		burstFrom(chips, "debris", ROCK:Lerp(Color3.new(1, 1, 1), 0.15), math.floor(14 * size), {
			simple = o.simple,
			to = ROCK,
			spread = 55,
			speedMin = 9 * size,
			speedMax = 20 * size,
			accel = Vector3.new(0, -55, 0),
			drag = 0.6,
			lifeMin = 0.55,
			lifeMax = 0.95,
			rotation = NumberRange.new(0, 360),
			rotSpeed = NumberRange.new(-400, 400),
			sizeSeq = NumberSequence.new({ kp(0, 0.75 * size, 0.3 * size), kp(1, 0.55 * size, 0.2 * size) }),
			transparency = NumberSequence.new({ kp(0, 0), kp(0.8, 0), kp(1, 1) }),
			area = Vector3.new(radius * 0.3, 0.2, radius * 0.3),
			emission = 0,
		})
	end
	-- the dust ring: a ground image growing to the radius while it thins out
	local lift = base + Vector3.new(0, SURFACE_LIFT + 0.03, 0)
	local holder, image = surfaceAt(
		"dustRing",
		CFrame.new(lift) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0),
		radius * 0.4,
		dustTint
	)
	if holder and image then
		image.ImageTransparency = 0.05
		local s = 0.7
		tween(
			holder,
			s,
			{ Size = Vector3.new(radius * 2.3, 0.05, radius * 2.3) },
			Enum.EasingStyle.Quart,
			Enum.EasingDirection.Out
		)
		tween(image, s, { ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Pool.holderLater(holder, s + 0.05)
	elseif not o.simple then
		Library.shockwave(at, radius, dustTint, 0.5, true)
	end
	-- a low cloud rolling out from the centre
	local cloud = textured("smoke", CFrame.new(base + Vector3.new(0, 0.5, 0)))
	if cloud then
		burstFrom(cloud, "smoke", dustTint, if o.simple then 3 else 6, {
			simple = o.simple,
			spread = 80,
			speedMin = radius * 0.8,
			speedMax = radius * 1.6,
			drag = 3,
			accel = Vector3.new(0, 1.2, 0),
			lifeMin = 0.8,
			lifeMax = 1.3,
			rotation = NumberRange.new(0, 360),
			rotSpeed = NumberRange.new(-40, 40),
			sizeSeq = NumberSequence.new({ kp(0, 1.4 * size), kp(1, 3.6 * size) }),
			transparency = NumberSequence.new({ kp(0, 0.35), kp(1, 1) }),
			area = Vector3.new(1, 0.2, 1),
			emission = 0,
		})
	end
end

-- W05: a war cry / a shout: a flare of rays at the chest, two rings of force running out over the ground one after the
-- other and a few embers thrown up.
function Library.warCry(at: Vector3, radius: number, color: Color3, opts: FxOpts?)
	local o: FxOpts = opts or {}
	local flare = textured("rays", CFrame.new(at + Vector3.new(0, 0.5, 0)))
	if flare then
		burstFrom(flare, "rays", color:Lerp(Color3.new(1, 1, 1), 0.25), 1, {
			exact = true,
			to = color,
			lifeMin = 0.35,
			lifeMax = 0.35,
			rotation = NumberRange.new(0, 360),
			rotSpeed = NumberRange.new(-60, 60),
			sizeSeq = NumberSequence.new({ kp(0, 2), kp(0.3, 7), kp(1, 9) }),
			transparency = NumberSequence.new({ kp(0, 0.1), kp(0.4, 0.3), kp(1, 1) }),
			zOffset = 1,
			emission = 1,
		})
	end
	ringSurface(at, radius * 0.7, color, 0.35)
	Clock.after(0.12, function()
		ringSurface(at, radius, color, 0.45)
	end)
	if not o.simple then
		local embers = textured("spark", CFrame.new(at))
		if embers then
			burstFrom(embers, "spark", color:Lerp(Color3.new(1, 1, 1), 0.3), 10, {
				simple = o.simple,
				to = color,
				spread = 70,
				speedMin = 8,
				speedMax = 16,
				drag = 2,
				accel = Vector3.new(0, -6, 0),
				lifeMin = 0.4,
				lifeMax = 0.7,
				orient = "parallel",
				sizeSeq = NumberSequence.new({ kp(0, 0.25), kp(1, 0.05) }),
				transparency = NumberSequence.new({ kp(0, 0), kp(1, 1) }),
				area = Vector3.new(2, 1, 2),
				emission = 1,
			})
		end
	end
end

-- W05: a whirlwind of blades: the full swoosh round the body plus a spiral of wind on the ground turning as it grows.
function Library.whirl(origin: CFrame, radius: number, color: Color3, simple: boolean?, key: string?)
	Library.slash(origin, radius, 180, -180, color, 0, simple, key)
	local base = ground(origin.Position) + Vector3.new(0, SURFACE_LIFT + 0.04, 0)
	local holder, image = surfaceAt("swirl", CFrame.new(base), radius * 1.2, color:Lerp(Color3.new(1, 1, 1), 0.2))
	if not holder or not image then
		return
	end
	image.ImageTransparency = 0.25
	local s = 0.45
	local turn = rng:NextNumber(0, math.pi * 2)
	holder.CFrame = CFrame.new(base) * CFrame.Angles(0, turn, 0)
	tween(holder, s, {
		Size = Vector3.new(radius * 2.2, 0.05, radius * 2.2),
		CFrame = CFrame.new(base) * CFrame.Angles(0, turn - math.pi * 0.9, 0),
	}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	tween(image, s, { ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Pool.holderLater(holder, s + 0.05)
end

-- W07: holy light: rays opening behind the point, motes of light rising slowly and a soft ring on the ground. The
-- body of the Cleric's heals and blessings (`size` 1 = a person).
function Library.holyBurst(at: Vector3, size: number, color: Color3, opts: FxOpts?)
	local o: FxOpts = opts or {}
	local flare = textured("rays", CFrame.new(at + Vector3.new(0, 0.6 * size, 0)))
	if flare then
		burstFrom(flare, "rays", color:Lerp(Color3.new(1, 1, 1), 0.35), 1, {
			exact = true,
			to = color,
			lifeMin = 0.5,
			lifeMax = 0.5,
			rotation = NumberRange.new(0, 360),
			rotSpeed = NumberRange.new(-25, 25),
			sizeSeq = NumberSequence.new({ kp(0, 1.5 * size), kp(0.35, 6 * size), kp(1, 7 * size) }),
			transparency = NumberSequence.new({ kp(0, 0.2), kp(0.5, 0.35), kp(1, 1) }),
			zOffset = 0.5,
			emission = 1,
		})
	end
	local motes = textured("glow", CFrame.new(ground(at) + Vector3.new(0, 0.5, 0)))
	if motes then
		burstFrom(motes, "glow", color:Lerp(Color3.new(1, 1, 1), 0.4), math.floor(10 * size), {
			simple = o.simple,
			to = color,
			spread = 25,
			speedMin = 2,
			speedMax = 5,
			drag = 0.8,
			accel = Vector3.new(0, 1.5, 0),
			lifeMin = 0.9,
			lifeMax = 1.5,
			sizeSeq = NumberSequence.new({ kp(0, 0), kp(0.2, 0.5 * size, 0.2 * size), kp(1, 0) }),
			transparency = NumberSequence.new({ kp(0, 0.1), kp(1, 1) }),
			area = Vector3.new(2.2 * size, 0.3, 2.2 * size),
			emission = 1,
		})
	end
	ringSurface(at, 2.2 * size, color, 0.5)
end

-- W06: leaves whirled up from the ground and fluttering down (the Hunter's traps, camouflage, nature shots).
local LEAF_GREEN = Color3.fromHex("#7FA04A")
function Library.leafBurst(at: Vector3, size: number, color: Color3, opts: FxOpts?)
	local o: FxOpts = opts or {}
	local leaves = textured("leaf", CFrame.new(ground(at) + Vector3.new(0, 0.5, 0)))
	if not leaves then
		return
	end
	burstFrom(leaves, "leaf", LEAF_GREEN:Lerp(color, 0.25), math.floor(10 * size), {
		simple = o.simple,
		to = LEAF_GREEN:Lerp(Color3.fromHex("#C9A45A"), 0.4),
		spread = 50,
		speedMin = 6 * size,
		speedMax = 12 * size,
		drag = 2.5,
		accel = Vector3.new(0, -5, 0),
		lifeMin = 1,
		lifeMax = 1.7,
		rotation = NumberRange.new(0, 360),
		rotSpeed = NumberRange.new(-260, 260),
		sizeSeq = NumberSequence.new({ kp(0, 0.5 * size, 0.15 * size), kp(1, 0.45 * size, 0.15 * size) }),
		transparency = NumberSequence.new({ kp(0, 0), kp(0.8, 0), kp(1, 1) }),
		area = Vector3.new(1.5 * size, 0.3, 1.5 * size),
		emission = 0,
	})
end

-- Dust puff at the feet (landings, slams). S112: with the smoke texture a smoke puff in the dust colour and a burst of
-- the dust texture.
function Library.dust(at: Vector3, size: number, low: boolean?)
	if not Textures.id("smoke") then
		dustParts(at, size, low)
		return
	end
	Library.smokePuff(at, size, DUST_COLOR, { simple = low })
	local holder = textured("dust", CFrame.new(ground(at) + Vector3.new(0, 0.3, 0)))
	if holder then
		burstFrom(holder, "dust", DUST_COLOR, math.floor(6 * size), {
			simple = low,
			spread = 70,
			speedMin = 3,
			speedMax = 8 * size,
			drag = 2,
			size = 1.6 * size,
			sizeEnd = 0.4 * size,
			lifeMin = 0.4,
			lifeMax = 0.9,
			accel = Vector3.new(0, -4, 0),
			rotation = NumberRange.new(0, 360),
			emission = 0,
		})
	end
end

-- S112 E2: a trail layer of sparks or splinters flying from a blow along opts.dir (default up): key opts.key or
-- "spark" (S113: by the target's material, Data/HitFx: `speed`, `life`, `gravity`), streaks along their flight for spark /
-- darkSpark.
-- Without the texture the same emitter with the default particle; in a ViewportFrame (skills window) small neon parts.
function Library.sparks(at: Vector3, color: Color3, opts: FxOpts?)
	local o: FxOpts = opts or {}
	local key = o.key or "spark"
	local dir = if o.dir and o.dir.Magnitude > 0.01 then o.dir.Unit else Vector3.yAxis
	if Pool.inViewport() then
		for _ = 1, if o.simple then 3 else 6 do
			local jitter = Vector3.new(rng:NextNumber(-0.6, 0.6), rng:NextNumber(-0.6, 0.6), rng:NextNumber(-0.6, 0.6))
			local way = (dir + jitter).Unit
			local bit = Pool.part("Block", color, Vector3.new(0.08, 0.08, 0.5), Enum.Material.Neon, 0.1)
			bit.CFrame = CFrame.lookAt(at, at + way)
			tween(bit, 0.3, { CFrame = CFrame.lookAt(at + way * 3, at + way * 4), Transparency = 1 })
			Pool.later(bit, 0.35)
		end
		return
	end
	local holder = Pool.holder("emitter", key)
	if not holder then
		return
	end
	holder.CFrame = facingFrame(at, dir)
	local streak = key == "spark" or key == "darkSpark"
	burstFrom(holder, key, color, o.count or 8, {
		simple = o.simple,
		direction = Enum.NormalId.Front,
		spread = 35,
		speedMin = if o.speed then o.speed[1] else 10,
		speedMax = if o.speed then o.speed[2] else 22,
		accel = Vector3.new(0, -(o.gravity or 40), 0),
		drag = 3,
		lifeMin = if o.life then o.life[1] else 0.18,
		lifeMax = if o.life then o.life[2] else 0.4,
		orient = if streak then "parallel" else nil,
		sizeSeq = NumberSequence.new({ kp(0, 0.215, 0.065), kp(1, 0.13, 0.04) }),
		transparency = NumberSequence.new({ kp(0, 0), kp(0.7, 0.2), kp(1, 1) }),
		rotation = if streak then nil else NumberRange.new(0, 360),
	})
end

-- Glowing hand(s) or weapon for `seconds` (charging a spell, holy weapons).
function Library.glow(
	model: Model,
	hand: "r" | "l" | "both" | "weapon",
	color: Color3,
	seconds: number,
	simple: boolean?,
	flame: boolean? -- W03: fire spells lick flames over the hand
)
	local names: { string } = if hand == "weapon"
		then { "VaelthornWeapon" }
		elseif hand == "both" then { "RightHand", "LeftHand" }
		elseif hand == "l" then { "LeftHand" }
		else { "RightHand" }
	for _, name in names do
		local part = model:FindFirstChild(name, true)
		if part and part:IsA("BasePart") then
			-- W03: a small white-hot core instead of a big flat disc of colour; the colour lives in the particles
			-- (a fire spell keeps its orange: bloom turns any pale neon to white)
			local orb = Pool.part(
				"Ball",
				if flame then color else color:Lerp(Color3.new(1, 1, 1), 0.25),
				Vector3.one * (if flame then 0.3 else 0.4),
				Enum.Material.Neon,
				if flame then 0.35 else 0.2
			)
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
				e.Transparency = NumberSequence.new(if flame then 0.6 else 0.2, 1)
				if Textures.particle(e, "glow") then -- S112
					e.Size = NumberSequence.new(if flame then 0.45 else 0.7, 0)
				end
				e.Parent = orb
				Clock.track(e)
				-- W03: motes drawn in from all round towards the hand while the spell gathers
				local motes = Instance.new("ParticleEmitter")
				motes.Shape = Enum.ParticleEmitterShape.Sphere
				motes.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
				motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
				motes.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.3), color)
				motes.LightEmission = 1
				motes.Rate = 36
				motes.Lifetime = NumberRange.new(0.25, 0.35)
				motes.Speed = NumberRange.new(5, 7)
				motes.Size = NumberSequence.new({ kp(0, 0.05), kp(0.5, 0.22), kp(1, 0.05) })
				motes.Transparency = NumberSequence.new({ kp(0, 1), kp(0.3, 0.1), kp(1, 0.4) })
				Textures.particle(motes, "spark")
				motes.Orientation = Enum.ParticleOrientation.VelocityParallel
				motes.Parent = orb
				Clock.track(motes)
				if flame then
					local f = Instance.new("ParticleEmitter")
					f.Color = ColorSequence.new({
						ColorSequenceKeypoint.new(0, color:Lerp(Color3.new(1, 1, 1), 0.25)),
						ColorSequenceKeypoint.new(0.5, color),
						ColorSequenceKeypoint.new(1, color:Lerp(Color3.new(0.2, 0, 0), 0.6)),
					})
					f.LightEmission = 1
					f.Rate = 22
					f.Lifetime = NumberRange.new(0.25, 0.4)
					f.Speed = NumberRange.new(0.5, 1.2)
					f.Acceleration = Vector3.new(0, 5, 0)
					f.Rotation = NumberRange.new(0, 360)
					f.RotSpeed = NumberRange.new(-120, 120)
					f.Size = NumberSequence.new({ kp(0, 0.3), kp(0.4, 0.5), kp(1, 0.05) })
					f.Transparency = NumberSequence.new({ kp(0, 0.25), kp(0.7, 0.5), kp(1, 1) })
					if Textures.particle(f, "fire") then
						f.Parent = orb
						Clock.track(f)
					else
						f:Destroy()
					end
				end
			end
			tween(orb, seconds, { Size = Vector3.one * (if flame then 0.55 else 0.8) })
			detachLater(orb, seconds)
		end
	end
end

-- Options of a weapon trail (S113): `basic` = a basic attack's trail ("VaelthornTrail", Data/AttackMotions.TRAIL: from
-- `base` of the weapon's length to the tip, the streak texture narrowing to the base, the rarity colour fading to
-- white); without it the skill trail ("VaelthornSkillTrail", grip to tip) of S28 / S112. `lifetime` overrides.
export type TrailOpts = { basic: boolean?, base: number?, lifetime: number? }

-- The base attachment of a basic attack's trail: `share` of the way from the grip to the tip (made once per weapon,
-- moved when the share changes).
local function trailBase(weapon: BasePart, grip: Attachment, tip: Attachment, share: number): Attachment
	local base = weapon:FindFirstChild("VaelthornTrailBase")
	local at = grip.Position + (tip.Position - grip.Position) * share
	if base and base:IsA("Attachment") then
		if (base.Position - at).Magnitude > 1e-3 then
			base.Position = at
		end
		return base
	end
	local created = Instance.new("Attachment")
	created.Name = "VaelthornTrailBase"
	created.Position = at
	created.Parent = weapon
	return created
end

-- Weapon trail of the held weapon, from..to seconds after now (S28 skills, S113 basic attacks: TrailOpts).
function Library.weaponTrail(model: Model, color: Color3, from: number, to: number, opts: TrailOpts?)
	local o: TrailOpts = opts or {}
	local weapon = model:FindFirstChild("VaelthornWeapon")
	if not weapon or not weapon:IsA("BasePart") then
		return
	end
	local grip = weapon:FindFirstChild("VaelthornGrip")
	local tip = weapon:FindFirstChild("VaelthornTip")
	if not grip or not tip or not grip:IsA("Attachment") or not tip:IsA("Attachment") then
		return
	end
	local basic = o.basic == true
	local spec = AttackMotions.TRAIL
	local name = if basic then "VaelthornTrail" else "VaelthornSkillTrail"
	local start: Attachment = if basic then trailBase(weapon, grip, tip, o.base or spec.base) else grip
	local trail = weapon:FindFirstChild(name) :: Trail?
	if not trail then
		local created = Instance.new("Trail")
		created.Name = name
		created.Attachment1 = tip
		created.MinLength = 0.05
		created.Enabled = false
		created.Parent = weapon
		trail = created
	end
	local t = Clock.track(trail :: Trail)
	t.Attachment0 = start
	if basic then
		t.Lifetime = o.lifetime or spec.lifetime
		t.LightEmission = 0.8
		t.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
		if Textures.trail(t, spec.key) then
			t.LightInfluence = 0.2
			t.WidthScale = NumberSequence.new(spec.widthTip, spec.widthBase)
			t.Transparency = NumberSequence.new(0, 1)
		else
			-- the look before S113: white-ish streak fading out
			t.Texture = ""
			t.LightInfluence = 0
			t.WidthScale = NumberSequence.new(1)
			t.Transparency = NumberSequence.new(0.25, 1)
		end
	else
		t.Lifetime = o.lifetime or 0.22
		t.LightEmission = 0.9
		t.Transparency = NumberSequence.new(0.15, 1)
		t.Color = ColorSequence.new(color)
		-- S112: the streak texture narrowing towards the tail (the trail is reused: the texture may have been switched off)
		if Textures.trail(t, "trailStreak") then
			t.WidthScale = NumberSequence.new(1, 0.3)
		else
			t.Texture = ""
			t.WidthScale = NumberSequence.new(1)
		end
	end
	Clock.after(math.max(0, from), function()
		if t.Parent then
			t.Enabled = true
		end
	end)
	Clock.after(math.max(from + 0.05, to), function()
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
		-- S112: flames, ice shards or poison bubbles (flipbook) instead of the default particle
		local key = if kind == "burn" then "fire" elseif kind == "frost" then "iceShard" else "poisonBubble"
		if key == "poisonBubble" and Textures.id(key) then
			e.Lifetime = NumberRange.new(0.7, 1.1) -- the bubble's whole flipbook plays over this life
		end
		if Textures.particle(e, key) then
			e.Rotation = NumberRange.new(0, 360)
			if kind == "burn" then
				e.Size = NumberSequence.new({ kp(0, 1.4), kp(1, 0.5) })
			elseif kind == "frost" then
				e.Size = NumberSequence.new({ kp(0, 0.6), kp(1, 0.2) })
				e.RotSpeed = NumberRange.new(-90, 90)
			else
				e.Size = NumberSequence.new({ kp(0, 0.9), kp(1, 1.1) })
				e.Rotation = NumberRange.new(0)
			end
		end
		e.Parent = disc
		Clock.track(e)
		light(disc, tint, radius * 2 + 4, 1)
	end
	Clock.after(seconds, function()
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
		local started = Clock.now()
		connection = RunService.Heartbeat:Connect(function()
			local t = Clock.now() - started
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
-- S114: `key` = a beam texture flowing along the line (Vfx/Textures; the plain line without it).
function Library.tether(a: Model, b: Model, color: Color3, seconds: number, key: string?)
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
	if key and Textures.beam(beam, key, { speed = 4, length = 2 }) then
		beam.Width0 = 0.3
		beam.Width1 = 0.3
	end
	beam.Parent = rootA
	Clock.track(beam)
	local function clear()
		beam:Destroy()
		from:Destroy()
		to:Destroy()
	end
	local ending = Clock.now() + math.max(0.3, seconds)
	task.spawn(function()
		while Clock.now() < ending and rootA.Parent and rootB.Parent and beam.Parent do
			task.wait(0.2)
		end
		clear()
	end)
end

-- S114 (Shield Wall): a half ring of see-through tower shields on the radius in front of `frame` (its look), rising
-- out of the ground in 0.15 s, held, then sinking and fading (6 shields, 3 when simple). Pooled parts only.
local SHIELD_SIZE = Vector3.new(2.4, 3.4, 0.35)

function Library.shieldArc(frame: CFrame, radius: number, color: Color3, simple: boolean?)
	local count = if simple then 3 else 6
	local base = ground(frame.Position)
	local rise, hold, sink = 0.15, 0.55, 0.3
	for i = 1, count do
		-- from -80 to +80 degrees around the look, the shields facing outwards
		local yaw = math.rad(-80 + 160 * (i - 1) / math.max(1, count - 1))
		local dir = (frame.Rotation * CFrame.Angles(0, yaw, 0)).LookVector
		local spot = base + Vector3.new(dir.X, 0, dir.Z).Unit * radius
		local up = CFrame.lookAt(spot + Vector3.new(0, SHIELD_SIZE.Y / 2, 0), spot + Vector3.new(dir.X, 0, dir.Z) * 2)
		local down = up - Vector3.new(0, SHIELD_SIZE.Y, 0)
		local shield = Pool.part("Block", color, SHIELD_SIZE, Enum.Material.ForceField, 0.15)
		shield.CFrame = down
		tween(shield, rise, { CFrame = up }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		Clock.after(rise + hold, function()
			tween(shield, sink, { CFrame = down, Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end)
		Pool.later(shield, rise + hold + sink + 0.05)
	end
end

-- S114 (Guardian Angel): two wings of light spreading behind a character's back for `seconds` (wedges welded to the
-- root, a soft glow shed from them when not simple), then fading.
local WING_SIZE = Vector3.new(0.2, 3.6, 2.6)

function Library.wings(model: Model, color: Color3, seconds: number, simple: boolean?)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	for _, side in { -1, 1 } do
		local wing = Pool.part("Wedge", color, WING_SIZE, Enum.Material.Neon, 0.35)
		local folded = CFrame.new(side * 0.6, 1.2, 0.7) * CFrame.Angles(0, math.rad(side * 15), 0)
		local spread = CFrame.new(side * 1.6, 1.6, 0.9) * CFrame.Angles(0, math.rad(side * 70), math.rad(-side * 25))
		wing.Anchored = false
		wing.Massless = true
		wing.CFrame = root.CFrame * folded
		local weld = Instance.new("Weld")
		weld.Part0 = root
		weld.Part1 = wing
		weld.C0 = folded
		weld.Parent = wing
		Clock.tween(weld, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { C0 = spread })
		if not simple then
			local e = Instance.new("ParticleEmitter")
			e.Color = ColorSequence.new(color)
			e.LightEmission = 1
			e.Rate = 10
			e.Lifetime = NumberRange.new(0.5, 0.9)
			e.Speed = NumberRange.new(0.5, 1.5)
			e.Acceleration = Vector3.new(0, -2, 0)
			e.Size = NumberSequence.new(0.5, 0)
			e.Transparency = NumberSequence.new(0.2, 1)
			Textures.particle(e, "feather")
			e.Parent = wing -- goes with the wing when the pool takes it back
			Clock.track(e)
		end
		detachLater(wing, math.max(0.3, seconds))
	end
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
local FALCON_REACH = 0.06 -- S115: seconds from beside the target to it (the damage came with the event)

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
	local born = Clock.now()
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
			leaving = { from = position, start = Clock.now() }
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
		local t = Clock.now()
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
			keepUntil = math.max(keepUntil, Clock.now() + seconds)
		end,
		strike = function(target: Model?, dive: boolean)
			if finished or leaving or not target or not target.Parent then
				return
			end
			local function at(): Vector3?
				return if target.Parent then centre(target) + Vector3.new(0, 1, 0) else nil
			end
			local now = Clock.now()
			table.clear(legs)
			local start = position
			-- S115: the server deals the damage with the event and the controller flashes the core then; the bird
			-- appears right by the target (a dive just above it) and reaches it within FALCON_REACH, its claws a trail
			local hitAt = at()
			if hitAt then
				local away = position - hitAt
				local side = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 1, 0)
				start = if dive then hitAt + Vector3.new(0, 6, 0) else hitAt + side * 2.5
				position = start
			end
			table.insert(legs, {
				from = start,
				to = at,
				start = now,
				dur = if dive then FALCON_REACH + 0.02 else FALCON_REACH,
				done = function()
					local hit = at()
					if not hit then
						return
					end
					local look = if heading.Magnitude > 0.01 then heading.Unit else Vector3.new(0, 0, -1)
					Library.slash(CFrame.lookAt(hit, hit + look), 2, 60, -60, color, 30, simple)
					-- S112: three feathers drifting down
					local feathers = textured("feather", CFrame.new(hit))
					if feathers then
						burstFrom(feathers, "feather", color:Lerp(Color3.new(1, 1, 1), 0.3), 3, {
							exact = true,
							speedMin = 3,
							speedMax = 6,
							drag = 2,
							accel = Vector3.new(0, -5, 0),
							lifeMin = 0.8,
							lifeMax = 1.2,
							size = 0.6,
							sizeEnd = 0.5,
							rotation = NumberRange.new(0, 360),
							rotSpeed = NumberRange.new(-120, 120),
							emission = 0,
						})
					end
				end,
			})
			table.insert(legs, {
				from = start,
				to = function(): Vector3?
					return circlePoint(Clock.now())
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

-- Owner 2026-10-21 ("boss and monster attacks plain and static: projectiles, particles, a blow that says wow") ------

-- The gathering of a blow on the caster for its windup: glowing motes drawn in from a sphere round it and a light
-- swelling to the blow. `size` ~ the caster's size (1 a man, 2-3 a boss).
function Library.charge(model: Model, color: Color3, seconds: number, size: number, simple: boolean?)
	local holder = Pool.part("Block", color, Vector3.one * (3.5 * size), Enum.Material.Neon, 1)
	if not attach(model, holder) then
		return
	end
	-- an imported model has its root at the feet: the gathering sits on the middle of the body
	local ok, box = pcall(function()
		return (model:GetBoundingBox())
	end)
	local weld = holder:FindFirstChildOfClass("WeldConstraint")
	if ok and typeof(box) == "CFrame" and weld then
		weld.Enabled = false
		holder.CFrame = CFrame.new(box.Position)
		weld.Enabled = true
	end
	if not simple then
		local e = Instance.new("ParticleEmitter")
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.4), color)
		e.LightEmission = 1
		e.Rate = 40 + 14 * size
		e.Lifetime = NumberRange.new(0.3, 0.5)
		e.Speed = NumberRange.new(4 * size, 6 * size)
		e.Size = NumberSequence.new({ kp(0, 0.12 * size), kp(0.6, 0.4 * size), kp(1, 0) })
		e.Transparency = NumberSequence.new({ kp(0, 1), kp(0.25, 0.05), kp(1, 0.5) })
		Textures.particle(e, "glow")
		e.Parent = holder
		Clock.track(e)
		Clock.after(math.max(0, seconds - 0.1), function()
			e.Enabled = false
		end)
	end
	local l = light(holder, color, 5 * size, 0.2)
	Clock.tween(
		l,
		TweenInfo.new(math.max(0.1, seconds), Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Brightness = 3, Range = 10 * size }
	)
	detachLater(holder, seconds)
end

-- Embers or motes rising from the whole danger area while it fills (the area is alive, not a flat circle).
function Library.dangerMotes(at: Vector3, radius: number, color: Color3, seconds: number, simple: boolean?)
	if simple or radius <= 0 then
		return
	end
	local base = ground(at)
	local side = math.max(1, radius * 1.5)
	local holder = Pool.part("Block", color, Vector3.new(side, 0.2, side), Enum.Material.Neon, 1)
	holder.CFrame = CFrame.new(base + Vector3.new(0, 0.25, 0))
	local e = Instance.new("ParticleEmitter")
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.EmissionDirection = Enum.NormalId.Top
	e.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.25), color)
	e.LightEmission = 0.9
	e.Rate = math.clamp(radius * radius * 0.8, 14, 80)
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(1.5, 4)
	e.Acceleration = Vector3.new(0, 5, 0)
	e.SpreadAngle = Vector2.new(12, 12)
	e.Size = NumberSequence.new({ kp(0, 0.5), kp(1, 0) })
	e.Transparency = NumberSequence.new({ kp(0, 0.1), kp(1, 1) })
	Textures.particle(e, "glow")
	e.Parent = holder
	Clock.track(e)
	Clock.after(math.max(0, seconds), function()
		e.Enabled = false
	end)
	Pool.later(holder, seconds + 1)
end

-- A volley from the caster to points spread over the area, every shot landing in the last `flight` seconds before
-- the blow (the last one exactly at it): orbs for a spell, rocks for a physical blow. `onLand` runs per shot.
function Library.volley(
	from: Vector3,
	at: Vector3,
	radius: number,
	count: number,
	windup: number,
	color: Color3,
	shape: Shape,
	simple: boolean?,
	onLand: ((point: Vector3) -> ())?
)
	local n = if simple then math.min(2, count) else count
	local flight = math.min(0.55, windup)
	local spread = math.min(0.45, windup - flight)
	for i = 1, n do
		-- a golden-angle spiral over the area: even cover, no randomness
		local a = i * 2.39996
		local d = radius * 0.75 * math.sqrt(i / n)
		local point = at + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
		local launch = windup - flight - spread * (1 - (i - 1) / math.max(1, n - 1))
		Clock.after(math.max(0, launch), function()
			Library.projectile(from, ground(point) + Vector3.new(0, 0.4, 0), shape, color, {
				simple = simple,
				time = flight,
				arc = 6 + radius * 0.4,
				size = if shape == "rock" then 2 else 1.8,
				flame = shape == "orb",
				onArrive = function(p: Vector3)
					Library.impactFlash(p, 2.2, color, { simple = simple })
					if onLand then
						onLand(p)
					end
				end,
			})
		end)
	end
end

-- Helpers for the controller
Library.flat = flat

return Library
