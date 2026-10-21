--!strict
-- W30 (walka-lm, docs/ANIMACJE.md §15): the Hunter's and the Mage's own skill pieces, so every skill of the two classes
-- has a shape of its own and reads in motion: motes spiralling into the hand while a spell gathers, a shock disc where
-- the shot leaves, arrows shot into the sky before a rain, stuck arrows quivering in the target, shock-ring tunnels,
-- traps that arm with beads and blinks and snap shut with steel teeth, crystals of ice bursting from the ground,
-- explosions with a white-hot core and shells, molten debris, forked lightning, arcs crawling over the struck, rifts of
-- a blink and of a meteor, arcane missiles curving to their target, nets, venom splashes, ghosts of a dash.
-- Data/LmVfxPieces describes every piece (layer, cost, phase); SkillVfx lists them (impact / trigger / strike as
-- usual, castFx, releaseFx, flight) and tunes them through `lmOpts`. Built from pooled parts (Vfx/Pool: neon, glass,
-- force field, a few textured holders of Library.kit) moved by the effect clock (Vfx/Clock), so AnimLab freezes them.
-- `simple` (far away or low quality) halves the parts and drops trails; the graphics level (W29, Logic/GraphicsLevel
-- `particles`) scales the counts. Looks only.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(script.Parent.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Library = require(script.Parent.Library)
local LmKit = require(script.Parent.LmKit)
local LmTypes = require(script.Parent.LmTypes)
local Pool = require(script.Parent.Pool)

type Ctx = LmTypes.Ctx
type Piece = LmTypes.Piece
type Flight = LmTypes.Flight
type Body = LmKit.Body

local kit = Library.kit
local kp = kit.kp
local tween = kit.tween
local ground = kit.ground
local centre = kit.centre

local rng = LmKit.rng
local WHITE = LmKit.WHITE
local WOOD = LmKit.WOOD
local STEEL = LmKit.STEEL
local ROCK = LmKit.ROCK
local ICE = LmKit.ICE
local SHADOW = LmKit.SHADOW
local NEON = LmKit.NEON
local FIELD = LmKit.FIELD
local GLASS = LmKit.GLASS
local amount = LmKit.amount
local part = LmKit.part
local fadeOut = LmKit.fadeOut
local trailOn = LmKit.trailOn
local sphereMesh = LmKit.sphereMesh
local discFrame = LmKit.discFrame
local facingDisc = LmKit.facingDisc
local unitOr = LmKit.unitOr
local over = LmKit.over
local ballistic = LmKit.ballistic
local randomRot = LmKit.randomRot
local spinVec = LmKit.spinVec
local shockDisc = LmKit.shockDisc
local jagged = LmKit.jagged
local segments = LmKit.segments
local forkBolt = LmKit.forkBolt
local arrowModel = LmKit.arrowModel

-- Where a piece aims from (the caster's centre) and the direction of the blow.
local function shotDir(ctx: Ctx): Vector3
	local from = if ctx.caster then centre(ctx.caster) else nil
	local to = ctx.aim or ctx.at
	if from and to then
		return unitOr(Library.flat(to - from), Vector3.new(0, 0, -1))
	end
	if ctx.frame then
		return ctx.frame.LookVector
	end
	return Vector3.new(0, 0, -1)
end

local pieces: { [string]: Piece } = {}
local flights: { [string]: Flight } = {}

-- Cast and release -------------------------------------------------------------------------------------------------

-- Motes spiralling into the gathering hand / tip over the gathering (`seconds`), a core swelling with a light, a pop
-- at the release. opts: count (motes), size, crackle (lightning: small arcs round the core), reach (start radius).
pieces.lmCharge = function(ctx: Ctx)
	local launch = ctx.launch
	if not launch then
		return
	end
	local o = ctx.opts
	local seconds = math.clamp(ctx.seconds, 0.15, 4)
	local size = (o.size or 1) * math.clamp(ctx.scale, 0.6, 1.8)
	local reach = (o.reach or 1.8) * size
	local count = amount(o.count or 4, ctx.simple)
	local color = ctx.color
	local core = part("Ball", color:Lerp(WHITE, 0.4), Vector3.one * 0.2, NEON, 0.55)
	core.CFrame = CFrame.new(launch())
	tween(core, seconds, { Size = Vector3.one * 0.9 * size, Transparency = 0.1 }, Enum.EasingStyle.Quad)
	if not ctx.simple then
		kit.flashLight(core, color, 10 * size, 1.6, seconds)
	end
	local motes: { { p: BasePart, axis: CFrame, phase: number } } = {}
	for i = 1, count do
		local mote = part("Ball", color:Lerp(WHITE, 0.3), Vector3.one * 0.22 * size, NEON, 0)
		mote.CFrame = core.CFrame
		if not ctx.simple then
			trailOn(mote, color, 0.18 * size, 0.18)
		end
		local axis = CFrame.Angles(rng:NextNumber(-1.2, 1.2), rng:NextNumber(0, 6.28), rng:NextNumber(-1.2, 1.2))
		table.insert(motes, { p = mote, axis = axis, phase = (i - 1) / count * math.pi * 2 })
	end
	local nextArc = 0
	over(seconds, function(u: number, t: number)
		local at = launch()
		core.CFrame = CFrame.new(at)
		-- the orbit tightens and quickens as the spell gathers
		local r = reach * (1 - u) ^ 1.4 + 0.12
		local angle = t * (6 + 16 * u)
		for _, m in motes do
			local local3 = Vector3.new(math.cos(angle + m.phase) * r, 0, math.sin(angle + m.phase) * r)
			m.p.CFrame = CFrame.new(at + m.axis:VectorToWorldSpace(local3))
		end
		if o.crackle and not ctx.simple and t >= nextArc then
			nextArc = t + 0.09
			local a = at + Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)).Unit * r
			segments(jagged(a, at, 3, 0.3), color, 0.06, 0.08, false)
		end
	end, function()
		for _, m in motes do
			Pool.release(m.p)
		end
		-- the release: the core pops
		fadeOut(core, 0.14, { Size = Vector3.one * 2.2 * size })
	end)
end

-- Where a shot leaves: a force-field disc rippling out across the line of fire, a forward spray of streaks, a puff of
-- the bow (or the crossbow's kick). opts: size, sparks (count), puff (a little dust).
pieces.lmMuzzle = function(ctx: Ctx)
	local at = ctx.at
	if not at then
		return
	end
	local o = ctx.opts
	local size = o.size or 1
	local dir = unitOr((ctx.aim or (at + shotDir(ctx))) - at, shotDir(ctx))
	shockDisc(facingDisc(at + dir * 0.4, dir), 0.3, 2.6 * size, ctx.color, 0.2)
	if not ctx.simple then
		shockDisc(facingDisc(at + dir * 1.1, dir), 0.2, 1.5 * size, ctx.color:Lerp(WHITE, 0.5), 0.14, 0.06)
	end
	local holder = kit.textured("spark", kit.facingFrame(at, dir))
	if holder then
		kit.burstFrom(holder, "spark", ctx.color:Lerp(WHITE, 0.5), o.sparks or 9, {
			simple = ctx.simple,
			to = ctx.color,
			direction = Enum.NormalId.Front,
			spread = 16,
			speedMin = 28,
			speedMax = 52,
			drag = 6,
			lifeMin = 0.08,
			lifeMax = 0.18,
			orient = "parallel",
			sizeSeq = NumberSequence.new({ kp(0, 0.22 * size), kp(1, 0.04) }),
			emission = 1,
		})
	end
	if o.puff and not ctx.simple then
		Library.smokePuff(at, 0.5 * size, Library.crackTint(ctx.color):Lerp(WHITE, 0.6), { simple = true })
	end
end

-- Arrows shot up into the sky from the bow before a rain falls (they fly on past the clouds and fade).
-- opts: count.
pieces.lmSkyVolley = function(ctx: Ctx)
	local at = ctx.at
	if not at then
		return
	end
	local aim = ctx.aim or at
	local count = amount(ctx.opts.count or 6, ctx.simple)
	local toward = Library.flat(aim - at) * 0.35
	for i = 1, count do
		Clock.after((i - 1) * 0.025, function()
			local top = at + toward + Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(34, 42), rng:NextNumber(-3, 3))
			Library.projectile(at, top, "arrow", ctx.color, {
				speed = 130,
				simple = ctx.simple,
				trail = "trailStreak",
				maxTime = 0.4,
			})
		end)
	end
	shockDisc(discFrame(at + Vector3.new(0, 0.6, 0)), 0.4, 3, ctx.color, 0.22)
