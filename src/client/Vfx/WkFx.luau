--!strict
-- Warrior and Cleric skill pieces (walka-wk, owner 2026-10-20: "każda umiejętność ma wyglądać wow"): the `wk*` pieces
-- of Data/SkillVfx, played by VfxController.piece through WkFx.pieces[name](ctx). Built only from Vfx/Library.kit (the
-- pooled holders, the device limits, the effect clock, the low-quality halving) and plain pooled parts, so AnimLab
-- freezes them like every other piece and nothing is created per frame.
--   wkSlam         a blow into the ground: a light, two rings, rock spikes erupting on a ring, rock chunks thrown on
--                  ballistic arcs (they bounce once and settle), a dust wall rolling out
--   wkFissure      a glowing crack running from the caster through the blow point (sunder)
--   wkFissureStar  cracks running out from the centre in a star (slams around the caster)
--   wkDebris       a few rock chunks only (a blow that bites the ground a little)
--   wkChargeTrail  the dust of a charge along its path, scuff marks, speed lines and a streak at knee height
--   wkShieldBash   a shield of force punching forward from the caster, a ripple facing the caster, sparks forward
--   wkShockRing    a ring of force standing up at the blow, facing the attacker (heavy single blows)
--   wkCrit         a critical blow: a big star, radial streaks and a small ring (also basic attacks, WkFx.crit)
--   wkVortex       blade streaks orbiting the caster and dust thrown outwards (one per whirl wave)
--   wkShout        two spheres of force expanding from the chest and a ring on the ground
--   wkNova         a dome of light expanding over the area, rays and a ring
--   wkHolyBeam     a column of light from the sky (two beams: the wide holy one and a white core), motes falling
--   wkHealBurst    a halo rising from the feet over the head, motes spiralling up around the body, a glint over the head
--   wkFeathers     feathers of light drifting down (angels, resurrection)
--   wkChains       a chain of light links from the caster to the target, shattering at the end
--   wkSkySword     a sword of light falling from the sky into the target's ground
--   wkSkyHammer    a hammer of light falling from the sky over the event's `d` (starts with the event: WkFx.FALLS)
--   wkRageLoop     a buff loop for `d`: embers rising, a red rune under the feet, a light pulsing like a heartbeat
--   wkHolyLoop     a buff loop for `d`: motes of light rising, the Cleric's rune turning under the feet, a soft light
--   wkGuardLoop    a buff loop for `d`: three shield plates orbiting the body, faint motes
--   wkGroundGlow   motes rising over a circle for `d` (a sanctified area)
-- Costs (holders and lights at the peak) are in tests/SkillLooks.PIECE_COST; tests/wkfx.spec checks that every `wk`
-- name of Data/SkillVfx is a piece here and has a layer and a cost. Low quality / far away (`simple`): fewer chunks,
-- spikes and links, no loop emitters, no lights.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Clock = require(script.Parent.Clock)
local Config = require(ReplicatedStorage.Shared.Config)
local Library = require(script.Parent.Library)
local Pool = require(script.Parent.Pool)
local Textures = require(script.Parent.Textures)

local kit = Library.kit
local kp = kit.kp
local tween = kit.tween

local WkFx = {}

-- What VfxController hands every piece (sizes from the server event, like the Library pieces).
export type Ctx = {
	at: Vector3?, -- the impact point (VfxController.impactPoint)
	radius: number, -- the event's radius, else the skill's, else 6 x scale
	scale: number, -- SkillVfx.size
	seconds: number, -- the event's `d`, else 1
	color: Color3,
	caster: Model?,
	target: Model?,
	frame: CFrame?, -- the blow's facing (VfxController.facing)
	simple: boolean, -- far away or low quality
	markRadius: number?, -- SkillVfx.markRadius
	coreDelay: number?, -- SkillVfx.coreDelay: blow-moment pieces (ring, crit) wait it too
	from: Vector3?, -- the event's `from` (where a charge started)
}
export type Piece = (ctx: Ctx) -> ()

local rng = Random.new()
local WHITE = Color3.new(1, 1, 1)
local ROCK = Color3.fromHex("#6E6256")
local ROCK_DARK = Color3.fromHex("#4A4038")
local CRACK = Color3.fromHex("#241E1A")
local GRAVITY = 70 -- studs/s² of the rock chunks (heavier than the particle chips: they read as stone)

-- Low quality (Library's rule: settings.quality == "low").
local function low(): boolean
	return kit.lowQuality()
end

local function lerpWhite(color: Color3, share: number): Color3
	return color:Lerp(WHITE, share)
end

-- Runs fn after the blow-moment delay (SkillVfx.coreDelay), at once without one.
local function atBlow(ctx: Ctx, fn: () -> ())
	local wait = ctx.coreDelay or 0
	if wait > 0 then
		Clock.after(wait, fn)
	else
		fn()
	end
end

local function modelOf(ctx: Ctx): Model?
	return ctx.target or ctx.caster
end

local function rootOf(model: Model?): BasePart?
	if not model or not model.Parent then
		return nil
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- The facing of the blow, flat (from the caster to the point, else the frame, else -Z).
local function forward(ctx: Ctx): Vector3
	local frame = ctx.frame
	if frame then
		local look = kit.flat(frame.LookVector)
		if look.Magnitude > 0.05 then
			return look.Unit
		end
	end
	local caster, at = ctx.caster, ctx.at
	if caster and at then
		local d = kit.flat(at - kit.centre(caster))
		if d.Magnitude > 0.1 then
			return d.Unit
		end
	end
	return Vector3.new(0, 0, -1)
end

-- A short light on a pooled anchor at `at` (the device's light budget: Pool.takeLight inside flashLight).
local function lightAt(at: Vector3, color: Color3, range: number, brightness: number, seconds: number)
	if low() then
		return
	end
	local anchor = Pool.part("Block", color, Vector3.one * 0.2, Enum.Material.SmoothPlastic, 1)
	anchor.CFrame = CFrame.new(at)
	kit.flashLight(anchor, color, range, brightness, seconds)
	Pool.later(anchor, seconds + 0.05)
end

-- Rock chunks ------------------------------------------------------------------------------------------------------

-- `count` chunks thrown from `base` (on the ground) up and out on ballistic arcs: they tumble, hit the ground once,
-- bounce low, roll a moment and sink away. Plain parts on the shared ticker.
local function chunks(base: Vector3, count: number, power: number, spread: number, tint: Color3)
	local floor = base.Y
	for _ = 1, count do
		local size = rng:NextNumber(0.35, 0.85) * math.clamp(power, 0.6, 1.6)
		local color = ROCK:Lerp(ROCK_DARK, rng:NextNumber()):Lerp(tint, 0.08)
		local p = Pool.part(
			"Block",
			color,
			Vector3.new(size, size * rng:NextNumber(0.6, 1), size * rng:NextNumber(0.7, 1.2)),
			Enum.Material.Slate,
			0
		)
		local a = rng:NextNumber(0, math.pi * 2)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local pos = base + out * rng:NextNumber(0, spread * 0.4) + Vector3.new(0, size * 0.5, 0)
		local vel = out * rng:NextNumber(5, 13) * power + Vector3.new(0, rng:NextNumber(14, 24) * power, 0)
		local spin = Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(-12, 12), rng:NextNumber(-12, 12))
		local turn = CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6))
		local bounced = false
		local last = Clock.now()
		local started = last
		local resting: number? = nil
		p.CFrame = CFrame.new(pos) * turn
		kit.animate(function(now: number): boolean
			if not p.Parent then
				return true
			end
			local dt = math.min(0.05, now - last)
			last = now
			if resting then
				if now - resting > 0.5 then
					tween(p, 0.35, { Transparency = 1, Size = p.Size * 0.4 })
					Pool.later(p, 0.4)
					return true
				end
				return false
			end
			vel -= Vector3.new(0, GRAVITY * dt, 0)
			pos += vel * dt
			turn = turn * CFrame.Angles(spin.X * dt, spin.Y * dt, spin.Z * dt)
			if pos.Y <= floor + p.Size.Y * 0.5 and vel.Y < 0 then
				pos = Vector3.new(pos.X, floor + p.Size.Y * 0.5, pos.Z)
				if bounced or now - started > 1.6 then
					resting = now
				else
					bounced = true
					vel = Vector3.new(vel.X * 0.45, -vel.Y * 0.3, vel.Z * 0.45)
					spin *= 0.4
				end
			end
			p.CFrame = CFrame.new(pos) * turn
			return false
		end)
	end
