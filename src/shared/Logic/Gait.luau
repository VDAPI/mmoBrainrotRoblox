--!strict
-- Procedural poses for placeholder monster rigs (no animation assets). RigBuilder joins the limbs with
-- Motor6Ds named "Gait_<part>" carrying the attributes Role, Side, Phase and Amp; the client
-- (AnimationController) turns the monster's movement and combat events into a Motion every frame and asks
-- this module for each joint's rotation and offset. Pure numbers only, so it runs in Lune.
-- S117 (DESIGN-16 §8, docs/ANIMACJE.md "Potwory i bossowie w walce"): attack styles by body plan (Data/MonsterMotions,
-- offsets per role on top of the walk / idle pose), a gather curve for telegraphed attacks (`charge`: the blow peaks
-- exactly at the end of the windup, when the server deals the damage and the telegraph flashes), the same timing for
-- basic attacks (`attack`), the phase roar, the climb of a summoned helper out of the ground, the flight of a dragon,
-- deaths by plan and a hit pushing the body away from the attacker (`hitLean`). Without a style and the new fields the
-- pose is exactly the one before S117 (tests/gait.spec).

local Config = require("../Config")
local MonsterMotions = require("../Data/MonsterMotions")

local Gait = {}

-- S24 adds: flap (wings of the generated looks), segment (a wave along a chain: serpents, tails, trunks),
-- claw (pincers open in the windup), sting (a tail strikes forward), jaw (opens to bite), orbit (slow turn
-- around Y: shards, skulls). Every role is at rest (all zeros) for the rest motion (time 0, nothing going on);
-- the continuous ones fade in over the first second of `time`, which in game is never near 0.
export type Role =
	"body"
	| "leg"
	| "spiderLeg"
	| "arm"
	| "head"
	| "tail"
	| "wing"
	| "flap"
	| "segment"
	| "claw"
	| "sting"
	| "jaw"
	| "orbit"

Gait.ROLES = {
	"body",
	"leg",
	"spiderLeg",
	"arm",
	"head",
	"tail",
	"wing",
	"flap",
	"segment",
	"claw",
	"sting",
	"jaw",
	"orbit",
}

export type Joint = {
	role: Role,
	side: number, -- -1 left, 1 right, 0 centre
	phase: number, -- 0..1 offset in the walk cycle
	amp: number, -- amplitude multiplier (1 = default; body: hover height for flyers)
	front: number?, -- S117: 1 a front limb, -1 a hind one, 0 / nil the middle (attribute Front, Util/LookBuild)
}

export type Motion = {
	cycle: number, -- walk cycle angle (radians), advanced by Gait.advance
	move: number, -- 0..1 how much the monster is walking
	time: number, -- seconds, for idle motion (already offset per monster)
	raise: number, -- 0..1 attack windup (limb raised / head reared)
	strike: number, -- 0..1 attack strike (lunge / bite)
	hit: number, -- 0..1 flinch after taking damage
	dead: number, -- 0..1 collapse progress
	-- S117 (all optional: nil / 0 = the pose before S117)
	style: string?, -- Data/MonsterMotions.STYLES key of the running attack
	tremble: number?, -- 0..1 shaking of a long windup (grows like the telegraph fill)
	hop: number?, -- 0..1 the visual jump of the blow (Gait.hopOf)
	spin: number?, -- 0..1 progress of the turn of a whirlwind (Gait.spinOf)
	roar: number?, -- 0..1 envelope of the phase roar (Gait.roarEnvelope)
	roarStyle: string?, -- the roar's style (default "roar")
	rise: number?, -- 0..1 climbing out of the ground (1 = on the ground, 0 = under it); nil = on the ground
	deathStyle: string?, -- Data/MonsterMotions.DEATH key
	deathSide: number?, -- -1 / 1: the side the seed picked for the death's `flip`
	hover: number?, -- studs at scale 1 a floating plan hovers (a `fall` death drops them)
	hitX: number?, -- the push of the last hit in the model's frame (from the attacker; length 1, bosses less)
	hitZ: number?,
	plan: string?, -- the body plan (Data/MonsterMotions.PLANS hit reaction)
	flying: number?, -- 0..1 a dragon in the air (wings beat wide and fast, legs tucked)
}