end

-- Two motes winding round the shot's path, three turns, bursting where it lands (Heartseeker). The flight time is the
-- server's (Offense: 90 studs/s, at most Config.Vfx.shotMaxTime).
pieces.lmSpiral = function(ctx: Ctx)
	local at = ctx.at
	local aim = ctx.aim
	if not at or not aim then
		return
	end
	local target = ctx.target
	local distance = (aim - at).Magnitude
	local total = math.clamp(distance / 90, 0.05, Config.Vfx.shotMaxTime)
	local count = if ctx.simple then 1 else 2
	local turns = ctx.opts.turns or 3
	local radius = ctx.opts.radius or 0.8
	local motes: { BasePart } = {}
	for i = 1, count do
		local mote = part("Ball", ctx.color:Lerp(WHITE, 0.3), Vector3.one * 0.3, NEON, 0)
		mote.CFrame = CFrame.new(at)
		if not ctx.simple then
			trailOn(mote, ctx.color, 0.22, 0.25, "trailStreak")
		end
		motes[i] = mote
	end
	over(total, function(u: number)
		local goal = if target and target.Parent then centre(target) else aim
		local line = goal - at
		local frame = CFrame.lookAt(at, at + unitOr(line, Vector3.zAxis))
		local r = radius * math.sin(u * math.pi) + 0.1
		for i, mote in motes do
			local a = u * turns * math.pi * 2 + (i - 1) * math.pi
			mote.CFrame =
				CFrame.new(at + line * u + frame:VectorToWorldSpace(Vector3.new(math.cos(a), math.sin(a), 0)) * r)
		end
	end, function()
		for _, mote in motes do
			fadeOut(mote, 0.12, { Size = Vector3.one * 1.4 })
		end
	end)
end

-- Arcane missiles: `count` motes (3 + the charges spent) curving out to the sides and back in, all arriving with the
-- server's damage; onArrive once.
flights.lmMissiles = function(from: Vector3, target: Model | Vector3, color: Color3, o: LmTypes.FlightOpts)
	local function goal(): Vector3
		if typeof(target) == "Vector3" then
			return target
		end
		local m = target :: Model
		return if m.Parent then centre(m) else from
	end
	local distance = (goal() - from).Magnitude
	local total = math.clamp(distance / o.speed, 0.05, o.maxTime)
	local count = math.clamp(o.count or 3, 1, 7)
	if o.simple then
		count = math.min(count, 2)
	end
	local dir = unitOr(goal() - from, Vector3.zAxis)
	local side = unitOr(dir:Cross(Vector3.yAxis), Vector3.xAxis)
	local missiles: { { p: BasePart, bend: Vector3, lag: number } } = {}
	for i = 1, count do
		local share = if count > 1 then (i - 1) / (count - 1) * 2 - 1 else 0
		local bend = side * share * math.min(5, distance * 0.35) + Vector3.new(0, rng:NextNumber(0.5, 3), 0)
		local mote = part("Ball", color:Lerp(WHITE, 0.45), Vector3.one * 0.38 * o.size, NEON, 0)
		mote.CFrame = CFrame.new(from)
		if not o.simple then
			trailOn(mote, color, 0.3 * o.size, 0.22, "trailStreak")
		end
		table.insert(missiles, { p = mote, bend = bend, lag = rng:NextNumber(0, 0.12) })
	end
	over(total, function(u: number)
		local to = goal()
		for _, m in missiles do
			local k = math.clamp((u - m.lag * (1 - u)) / 1, 0, 1)
			local mid = (from + to) / 2 + m.bend
			local p = from:Lerp(mid, k):Lerp(mid:Lerp(to, k), k)
			m.p.CFrame = CFrame.new(p)
		end
	end, function()
		local to = goal()
		for _, m in missiles do
			m.p.CFrame = CFrame.new(to + Vector3.new(rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.4, 0.4), 0))
			fadeOut(m.p, 0.1, { Size = Vector3.one * 1.6 * o.size })
		end
		o.onArrive(to)
	end)
end

-- Hunter impacts ---------------------------------------------------------------------------------------------------

-- Wood splinters and a chip of the head thrown back towards the shooter from the hit. opts: count, color (wood).
pieces.lmSplinters = function(ctx: Ctx)
	local at = ctx.at
	if not at then
		return
	end
	local back = -shotDir(ctx)
	local floor = ground(at).Y + 0.1
	local bodies: { Body } = {}
	local wood: Color3 = if ctx.opts.metal then STEEL else WOOD
	for i = 1, amount(ctx.opts.count or 7, ctx.simple) do
		local bright = i == 1
		local p = part(
			"Block",
			if bright then ctx.color:Lerp(WHITE, 0.4) else wood,
			Vector3.new(0.07, 0.07, rng:NextNumber(0.3, 0.6)),
			if bright then NEON else Enum.Material.Wood,
			0
		)
		local vel = (back + Vector3.new(rng:NextNumber(-0.8, 0.8), rng:NextNumber(0.4, 1.3), rng:NextNumber(-0.8, 0.8))).Unit
			* rng:NextNumber(10, 20)
		table.insert(bodies, {
			p = p,
			pos = at,
			vel = vel,
			rot = randomRot(),
			spin = spinVec(18),
			floor = floor,
			life = rng:NextNumber(0.6, 0.9),
			bounce = 0.3,
		})
	end
	ballistic(bodies, 50)
end

-- The arrow stays in the target (or the ground) a moment, quivering, then fades. opts: size, seconds, bolt (a short
-- iron bolt instead of an arrow).
pieces.lmStuckArrow = function(ctx: Ctx)
	local at = ctx.at
	if not at or ctx.simple then
		return
	end
	local o = ctx.opts
	local dir = shotDir(ctx)
	local seconds = o.seconds or 1.2
	local size = o.size or 1
	local arrow = arrowModel(ctx.color, size * (if o.bolt then 0.7 else 1))
	if o.bolt then
		arrow.Color = STEEL
		arrow.Material = Enum.Material.Metal
	end
	local target = ctx.target
	local root = if target then target:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	local tilt = CFrame.Angles(rng:NextNumber(-0.25, 0.1), rng:NextNumber(-0.3, 0.3), 0)
	local offset: CFrame
	local function base(): CFrame
		if root and root.Parent then
			return root.CFrame
		end
		return CFrame.new(at)
	end
	local hit = if root then at + Vector3.new(0, rng:NextNumber(-0.3, 0.8), 0) else ground(at) + Vector3.new(0, 0.6, 0)
	local pitch = if root then 0 else -0.9
	local shaftLength = arrow.Size.Z
	local world = CFrame.lookAt(hit, hit + dir)
		* CFrame.Angles(pitch, 0, 0)
		* tilt
		* CFrame.new(0, 0, shaftLength * 0.3)
	offset = base():ToObjectSpace(world)
	over(seconds, function(_u: number, t: number)
		-- a quiver dying out over the first 0.4 s
		local wobble = math.sin(t * 55) * math.exp(-t * 9) * 0.12
		arrow.CFrame = base() * offset * CFrame.Angles(wobble, wobble * 0.6, 0)
	end, function()
		fadeOut(arrow, 0.2)
	end)
end