end

-- Rock spikes erupting on a ring of `radius` around `base`: wedges thrust up and out from under the ground in 0.08 s,
-- held a moment, sunk back.
local function spikes(base: Vector3, radius: number, count: number, height: number, tint: Color3, delay: number?)
	local function raise()
		local turn0 = rng:NextNumber(0, math.pi * 2)
		for i = 1, count do
			local a = turn0 + (i / count) * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			local h = height * rng:NextNumber(0.7, 1.2)
			local w = h * rng:NextNumber(0.35, 0.5)
			local spot = kit.ground(base + out * radius * rng:NextNumber(0.85, 1.1))
			local color = ROCK:Lerp(tint, 0.12):Lerp(ROCK_DARK, rng:NextNumber(0, 0.5))
			local p = Pool.part("Wedge", color, Vector3.new(w, h, w * 1.3), Enum.Material.Slate, 0)
			-- the wedge's slope faces the centre, leaning outwards
			local frame = CFrame.lookAt(spot, spot - out) * CFrame.Angles(math.rad(-rng:NextNumber(12, 28)), 0, 0)
			p.CFrame = frame * CFrame.new(0, -h * 0.6, 0)
			tween(
				p,
				0.08,
				{ CFrame = frame * CFrame.new(0, h * 0.35, 0) },
				Enum.EasingStyle.Back,
				Enum.EasingDirection.Out
			)
			Clock.after(0.5 + rng:NextNumber(0, 0.15), function()
				if p.Parent then
					tween(
						p,
						0.35,
						{ CFrame = frame * CFrame.new(0, -h * 0.7, 0) },
						Enum.EasingStyle.Quad,
						Enum.EasingDirection.In
					)
					Pool.later(p, 0.4)
				end
			end)
		end
	end
	if delay and delay > 0 then
		Clock.after(delay, raise)
	else
		raise()
	end
end

-- A dust wall rolling out over the ground from `base` (one smoke burst, flattened).
local function dustWall(base: Vector3, radius: number, tint: Color3, simple: boolean)
	local holder = kit.textured("smoke", CFrame.new(base + Vector3.new(0, 0.6, 0)))
	if not holder then
		return
	end
	kit.burstFrom(holder, "smoke", tint, if simple then 5 else 12, {
		simple = simple,
		spread = 88,
		speedMin = radius * 1.3,
		speedMax = radius * 2.2,
		drag = 4,
		accel = Vector3.new(0, 1.5, 0),
		lifeMin = 0.9,
		lifeMax = 1.5,
		rotation = NumberRange.new(0, 360),
		rotSpeed = NumberRange.new(-50, 50),
		sizeSeq = NumberSequence.new({ kp(0, 1.6), kp(0.4, 3.4), kp(1, 4.6) }),
		transparency = NumberSequence.new({ kp(0, 0.3), kp(0.6, 0.55), kp(1, 1) }),
		area = Vector3.new(1.5, 0.2, 1.5),
		emission = 0,
	})
end

-- A glowing crack: a zigzag of dark slabs from `a` to `b` with the skill's colour glowing in it, drawn from `a` on
-- (0.15 s), held, faded.
local function crackLine(a: Vector3, b: Vector3, color: Color3, width: number, simple: boolean)
	local length = (b - a).Magnitude
	if length < 0.5 then
		return
	end
	local dir = (b - a).Unit
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local steps = math.clamp(math.floor(length / 1.6), 2, if simple then 5 else 10)
	local prev = a
	for i = 1, steps do
		local u = i / steps
		local wobble = if i == steps then 0 else rng:NextNumber(-0.6, 0.6) * width * 2
		local nextPoint = kit.ground(a:Lerp(b, u) + side * wobble + Vector3.new(0, 1, 0))
			+ Vector3.new(0, kit.SURFACE_LIFT, 0)
		local p0, p1 = prev, nextPoint
		local seg = (p1 - p0).Magnitude
		if seg > 0.1 then
			local w = width * (1.2 - 0.6 * u)
			Clock.after(u * 0.15, function()
				local slab = Pool.part("Block", CRACK, Vector3.new(w, 0.08, seg + 0.15), Enum.Material.Slate, 0.05)
				slab.CFrame = CFrame.lookAt((p0 + p1) / 2, p1)
				local glow = Pool.part("Block", color, Vector3.new(w * 0.45, 0.1, seg + 0.1), Enum.Material.Neon, 0.1)
				glow.CFrame = slab.CFrame + Vector3.new(0, 0.02, 0)
				tween(
					glow,
					0.9,
					{ Transparency = 1, Size = Vector3.new(w * 0.2, 0.1, seg) },
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.In
				)
				Pool.later(glow, 0.95)
				Clock.after(0.9, function()
					if slab.Parent then
						tween(slab, Config.Vfx.decalFade, { Transparency = 1 })
						Pool.later(slab, Config.Vfx.decalFade + 0.05)
					end
				end)
			end)
		end
		prev = nextPoint
	end
end

-- Pieces -----------------------------------------------------------------------------------------------------------

local pieces: { [string]: Piece } = {}

