--!strict
-- W30 (walka-lm): the ranged basic attacks of the Hunter and the Mage (CombatFxController.attackFx): what happens where
-- the shot leaves (`release`) and where it lands (`arrive`), by the motion (Data/AttackMotions: bow, crossbow, wand,
-- staff) and the weapon's element. A bow's string snaps a small ring of air and sheds a puff of dust, a crossbow kicks
-- a burst of sparks and a ring, a wand flicks a small disc of its colour, a staff a bigger one with motes; an arrow's
-- hit throws wood splinters back, a bolt's sparks and a chip of iron, a spell's hit bursts by its element (fire: embers
-- and a hot pop, ice: chips of ice, lightning: small arcs, poison: drops, none: a ring of force). The projectiles
-- themselves (and their trails) stay in CombatFxController. Looks only; `simple` (far away or low quality) keeps the
-- core of each. Vfx/LmKit parts on the effect clock.

local Library = require(script.Parent.Library)
local LmKit = require(script.Parent.LmKit)

local kit = Library.kit
local kp = kit.kp
local rng = LmKit.rng
local WHITE = LmKit.WHITE

local LmShots = {}

type Body = LmKit.Body

local STAFF_SCALE = 1.45 -- a staff's release and hit against a wand's
local DUST = Color3.fromHex("#C8B89A")

local function direction(from: Vector3, to: Vector3): Vector3
	return LmKit.unitOr(to - from, Vector3.new(0, 0, -1))
end

-- Where the shot leaves the weapon. `kind`: "arrow" | "bolt" | "magic"; `motion`: the AttackMotions motion.
function LmShots.release(kind: string, motion: string, from: Vector3, to: Vector3, color: Color3, simple: boolean)
	local dir = direction(from, to)
	if kind == "arrow" then
		LmKit.shockDisc(LmKit.facingDisc(from + dir * 0.3, dir), 0.2, 1.4, WHITE, 0.14, 0.05)
		if not simple then
			local holder = kit.textured("dust", CFrame.new(from))
			if holder then
				kit.burstFrom(holder, "dust", DUST, 4, {
					spread = 60,
					speedMin = 1,
					speedMax = 3,
					drag = 4,
					lifeMin = 0.25,
					lifeMax = 0.45,
					sizeSeq = NumberSequence.new({ kp(0, 0.3), kp(1, 0.8) }),
					transparency = NumberSequence.new({ kp(0, 0.5), kp(1, 1) }),
					emission = 0,
				})
			end
		end
	elseif kind == "bolt" then
		LmKit.shockDisc(LmKit.facingDisc(from + dir * 0.4, dir), 0.3, 1.8, Color3.fromHex("#FFE0A0"), 0.12)
		if not simple then
			local holder = kit.textured("spark", kit.facingFrame(from, dir))
			if holder then
				kit.burstFrom(holder, "spark", Color3.fromHex("#FFE0A0"), 6, {
					to = Color3.fromHex("#FF9A3A"),
					direction = Enum.NormalId.Front,
					spread = 25,
					speedMin = 18,
					speedMax = 30,
					drag = 6,
					lifeMin = 0.06,
					lifeMax = 0.14,
					orient = "parallel",
					sizeSeq = NumberSequence.new({ kp(0, 0.16), kp(1, 0.03) }),
					emission = 1,
				})
			end
		end
	else
		local s = if motion == "staff" then STAFF_SCALE else 1
		LmKit.shockDisc(LmKit.facingDisc(from + dir * 0.3, dir), 0.2, 1.6 * s, color, 0.16)
		local pop = LmKit.part("Ball", color:Lerp(WHITE, 0.5), Vector3.one * 0.3 * s, LmKit.NEON, 0)
		pop.CFrame = CFrame.new(from)
		LmKit.fadeOut(pop, 0.1, { Size = Vector3.one * 1.1 * s })
		if motion == "staff" and not simple then
			-- motes thrown off the head of the staff
			for i = 1, 3 do
				local a = i / 3 * math.pi * 2
				local side = LmKit.unitOr(dir:Cross(Vector3.yAxis), Vector3.xAxis)
				local up = LmKit.unitOr(side:Cross(dir), Vector3.yAxis)
				local mote = LmKit.part("Ball", color:Lerp(WHITE, 0.3), Vector3.one * 0.18, LmKit.NEON, 0)
				mote.CFrame = CFrame.new(from)
				local out = from + (side * math.cos(a) + up * math.sin(a)) * 1.1 + dir * 0.8
				LmKit.fadeOut(mote, 0.22, { CFrame = CFrame.new(out) })
			end
		end
	end
end