-- A tunnel of shock rings along a piercing shot: rings rippling out one after another from the start to the end of the
-- line, a thin white core streak. opts: count, size; the line from the event (cf, l) or the caster to the point.
pieces.lmShockRings = function(ctx: Ctx)
	local start: Vector3, finish: Vector3
	local cf = ctx.data.cf
	if typeof(cf) == "CFrame" then
		local length = tonumber(ctx.data.l) or (ctx.skill and ctx.skill.length) or 20
		start = cf.Position + Vector3.new(0, 1, 0)
		finish = start + cf.LookVector * length
	elseif ctx.caster and ctx.at then
		start = centre(ctx.caster) + Vector3.new(0, 0.6, 0)
		finish = ctx.at
		local d = finish - start
		if d.Magnitude > 14 then
			-- a long shot: the rings stay near the hit (the last 14 studs)
			start = finish - d.Unit * 14
		end
	else
		return
	end
	local line = finish - start
	if line.Magnitude < 0.5 then
		return
	end
	local dir = line.Unit
	local count = amount(ctx.opts.count or 6, ctx.simple)
	local size = ctx.opts.size or 1
	for i = 1, count do
		local u = i / count
		Clock.after(u * 0.12, function()
			shockDisc(facingDisc(start + line * u, dir), 0.4, (1.6 + 1.6 * u) * size, ctx.color, 0.28)
		end)
	end
	local streak = part("Block", ctx.color:Lerp(WHITE, 0.6), Vector3.new(0.12, 0.12, line.Magnitude), NEON, 0)
	streak.CFrame = CFrame.lookAt((start + finish) / 2, finish)
	fadeOut(streak, 0.22, { Size = Vector3.new(0.02, 0.02, line.Magnitude) })
end

-- The shadow of the falling arrows darkening the circle for the rain's waves, with a pale rim.
pieces.lmRainShadow = function(ctx: Ctx)
	local at = ctx.at
	if not at then
		return
	end
	local skill = ctx.skill or {}
	local waves = math.max(1, tonumber(ctx.data.n) or skill.hits or 1)
	local lasts = math.clamp(waves * (skill.interval or 0.5) + 0.4, 0.6, 4)
	local base = ground(at) + Vector3.new(0, kit.SURFACE_LIFT, 0)
	local r = ctx.radius * 2
	local shadow = part("Cylinder", SHADOW, Vector3.new(0.05, r * 0.3, r * 0.3), Enum.Material.SmoothPlastic, 1)
	shadow.CFrame = discFrame(base)
	tween(shadow, 0.3, { Size = Vector3.new(0.05, r, r), Transparency = 0.55 })
	Clock.after(lasts, fadeOut, shadow, 0.35)
	local rim = part("Cylinder", ctx.color, Vector3.new(0.06, r * 0.3, r * 0.3), FIELD, 0.3)
	rim.CFrame = discFrame(base + Vector3.new(0, 0.02, 0))
	tween(rim, 0.3, { Size = Vector3.new(0.06, r * 1.04, r * 1.04) })
	Clock.after(lasts, fadeOut, rim, 0.35)
end

-- Streaks of wind tearing through a cone (Volley): thin bright darts flying out across the cone's angle.
pieces.lmGust = function(ctx: Ctx)
	local frame = ctx.frame
	if not frame then
		return
	end
	local angle = tonumber(ctx.data.a) or (ctx.skill and ctx.skill.angle) or 60
	local radius = ctx.radius
	local count = amount(ctx.opts.count or 8, ctx.simple)
	local origin = frame.Position + Vector3.new(0, 0.8, 0)
	for i = 1, count do
		local yaw = math.rad(rng:NextNumber(-angle / 2, angle / 2))
		local dir = (frame * CFrame.Angles(0, yaw, 0)).LookVector
		local start = origin + dir * rng:NextNumber(0.5, 2) + Vector3.new(0, rng:NextNumber(-0.5, 1.2), 0)
		local dart = part("Block", ctx.color:Lerp(WHITE, 0.7), Vector3.new(0.06, 0.06, 2.4), NEON, 0.3)
		dart.CFrame = CFrame.lookAt(start, start + dir)
		local finish = start + dir * radius * rng:NextNumber(0.7, 1)
		Clock.after(rng:NextNumber(0, 0.1), function()
			fadeOut(dart, 0.3, { CFrame = CFrame.lookAt(finish, finish + dir), Size = Vector3.new(0.02, 0.02, 4) })
		end)
	end
end

-- A trap arming: beads closing in a spiral onto the snare, then three blinks of a light over it and a ripple: armed.
pieces.lmTrapArm = function(ctx: Ctx)
	local at = ctx.at
	if not at then
		return
	end
	local base = ground(at) + Vector3.new(0, 0.25, 0)
	local count = amount(8, ctx.simple)
	local reach = ctx.opts.reach or 3
	local beads: { BasePart } = {}
	for i = 1, count do
		local bead = part("Ball", ctx.color:Lerp(WHITE, 0.3), Vector3.one * 0.25, NEON, 0)
		bead.CFrame = CFrame.new(base)
		beads[i] = bead
	end
	over(0.45, function(u: number)
		local r = reach * (1 - u) ^ 1.3 + 0.2
		local turn = u * math.pi * 1.5
		for i, bead in beads do
			local a = (i / count) * math.pi * 2 + turn
			bead.CFrame =
				CFrame.new(base + Vector3.new(math.cos(a) * r, 0.1 + 0.4 * math.sin(u * math.pi), math.sin(a) * r))
		end
	end, function()
		for _, bead in beads do
			Pool.release(bead)
		end
		shockDisc(discFrame(base), 0.5, 3.4, ctx.color, 0.3)
	end)
	-- three blinks: armed
	for i = 0, 2 do
		Clock.after(0.5 + i * 0.16, function()
			local blink = part("Block", ctx.color:Lerp(WHITE, 0.5), Vector3.one * 0.3, NEON, 0)
			blink.CFrame = CFrame.new(base + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0.785, 0.785, 0)
			fadeOut(blink, 0.12, { Size = Vector3.one * (0.5 + 0.15 * i) })
		end)
	end
end