pieces.wkSlam = function(ctx: Ctx)
	local at = ctx.at
	if not at then
		return
	end
	local radius = ctx.markRadius or math.max(3, ctx.radius * 0.8)
	local base = kit.ground(at)
	local power = math.clamp(radius / 6, 0.6, 1.5)
	local dustTint = kit.DUST_COLOR:Lerp(ctx.color, 0.15)
	lightAt(base + Vector3.new(0, 1.5, 0), lerpWhite(ctx.color, 0.3), radius * 3 + 8, 4, 0.18)
	-- the shock: a bright ring at once, a wider dust ring behind it
	kit.ringSurface(at, radius, lerpWhite(ctx.color, 0.2), 0.35)
	Clock.after(0.06, function()
		kit.ringSurface(at, radius * 1.25, dustTint, 0.6, "dustRing")
	end)
	local simple = ctx.simple
	local lowNow = low()
	spikes(base, radius * 0.6, if simple or lowNow then 5 else 10, 1.6 + power, ctx.color, 0.02)
	chunks(base, if simple then 3 elseif lowNow then 4 else math.floor(7 + 3 * power), power, radius, ctx.color)
	dustWall(base, radius, dustTint, simple)
end

pieces.wkDebris = function(ctx: Ctx)
	local at = ctx.at
	if not at then
		return
	end
	local power = 0.7 * ctx.scale
	atBlow(ctx, function()
		chunks(kit.ground(at), if ctx.simple or low() then 2 else 5, math.max(0.6, power), 2, ctx.color)
	end)
end

pieces.wkFissure = function(ctx: Ctx)
	local caster, at = ctx.caster, ctx.at
	if not at then
		return
	end
	local dir = forward(ctx)
	local start = if caster then kit.centre(caster) + dir * 1.2 else at - dir * 2
	local length = math.max(5, (kit.flat(at - start)).Magnitude + 3)
	crackLine(kit.ground(start), kit.ground(start + dir * length), ctx.color, 0.5, ctx.simple)
end

pieces.wkFissureStar = function(ctx: Ctx)
	local at = ctx.at
	if not at then
		return
	end
	local radius = math.max(4, ctx.radius)
	local count = if ctx.simple then 3 else 6
	local turn = rng:NextNumber(0, math.pi * 2)
	local base = kit.ground(at)
	for i = 1, count do
		local a = turn + (i / count) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		crackLine(base + out * 0.8, base + out * radius * rng:NextNumber(0.75, 1.05), ctx.color, 0.45, ctx.simple)
	end
end