-- Rotation in radians around the joint's X, Y, Z and offset in studs at scale 1 (the caller scales it).
export type Pose = { rx: number, ry: number, rz: number, x: number, y: number, z: number }

-- Attack timing (seconds). S117: the strike takes the last STRIKE_SECONDS of the windup and peaks at its end (the
-- server's hit), the recovery follows.
Gait.STRIKE_SECONDS = 0.14
Gait.RECOVER_SECONDS = 0.35
Gait.DEFAULT_WINDUP = 0.22
-- S117: a basic attack's event arrives with its damage; the blow peaks this long after it (MonsterAttack strikeNow).
Gait.STRIKE_NOW_LEAD = 0.03
-- S117: the visual jump of a pounce / slam lasts this long and lands at the hit; a summoned helper starts this deep.
Gait.HOP_SECONDS = 0.3
Gait.RISE_DEPTH = 3
-- S117: the strike overshoots a little in the recovery (follow-through), then settles.
Gait.OVERSHOOT = 0.12
-- S110: reaction lengths shared by AnimationController, MobVizController and AnimLab (the same values as before).
Gait.HIT_SECONDS = 0.25 -- the flinch after taking damage fades over this
Gait.DEATH_SECONDS = Config.MonsterLook.deathSeconds -- the collapse (S117: 0.55 -> 0.8, a death by plan)
Gait.SPAWN_SECONDS = 0.55 -- the collapse played backwards when a preview "spawns"
-- S110: default speeds of the walk / run states (studs per second).
Gait.WALK_SPEED = 8
Gait.RUN_SPEED = 16
-- Stride length (studs at scale 1): one full cycle covers this distance.
Gait.STRIDE = 4.5

local TAU = 2 * math.pi
local TREMBLE_SPEED = 40 -- rad/s of the windup shake
local ROAR_IN, ROAR_OUT = 0.25, 0.4 -- seconds of the roar envelope's rise and fall

local function smooth(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Advances the walk cycle by the distance travelled; bigger monsters take longer strides.
function Gait.advance(cycle: number, dt: number, speed: number, scale: number): number
	local stride = Gait.STRIDE * math.max(scale, 0.2)
	return (cycle + dt * speed / stride * TAU) % TAU
end

-- The common shape of attacks: the gather until the strike starts (windup - STRIKE_SECONDS), the strike up to the end
-- of the windup (it peaks there: the server's hit), the recovery with a little overshoot.
local function shape(elapsed: number, windup: number, gather: (number, number) -> number): (number, number)
	if elapsed < 0 then
		return 0, 0
	end
	windup = math.max(windup, 0.05)
	local from = math.max(0, windup - Gait.STRIKE_SECONDS)
	if elapsed < from then
		return gather(elapsed, windup), 0
	end
	if elapsed <= windup then
		local held = if from > 0 then gather(from, windup) else 1
		local k = if windup > from then (elapsed - from) / (windup - from) else 1
		return held * (1 - k * 0.8), k
	end
	local t = elapsed - windup
	if t < Gait.RECOVER_SECONDS then
		local k = t / Gait.RECOVER_SECONDS
		local held = if from > 0 then gather(from, windup) else 1
		return 0.2 * held * (1 - smooth(k)), 1 - smooth(k) + Gait.OVERSHOOT * math.sin(math.pi * k) * (1 - k)
	end
	return 0, 0
end

-- The gather of a basic attack (smooth up to the start of the strike) and of a telegraphed one (S117).
local function gatherBasic(e: number, w: number): number
	local from = math.max(0, w - Gait.STRIKE_SECONDS)
	return if from > 0 then smooth(e / from) else 1
end

local function gatherCharge(e: number, w: number): number
	local p = math.clamp(e / w, 0, 1)
	return 1 - (1 - p) * (1 - p)
end

-- Attack curve after `elapsed` seconds: (raise, strike), both 0..1 (the strike a little over 1 right after the hit).
-- The limb rises during the windup, snaps forward in its last STRIKE_SECONDS, peaks at `windup` and settles back
-- (S117: before, the peak came STRIKE_SECONDS after the windup, i.e. after the server's hit). Zeros before and after.
function Gait.attack(elapsed: number, windup: number): (number, number)
	return shape(elapsed, windup, gatherBasic)
end

-- S117: the gather of a telegraphed attack (Elite II, bosses) after `elapsed` seconds of `windup`: (raise, strike,
-- tremble). raise = 1 - (1 - p)^2 (the silhouette is readable within the first 0.3 s, then held), tremble = p^2 (it grows
-- like the telegraph's fill), the strike in the last STRIKE_SECONDS peaks at exactly `windup` (the telegraph's flash).
function Gait.charge(elapsed: number, windup: number): (number, number, number)
	local raise, strike = shape(elapsed, windup, gatherCharge)
	local w = math.max(windup, 0.05)
	local tremble = if elapsed >= 0 and elapsed <= w then (elapsed / w) ^ 2 else 0
	return raise, strike, tremble
end

-- Total length of an attack with the given windup (S117: the strike is inside the windup).
function Gait.attackLength(windup: number): number
	return math.max(windup, 0.05) + Gait.RECOVER_SECONDS
end

-- S117: the visual jump of a pounce / slam: up and down over the last HOP_SECONDS of the windup, landing at the hit.
function Gait.hopOf(elapsed: number, windup: number): number
	local w = math.max(windup, 0.05)
	local length = math.min(Gait.HOP_SECONDS, w)
	local k = (elapsed - (w - length)) / length
	if k <= 0 or k >= 1 then
		return 0
	end
	return math.sin(math.pi * k)
end

-- S117: the progress of a whirlwind's turn: from the start of the strike to the end of the recovery (eased).
function Gait.spinOf(elapsed: number, windup: number): number
	local w = math.max(windup, 0.05)
	local from = math.max(0, w - Gait.STRIKE_SECONDS)
	local k = (elapsed - from) / (w + Gait.RECOVER_SECONDS - from)
	if k <= 0 or k >= 1 then
		return 0
	end
	return smooth(k)
end

-- S117: the envelope of a roar `t` seconds in, lasting `seconds`: up in 0.25 s, held, down in the last 0.4 s.
function Gait.roarEnvelope(t: number, seconds: number): number
	if t < 0 or t >= seconds then
		return 0
	end
	local up = math.min(1, t / ROAR_IN)
	local down = math.min(1, (seconds - t) / ROAR_OUT)
	return smooth(math.min(up, down))
end

-- S117: how far a summoned helper has climbed out of the ground `t` seconds into a climb of `seconds` (0 under it, 1 on
-- the ground); the game and AnimLab both use it.
function Gait.riseOf(t: number, seconds: number): number
	return smooth(t / math.max(0.05, seconds))
end

-- S117: the point of a visual leap at k (0..1) from `from` to `to` ({ x, y, z }), `height` studs over the straight
-- line at the middle.
function Gait.leapArc(k: number, from: { number }, to: { number }, height: number): (number, number, number)
	k = math.clamp(k, 0, 1)
	local lift = 4 * height * k * (1 - k)
	return from[1] + (to[1] - from[1]) * k, from[2] + (to[2] - from[2]) * k + lift, from[3] + (to[3] - from[3]) * k
end

-- S117: the push of a hit on the body: (rx, rz, x, z) away from the attacker. `hitX`, `hitZ`: the push in the model's
-- frame (from the attacker to the monster; z > 0 = backwards, i.e. a blow from the front), `hit` the flinch 0..1, `plan`
-- the body plan (Data/MonsterMotions.PLANS hit, else Config.MonsterLook.hitLean / hitPush). A blow from the front leans
-- the body back (rx > 0), one from the right pushes it left (rz > 0 tilts the top to -X).
function Gait.hitLean(hitX: number, hitZ: number, hit: number, plan: string?): (number, number, number, number)
	local entry = if plan then MonsterMotions.PLANS[plan] else nil
	local react = entry and entry.hit
	local lean = (react and react.lean) or Config.MonsterLook.hitLean
	local push = (react and react.push) or Config.MonsterLook.hitPush
	return hitZ * lean * hit, -hitX * lean * hit, hitX * push * hit, hitZ * push * hit
end

local function headTurn(plan: string?): number
	local entry = if plan then MonsterMotions.PLANS[plan] else nil
	local react = entry and entry.hit
	return (react and react.head) or 0.2
end

local function pose(rx: number, ry: number, rz: number, x: number, y: number, z: number): Pose
	return { rx = rx, ry = ry, rz = rz, x = x, y = y, z = z }
end

-- The generic attack terms of a joint are replaced when the style lists its role (S117).
local function owns(style: MonsterMotions.Style, joint: Joint): boolean
	local role = joint.role
	if (role == "leg" or role == "spiderLeg") and (joint.front or 0) < 0 then
		return style.hindWindup ~= nil or style.hindStrike ~= nil
	end
	if role == "arm" and joint.side < 0 and style.left then
		return true
	end
	return style.windup[role] ~= nil or style.strike[role] ~= nil
end

-- Adds `k` x the offset `o` ({ rx, ry, rz, x, y, z }, right-side convention) to `p`, mirrored for the left side.
local function add(p: Pose, o: MonsterMotions.RolePose?, k: number, side: number)
	if not o or k == 0 then
		return
	end
	local m = if side < 0 then -1 else 1
	p.rx += (o[1] or 0) * k
	p.ry += (o[2] or 0) * k * m
	p.rz += (o[3] or 0) * k * m
	p.x += (o[4] or 0) * k * m
	p.y += (o[5] or 0) * k
	p.z += (o[6] or 0) * k
end

-- The style's offset of a joint at (raise, strike): its entry (hind legs, the left arm), shared by `arms`.
local function addStyle(p: Pose, style: MonsterMotions.Style, joint: Joint, raise: number, strike: number, k: number)
	local role = joint.role
	local front = joint.front or 0
	local w: MonsterMotions.RolePose?, s: MonsterMotions.RolePose?
	local shared = false
	if (role == "leg" or role == "spiderLeg") and front < 0 then
		w, s = style.hindWindup, style.hindStrike
	elseif role == "arm" and joint.side < 0 and style.left then
		w, s = style.left.windup, style.left.strike
	else
		w, s = style.windup[role], style.strike[role]
		shared = role == "arm" or (role == "leg" and front > 0)
	end
	local shareW, shareS = 1, 1
	if shared then
		local arms = style.arms or "both"
		local right = joint.side >= 0
		if arms == "right" then
			shareW = if right then 1 else 0.3
			shareS = shareW
		elseif arms == "alt" then
			shareW = if right then 1 else 0.3
			shareS = if right then 0.3 else 1
		end
	end
	add(p, w, raise * shareW * k, joint.side)
	add(p, s, strike * shareS * k, joint.side)
end

-- A death style's offset at `dead` (0..1).
local function addDeath(p: Pose, def: MonsterMotions.DeathStyle, joint: Joint, m: Motion)
	local role = joint.role
	local d = m.dead
	local final = def.pose[role]
	local early = def.early and def.early[role]
	local sign = if (m.deathSide or 1) < 0 then -1 else 1
	local function flipped(o: MonsterMotions.RolePose?): MonsterMotions.RolePose?
		if not o or role ~= "body" or not def.flip then
			return o
		end
		local copy = table.clone(o)
		if def.flip == "rz" then
			copy[3] = (copy[3] or 0) * sign
		else
			copy[1] = (copy[1] or 0) * sign
		end
		return copy
	end
	if def.early then
		local split = math.clamp(def.split or 0.5, 0.05, 0.95)
		local k1 = smooth(d / split)
		local k2 = smooth((d - split) / (1 - split))
		add(p, flipped(early), k1 * (1 - k2), joint.side)
		add(p, flipped(final), k2, joint.side)
	else
		add(p, flipped(final), smooth(d), joint.side)
	end
	if role == "body" and def.hoverDrop then
		p.y -= (m.hover or 0) * smooth(d)
	end
end

function Gait.pose(joint: Joint, m: Motion): Pose
	local amp = joint.amp
	local swing = math.sin(m.cycle + joint.phase * TAU)
	local alive = 1 - m.dead
	local idle = 1 - m.move
	local role = joint.role
	-- S117: a style takes over the attack of the roles it lists, a death style the collapse, a directional hit the lean
	local style = if m.style then MonsterMotions.STYLES[m.style] else nil
	local styled = style ~= nil and owns(style :: MonsterMotions.Style, joint)
	local raise = if styled then 0 else m.raise
	local strike = if styled then 0 else m.strike
	local deathDef = if m.deathStyle then MonsterMotions.DEATH[m.deathStyle] else nil
	local dead = if deathDef then 0 else m.dead
	local directional = (m.hitX or 0) ~= 0 or (m.hitZ or 0) ~= 0
	local flying = m.flying or 0

	local p: Pose
	if role == "body" then
		-- Breathing bob (or hovering for flyers), a lean into the strike, a flinch when hit, then the collapse.
		local hit = if directional then 0 else m.hit
		local hover = if amp > 1 then amp - 1 else 0
		local bob = math.sin(m.time * 2) * 0.05 + math.sin(m.time * 1.6) * hover
		local step = math.abs(swing) * 0.08 * m.move
		local lean = -strike * 0.14 + raise * 0.06 + hit * 0.12
		p = pose(lean * alive, 0, dead * 1.35, 0, (bob + step) * alive - dead * 0.4, -strike * 0.5 * alive + hit * 0.15)
	elseif role == "leg" then
		local walk = swing * 0.65 * amp * m.move
		p = pose(walk * alive + dead * 0.5, 0, 0, 0, 0, 0)
	elseif role == "spiderLeg" then
		-- Legs stick out sideways: swing forward/back around Y, lift around Z.
		local lift = math.max(0, math.cos(m.cycle + joint.phase * TAU)) * 0.35 * m.move
		local twitch = math.sin(m.time * 9 + joint.phase * TAU) * 0.04 * idle
		p = pose(
			0,
			swing * 0.4 * amp * m.move * alive,
			joint.side * (lift + twitch) * alive + joint.side * dead * 0.6,
			0,
			0,
			0
		)
	elseif role == "arm" then
		-- Arms swing against the legs; the right arm (side 1) carries the attack, the left follows a little.
		local walk = -swing * 0.5 * amp * m.move
		local share = if joint.side > 0 then 1 else 0.3
		local attack = (raise * 2.3 - strike * 0.5 * (1 - raise)) * share
		local sway = math.sin(m.time * 1.8 + joint.side) * 0.04 * idle
		p = pose((walk + attack + sway) * alive, 0, joint.side * (0.05 + raise * 0.15 * share) * alive, 0, 0, 0)
	elseif role == "head" then
		-- Looks around while idle, rears up in the windup, bites down on the strike.
		local look = math.sin(m.time * 0.7) * 0.25 * idle
		local nod = math.sin(m.cycle * 2) * 0.05 * m.move
		local rx = raise * 0.45 - strike * 0.55 + nod - m.hit * 0.2
		p = pose(rx * alive - dead * 0.3, look * alive, 0, 0, 0, 0)
	elseif role == "tail" then
		local wag = math.sin(m.time * 2.4) * 0.35 + math.sin(m.cycle) * 0.25 * m.move
		p = pose(math.sin(m.time * 1.3) * 0.08 * alive, wag * amp * alive, 0, 0, 0, 0)
	elseif role == "flap" then
		-- Generated wings: quick beats while moving or attacking, slow ones while hovering; folded when dead.
		local ramp = math.clamp(m.time, 0, 1)
		local busy = math.max(m.move, raise, flying)
		local speed = 5 + 7 * busy
		local width = 0.32 + 0.3 * busy + 0.2 * flying
		local beat = math.sin(m.time * speed) * width * ramp
		p = pose(0, 0, joint.side * (beat * amp * alive - dead * 0.7), 0, 0, 0)
	elseif role == "segment" then
		-- A wave runs along the chain (phase = position in it); the chain whips forward on a strike.
		local ramp = math.clamp(m.time, 0, 1)
		local speed = 1.6 + 2.4 * m.move
		local wave = math.sin(m.time * speed - joint.phase * TAU) * 0.28 * amp * ramp
		p = pose((-strike * 0.25 + raise * 0.12) * amp * alive, wave * alive, 0, 0, 0, 0)
	elseif role == "claw" then
		-- Pincers open in the windup and snap shut on the strike.
		p = pose((-raise * 0.6 + strike * 0.25) * alive, 0, 0, 0, 0, 0)
	elseif role == "sting" then
		-- The tail curls back in the windup and stabs forward on the strike.
		local ramp = math.clamp(m.time, 0, 1)
		local sway = math.sin(m.time * 1.5 + joint.phase * TAU) * 0.05 * idle * ramp
		p = pose((raise * 0.35 - strike * 0.85) * amp * alive, sway * alive, 0, 0, 0, 0)
	elseif role == "jaw" then
		-- Opens wide in the windup, bites on the strike, gapes when dead.
		local open = raise * 0.5 + strike * 0.15 * (1 - raise) + m.hit * 0.15
		p = pose(-open * amp * alive - dead * 0.35, 0, 0, 0, 0, 0)
	elseif role == "orbit" then
		-- Slow turn around Y (keeps turning after death, slower).
		local ramp = math.clamp(m.time, 0, 1)
		local angle = (m.time * (0.8 - m.dead * 0.5) * amp) % TAU
		p = pose(0, angle * ramp, 0, 0, 0, 0)
	elseif role == "wing" then
		-- Faster, wider flaps while moving or attacking; folded when dead.
		local busy = math.max(m.move, raise, flying)
		local speed = 3 + 4 * busy
		local width = 0.3 + 0.25 * busy
		local flap = 0.15 + math.sin(m.time * speed) * width
		p = pose(0, 0, joint.side * flap * amp * alive - joint.side * dead * 0.6, 0, 0, 0)
	else
		p = pose(0, 0, 0, 0, 0, 0)
	end

	-- S117 additions (each zero without its field)
	if style and alive > 0 then
		addStyle(p, style :: MonsterMotions.Style, joint, m.raise, m.strike, alive)
		local tremble = (m.tremble or 0) * (style.tremble or 0)
		if tremble > 0 and (role == "body" or role == "arm" or role == "head") then
			local shake = math.sin(m.time * TREMBLE_SPEED + joint.side) * tremble * alive
			p.rx += shake
			if role == "body" then
				p.rz += math.sin(m.time * TREMBLE_SPEED * 1.3) * tremble * 0.6 * alive
			end
		end
		if role == "body" then
			p.y += (m.hop or 0) * (style.hop or 0) * alive
			p.z -= m.strike * (style.dash or 0) * alive
			p.ry += (m.spin or 0) * TAU * (style.spin or 0)
		end
	end
	local roar = m.roar or 0
	if roar > 0 and alive > 0 then
		local roarStyle = MonsterMotions.STYLES[m.roarStyle or "roar"]
		if roarStyle then
			addStyle(p, roarStyle, joint, roar, 0, alive)
		end
	end
	local rise = m.rise
	if rise and rise < 1 then
		local under = 1 - math.clamp(rise, 0, 1)
		local riseStyle = MonsterMotions.STYLES.rise
		if riseStyle then
			addStyle(p, riseStyle, joint, under, 0, 1)
		end
		if role == "body" then
			p.y -= under * Gait.RISE_DEPTH
			p.rz += math.sin(m.time * 25) * 0.06 * under
		end
	end
	if flying > 0 and alive > 0 then
		if role == "body" then
			p.rx -= 0.15 * flying * alive
		elseif role == "leg" then
			p.rx -= 0.5 * flying * alive
		elseif role == "tail" or role == "segment" then
			p.rx += 0.1 * flying * alive
		end
	end
	if deathDef and m.dead > 0 then
		addDeath(p, deathDef, joint, m)
	end
	if directional and m.hit > 0 then
		local hitX, hitZ = m.hitX or 0, m.hitZ or 0
		if role == "body" then
			local rx, rz, x, z = Gait.hitLean(hitX, hitZ, m.hit, m.plan)
			p.rx += rx * alive
			p.rz += rz * alive
			p.x += x * alive
			p.z += z * alive
		elseif role == "head" then
			-- the head turns a little towards the attacker (who stands against the push)
			p.ry += hitX * headTurn(m.plan) * m.hit * alive
		end
	end
	return p
end

-- S117: fills the attack fields of `m` for `elapsed` seconds into an attack of `windup` (`charged`: a telegraphed one,
-- Gait.charge; else a basic attack, Gait.attack): raise, strike, tremble, hop, spin. Returns m.
function Gait.attackMotion(m: Motion, elapsed: number, windup: number, charged: boolean?): Motion
	if charged then
		m.raise, m.strike, m.tremble = Gait.charge(elapsed, windup)
	else
		m.raise, m.strike = Gait.attack(elapsed, windup)
		m.tremble = 0
	end
	local busy = m.raise > 0 or m.strike > 0
	m.hop = if busy then Gait.hopOf(elapsed, windup) else 0
	m.spin = if busy then Gait.spinOf(elapsed, windup) else 0
	return m
end

-- S110 (AnimLab, docs/ANIMACJE.md): what a generated monster does `t` seconds into a state, as one Motion.
export type Slot = "idle" | "walk" | "run" | "attack1" | "attack2" | "cast" | "hit" | "death" | "spawn"
export type StateOptions = {
	windup: number?, -- attack slots: seconds of the windup (default DEFAULT_WINDUP)
	speed: number?, -- walk / run: studs per second (default WALK_SPEED / RUN_SPEED)
	scale: number?, -- walk / run: rig scale for the stride (default 1)
	seed: number?, -- offset of the idle clock (default 0)
	-- S117 (the game's choices, AnimationController)
	style: string?, -- attack slots: the attack's style
	charged: boolean?, -- attack slots: a telegraphed attack (Gait.charge)
	deathStyle: string?, -- death: the plan's death
	deathSide: number?,
	hover: number?,
	plan: string?,
	rise: boolean?, -- spawn: climbs out of the ground over riseSeconds instead of the reversed collapse
	riseSeconds: number?,
	roar: number?, -- seconds of a roar played from t = 0 (any slot)
	roarStyle: string?,
	flying: boolean?,
}

-- The motion of a generated monster `t` seconds into `slot` (pure: the same arguments give the same motion). The walk
-- cycle is advanced in one step from 0 (Gait.advance is linear modulo 2*pi, so it equals the sum of small steps).
function Gait.stateMotion(slot: Slot, t: number, options: StateOptions?): Motion
	local o: StateOptions = options or {}
	local m: Motion = { cycle = 0, move = 0, time = t + (o.seed or 0), raise = 0, strike = 0, hit = 0, dead = 0 }
	m.plan = o.plan
	m.hover = o.hover
	if o.flying then
		m.flying = 1
	end
	if slot == "walk" or slot == "run" then
		local speed = o.speed or (if slot == "run" then Gait.RUN_SPEED else Gait.WALK_SPEED)
		m.move = 1
		m.cycle = Gait.advance(0, t, speed, o.scale or 1)
	elseif slot == "attack1" or slot == "attack2" or slot == "cast" then
		Gait.attackMotion(m, t, o.windup or Gait.DEFAULT_WINDUP, o.charged)
		if m.raise > 0 or m.strike > 0 then
			m.style = o.style
		end
	elseif slot == "hit" then
		m.hit = math.max(0, 1 - t / Gait.HIT_SECONDS)
	elseif slot == "death" then
		m.dead = math.clamp(t / Gait.DEATH_SECONDS, 0, 1)
		m.deathStyle = o.deathStyle
		m.deathSide = o.deathSide
	elseif slot == "spawn" then
		if o.rise then
			m.rise = Gait.riseOf(t, o.riseSeconds or Config.MonsterLook.summonRise)
		else
			m.dead = 1 - math.clamp(t / Gait.SPAWN_SECONDS, 0, 1)
		end
	end
	if o.roar then
		m.roar = Gait.roarEnvelope(t, o.roar)
		m.roarStyle = o.roarStyle
	end
	return m
end

-- True when a pose leaves the joint at rest (used by the client to skip work and by tests).
function Gait.isRest(p: Pose): boolean
	local e = 1e-6
	return math.abs(p.rx) < e
		and math.abs(p.ry) < e
		and math.abs(p.rz) < e
		and math.abs(p.x) < e
		and math.abs(p.y) < e
		and math.abs(p.z) < e
end

return Gait