-- Steel teeth snapping shut where a trap springs (from lying open outwards to closed over the point), then fading.
pieces.lmSpringJaws = function(ctx: Ctx)
	local at = ctx.at
	if not at then
		return
	end
	local base = ground(at)
	local count = if ctx.simple then 5 else 9
	local ring = ctx.opts.reach or 1.6
	for i = 1, count do
		local a = (i / count) * math.pi * 2
		local root = CFrame.new(base + Vector3.new(math.cos(a) * ring, 0.05, math.sin(a) * ring))
			* CFrame.Angles(0, -a + math.pi / 2, 0)
		local tooth = part(
			"Wedge",
			if i % 3 == 0 then ctx.color else STEEL,
			Vector3.new(0.18, 1.5, 0.5),
			if i % 3 == 0 then NEON else Enum.Material.Metal,
			0
		)
		-- hinged at its foot: open = lying outwards, shut = leaning in over the point
		local function pose(angle: number): CFrame
			return root * CFrame.Angles(angle, 0, 0) * CFrame.new(0, 0.75, 0)
		end
		tooth.CFrame = pose(-1.45)
		tween(tooth, 0.08, { CFrame = pose(0.42) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		Clock.after(0.5, fadeOut, tooth, 0.25)
	end
end

-- Venom drops flung out from the hit, a puddle where each lands. opts: count.
pieces.lmVenomSplash = function(ctx: Ctx)
	local at = ctx.at
	if not at then
		return
	end
	local floor = ground(at).Y + 0.08
	local bodies: { Body } = {}
	for _ = 1, amount(ctx.opts.count or 9, ctx.simple) do
		local drop = part("Ball", ctx.color, Vector3.one * rng:NextNumber(0.22, 0.4), GLASS, 0.15)
		local ang = rng:NextNumber(0, math.pi * 2)
		table.insert(bodies, {
			p = drop,
			pos = at + Vector3.new(0, 0.5, 0),
			vel = Vector3.new(
				math.cos(ang) * rng:NextNumber(5, 11),
				rng:NextNumber(8, 15),
				math.sin(ang) * rng:NextNumber(5, 11)
			),
			rot = CFrame.identity,
			spin = Vector3.zero,
			floor = floor,
			life = 0.9,
			bounce = 0,
		})
	end
	ballistic(bodies, 45, function(b: Body)
		if ctx.simple then
			return
		end
		local puddle = part("Cylinder", ctx.color, Vector3.new(0.04, 0.2, 0.2), GLASS, 0.2)
		puddle.CFrame = discFrame(b.pos)
		tween(puddle, 0.25, { Size = Vector3.new(0.04, rng:NextNumber(0.9, 1.6), rng:NextNumber(0.9, 1.6)) })
		Clock.after(0.9, fadeOut, puddle, 0.4)
	end)
end

-- A reticle closing on the prey: four brackets turning in from wide to tight round its chest, a lock flash, then a
-- spinning diamond over its head for a while. opts: seconds (the mark's), reach.
pieces.lmReticle = function(ctx: Ctx)
	local model = ctx.target or ctx.caster
	if not model then
		return
	end
	local color = ctx.color
	local brackets: { BasePart } = {}
	for i = 1, 4 do
		local b = part("Block", color:Lerp(WHITE, 0.25), Vector3.new(0.14, 0.14, 0.9), NEON, 0)
		brackets[i] = b
	end
	local reach = ctx.opts.reach or 4
	over(0.35, function(u: number)
		local c = centre(model) + Vector3.new(0, 0.6, 0)
		local r = reach + (1.6 - reach) * (1 - (1 - u) ^ 3)
		for i, b in brackets do
			local a = (i / 4) * math.pi * 2 + (1 - u) * 1.6
			local p = c + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			b.CFrame = CFrame.lookAt(p, c) * CFrame.Angles(0, math.pi / 2, 0)
		end
	end, function()
		for _, b in brackets do
			fadeOut(b, 0.2, { Size = Vector3.new(0.3, 0.3, 1.4) })
		end
		local c = centre(model)
		shockDisc(discFrame(ground(c) + Vector3.new(0, 0.15, 0)), 4, 1.2, color, 0.25)
	end)
	if ctx.simple then
		return
	end
	local seconds = math.clamp(ctx.opts.seconds or ctx.seconds, 0.8, 3)
	local diamond = part("Block", color, Vector3.one * 0.5, NEON, 0.1)
	Clock.after(0.3, function()
		over(seconds, function(_u: number, t: number)
			local top = centre(model) + Vector3.new(0, 3.6 + math.sin(t * 5) * 0.2, 0)
			diamond.CFrame = CFrame.new(top) * CFrame.Angles(0, t * 4, 0) * CFrame.Angles(0.785, 0, 0.785)
		end, function()
			fadeOut(diamond, 0.2, { Size = Vector3.one * 0.1 })
		end)
	end)
end

-- Stakes of light driven round the target's feet and a binding ring closing on them (Pinning Shot).
pieces.lmPinRing = function(ctx: Ctx)
	local model = ctx.target
	local at = if model then centre(model) else ctx.at
	if not at then
		return
	end
	local base = ground(at)
	local count = if ctx.simple then 3 else 4
	for i = 1, count do
		local a = (i / count) * math.pi * 2 + 0.4
		local spot = base + Vector3.new(math.cos(a) * 1.4, 0, math.sin(a) * 1.4)
		local stake = part("Block", ctx.color:Lerp(WHITE, 0.3), Vector3.new(0.16, 1.4, 0.16), NEON, 0)
		stake.CFrame = CFrame.new(spot + Vector3.new(0, 6, 0)) * CFrame.Angles(0.2, a, 0)
		Clock.after((i - 1) * 0.04, function()
			tween(
				stake,
				0.12,
				{ CFrame = CFrame.new(spot + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0.2, a, 0) },
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			)
			Clock.after(0.12, function()
				shockDisc(discFrame(spot + Vector3.new(0, 0.1, 0)), 0.2, 1.2, ctx.color, 0.2)
			end)
			Clock.after(1.2, fadeOut, stake, 0.25)
		end)
	end
	shockDisc(discFrame(base + Vector3.new(0, 0.12, 0)), 4.5, 2.6, ctx.color, 0.4)
end

-- R15 parts that make a ghost (the head as a ball).
local GHOST_PARTS = {
	"Head",
	"UpperTorso",
	"LowerTorso",
	"LeftUpperArm",
	"LeftLowerArm",
	"RightUpperArm",
	"RightLowerArm",
	"LeftUpperLeg",
	"LeftLowerLeg",
	"RightUpperLeg",
	"RightLowerLeg",
}

-- Ghosts of the body left along a dash, from where it started (the event's `from`) towards where it ends: force-field
-- copies of the limbs in the pose of the moment, drifting back and fading. opts: count.
pieces.lmAfterimage = function(ctx: Ctx)
	local caster = ctx.caster
	local root = if caster then caster:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if not caster or not root then
		return
	end
	local start: Vector3 = if typeof(ctx.data.from) == "Vector3" then ctx.data.from else root.Position
	local finish: Vector3 = if typeof(ctx.data.p) == "Vector3" then ctx.data.p else start
	local count = if ctx.simple then 1 else (ctx.opts.count or 3)
	local rotation = root.CFrame.Rotation
	local limbs: { { size: Vector3, rel: CFrame, ball: boolean } } = {}
	for _, name in GHOST_PARTS do
		local limb = caster:FindFirstChild(name)
		if limb and limb:IsA("BasePart") then
			table.insert(
				limbs,
				{ size = limb.Size, rel = root.CFrame:ToObjectSpace(limb.CFrame), ball = name == "Head" }
			)
		end
	end
	local away = unitOr(Library.flat(start - finish), -root.CFrame.LookVector)
	for i = 1, count do
		local share = (i - 1) / math.max(1, count)
		local spot = start:Lerp(Vector3.new(finish.X, start.Y, finish.Z), share * 0.6)
		local frame = CFrame.new(spot) * rotation
		Clock.after((i - 1) * 0.05, function()
			for _, limb in limbs do
				local ghost = part(
					if limb.ball then "Ball" else "Block",
					ctx.color,
					if limb.ball then Vector3.one * limb.size.Y else limb.size,
					FIELD,
					0
				)
				local cf = frame * limb.rel
				ghost.CFrame = cf
				fadeOut(ghost, 0.45 + share * 0.1, { CFrame = cf + away * 1.2 })
			end
		end)
	end
end

-- Ribbons of wind winding up round the caster (Windstep, the falcon's call): bright motes with long trails on a
-- rising helix. opts: count, height, feathers (a burst of feathers too).
pieces.lmWindRibbons = function(ctx: Ctx)
	local model = ctx.caster
	if not model then
		return
	end
	local count = amount(ctx.opts.count or 3, ctx.simple)
	local height = ctx.opts.height or 5
	local motes: { BasePart } = {}
	for i = 1, count do
		local mote = part("Ball", ctx.color:Lerp(WHITE, 0.5), Vector3.one * 0.18, NEON, 0.2)
		if not ctx.simple then
			trailOn(mote, ctx.color, 0.35, 0.3, "trailStreak")
		end
		motes[i] = mote
	end
	over(0.7, function(u: number)
		local c = centre(model) - Vector3.new(0, 2.6, 0)
		for i, mote in motes do
			local a = u * math.pi * 3 + (i / count) * math.pi * 2
			local r = 2.2 - 1.2 * u
			mote.CFrame = CFrame.new(c + Vector3.new(math.cos(a) * r, height * u, math.sin(a) * r))
		end
	end, function()
		for _, mote in motes do
			fadeOut(mote, 0.15)
		end
	end)
	if ctx.opts.feathers and not ctx.simple then
		Library.sparks(centre(model) + Vector3.new(0, 1.5, 0), ctx.color, {
			key = "feather",
			count = 8,
			speed = { 4, 9 },
			life = { 0.6, 1.1 },
			gravity = 4,
		})
	end
end

-- A net spreading as it drops over the circle, lying a moment, then fading (Net Shot).
pieces.lmNet = function(ctx: Ctx)
	local at = ctx.at
	if not at then
		return
	end
	local base = ground(at) + Vector3.new(0, 0.15, 0)
	local r = math.max(2, ctx.radius)
	local strands = if ctx.simple then 3 else 5
	local rope = Color3.fromHex("#8A7454"):Lerp(ctx.color, 0.2)
	local high = base + Vector3.new(0, 5, 0)
	for axis = 0, 1 do
		for i = 1, strands do
			local share = (i - 0.5) / strands * 2 - 1
			local turn = CFrame.Angles(0, axis * math.pi / 2, 0)
			local strand = part("Block", rope, Vector3.new(0.09, 0.09, 0.4 * r), Enum.Material.Fabric, 0)
			strand.CFrame = CFrame.new(high) * turn * CFrame.new(share * r * 0.2, 0, 0)
			tween(strand, 0.22, {
				CFrame = CFrame.new(base) * turn * CFrame.new(share * r * 0.95, 0, 0),
				Size = Vector3.new(0.09, 0.09, 2 * r * math.sqrt(math.max(0.05, 1 - share * share))),
			}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			Clock.after(1.3, fadeOut, strand, 0.3)
		end
	end
	Clock.after(0.22, function()
		shockDisc(discFrame(base), r * 0.8, r * 2.3, ctx.color, 0.3)
		if not ctx.simple then
			Library.dust(base + Vector3.new(0, 2.6, 0), 0.7, true)
		end
	end)
end

-- Mage impacts ----------------------------------------------------------------------------------------------------

-- A tear in the air: an upright ellipse of light opening and closing at both ends of a blink, motes drawn into the
-- start. opts: height.
pieces.lmRift = function(ctx: Ctx)
	local caster = ctx.caster
	local root = if caster then caster:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	local start: Vector3? = if typeof(ctx.data.from) == "Vector3"
		then ctx.data.from
		else (if root then root.Position else nil)
	local finish: Vector3? = if typeof(ctx.data.p) == "Vector3" then ctx.data.p else ctx.at
	if not start then
		return
	end
	local dir = if finish then unitOr(Library.flat(finish - start), Vector3.zAxis) else Vector3.zAxis
	local height = ctx.opts.height or 6
	local function tear(at: Vector3, delay: number)
		Clock.after(delay, function()
			local frame = CFrame.lookAt(at, at + dir)
			local glow = part("Block", ctx.color, Vector3.one, NEON, 0.1)
			glow.CFrame = frame
			local mesh = sphereMesh(glow, Vector3.new(0.2, 0.2, 0.05))
			local core = part("Block", SHADOW, Vector3.one, Enum.Material.SmoothPlastic, 0)
			core.CFrame = frame * CFrame.new(0, 0, -0.03)
			local inner = sphereMesh(core, Vector3.new(0.1, 0.1, 0.04))
			Clock.tween(
				mesh,
				TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = Vector3.new(2.4, height, 0.2) }
			)
			Clock.tween(
				inner,
				TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = Vector3.new(1.4, height * 0.85, 0.22) }
			)
			Clock.after(0.3, function()
				Clock.tween(
					mesh,
					TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ Scale = Vector3.new(0.05, height * 1.2, 0.05) }
				)
				Clock.tween(
					inner,
					TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ Scale = Vector3.new(0.02, height, 0.02) }
				)
				fadeOut(glow, 0.18)
				fadeOut(core, 0.16)
			end)
		end)
	end
	tear(start, 0)
	if finish and (finish - start).Magnitude > 2 then
		tear(finish, 0.04)
	end
	if not ctx.simple then
		local holder = kit.textured("glow", CFrame.new(start))
		if holder then
			kit.burstFrom(holder, "glow", ctx.color:Lerp(WHITE, 0.4), 14, {
				to = ctx.color,
				area = Vector3.new(1.5, height * 0.8, 1.5),
				speedMin = 2,
				speedMax = 5,
				drag = 3,
				lifeMin = 0.3,
				lifeMax = 0.6,
				sizeSeq = NumberSequence.new({ kp(0, 0.6), kp(1, 0) }),
				emission = 1,
			})
		end
	end
end

-- An explosion: a white-hot core swelling fast, a shell of the element's colour, a rippling heat shell, a ground ring
-- racing out, a short strong light. opts: size (x scale).
pieces.lmExplosion = function(ctx: Ctx)
	local at = ctx.at
	if not at then
		return
	end
	local s = (ctx.opts.size or 1) * math.clamp(ctx.scale, 0.5, 2.5)
	local color = ctx.color
	local centreAt = at + Vector3.new(0, 0.8 * s, 0)
	local core = part("Ball", color:Lerp(WHITE, 0.7), Vector3.one * 0.6 * s, NEON, 0)
	core.CFrame = CFrame.new(centreAt)
	tween(core, 0.1, { Size = Vector3.one * 3.4 * s }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	Clock.after(0.1, fadeOut, core, 0.16, { Size = Vector3.one * 4.2 * s })
	local shell = part("Ball", color, Vector3.one * 1.2 * s, NEON, 0.25)
	shell.CFrame = CFrame.new(centreAt)
	tween(
		shell,
		0.3,
		{ Size = Vector3.one * 6 * s, Transparency = 0.7 },
		Enum.EasingStyle.Quint,
		Enum.EasingDirection.Out
	)
	Clock.after(0.3, fadeOut, shell, 0.15)
	if not ctx.simple then
		local heat = part("Ball", color:Lerp(WHITE, 0.3), Vector3.one * 2 * s, FIELD, 0)
		heat.CFrame = CFrame.new(centreAt)
		fadeOut(heat, 0.45, { Size = Vector3.one * 9 * s }, Enum.EasingStyle.Quad)
		kit.flashLight(core, color, 24 * s, 4, 0.25)
	end
	local ringR = math.max(ctx.radius, 3 * s) * 2.2
	shockDisc(discFrame(ground(at) + Vector3.new(0, 0.2, 0)), 1, ringR, color, 0.4, 0.2)
end

-- Rock chunks thrown out from the blow (some molten, glowing), bouncing once. opts: count, size, molten (share).
pieces.lmDebris = function(ctx: Ctx)
	local at = ctx.at
	if not at then
		return
	end
	local o = ctx.opts
	local floor = ground(at).Y
	local bodies: { Body } = {}
	local molten = o.molten or 0.35
	for _ = 1, amount(o.count or 9, ctx.simple) do
		local hot = rng:NextNumber() < molten
		local d = rng:NextNumber(0.35, 1.0) * (o.size or 1)
		local chunk = part(
			"Block",
			if hot then ctx.color:Lerp(Color3.fromHex("#FFB040"), 0.4) else ROCK,
			Vector3.new(d, d * rng:NextNumber(0.6, 1), d * rng:NextNumber(0.6, 1.2)),
			if hot then NEON else Enum.Material.Basalt,
			0
		)
		local ang = rng:NextNumber(0, math.pi * 2)
		local out = rng:NextNumber(8, 18)
		table.insert(bodies, {
			p = chunk,
			pos = at + Vector3.new(0, 0.6, 0),
			vel = Vector3.new(math.cos(ang) * out, rng:NextNumber(14, 26), math.sin(ang) * out),
			rot = randomRot(),
			spin = spinVec(12),
			floor = floor + d * 0.4,
			life = rng:NextNumber(1.1, 1.6),
			bounce = 0.35,
		})
	end
	ballistic(bodies, 60)
end

-- Embers drifting up from the blow for a second or two (fire). opts: count, spread (studs).
pieces.lmEmbers = function(ctx: Ctx)
	local at = ctx.at
	if not at then
		return
	end
	local spread = ctx.opts.spread or math.min(ctx.radius, 4)
	local holder = kit.textured("spark", CFrame.new(at + Vector3.new(0, 0.5, 0)))
	if not holder then
		return
	end
	kit.burstFrom(holder, "spark", ctx.color:Lerp(Color3.fromHex("#FFD27A"), 0.5), ctx.opts.count or 18, {
		simple = ctx.simple,
		to = ctx.color:Lerp(Color3.fromHex("#5A0A04"), 0.5),
		area = Vector3.new(spread * 2, 0.5, spread * 2),
		spread = 40,
		speedMin = 2,
		speedMax = 6,
		accel = Vector3.new(rng:NextNumber(-1, 1), 5, rng:NextNumber(-1, 1)),
		drag = 0.6,
		lifeMin = 0.9,
		lifeMax = 1.7,
		orient = "parallel",
		rotSpeed = NumberRange.new(-60, 60),
		sizeSeq = NumberSequence.new({ kp(0, 0.16), kp(0.5, 0.2), kp(1, 0.02) }),
		transparency = NumberSequence.new({ kp(0, 0), kp(0.7, 0.2), kp(1, 1) }),
		emission = 1,
	})
end

-- A jagged bolt with forks and a flash of light where it strikes. opts.mode: "sky" (from high above the point),
-- "cloud" (from the storm cloud, Config.Vfx.cloudHeight), "link" (from the previous link / the caster to the
-- target: a chain), "line" (along the event's line); width, forks.
pieces.lmForkBolt = function(ctx: Ctx)
	local o = ctx.opts
	local mode = o.mode or "sky"
	local a: Vector3?, b: Vector3? = nil, nil
	local target = ctx.target
	local hit = if target then centre(target) else ctx.at
	if mode == "link" then
		local source = ctx.from or ctx.caster
		a = if source then centre(source) + Vector3.new(0, 0.5, 0) else nil
		b = hit
	elseif mode == "line" then
		local cf = ctx.data.cf
		if typeof(cf) == "CFrame" then
			local length = tonumber(ctx.data.l) or (ctx.skill and ctx.skill.length) or 20
			a = cf.Position + Vector3.new(0, 1, 0)
			b = a + cf.LookVector * length
		end
	elseif hit then
		local height = if mode == "cloud" then Config.Vfx.cloudHeight else 30
		a = hit + Vector3.new(rng:NextNumber(-4, 4), height, rng:NextNumber(-4, 4))
		b = if target then hit else ground(hit)
	end
	if not a or not b then
		return
	end
	local width = (o.width or 0.22) * math.clamp(ctx.scale, 0.6, 1.6)
	forkBolt(a, b, ctx.color, width, ctx.simple, o.forks)
	if not ctx.simple then
		local spark = part("Ball", ctx.color:Lerp(WHITE, 0.6), Vector3.one * 0.8, NEON, 0)
		spark.CFrame = CFrame.new(b)
		kit.flashLight(spark, ctx.color, 18, 3, 0.12)
		fadeOut(spark, 0.14, { Size = Vector3.one * 2.4 })
	end
end

-- Small arcs crawling over the struck body for a moment. opts: seconds, every (s between arcs).
pieces.lmArcCrawl = function(ctx: Ctx)
	local model = ctx.target or ctx.caster
	if not model then
		return
	end
	local seconds = math.clamp(ctx.opts.seconds or 0.5, 0.2, 3)
	local every = (ctx.opts.every or 0.06) * (if ctx.simple then 2 else 1)
	local nextAt = 0
	over(seconds, function(_u: number, t: number)
		if t < nextAt or not model.Parent then
			return
		end
		nextAt = t + every
		local c = centre(model) + Vector3.new(0, 0.3, 0)
		local function onBody(): Vector3
			return c + Vector3.new(rng:NextNumber(-1.1, 1.1), rng:NextNumber(-2.2, 1.6), rng:NextNumber(-1.1, 1.1))
		end
		local p = onBody()
		segments(jagged(p, p + (onBody() - p) * 0.7, 3, 0.35), ctx.color, 0.07, 0.07, false)
	end)
end

-- Tongues of flame roaring through a cone from the caster (Flame Wave). opts: count.
pieces.lmFlameJet = function(ctx: Ctx)
	local frame = ctx.frame
	if not frame then
		return
	end
	local angle = tonumber(ctx.data.a) or (ctx.skill and ctx.skill.angle) or 60
	local origin = frame.Position + Vector3.new(0, 0.6, 0) + frame.LookVector
	local holder = kit.textured("fire", kit.facingFrame(origin, frame.LookVector))
	if holder then
		kit.burstFrom(holder, "fire", ctx.color:Lerp(Color3.fromHex("#FFC24A"), 0.35), ctx.opts.count or 26, {
			simple = ctx.simple,
			to = ctx.color:Lerp(Color3.fromHex("#5A0A04"), 0.6),
			direction = Enum.NormalId.Front,
			spread = angle / 2,
			speedMin = ctx.radius * 1.6,
			speedMax = ctx.radius * 2.6,
			drag = 2.5,
			accel = Vector3.new(0, 4, 0),
			lifeMin = 0.35,
			lifeMax = 0.55,
			rotation = NumberRange.new(0, 360),
			rotSpeed = NumberRange.new(-120, 120),
			sizeSeq = NumberSequence.new({ kp(0, 0.8), kp(0.4, 2.6), kp(1, 1.2) }),
			transparency = NumberSequence.new({ kp(0, 0.15), kp(0.6, 0.35), kp(1, 1) }),
			emission = 0.8,
		})
	end
	-- a bright sheet licking the ground along the middle of the cone
	local tongue = part("Wedge", ctx.color:Lerp(WHITE, 0.3), Vector3.new(1.4, 0.3, 1), NEON, 0.35)
	local flat = frame - frame.Position + origin - Vector3.new(0, 0.5, 0)
	tongue.CFrame = flat * CFrame.new(0, 0, -0.5) * CFrame.Angles(0, math.pi, 0)
	fadeOut(tongue, 0.35, {
		Size = Vector3.new(ctx.radius * math.tan(math.rad(angle / 2)) * 2, 0.3, ctx.radius),
		CFrame = flat * CFrame.new(0, 0, -ctx.radius / 2) * CFrame.Angles(0, math.pi, 0),
	})
end

-- A shimmering shield sphere popping on round the model (overshoot), breathing, then popping off. opts: size, seconds.
pieces.lmBubble = function(ctx: Ctx)
	local model = ctx.target or ctx.caster
	if not model then
		return
	end
	local size = (ctx.opts.size or 7) * math.clamp(ctx.scale, 0.6, 1.4)
	local seconds = math.clamp(ctx.opts.seconds or 1.1, 0.4, 2.5)
	local shell = part("Ball", ctx.color, Vector3.one * 0.6, FIELD, 0)
	local tint = part("Ball", ctx.color, Vector3.one * 0.5, NEON, 0.86)
	local function place(extra: number)
		local c = centre(model)
		shell.CFrame = CFrame.new(c)
		tint.CFrame = CFrame.new(c)
		if extra > 0 then
			shell.Size = Vector3.one * size * extra
			tint.Size = Vector3.one * size * 0.97 * extra
		end
	end
	place(0)
	tween(shell, 0.25, { Size = Vector3.one * size }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	tween(tint, 0.25, { Size = Vector3.one * size * 0.97 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	over(seconds, function(_u: number, t: number)
		if t > 0.25 then
			place(1 + math.sin(t * 7) * 0.025)
		else
			place(0)
		end
	end, function()
		fadeOut(shell, 0.16, { Size = Vector3.one * size * 1.2 })
		fadeOut(tint, 0.12, { Size = Vector3.one * size * 1.2 })
	end)
end

-- The burning rift a falling rock comes out of: a disc of the element's colour tearing open in the sky along the fall,
-- a dark heart; it closes once the rock has gone through (the event's `d`). opts: low (a short fall: the rift sits
-- lower, as Library.meteor starts lower), overhead (a storm's rift right over the circle), size, seconds.
pieces.lmSkyRift = function(ctx: Ctx)
	local at = ctx.at
	if not at then
		return
	end
	local landing = ground(at)
	local offset = if ctx.opts.overhead
		then Vector3.new(0, 26, 0)
		elseif ctx.opts.low then Vector3.new(-6, 16, -3)
		else Vector3.new(-16, 42, -8)
	local spot = landing + offset * 0.9
	local dir = unitOr(landing - spot, -Vector3.yAxis)
	local size = (ctx.opts.size or 1) * math.clamp(ctx.radius * 0.7, 3, 8)
	local frame = facingDisc(spot, dir)
	local rim = part("Cylinder", ctx.color, Vector3.new(0.2, 0.5, 0.5), NEON, 0.15)
	rim.CFrame = frame
	local heart = part("Cylinder", SHADOW, Vector3.new(0.25, 0.3, 0.3), Enum.Material.SmoothPlastic, 0)
	heart.CFrame = frame
	local ring = part("Cylinder", ctx.color:Lerp(WHITE, 0.3), Vector3.new(0.3, 0.6, 0.6), FIELD, 0)
	ring.CFrame = frame
	tween(rim, 0.25, { Size = Vector3.new(0.2, size, size) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	tween(
		heart,
		0.25,
		{ Size = Vector3.new(0.25, size * 0.72, size * 0.72) },
		Enum.EasingStyle.Back,
		Enum.EasingDirection.Out
	)
	tween(ring, 0.3, { Size = Vector3.new(0.3, size * 1.5, size * 1.5) })
	local lasts = math.clamp(ctx.opts.seconds or ctx.seconds, 0.2, 6) + 0.15
	over(lasts, function(_u: number, t: number)
		local spin = CFrame.Angles(t * 3, 0, 0)
		rim.CFrame = frame * spin
		ring.CFrame = frame * CFrame.Angles(-t * 2, 0, 0)
	end, function()
		fadeOut(rim, 0.2, { Size = Vector3.new(0.2, 0.2, 0.2) })
		fadeOut(heart, 0.15, { Size = Vector3.new(0.25, 0.1, 0.1) })
		fadeOut(ring, 0.2)
	end)
end

-- Motes on a rising helix round the caster (Elemental Vortex), with a turning disc at the feet. opts: count.
pieces.lmVortex = function(ctx: Ctx)
	local model = ctx.caster
	if not model then
		return
	end
	local count = amount(ctx.opts.count or 6, ctx.simple)
	local r = math.max(2, ctx.radius * 0.6)
	local motes: { BasePart } = {}
	for i = 1, count do
		local mote = part("Ball", ctx.color:Lerp(WHITE, 0.35), Vector3.one * 0.3, NEON, 0)
		if not ctx.simple then
			trailOn(mote, ctx.color, 0.4, 0.25, "trailStreak")
		end
		motes[i] = mote
	end
	over(0.85, function(u: number)
		local c = centre(model) - Vector3.new(0, 2.4, 0)
		for i, mote in motes do
			local a = u * math.pi * 4 + (i / count) * math.pi * 2
			local radius = r * (0.6 + 0.4 * math.sin(u * math.pi))
			mote.CFrame =
				CFrame.new(c + Vector3.new(math.cos(a) * radius, 0.4 + 4 * u + (i % 2) * 0.6, math.sin(a) * radius))
		end
	end, function()
		for _, mote in motes do
			fadeOut(mote, 0.15)
		end
	end)
	shockDisc(discFrame(ground(centre(model)) + Vector3.new(0, 0.15, 0)), r * 2.4, r * 0.6, ctx.color, 0.5)
end

-- Two counter-turning rings of runes round a channel (Evocation), for the channel's time (`d`, at most 6 s); a
-- channel cut short leaves them a moment longer (the motion stops on channelEnd).
pieces.lmRuneRings = function(ctx: Ctx)
	local model = ctx.target or ctx.caster
	if not model then
		return
	end
	local seconds = math.clamp(tonumber(ctx.data.d) or ctx.seconds, 0.8, 6)
	local per = if ctx.simple then 5 else 8
	local runes: { { p: BasePart, ring: number, a: number } } = {}
	for ring = 1, 2 do
		for i = 1, per do
			local rune = part("Block", ctx.color:Lerp(WHITE, 0.3), Vector3.new(0.12, 0.38, 0.38), NEON, 0.1)
			table.insert(runes, { p = rune, ring = ring, a = (i / per) * math.pi * 2 })
		end
	end
	over(seconds, function(u: number, t: number)
		local c = centre(model)
		local open = math.min(1, t / 0.3) * (if u > 0.92 then (1 - u) / 0.08 else 1)
		for _, r in runes do
			local dirn = if r.ring == 1 then 1 else -1
			local a = r.a + t * 1.6 * dirn
			local radius = (if r.ring == 1 then 2.6 else 1.9) * open
			local y = if r.ring == 1 then -2.2 else 0.6 + math.sin(t * 2) * 0.2
			local p = c + Vector3.new(math.cos(a) * radius, y, math.sin(a) * radius)
			r.p.CFrame = CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)) * CFrame.Angles(0, 0, t * 2)
		end
	end, function()
		for _, r in runes do
			fadeOut(r.p, 0.15)
		end
	end)
end

-- Two motes winding along a beam from the weapon's tip to its target every tick (Arcane Torrent). The tip comes as
-- the context's `launch`, else the caster's centre.
pieces.lmHelix = function(ctx: Ctx)
	local target = ctx.target
	local caster = ctx.caster
	if not target or not caster or ctx.simple then
		return
	end
	local launch = ctx.launch
	local seconds = math.max(0.2, (ctx.skill and ctx.skill.interval) or 0.5)
	local motes: { BasePart } = {}
	for i = 1, 2 do
		local mote = part("Ball", ctx.color:Lerp(WHITE, 0.4), Vector3.one * 0.25, NEON, 0)
		trailOn(mote, ctx.color, 0.2, 0.2, "trailStreak")
		motes[i] = mote
	end
	over(seconds, function(u: number)
		local a = if launch then launch() else centre(caster)
		local b = centre(target)
		local line = b - a
		local frame = CFrame.lookAt(a, a + unitOr(line, Vector3.zAxis))
		for i, mote in motes do
			local ang = u * math.pi * 6 + (i - 1) * math.pi
			local r = 0.5 * math.sin(u * math.pi) + 0.1
			mote.CFrame =
				CFrame.new(a + line * u + frame:VectorToWorldSpace(Vector3.new(math.cos(ang), math.sin(ang), 0)) * r)
		end
	end, function()
		for _, mote in motes do
			fadeOut(mote, 0.1, { Size = Vector3.one * 0.8 })
		end
	end)
end

-- Ice chunks falling into the circle, each shattering where it lands (Hailstorm, Blizzard). opts: count.
pieces.lmHail = function(ctx: Ctx)
	local at = ctx.at
	if not at then
		return
	end
	local count = amount(ctx.opts.count or 7, ctx.simple)
	local r = math.max(2, ctx.radius)
	for i = 1, count do
		Clock.after(rng:NextNumber(0, 0.35), function()
			local a = rng:NextNumber(0, math.pi * 2)
			local d = math.sqrt(rng:NextNumber()) * r
			local spot = ground(at + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d))
			local size = rng:NextNumber(0.5, 1)
			local chunk = part("Block", ICE:Lerp(ctx.color, 0.3), Vector3.new(size, size * 1.4, size), GLASS, 0.1)
			local start = spot + Vector3.new(-3, 18, -2)
			chunk.CFrame = CFrame.lookAt(start, spot)
			if not ctx.simple and i % 2 == 0 then
				trailOn(chunk, ICE, 0.25, 0.12, "trailStreak")
			end
			tween(
				chunk,
				0.24,
				{ CFrame = CFrame.lookAt(spot, spot + (spot - start)) },
				Enum.EasingStyle.Quad,
				Enum.EasingDirection.In
			)
			Clock.after(0.24, function()
				Pool.release(chunk)
				shockDisc(discFrame(spot + Vector3.new(0, 0.1, 0)), 0.3, 2.2, ctx.color, 0.2)
				if ctx.simple then
					return
				end
				local bodies: { Body } = {}
				for _ = 1, 3 do
					local ang = rng:NextNumber(0, math.pi * 2)
					table.insert(bodies, {
						p = part("Block", ICE, Vector3.one * rng:NextNumber(0.15, 0.3), GLASS, 0.1),
						pos = spot + Vector3.new(0, 0.3, 0),
						vel = Vector3.new(math.cos(ang) * 6, rng:NextNumber(6, 10), math.sin(ang) * 6),
						rot = randomRot(),
						spin = spinVec(15),
						floor = spot.Y + 0.1,
						life = 0.5,
						bounce = 0,
					})
				end
				ballistic(bodies, 45)
			end)
		end)
	end
end

-- A big orb over the circle for this wave, pulsing (a frost orb shedding glints, a ball of lightning crackling).
-- opts: size, arcs (lightning arcs to the ground).
pieces.lmOrbPulse = function(ctx: Ctx)
	local at = ctx.at
	if not at then
		return
	end
	local size = (ctx.opts.size or 2.2) * math.clamp(ctx.scale, 0.6, 1.6)
	local lasts = math.max(0.3, ((ctx.skill and ctx.skill.interval) or 0.5) + 0.12)
	local centreAt = ground(at) + Vector3.new(0, 2.4, 0)
	local orb = part("Ball", ctx.color:Lerp(WHITE, 0.35), Vector3.one * size * 0.5, NEON, 0.15)
	local shell = part("Ball", ctx.color, Vector3.one * size, FIELD, 0)
	orb.CFrame = CFrame.new(centreAt)
	shell.CFrame = CFrame.new(centreAt)
	if not ctx.simple and ctx.wave <= 1 then
		kit.flashLight(orb, ctx.color, 16, 2, lasts)
	end
	over(lasts, function(_u: number, t: number)
		local pulse = 1 + math.sin(t * 18) * 0.08
		orb.Size = Vector3.one * size * 0.65 * pulse
		shell.Size = Vector3.one * size * (1.1 + 0.25 * math.min(1, t / lasts))
		shell.CFrame = CFrame.new(centreAt) * CFrame.Angles(t * 2, t * 3, 0)
	end, function()
		fadeOut(orb, 0.1)
		fadeOut(shell, 0.12, { Size = Vector3.one * size * 1.8 })
	end)
	if ctx.opts.arcs and not ctx.simple then
		for _ = 1, 2 do
			local a = rng:NextNumber(0, math.pi * 2)
			local spot =
				ground(at + Vector3.new(math.cos(a), 0, math.sin(a)) * rng:NextNumber(2, math.max(2.5, ctx.radius)))
			segments(jagged(centreAt, spot, 5, 0.8), ctx.color, 0.1, 0.12, false)
		end
	end
end

-- Crystals of ice bursting from the ground and sinking back (or breaking). opts.mode: "ring" (rows racing out from the
-- point over the radius: Frost Nova), "cluster" (a spray of spikes round the point), "encase" (spikes leaning in over
-- the target: Deep Freeze), "burst" (a cluster that shatters outward at once: Shatter); size, count, hold.
pieces.lmIceSpikes = function(ctx: Ctx)
	local at = ctx.at
	if ctx.target and ctx.opts.mode ~= "ring" then
		at = centre(ctx.target)
	end
	if not at then
		return
	end
	local o = ctx.opts
	local mode = o.mode or "cluster"
	local base = ground(at)
	local size = (o.size or 1) * math.clamp(ctx.scale, 0.6, 1.8)
	local hold = o.hold or (if mode == "burst" then 0.08 else 0.55)
	type Spike = { spot: Vector3, out: Vector3, height: number, lean: number, delay: number }
	local spikes: { Spike } = {}
	if mode == "ring" then
		local r = math.max(3, ctx.radius)
		for row, share in { 0.4, 0.75, 1 } do
			local n = amount(math.floor(r * share * 1.6) + 4, ctx.simple)
			for i = 1, n do
				local a = (i + row * 0.5) / n * math.pi * 2
				local out = Vector3.new(math.cos(a), 0, math.sin(a))
				table.insert(spikes, {
					spot = base + out * r * share * rng:NextNumber(0.9, 1.05),
					out = out,
					height = rng:NextNumber(1.4, 2.6) * size * (1.15 - share * 0.4),
					lean = rng:NextNumber(0.25, 0.55),
					delay = share * 0.14,
				})
			end
		end
	else
		local n = amount(o.count or (if mode == "encase" then 8 else 7), ctx.simple)
		for i = 1, n do
			local a = (i / n) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			local reach = if mode == "encase" then 1.5 else rng:NextNumber(0.3, 1.6)
			table.insert(spikes, {
				spot = base + out * reach * size,
				out = out,
				height = rng:NextNumber(1.8, 3.2) * size,
				-- encase: leaning in over the target; the rest lean outwards
				lean = if mode == "encase" then -0.45 else rng:NextNumber(0.2, 0.7),
				delay = rng:NextNumber(0, 0.06),
			})
		end
	end
	for _, s in spikes do
		Clock.after(s.delay, function()
			local tilt = CFrame.lookAt(s.spot, s.spot + s.out) * CFrame.Angles(-s.lean, 0, 0)
			local w = 0.35 * size + s.height * 0.12
			local crystal = part("Block", ICE:Lerp(ctx.color, 0.35), Vector3.new(w, 0.1, w), GLASS, 0.05)
			local twist = CFrame.Angles(0, 0.785, 0)
			crystal.CFrame = tilt * CFrame.new(0, 0.05, 0) * twist
			tween(crystal, 0.09, {
				Size = Vector3.new(w, s.height, w),
				CFrame = tilt * CFrame.new(0, s.height / 2 - 0.2, 0) * twist,
			}, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
			Clock.after(0.09 + hold, function()
				if mode == "burst" or (not ctx.simple and rng:NextNumber() < 0.3) then
					-- shattered: chips thrown out, the crystal gone
					Pool.release(crystal)
					if ctx.simple then
						return
					end
					local bodies: { Body } = {}
					for _ = 1, 3 do
						table.insert(bodies, {
							p = part("Block", ICE, Vector3.one * rng:NextNumber(0.2, 0.4) * size, GLASS, 0.05),
							pos = s.spot + Vector3.new(0, s.height * 0.5, 0),
							vel = (s.out + Vector3.new(
								rng:NextNumber(-0.5, 0.5),
								rng:NextNumber(0.6, 1.2),
								rng:NextNumber(-0.5, 0.5)
							)) * rng:NextNumber(8, 15),
							rot = randomRot(),
							spin = spinVec(14),
							floor = s.spot.Y + 0.1,
							life = 0.55,
							bounce = 0.2,
						})
					end
					ballistic(bodies, 50)
				else
					-- sinking back into the ground
					fadeOut(
						crystal,
						0.3,
						{ Size = Vector3.new(w * 0.7, 0.1, w * 0.7), CFrame = tilt * CFrame.new(0, 0.05, 0) * twist }
					)
				end
			end)
		end)
	end
	if not ctx.simple then
		local glints = kit.textured("star", CFrame.new(base + Vector3.new(0, 1.5, 0)))
		if glints then
			local r = if mode == "ring" then math.max(3, ctx.radius) else 1.6 * size
			kit.burstFrom(glints, "star", WHITE, 8, {
				to = ctx.color,
				area = Vector3.new(r * 2, 1.5, r * 2),
				speedMin = 0,
				speedMax = 1,
				lifeMin = 0.25,
				lifeMax = 0.5,
				rotation = NumberRange.new(0, 360),
				sizeSeq = NumberSequence.new({ kp(0, 0.1), kp(0.3, 0.9), kp(1, 0) }),
				emission = 1,
			})
		end
	end
end

return {
	pieces = pieces,
	flights = flights,
}