pieces.wkChargeTrail = function(ctx: Ctx)
	local a, b = ctx.from, ctx.at
	if not a or not b then
		return
	end
	local path = kit.flat(b - a)
	local length = path.Magnitude
	if length < 1 then
		return
	end
	local dir = path.Unit
	local groundA, groundB = kit.ground(a), kit.ground(b)
	-- dust along the whole path in one burst (the holder's box spans it), thrown up and to the sides
	local mid = (groundA + groundB) / 2 + Vector3.new(0, 0.4, 0)
	local holder = kit.textured("smoke", CFrame.lookAt(mid, mid + dir))
	if holder then
		kit.burstFrom(holder, "smoke", kit.DUST_COLOR:Lerp(ctx.color, 0.1), if ctx.simple then 4 else 10, {
			simple = ctx.simple,
			spread = 60,
			speedMin = 2,
			speedMax = 6,
			drag = 2.5,
			accel = Vector3.new(0, 1, 0),
			lifeMin = 0.7,
			lifeMax = 1.2,
			rotation = NumberRange.new(0, 360),
			rotSpeed = NumberRange.new(-40, 40),
			sizeSeq = NumberSequence.new({ kp(0, 1.2), kp(1, 3.2) }),
			transparency = NumberSequence.new({ kp(0, 0.35), kp(1, 1) }),
			area = Vector3.new(1.4, 0.2, length),
			emission = 0,
		})
	end
	-- scuff marks where the feet dug in
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local marks = if ctx.simple then 2 else math.clamp(math.floor(length / 2.5), 2, 7)
	for i = 1, marks do
		local u = (i - 0.5) / marks
		local spot = groundA:Lerp(groundB, u) + side * (if i % 2 == 0 then 0.6 else -0.6)
		local mark = Pool.part("Block", CRACK, Vector3.new(0.7, 0.06, 1.6), Enum.Material.Ground, 0.35)
		mark.CFrame =
			CFrame.lookAt(spot + Vector3.new(0, kit.SURFACE_LIFT, 0), spot + Vector3.new(0, kit.SURFACE_LIFT, 0) + dir)
		Clock.after(0.8, function()
			if mark.Parent then
				tween(mark, 0.5, { Transparency = 1 })
				Pool.later(mark, 0.55)
			end
		end)
	end
	-- speed lines streaming past the path
	if not ctx.simple and not low() then
		for _ = 1, 6 do
			local offset = side * rng:NextNumber(-1.6, 1.6) + Vector3.new(0, rng:NextNumber(1, 4), 0)
			local u = rng:NextNumber(0.1, 0.7)
			local start = groundA:Lerp(groundB, u) + offset
			local line =
				Pool.part("Block", lerpWhite(ctx.color, 0.5), Vector3.new(0.08, 0.08, 3), Enum.Material.Neon, 0.3)
			line.CFrame = CFrame.lookAt(start, start + dir)
			tween(line, 0.25, {
				CFrame = CFrame.lookAt(start + dir * 4, start + dir * 5),
				Transparency = 1,
				Size = Vector3.new(0.04, 0.04, 6),
			})
			Pool.later(line, 0.3)
		end
	end
	-- the streak at knee height (a camera-facing beam of the streak texture)
	local streak = if Textures.id("trailStreak") then Pool.holder("beam", "trailStreak") else nil
	local beam = if streak then kit.setupBeam(streak, lerpWhite(ctx.color, 0.2), 1.6, true, ctx.simple) else nil
	if streak and beam then
		local a0, a1 = kit.attachments(streak)
		local from = groundA + Vector3.new(0, 1.2, 0)
		streak.CFrame = CFrame.lookAt(from, from + dir)
		a0.CFrame = CFrame.new()
		a1.CFrame = CFrame.new(0, 0, -length)
		Textures.beam(beam, "trailStreak", { speed = 12 })
		beam.Width0 = 0.3
		beam.Width1 = 2
		kit.fadeBeam(beam, 0.15, 1, 0.45)
		Pool.holderLater(streak, 0.5)
	end
end

-- A ring of force standing up at `at`, its face towards `towards` (the attacker / the camera side).
local function standingRing(at: Vector3, towards: Vector3, size: number, color: Color3, seconds: number, key: string?)
	local d = towards - at
	local look = if d.Magnitude > 0.05 then d.Unit else Vector3.zAxis
	-- the holder's top face (the image) turned to look at the attacker: +Y onto `look`
	local frame = CFrame.lookAt(at, at - look) * CFrame.Angles(math.pi / 2, 0, 0)
	local holder, image = kit.surfaceAt(key or "ring", frame, size * 0.25, color)
	if not holder or not image then
		return
	end
	image.ImageTransparency = 0.05
	tween(holder, seconds, { Size = Vector3.new(size, 0.05, size) }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	tween(image, seconds, { ImageTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Pool.holderLater(holder, seconds + 0.05)
end

-- The point a standing ring faces: the caster, else the camera.
local function viewer(ctx: Ctx, at: Vector3): Vector3
	local caster = ctx.caster
	if caster and caster ~= ctx.target then
		return kit.centre(caster)
	end
	local camera = workspace.CurrentCamera
	return if camera then camera.CFrame.Position else at + Vector3.zAxis
end

pieces.wkShockRing = function(ctx: Ctx)
	local at = ctx.at
	if not at then
		return
	end
	atBlow(ctx, function()
		standingRing(at, viewer(ctx, at), 7 * math.max(0.6, ctx.scale), lerpWhite(ctx.color, 0.25), 0.28)
	end)
end

-- The core of a critical blow at `at` (towards = the attacker): a big star, radial streaks and a small standing ring.
function WkFx.crit(at: Vector3, towards: Vector3?, color: Color3, simple: boolean)
	Library.impactFlash(at, 4.2, lerpWhite(color, 0.15), { simple = simple, key = "hitStar" })
	local count = if simple or low() then 4 else 9
	local turn = rng:NextNumber(0, math.pi * 2)
	local face = if towards then towards - at else Vector3.zAxis
	local look = if face.Magnitude > 0.05 then face.Unit else Vector3.zAxis
	local frame = CFrame.lookAt(at, at + look)
	for i = 1, count do
		local a = turn + (i / count) * math.pi * 2
		local out = (frame.RightVector * math.cos(a) + frame.UpVector * math.sin(a) + look * 0.35).Unit
		local streak = Pool.part("Block", lerpWhite(color, 0.4), Vector3.new(0.1, 0.1, 0.6), Enum.Material.Neon, 0)
		streak.CFrame = CFrame.lookAt(at + out * 0.4, at + out * 2)
		local length = rng:NextNumber(2.2, 3.6)
		tween(streak, 0.18, {
			CFrame = CFrame.lookAt(at + out * (1 + length * 0.6), at + out * (2 + length)),
			Size = Vector3.new(0.05, 0.05, length),
			Transparency = 1,
		}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		Pool.later(streak, 0.22)
	end
	if towards then
		standingRing(at, towards, 5.5, lerpWhite(color, 0.3), 0.22)
	end
end

-- Basic attacks (CombatFxController): a few chips knocked out of the ground under `at` by a heavy head.
function WkFx.chips(at: Vector3, count: number)
	chunks(kit.ground(at), count, 0.6, 1.5, ROCK)
end

-- Basic attacks of holy weapons: a small gold ring of light at `at` facing the attacker.
local HOLY_TAP = Color3.fromHex("#FFE7A0")
function WkFx.holyTap(at: Vector3, towards: Vector3, simple: boolean)
	if simple then
		return
	end
	standingRing(at, towards, 4, HOLY_TAP, 0.25)
end

pieces.wkCrit = function(ctx: Ctx)
	local at = ctx.at
	if not at then
		return
	end
	atBlow(ctx, function()
		WkFx.crit(at, viewer(ctx, at), ctx.color, ctx.simple)
	end)
end

pieces.wkShieldBash = function(ctx: Ctx)
	local caster = ctx.caster
	if not caster then
		return
	end
	local dir = forward(ctx)
	local chest = kit.centre(caster) + Vector3.new(0, 0.6, 0)
	local size = 4.5 * math.max(0.7, ctx.scale + 0.4)
	-- the shield of force: a disc facing forward punching out and fading, with a neon rim
	local face = CFrame.lookAt(chest + dir * 1.4, chest + dir * 3) * CFrame.Angles(0, math.pi / 2, 0)
	local disc = Pool.part("Cylinder", ctx.color, Vector3.new(0.2, size * 0.6, size * 0.6), Enum.Material.ForceField, 0)
	disc.CFrame = face
	local reach = math.clamp(ctx.radius * 0.5, 2.5, 5)
	tween(disc, 0.3, {
		CFrame = face + dir * reach,
		Size = Vector3.new(0.2, size * 1.3, size * 1.3),
		Transparency = 1,
	}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	Pool.later(disc, 0.35)
	local rim = Pool.part(
		"Cylinder",
		lerpWhite(ctx.color, 0.3),
		Vector3.new(0.12, size * 0.65, size * 0.65),
		Enum.Material.Neon,
		0.55
	)
	rim.CFrame = face + dir * 0.05
	tween(rim, 0.22, {
		CFrame = face + dir * (reach * 0.8),
		Size = Vector3.new(0.05, size * 1.4, size * 1.4),
		Transparency = 1,
	}, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	Pool.later(rim, 0.25)
	-- the ripple at the front of the push, facing back at the caster (and the camera behind him)
	local front = chest + dir * (reach + 1)
	standingRing(front, chest, size * 1.6, lerpWhite(ctx.color, 0.2), 0.3)
	Library.sparks(front, ctx.color, { simple = ctx.simple, dir = (dir + Vector3.new(0, 0.3, 0)).Unit, count = 12 })
end

pieces.wkVortex = function(ctx: Ctx)
	local caster = ctx.caster
	local root = rootOf(caster)
	if not root then
		return
	end
	local radius = math.clamp(ctx.radius * 0.6, 2.5, 6)
	local count = if ctx.simple or low() then 2 else 4
	local started = Clock.now()
	local seconds = 0.32
	local parts: { BasePart } = {}
	local offsets: { number } = {}
	for i = 1, count do
		local streak =
			Pool.part("Block", lerpWhite(ctx.color, 0.35), Vector3.new(0.12, 0.12, 2.6), Enum.Material.Neon, 0.2)
		table.insert(parts, streak)
		table.insert(offsets, (i / count) * math.pi * 2)
	end
	kit.animate(function(now: number): boolean
		local u = math.clamp((now - started) / seconds, 0, 1)
		local centre = if root.Parent then root.Position else Vector3.zero
		for i, streak in parts do
			local a = offsets[i] + u * math.pi * 3
			local r = radius * (0.6 + 0.4 * u)
			local h = -0.8 + (i % 2) * 1.2 + u * 0.6
			local pos = centre + Vector3.new(math.cos(a) * r, h, math.sin(a) * r)
			local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
			streak.CFrame = CFrame.lookAt(pos, pos + tangent)
			streak.Transparency = 0.2 + 0.8 * u
		end
		if u >= 1 then
			for _, streak in parts do
				Pool.release(streak)
			end
			return true
		end
		return false
	end)
	local base = kit.ground(root.Position)
	local holder = kit.textured("dust", CFrame.new(base + Vector3.new(0, 0.3, 0)))
	if holder then
		kit.burstFrom(holder, "dust", kit.DUST_COLOR, if ctx.simple then 3 else 8, {
			simple = ctx.simple,
			spread = 85,
			speedMin = 8,
			speedMax = 14,
			drag = 3,
			accel = Vector3.new(0, -3, 0),
			lifeMin = 0.4,
			lifeMax = 0.8,
			size = 1.4,
			sizeEnd = 0.5,
			rotation = NumberRange.new(0, 360),
			area = Vector3.new(radius, 0.2, radius),
			emission = 0,
		})
	end
end

-- An expanding sphere of force (ForceField shimmer) from `at` to `radius`.
local function forceSphere(at: Vector3, radius: number, color: Color3, seconds: number)
	local ball = Pool.part("Ball", color, Vector3.one * 2, Enum.Material.ForceField, 0)
	ball.CFrame = CFrame.new(at)
	tween(
		ball,
		seconds,
		{ Size = Vector3.one * radius * 2, Transparency = 1 },
		Enum.EasingStyle.Quart,
		Enum.EasingDirection.Out
	)
	Pool.later(ball, seconds + 0.05)
end

pieces.wkShout = function(ctx: Ctx)
	local where = if ctx.caster then kit.centre(ctx.caster) + Vector3.new(0, 0.8, 0) else ctx.at
	if not where then
		return
	end
	local radius = math.max(5, ctx.radius * 0.7)
	forceSphere(where, radius * 0.6, ctx.color, 0.35)
	if not ctx.simple then
		Clock.after(0.1, forceSphere, where, radius, lerpWhite(ctx.color, 0.2), 0.45)
	end
	kit.ringSurface(where, radius, ctx.color, 0.5)
end

pieces.wkNova = function(ctx: Ctx)
	local at = ctx.at or (if ctx.caster then kit.centre(ctx.caster) else nil)
	if not at then
		return
	end
	local radius = math.max(3, ctx.radius)
	local base = kit.ground(at)
	local dome = Pool.part("Ball", lerpWhite(ctx.color, 0.35), Vector3.one * 1.5, Enum.Material.Neon, 0.35)
	dome.CFrame = CFrame.new(base)
	tween(
		dome,
		0.45,
		{ Size = Vector3.one * radius * 2, Transparency = 1 },
		Enum.EasingStyle.Quart,
		Enum.EasingDirection.Out
	)
	Pool.later(dome, 0.5)
	local shell = Pool.part("Ball", ctx.color, Vector3.one * 2, Enum.Material.ForceField, 0)
	shell.CFrame = CFrame.new(base)
	tween(
		shell,
		0.6,
		{ Size = Vector3.one * radius * 2.2, Transparency = 1 },
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.Out
	)
	Pool.later(shell, 0.65)
	local rays = kit.textured("rays", CFrame.new(base + Vector3.new(0, 1.5, 0)))
	if rays then
		kit.burstFrom(rays, "rays", lerpWhite(ctx.color, 0.3), 1, {
			exact = true,
			to = ctx.color,
			lifeMin = 0.45,
			lifeMax = 0.45,
			rotation = NumberRange.new(0, 360),
			rotSpeed = NumberRange.new(-40, 40),
			sizeSeq = NumberSequence.new({ kp(0, 2), kp(0.3, radius * 1.2), kp(1, radius * 1.5) }),
			transparency = NumberSequence.new({ kp(0, 0.1), kp(0.5, 0.35), kp(1, 1) }),
			zOffset = 1,
			emission = 1,
		})
	end
	kit.ringSurface(at, radius, ctx.color, 0.45)
	lightAt(base + Vector3.new(0, 2, 0), ctx.color, radius * 2 + 8, 3, 0.3)
end

pieces.wkHolyBeam = function(ctx: Ctx)
	local model = ctx.target
	local where = if model then kit.centre(model) else ctx.at
	if not where then
		return
	end
	local base = kit.ground(where)
	local top = base + Vector3.new(0, 42, 0)
	local width = 2.4 + 2.2 * ctx.scale
	local function column(key: string, w: number, color: Color3, seconds: number, speed: number)
		local holder = if Textures.id(key) then Pool.holder("beam", key) else nil
		local beam = if holder then kit.setupBeam(holder, color, w * 0.1, true, ctx.simple) else nil
		if not holder or not beam then
			-- without the texture a neon column (the old pillar look)
			local col = Pool.part("Cylinder", color, Vector3.new(42, w * 0.2, w * 0.2), Enum.Material.Neon, 0.3)
			col.CFrame = CFrame.new((base + top) / 2) * CFrame.Angles(0, 0, math.rad(90))
			tween(col, seconds, { Size = Vector3.new(42, w * 0.05, w * 0.05), Transparency = 1 })
			Pool.later(col, seconds + 0.05)
			return
		end
		local a0, a1 = kit.attachments(holder)
		holder.CFrame = CFrame.new(top)
		a0.CFrame = CFrame.new()
		a1.CFrame = CFrame.new(0, -42, 0)
		Textures.beam(beam, key, { speed = speed, length = w * 3 })
		beam.Transparency = NumberSequence.new(0.05)
		local started = Clock.now()
		kit.animate(function(now: number): boolean
			local t = now - started
			local grow = math.clamp(t / 0.1, 0, 1)
			local fade = math.clamp((t - 0.15) / math.max(0.05, seconds - 0.15), 0, 1)
			local w1 = w * (0.1 + 0.9 * grow) * (1 - 0.85 * fade)
			beam.Width0 = w1 * 0.7
			beam.Width1 = w1
			beam.Transparency = NumberSequence.new(0.05 + 0.95 * fade)
			return t >= seconds
		end)
		Pool.holderLater(holder, seconds + 0.05)
	end
	column("beamHoly", width, ctx.color, 0.75, -10)
	column("trailSoft", width * 0.35, lerpWhite(ctx.color, 0.7), 0.5, -18)
	-- motes of light drifting down the column
	local motes = kit.textured("glow", CFrame.new(base + Vector3.new(0, 10, 0)))
	if motes then
		kit.burstFrom(motes, "glow", lerpWhite(ctx.color, 0.5), if ctx.simple then 5 else 14, {
			simple = ctx.simple,
			to = ctx.color,
			spread = 15,
			speedMin = 1,
			speedMax = 3,
			accel = Vector3.new(0, -6, 0),
			drag = 0.5,
			lifeMin = 0.8,
			lifeMax = 1.3,
			direction = Enum.NormalId.Bottom,
			sizeSeq = NumberSequence.new({ kp(0, 0), kp(0.2, 0.5, 0.2), kp(1, 0) }),
			transparency = NumberSequence.new({ kp(0, 0.1), kp(1, 1) }),
			area = Vector3.new(width, 16, width),
			emission = 1,
		})
	end
	kit.ringSurface(base, width * 1.4, ctx.color, 0.55)
	lightAt(base + Vector3.new(0, 3, 0), ctx.color, 18 + width * 2, 4, 0.5)
end

pieces.wkHealBurst = function(ctx: Ctx)
	local model = modelOf(ctx)
	local root = rootOf(model)
	if not root then
		return
	end
	local color = ctx.color
	local size = math.max(0.6, ctx.scale + 0.3)
	local feet = kit.ground(root.Position)
	local headY = root.Position.Y + 2.6
	-- the halo rising from the feet over the head, narrowing
	local holder, image =
		kit.surfaceAt("ring", CFrame.new(feet + Vector3.new(0, 0.2, 0)), 4.6 * size, lerpWhite(color, 0.25))
	local started = Clock.now()
	local seconds = 0.75
	if holder and image then
		image.ImageTransparency = 0.05
		kit.animate(function(now: number): boolean
			local u = math.clamp((now - started) / seconds, 0, 1)
			local e = 1 - (1 - u) * (1 - u)
			local centre = if root.Parent then root.Position else feet
			local y = feet.Y + 0.2 + (headY + 0.6 - feet.Y) * e
			holder.CFrame = CFrame.new(Vector3.new(centre.X, y, centre.Z))
			local s = 4.6 * size * (1 - 0.45 * e)
			holder.Size = Vector3.new(s, 0.05, s)
			image.ImageTransparency = 0.05 + 0.95 * (u * u)
			if u >= 1 then
				Pool.releaseHolder(holder)
				return true
			end
			return false
		end)
	end
	-- motes spiralling up around the body (plain neon balls: particles cannot orbit)
	local count = if ctx.simple or low() then 4 else 9
	local motes: { BasePart } = {}
	for i = 1, count do
		local mote = Pool.part("Ball", lerpWhite(color, 0.45), Vector3.one * 0.32, Enum.Material.Neon, 0)
		table.insert(motes, mote)
	end
	local spiral = 1.1
	kit.animate(function(now: number): boolean
		local t = now - started
		local centre = if root.Parent then root.Position else feet
		local done = true
		for i, mote in motes do
			local phase = (i / count) * math.pi * 2
			local u = math.clamp((t - (i - 1) * 0.04) / spiral, 0, 1)
			if u < 1 then
				done = false
			end
			local a = phase + u * math.pi * 3
			local r = 1.9 * size * (1 - 0.5 * u)
			local y = feet.Y + 0.3 + (headY + 1.4 - feet.Y) * u
			mote.CFrame = CFrame.new(Vector3.new(centre.X + math.cos(a) * r, y, centre.Z + math.sin(a) * r))
			mote.Transparency = if u <= 0 then 1 else math.clamp((u - 0.6) / 0.4, 0, 1)
			mote.Size = Vector3.one * 0.32 * (1 - 0.5 * u)
		end
		if done then
			for _, mote in motes do
				Pool.release(mote)
			end
			return true
		end
		return false
	end)
	-- a glint over the head when the halo arrives
	Clock.after(seconds * 0.85, function()
		if root.Parent then
			local glint = kit.textured("star", CFrame.new(root.Position + Vector3.new(0, 3.4, 0)))
			if glint then
				kit.burstFrom(glint, "star", lerpWhite(color, 0.5), 1, {
					exact = true,
					lifeMin = 0.3,
					lifeMax = 0.3,
					sizeSeq = NumberSequence.new({ kp(0, 0.5), kp(0.3, 2.6 * size), kp(1, 0) }),
					transparency = NumberSequence.new({ kp(0, 0), kp(1, 1) }),
					rotSpeed = NumberRange.new(120),
					zOffset = 1,
					emission = 1,
				})
			end
		end
	end)
	-- a soft upward glow from the ground
	local lift = kit.textured("glow", CFrame.new(feet + Vector3.new(0, 0.4, 0)))
	if lift then
		kit.burstFrom(lift, "glow", lerpWhite(color, 0.3), if ctx.simple then 3 else 8, {
			simple = ctx.simple,
			to = color,
			spread = 12,
			speedMin = 3,
			speedMax = 6,
			drag = 1,
			lifeMin = 0.6,
			lifeMax = 1,
			sizeSeq = NumberSequence.new({ kp(0, 0.8 * size), kp(1, 0) }),
			transparency = NumberSequence.new({ kp(0, 0.2), kp(1, 1) }),
			area = Vector3.new(2.4 * size, 0.2, 2.4 * size),
			emission = 1,
		})
	end
end

pieces.wkFeathers = function(ctx: Ctx)
	local model = modelOf(ctx)
	local where = if model then kit.centre(model) else ctx.at
	if not where then
		return
	end
	local holder = kit.textured("feather", CFrame.new(where + Vector3.new(0, 4, 0)))
	if not holder then
		return
	end
	kit.burstFrom(holder, "feather", lerpWhite(ctx.color, 0.6), if ctx.simple then 4 else 12, {
		simple = ctx.simple,
		to = ctx.color,
		spread = 70,
		speedMin = 3,
		speedMax = 7,
		drag = 2.5,
		accel = Vector3.new(0, -2.5, 0),
		lifeMin = 1.3,
		lifeMax = 2,
		rotation = NumberRange.new(0, 360),
		rotSpeed = NumberRange.new(-120, 120),
		sizeSeq = NumberSequence.new({ kp(0, 0.6, 0.2), kp(1, 0.5, 0.2) }),
		transparency = NumberSequence.new({ kp(0, 0.1), kp(0.75, 0.2), kp(1, 1) }),
		area = Vector3.new(3, 1, 3),
		emission = 0.8,
	})
end

pieces.wkChains = function(ctx: Ctx)
	local caster, target = ctx.caster, ctx.target
	if not caster or not target or caster == target then
		return
	end
	local a = kit.centre(caster) + Vector3.new(0, 0.6, 0)
	local b = kit.centre(target)
	local length = (b - a).Magnitude
	if length < 1 then
		return
	end
	local dir = (b - a).Unit
	local step = 1.1
	local count = math.clamp(math.floor(length / step), 2, if ctx.simple then 8 else 26)
	local links: { BasePart } = {}
	local hold = math.max(0.5, math.min(ctx.seconds, 1.2))
	for i = 1, count do
		local u = (i - 0.5) / count
		-- a slight sag in the middle
		local sag = Vector3.new(0, -math.sin(u * math.pi) * math.min(1.2, length * 0.05), 0)
		local pos = a:Lerp(b, u) + sag
		local roll = if i % 2 == 0 then math.pi / 2 else 0
		local link = Pool.part("Block", lerpWhite(ctx.color, 0.2), Vector3.new(0.5, 0.18, 0.9), Enum.Material.Neon, 1)
		link.CFrame = CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, 0, roll)
		table.insert(links, link)
		Clock.after(u * 0.15, function()
			if link.Parent then
				link.Transparency = 0.1
			end
		end)
	end
	-- the links burst apart at the end
	Clock.after(0.15 + hold, function()
		for _, link in links do
			if link.Parent then
				local out = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(0, 1), rng:NextNumber(-1, 1)) * 2
				tween(link, 0.3, {
					CFrame = link.CFrame * CFrame.Angles(rng:NextNumber(-2, 2), rng:NextNumber(-2, 2), 0) + out,
					Transparency = 1,
					Size = link.Size * 0.5,
				})
				Pool.later(link, 0.35)
			end
		end
	end)
end

-- A blade or a hammer of light: plain neon parts welded to an invisible anchor that moves.
local function lightWeapon(kind: "sword" | "hammer", color: Color3, scale: number): (BasePart, { BasePart })
	local anchor = Pool.part("Block", color, Vector3.one * 0.2, Enum.Material.Neon, 1)
	local parts: { BasePart } = {}
	local function add(shape: string, size: Vector3, offset: CFrame, transparency: number, tint: Color3)
		local p = Pool.part(shape, tint, size * scale, Enum.Material.Neon, transparency)
		p:SetAttribute("WkOffset", offset)
		table.insert(parts, p)
	end
	local bright = lerpWhite(color, 0.55)
	if kind == "sword" then
		-- pointing down: the blade below the anchor, the guard and the grip above
		add("Block", Vector3.new(0.9, 7, 0.25), CFrame.new(0, -3.5 * scale, 0), 0.15, bright)
		add(
			"Wedge",
			Vector3.new(0.25, 1.2, 0.9),
			CFrame.new(0, -7.6 * scale, 0) * CFrame.Angles(math.pi, math.pi / 2, 0),
			0.15,
			bright
		)
		add("Block", Vector3.new(3, 0.35, 0.45), CFrame.new(0, 0.2 * scale, 0), 0.05, color)
		add("Block", Vector3.new(0.35, 1.6, 0.35), CFrame.new(0, 1.2 * scale, 0), 0.05, color)
		add("Block", Vector3.new(1.6, 9, 0.1), CFrame.new(0, -3.8 * scale, 0), 0.75, color) -- the glow around the blade
	else
		-- head down: the head under the anchor, the haft above
		add("Block", Vector3.new(4.2, 2.4, 2.4), CFrame.new(0, -1.2 * scale, 0), 0.1, bright)
		add("Block", Vector3.new(4.8, 0.5, 2.8), CFrame.new(0, -1.2 * scale, 0), 0.4, color)
		add(
			"Cylinder",
			Vector3.new(7, 0.6, 0.6),
			CFrame.new(0, 3.5 * scale, 0) * CFrame.Angles(0, 0, math.pi / 2),
			0.1,
			color
		)
		add("Block", Vector3.new(5.6, 3.2, 3.2), CFrame.new(0, -1.2 * scale, 0), 0.8, color)
	end
	return anchor, parts
end

local function placeWeapon(anchor: BasePart, parts: { BasePart }, frame: CFrame)
	anchor.CFrame = frame
	for _, p in parts do
		local offset = p:GetAttribute("WkOffset")
		if typeof(offset) == "CFrame" then
			p.CFrame = frame * offset
		end
	end
end

local function dropWeapon(anchor: BasePart, parts: { BasePart }, seconds: number)
	for _, p in parts do
		tween(p, seconds, { Transparency = 1 })
		Pool.later(p, seconds + 0.05)
		p:SetAttribute("WkOffset", nil)
	end
	Pool.later(anchor, seconds + 0.05)
end

-- A weapon of light falling from `height` studs over the ground at `base` in `fall` seconds (accelerating), stuck in
-- the ground for `stay`, then fading upwards.
local function fallingWeapon(
	kind: "sword" | "hammer",
	base: Vector3,
	color: Color3,
	scale: number,
	fall: number,
	stay: number
)
	local anchor, parts = lightWeapon(kind, color, scale)
	local height = 28
	local tilt = CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), rng:NextNumber(0, math.pi * 2), 0)
	local landOffset = if kind == "sword" then 6 * scale else 2.4 * scale
	local started = Clock.now()
	kit.animate(function(now: number): boolean
		if not anchor.Parent then
			return true
		end
		local u = math.clamp((now - started) / math.max(0.05, fall), 0, 1)
		local y = height * (1 - u * u)
		placeWeapon(anchor, parts, CFrame.new(base + Vector3.new(0, landOffset + y, 0)) * tilt)
		if u >= 1 then
			Clock.after(stay, function()
				if anchor.Parent then
					local lift = CFrame.new(base + Vector3.new(0, landOffset + 3, 0)) * tilt
					for _, p in parts do
						local offset = p:GetAttribute("WkOffset")
						if typeof(offset) == "CFrame" then
							tween(p, 0.35, { CFrame = lift * offset })
						end
					end
					dropWeapon(anchor, parts, 0.35)
				end
			end)
			return true
		end
		return false
	end)
end

pieces.wkSkySword = function(ctx: Ctx)
	local where = if ctx.target then kit.centre(ctx.target) else ctx.at
	if not where then
		return
	end
	fallingWeapon("sword", kit.ground(where), ctx.color, math.max(0.7, ctx.scale + 0.3), 0.1, 0.45)
end

-- Starts with the event and lands with the blow (`d` later: SkillVfx.landsAfter, WkFx.FALLS).
pieces.wkSkyHammer = function(ctx: Ctx)
	local at = ctx.at
	if not at then
		return
	end
	local fall = math.max(0.15, ctx.seconds)
	fallingWeapon("hammer", kit.ground(at), ctx.color, math.max(0.8, ctx.scale), fall, 0.3)
end

-- Loops -------------------------------------------------------------------------------------------------------------

-- A part that follows the model's root every frame for `seconds` (then `finish` takes everything down). Returns the
-- part (anchored, invisible) or nil without a root.
local function follower(
	model: Model?,
	seconds: number,
	step: ((root: BasePart, t: number, holder: BasePart) -> ())?,
	finish: () -> ()
): BasePart?
	local root = rootOf(model)
	if not root then
		return nil
	end
	local holder = Pool.part("Block", WHITE, Vector3.new(2.5, 4, 2.5), Enum.Material.SmoothPlastic, 1)
	holder.CFrame = root.CFrame
	local started = Clock.now()
	kit.animate(function(now: number): boolean
		local t = now - started
		if not root.Parent or not holder.Parent or t >= seconds then
			finish()
			if holder.Parent then
				-- emitters stop and their particles live out before the part goes back
				for _, child in holder:GetChildren() do
					if child:IsA("ParticleEmitter") then
						child.Enabled = false
					elseif child:IsA("PointLight") then
						child:Destroy()
						Pool.dropLight()
					end
				end
				Pool.later(holder, 1.6)
			end
			return true
		end
		holder.CFrame = root.CFrame
		if step then
			step(root, t, holder)
		end
		return false
	end)
	return holder
end

-- A rate emitter of a loop on `holder` (none far away / on low quality); the texture when it loaded.
local function loopEmitter(
	holder: BasePart,
	key: string,
	color: Color3,
	rate: number,
	o: { [string]: any }
): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(color, o.to or color)
	e.Rate = rate * (if low() then Config.Vfx.lowParticles else 1)
	e.Lifetime = NumberRange.new(o.lifeMin or 0.6, o.lifeMax or 1.1)
	e.Speed = NumberRange.new(o.speedMin or 1, o.speedMax or 3)
	e.SpreadAngle = Vector2.new(o.spread or 20, o.spread or 20)
	e.Acceleration = o.accel or Vector3.zero
	e.Drag = o.drag or 0
	e.Size = o.sizeSeq or NumberSequence.new(0.4, 0)
	e.Transparency = o.transparency or NumberSequence.new(0.2, 1)
	e.Rotation = o.rotation or NumberRange.new(0)
	e.RotSpeed = o.rotSpeed or NumberRange.new(0)
	e.EmissionDirection = Enum.NormalId.Top
	e.LightEmission = 1
	e.LightInfluence = 0
	e.LockedToPart = false
	if o.orient == "parallel" then
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
	end
	Textures.particle(e, key, o.emission)
	e.Parent = holder
	Clock.track(e)
	return e
end

-- A pulsing light on a loop's holder (the device budget; none on low quality / far away).
local function loopLight(holder: BasePart, color: Color3, range: number): PointLight?
	if low() or not Pool.takeLight() then
		return nil
	end
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = 1
	l.Shadows = false
	l.Parent = holder
	return l
end

-- A rune under the feet that follows and turns, fading in and out. Returns (holder, image) or nil.
local function footRune(key: string, size: number, color: Color3): (BasePart?, ImageLabel?)
	local holder, image = kit.surfaceAt(key, CFrame.new(), size, color)
	if image then
		image.ImageTransparency = 1
	end
	return holder, image
end

local function runLoop(ctx: Ctx, style: "rage" | "holy" | "guard")
	local model = modelOf(ctx)
	local seconds = math.max(1, ctx.seconds)
	local color = ctx.color
	local full = not ctx.simple and not low()
	local rune: BasePart?, runeImage: ImageLabel? = nil, nil
	if style ~= "guard" then
		rune, runeImage = footRune(if style == "rage" then "runeWarrior" else "runeCleric", 5, color)
	end
	local plates: { BasePart } = {}
	if style == "guard" then
		for _ = 1, if full then 3 else 2 do
			local plate = Pool.part("Cylinder", color, Vector3.new(0.15, 1.6, 1.6), Enum.Material.ForceField, 0)
			table.insert(plates, plate)
		end
	end
	local light: PointLight? = nil
	local holder = follower(model, seconds, function(root: BasePart, t: number, _holder: BasePart)
		local fadeIn = math.clamp(t / 0.3, 0, 1)
		local fadeOut = math.clamp((seconds - t) / 0.4, 0, 1)
		local alpha = fadeIn * fadeOut
		if rune and runeImage then
			local feet = root.Position - Vector3.new(0, 2.9, 0)
			rune.CFrame = CFrame.new(feet) * CFrame.Angles(0, t * (if style == "rage" then -0.8 else 0.5), 0)
			local pulse = if style == "rage" then 0.5 + 0.5 * math.abs(math.sin(t * 4)) else 0.7 + 0.3 * math.sin(t * 2)
			runeImage.ImageTransparency = 1 - 0.75 * alpha * pulse
		end
		for i, plate in plates do
			local a = t * 2.4 + (i / #plates) * math.pi * 2
			local pos = root.Position
				+ Vector3.new(math.cos(a) * 2.4, 0.4 + 0.3 * math.sin(t * 3 + i), math.sin(a) * 2.4)
			-- the plate's face (the cylinder's axis) points out from the body
			plate.CFrame = CFrame.lookAt(pos, pos + (pos - root.Position)) * CFrame.Angles(0, math.pi / 2, 0)
			plate.Transparency = 1 - alpha
		end
		local l = light
		if l then
			-- rage: a heartbeat (two beats a second); holy and guard: a slow breath
			local beat = if style == "rage" then math.max(0, math.sin(t * 7)) ^ 4 else 0.5 + 0.5 * math.sin(t * 2.2)
			l.Brightness = (0.6 + 1.4 * beat) * alpha
		end
	end, function()
		if rune then
			Pool.releaseHolder(rune)
		end
		for _, plate in plates do
			Pool.release(plate)
		end
	end)
	if not holder then
		if rune then
			Pool.releaseHolder(rune)
		end
		for _, plate in plates do
			Pool.release(plate)
		end
		return
	end
	if not ctx.simple then
		if style == "rage" then
			loopEmitter(holder, "spark", lerpWhite(color, 0.35), 18, {
				to = color,
				lifeMin = 0.5,
				lifeMax = 0.9,
				speedMin = 3,
				speedMax = 6,
				spread = 30,
				accel = Vector3.new(0, 4, 0),
				drag = 1,
				orient = "parallel",
				sizeSeq = NumberSequence.new({ kp(0, 0.18), kp(1, 0.04) }),
				transparency = NumberSequence.new({ kp(0, 0.1), kp(1, 1) }),
			})
		elseif style == "holy" then
			loopEmitter(holder, "glow", lerpWhite(color, 0.4), 10, {
				to = color,
				lifeMin = 0.9,
				lifeMax = 1.5,
				speedMin = 1,
				speedMax = 2.4,
				spread = 25,
				accel = Vector3.new(0, 1.2, 0),
				drag = 0.6,
				sizeSeq = NumberSequence.new({ kp(0, 0), kp(0.25, 0.45, 0.15), kp(1, 0) }),
				transparency = NumberSequence.new({ kp(0, 0.1), kp(1, 1) }),
			})
		else
			loopEmitter(holder, "glow", lerpWhite(color, 0.4), 5, {
				to = color,
				lifeMin = 0.7,
				lifeMax = 1.1,
				speedMin = 0.5,
				speedMax = 1.5,
				spread = 40,
				sizeSeq = NumberSequence.new({ kp(0, 0.35), kp(1, 0) }),
			})
		end
		light = loopLight(holder, color, if style == "guard" then 8 else 12)
	end
end

pieces.wkRageLoop = function(ctx: Ctx)
	runLoop(ctx, "rage")
end

pieces.wkHolyLoop = function(ctx: Ctx)
	runLoop(ctx, "holy")
end

pieces.wkGuardLoop = function(ctx: Ctx)
	runLoop(ctx, "guard")
end

pieces.wkGroundGlow = function(ctx: Ctx)
	local at = ctx.at or (if ctx.caster then kit.centre(ctx.caster) else nil)
	if not at or ctx.simple then
		return
	end
	local radius = math.max(2, ctx.radius)
	local seconds = math.max(1, ctx.seconds)
	local base = kit.ground(at)
	local holder =
		Pool.part("Block", WHITE, Vector3.new(radius * 1.6, 0.2, radius * 1.6), Enum.Material.SmoothPlastic, 1)
	holder.CFrame = CFrame.new(base + Vector3.new(0, 0.3, 0))
	local e = loopEmitter(holder, "glow", lerpWhite(ctx.color, 0.4), math.clamp(radius * 3, 8, 30), {
		to = ctx.color,
		lifeMin = 1,
		lifeMax = 1.8,
		speedMin = 1.5,
		speedMax = 3.5,
		spread = 10,
		drag = 0.4,
		sizeSeq = NumberSequence.new({ kp(0, 0), kp(0.2, 0.4, 0.15), kp(1, 0) }),
		transparency = NumberSequence.new({ kp(0, 0.15), kp(1, 1) }),
	})
	Clock.after(seconds, function()
		e.Enabled = false
		Pool.later(holder, 1.9)
	end)
end

WkFx.pieces = pieces

-- Pieces that start with the event even when the blow lands `d` later (SkillVfx.landsAfter): the falling hammer.
WkFx.FALLS = { wkSkyHammer = true } :: { [string]: boolean }

function WkFx.has(name: string): boolean
	return pieces[name] ~= nil
end

return WkFx
