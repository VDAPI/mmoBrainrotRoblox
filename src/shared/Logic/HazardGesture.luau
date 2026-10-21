--!strict
-- S159a (owner 2026-10-21, "when it attacks it is wow"): the timing of a caster's gesture for a dodgeable hazard cast
-- (Data/HazardPatterns, Data/BossMotions.patterns). The anticipation runs over the cast's warning and the blow peaks at
-- the release: when the first bolt leaves, the first wave / ring starts running, the breath starts turning, a thrown
-- lob leaves the hand (LOB_FLIGHT before it lands) or a rock called from the sky lands. Projectiles released later (a
-- spiral, a rain of shards, a turning breath) make the gesture hold the blow until the last one (a channel), then the
-- follow-through plays. Pure (Lune): CombatFxController poses by it, Vfx/HazardFx flies the thrown lobs by LOB_FLIGHT,
-- tests/bossgestures.spec checks every boss pattern.

local Hazards = require("./Hazards")

local HazardGesture = {}

-- Seconds a thrown lob (a bomb, a boulder) flies from the caster's hands to its circle; before that it is held up
-- (its circle fills for the whole warning).
HazardGesture.LOB_FLIGHT = 0.75
-- The shortest anticipation a gesture gets (a lob thrown right away still shows the reach back).
HazardGesture.MIN_WINDUP = 0.35
-- The longest channel a gesture holds the blow for.
HazardGesture.MAX_HOLD = 3
-- Lob looks that fall from the sky (the rest are thrown from the hands).
HazardGesture.SKY = table.freeze({ meteor = true, iceShard = true })
-- The most a gesture turns the body over a channel (radians): a spiral turns with its shots, a breath with its cone.
HazardGesture.MAX_TURN = math.pi

export type Timing = {
	windup: number, -- seconds from the cast to the blow (the release)
	hold: number, -- seconds the blow is held after it (a channel)
	release: number, -- seconds from the cast to the first release
	last: number, -- seconds from the cast to the last release
}

-- Whether lobs of `look` are thrown (false: they fall from the sky).
function HazardGesture.thrown(look: string): boolean
	return not HazardGesture.SKY[look]
end

-- Seconds a thrown lob with `delay` s from its warning to its landing flies (the rest it is held).
function HazardGesture.flight(delay: number): number
	return math.min(HazardGesture.LOB_FLIGHT, math.max(0.05, delay))
end

local function num(v: number?, default: number): number
	return if v == nil then default else v
end

-- The first and the last release of one emitter of `pattern` in a cast whose least warning is `w`.
local function releases(pattern: Hazards.Pattern, e: Hazards.Emitter, w: number): (number, number)
	local delay = math.max(w, num(e.delay, Hazards.MIN_WARN))
	local count = math.max(1, math.floor(num(e.count, 1)))
	local shots = math.max(1, math.floor(num(e.shots, 1)))
	local every = num(e.every, 0)
	local kind = e.kind
	if kind == "bolt" then
		return delay, delay + (shots - 1) * every
	elseif kind == "lob" then
		-- Hazards.expand: lob k of shot s of a set starts its warning at ((s - 1) * count + (k - 1)) * every
		local spread = (shots * count - 1) * every
		local look = e.look or pattern.look
		local lead = if HazardGesture.thrown(look) then HazardGesture.flight(delay) else 0
		return delay - lead, delay + spread - lead
	elseif kind == "ring" then
		return delay, delay + (shots * count - 1) * every
	elseif kind == "sweep" then
		return delay, delay + num(e.seconds, 2)
	end
	return delay, delay -- wave: every front starts at once
end

-- The gesture's timing for a cast of `pattern` whose least warning is `w` (the event's `d`: a boss attack's windup,
-- an ambient pattern's own warning).
function HazardGesture.timing(pattern: Hazards.Pattern, w: number?): Timing
	local least = math.max(0, w or 0)
	local first, last = math.huge, 0
	for _, e in pattern.emitters do
		local a, b = releases(pattern, e, least)
		first = math.min(first, a)
		last = math.max(last, b)
	end
	if first == math.huge then
		first, last = least, least
	end
	local windup = math.max(HazardGesture.MIN_WINDUP, first)
	return {
		windup = windup,
		hold = math.clamp(last - windup, 0, HazardGesture.MAX_HOLD),
		release = first,
		last = last,
	}
end

-- The body turn over a cast's channel as Gait ry offsets (ry > 0 turns the front to the left, i.e. a smaller Hazards
-- angle): (from, to), or nil when the gesture does not turn. A breath (the first sweep of `insts`) turns with its
-- cone from where it starts to where it ends, relative to `facing` (the model's Hazards angle now); a spiral (bolts
-- with `turn`) turns by its own angle over its shots. Both within MAX_TURN.
function HazardGesture.turnOf(pattern: Hazards.Pattern, insts: { Hazards.Inst }, facing: number): (number?, number?)
	for _, inst in insts do
		if inst.kind == "sweep" then
			local from = -Hazards.wrap(inst.a + inst.from - facing)
			local to = -Hazards.wrap(inst.a + inst.to - facing)
			local cap = HazardGesture.MAX_TURN
			return math.clamp(from, -cap, cap), math.clamp(to, -cap, cap)
		end
	end
	for _, e in pattern.emitters do
		local shots = math.max(1, math.floor(num(e.shots, 1)))
		if e.kind == "bolt" and shots > 1 and (e.turn or 0) ~= 0 then
			local total = math.rad(e.turn :: number) * (shots - 1)
			return 0, -math.clamp(total, -HazardGesture.MAX_TURN, HazardGesture.MAX_TURN)
		end
	end
	return nil, nil
end

-- A Roblox look vector's Hazards angle (x / z plane).
function HazardGesture.facing(lookX: number, lookZ: number): number
	return Hazards.angleTo(0, 0, lookX, lookZ)
end

return HazardGesture