-- Where the shot lands (`at`), flying along `dir`. `element` = the weapon's element (Data/Elements), nil for none.
function LmShots.arrive(
	kind: string,
	motion: string,
	at: Vector3,
	dir: Vector3,
	color: Color3,
	element: string?,
	simple: boolean
)
	local back = -LmKit.unitOr(dir, Vector3.new(0, 0, -1))
	local floor = kit.ground(at).Y + 0.1
	local function throw(n: number, make: () -> BasePart, speed: number, life: number, gravity: number)
		local bodies: { Body } = {}
		for _ = 1, LmKit.amount(n, simple) do
			local vel = (back * 0.8 + Vector3.new(
				rng:NextNumber(-0.9, 0.9),
				rng:NextNumber(0.3, 1.2),
				rng:NextNumber(-0.9, 0.9)
			)).Unit * speed * rng:NextNumber(0.6, 1)
			table.insert(bodies, {
				p = make(),
				pos = at,
				vel = vel,
				rot = LmKit.randomRot(),
				spin = LmKit.spinVec(16),
				floor = floor,
				life = life,
				bounce = 0.25,
			})
		end
		LmKit.ballistic(bodies, gravity)
	end
	if kind == "arrow" then
		throw(4, function()
			return LmKit.part(
				"Block",
				LmKit.WOOD,
				Vector3.new(0.06, 0.06, rng:NextNumber(0.25, 0.5)),
				Enum.Material.Wood,
				0
			)
		end, 14, 0.6, 50)
		return
	elseif kind == "bolt" then
		throw(3, function()
			return LmKit.part("Block", LmKit.STEEL, Vector3.one * rng:NextNumber(0.1, 0.18), Enum.Material.Metal, 0)
		end, 12, 0.5, 50)
		if not simple then
			Library.sparks(at, Color3.fromHex("#FFE0A0"), { count = 6, dir = back + Vector3.new(0, 0.5, 0) })
		end
		return
	end
	local s = if motion == "staff" then STAFF_SCALE else 1
	if element == "fire" then
		local hot = LmKit.part("Ball", color:Lerp(Color3.fromHex("#FFE08A"), 0.5), Vector3.one * 0.6 * s, LmKit.NEON, 0)
		hot.CFrame = CFrame.new(at)
		LmKit.fadeOut(hot, 0.18, { Size = Vector3.one * 2.4 * s })
		if not simple then
			local holder = kit.textured("spark", CFrame.new(at))
			if holder then
				kit.burstFrom(holder, "spark", color:Lerp(Color3.fromHex("#FFD27A"), 0.5), 8, {
					to = color,
					spread = 80,
					speedMin = 4,
					speedMax = 10,
					accel = Vector3.new(0, 6, 0),
					drag = 1.5,
					lifeMin = 0.4,
					lifeMax = 0.8,
					orient = "parallel",
					sizeSeq = NumberSequence.new({ kp(0, 0.14 * s), kp(1, 0.02) }),
					emission = 1,
				})
			end
		end
	elseif element == "ice" then
		throw(4, function()
			return LmKit.part(
				"Block",
				LmKit.ICE:Lerp(color, 0.3),
				Vector3.one * rng:NextNumber(0.15, 0.3) * s,
				LmKit.GLASS,
				0.05
			)
		end, 11, 0.55, 45)
		LmKit.shockDisc(LmKit.facingDisc(at, back), 0.3, 2 * s, color, 0.18)
	elseif element == "lightning" then
		if not simple then
			for _ = 1, 2 do
				local to = at
					+ Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1)).Unit * 2 * s
				LmKit.segments(LmKit.jagged(at, to, 3, 0.4), color, 0.07, 0.1, false)
			end
		end
		local pop = LmKit.part("Ball", color:Lerp(WHITE, 0.6), Vector3.one * 0.4 * s, LmKit.NEON, 0)
		pop.CFrame = CFrame.new(at)
		LmKit.fadeOut(pop, 0.08, { Size = Vector3.one * 1.8 * s })
	elseif element == "poison" then
		local bodies: { Body } = {}
		for _ = 1, LmKit.amount(4, simple) do
			local ang = rng:NextNumber(0, math.pi * 2)
			table.insert(bodies, {
				p = LmKit.part("Ball", color, Vector3.one * rng:NextNumber(0.15, 0.28) * s, LmKit.GLASS, 0.15),
				pos = at,
				vel = Vector3.new(math.cos(ang) * 5, rng:NextNumber(5, 9), math.sin(ang) * 5),
				rot = CFrame.identity,
				spin = Vector3.zero,
				floor = floor,
				life = 0.6,
				bounce = 0,
			})
		end
		LmKit.ballistic(bodies, 40)
	else
		LmKit.shockDisc(LmKit.facingDisc(at, back), 0.4, 2.4 * s, color, 0.2)
	end
	if motion == "staff" and not simple then
		LmKit.shockDisc(LmKit.discFrame(kit.ground(at) + Vector3.new(0, 0.15, 0)), 0.5, 3.2, color, 0.3)
	end
end

return LmShots
