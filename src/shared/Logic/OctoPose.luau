--!strict
-- Template animation (owner 2026-10-31, docs/ANIM-WZORCE.md §6.6): the legs of a many-legged crawler with a skeleton
-- (Data/OctoRigs) as chains bending in one plane each. Pure: client/Anim/RigidRig reads the bones' rest rotations and
-- positions in the look's frame (its PrimaryPart: feet at y = 0, front -Z) and writes the turns returned here.
-- A leg turns as a whole about the vertical through its hip (`psi`, + to the left seen from above) and each joint about
-- the leg's bend axis (`c[i]`, + lifts the outer part), the axis lying flat and across the leg's rest direction. The
-- turns add up down the chain (each joint's turn is relative to the one above it), so a bone's Transform is
-- rest^-1 * R(axis, angle) * rest (Logic/QuadPose's convention): the rig turns the model axes into each bone's own
-- once and writes CFrame.fromAxisAngle per frame.
-- Two numbers bend a leg: `a` lifts it from the hip (the coxa and the femur) and `b` folds it at the knee (the femur
-- rises, the joints below the knee fold in: the foot comes in toward the hip); the inverse kinematics finds the pair
-- that puts the foot on a target (damped least squares from the last frame's pair, the yaw solved exactly).
-- Every other chain (fangs, the abdomen, a scorpion's pincers and tail) turns about one fixed axis per bone.

local OctoRigs = require("../Data/OctoRigs")

local OctoPose = {}

type Vec = { number }
type Mat = { number }

export type Bone = { rest: Mat, pos: Vec, parent: string? }
export type Leg = {
	name: string,
	bones: { string },
	n: number, -- joints
	hip: Vec, -- the first joint (look frame)
	rx: number, -- the leg's rest direction on the ground (unit), from the hip toward the foot
	rz: number,
	ax: number, -- the bend axis (flat, across the leg: r x up): + lifts the outer part
	az: number,
	sr: { number }, -- each segment (joint i to joint i + 1, the last to the foot) along the rest direction
	sy: { number }, -- .. and up
	sw: number, -- the segments' sum along the bend axis (out of the plane; a turn about the axis keeps it)
	sws: { number }, -- each segment's part along the bend axis
	lift: { number }, -- each joint's share of `a`
	bend: { number }, -- each joint's share of `b`
	curl: { number }, -- each joint's turn in the curled pose (the dead spider's: in under the body)
	foot: Vec, -- the rest foot (look frame, on the ground)
	span: number, -- the rest foot's flat distance from the hip
	reach: number, -- the leg's length along its segments
	yaw0: number, -- the rest direction's heading (rad, 0 = forward, + to the left)
	knee: number, -- the joint highest at rest
	group: number,
	rank: number,
	front: number,
	palp: boolean,
	side: number, -- -1 left, 1 right
}
-- A chain turned about one axis (model frame) per bone, by a share of one angle.
export type Turn = { bones: { string }, axis: { Vec }, share: { number }, side: number }
export type Skeleton = {
	rig: OctoRigs.Rig,
	legs: { Leg },
	fangs: { Turn },
	abdomen: Turn?,
	arms: { Leg },
	tail: Turn?,
	ground: number, -- the ground's height in the look frame (its lowest point at rest)
	hipH: number, -- the hips' mean height over the ground
	cx: number, -- the hips' centre (look frame)
	cz: number,
	span: number, -- the legs' mean rest span
}

local TAU = 2 * math.pi

-- The heading of a flat direction (0 = forward -Z, + to the left): the angle CFrame.Angles(0, psi, 0) adds.
local function heading(x: number, z: number): number
	return math.atan2(-x, -z)
end
OctoPose.heading = heading

-- The joints' shares of the lift and the fold for a chain of `n` joints whose knee is joint `k`.
local function shares(n: number, k: number): ({ number }, { number })
	local lift, bend = table.create(n, 0), table.create(n, 0)
	local before = math.max(1, k - 1)
	for i = 1, before do
		lift[i] = 1 / before
	end
	-- the femur (the joint above the knee) rises, the knee and the joints below it fold in, less and less
	local up = math.max(1, k - 1)
	bend[up] = 0.45
	local weights = { 0.55, 0.25, 0.15, 0.05 }
	local i = 1
	for j = math.max(k, up + 1), n do
		bend[j] = -(weights[i] or 0.03)
		i += 1
	end
	return lift, bend
end

-- The turns of the curled pose: each segment's elevation (rad, from flat and outward, + up) brought to a target. The
-- segments above the knee point out and up, the ones below curl in under the body (-90 down, -180 back in, beyond that
-- up toward the belly); `depth` scales the curl.
local CURL_ABOVE = math.rad(55)
local CURL_BELOW = { math.rad(-70), math.rad(-135), math.rad(-195), math.rad(-240), math.rad(-270) }

local function curlTurns(sr: { number }, sy: { number }, n: number, knee: number): { number }
	local out = table.create(n, 0)
	local prev = 0
	for i = 1, n do
		local elev = math.atan2(sy[i], sr[i])
		local want = if i < knee then CURL_ABOVE else CURL_BELOW[math.min(i - knee + 1, #CURL_BELOW)]
		-- always curling down and in (never the long way up and over)
		local delta = want - elev
		out[i] = delta - prev
		prev = delta
	end
	return out
end

local function legOf(
	bones: { [string]: Bone },
	names: { string },
	ground: number,
	o: { group: number, rank: number, front: number, palp: boolean?, name: string }
): Leg?
	local n = #names
	if n < 2 then
		return nil
	end
	local pts: { Vec } = {}
	for i, name in names do
		local b = bones[name]
		if not b then
			return nil
		end
		pts[i] = b.pos
	end
	-- the foot: the last segment carried on (as long as the one before it at most 1.6 times) down to the ground
	local last, prev = pts[n], pts[n - 1]
	local dx, dy, dz = last[1] - prev[1], last[2] - prev[2], last[3] - prev[3]
	local k = if dy < -1e-4 then math.clamp((last[2] - ground) / -dy, 0.3, 1.6) else 0.8
	local foot = { last[1] + dx * k, ground, last[3] + dz * k }
	if dy >= -1e-4 then
		foot[2] = last[2] + dy * k
	end
	pts[n + 1] = foot
	local hip = pts[1]
	local fx, fz = foot[1] - hip[1], foot[3] - hip[3]
	local span = math.sqrt(fx * fx + fz * fz)
	if span < 1e-4 then
		return nil
	end
	local rx, rz = fx / span, fz / span
	-- the bend axis r x up: (rx, 0, rz) x (0, 1, 0) = (-rz, 0, rx)
	local ax, az = -rz, rx
	local sr, sy, sws = table.create(n, 0), table.create(n, 0), table.create(n, 0)
	local sw, reach = 0, 0
	local knee, top = 1, -math.huge
	for i = 1, n do
		local a, b = pts[i], pts[i + 1]
		local vx, vy, vz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
		sr[i] = vx * rx + vz * rz
		sy[i] = vy
		sws[i] = vx * ax + vz * az
		sw += sws[i]
		reach += math.sqrt(vx * vx + vy * vy + vz * vz)
		if i > 1 and a[2] > top then
			top = a[2]
			knee = i
		end
	end
	local lift, bend = shares(n, knee)
	return {
		name = o.name,
		bones = names,
		n = n,
		hip = { hip[1], hip[2], hip[3] },
		rx = rx,
		rz = rz,
		ax = ax,
		az = az,
		sr = sr,
		sy = sy,
		sw = sw,
		sws = sws,
		lift = lift,
		bend = bend,
		curl = curlTurns(sr, sy, n, knee),
		foot = foot,
		span = span,
		reach = reach,
		yaw0 = heading(rx, rz),
		knee = knee,
		group = o.group,
		rank = o.rank,
		front = o.front,
		palp = o.palp == true,
		side = if foot[1] < hip[1] then -1 else 1,
	}
end

local function unit(x: number, y: number, z: number): Vec
	local m = math.sqrt(x * x + y * y + z * z)
	return if m > 1e-9 then { x / m, y / m, z / m } else { 1, 0, 0 }
end

-- A chain turning about axes that open its tip toward `side` and forward (fangs) or lift it (the abdomen).
local function turnOf(bones: { [string]: Bone }, names: { string }, side: number, kind: string): Turn?
	if #names == 0 then
		return nil
	end
	local axis, share = {}, {}
	for i, name in names do
		local b = bones[name]
		if not b then
			return nil
		end
		if kind == "fang" then
			-- the fang hangs down: opening swings its tip forward and to its side (about an axis across both)
			local ox, oz = side * 0.8, -1
			-- down x outward: (0, -1, 0) x (ox, 0, oz) = (-oz, 0, ox)
			axis[i] = unit(-oz, 0, ox)
		else
			-- about the side axis: + lifts the far end of a chain pointing back (the abdomen's pump, a tail curling up
			-- and over the back)
			axis[i] = { -1, 0, 0 }
		end
		share[i] = if i == 1 then 0.6 else 0.4 / math.max(1, #names - 1)
	end
	return { bones = names, axis = axis, share = share, side = side }
end

-- The skeleton from the bones in the look's frame (rest, pos, parent by name) and the map; `ground` the ground's height
-- in that frame (the look's lowest point at rest, 0 for a model standing on its pivot). Nil when a bone is missing.
function OctoPose.skeleton(bones: { [string]: Bone }, rig: OctoRigs.Rig, ground: number): Skeleton?
	local legs: { Leg } = {}
	local hy, cx, cz, span = 0, 0, 0, 0
	for _, def in rig.legs do
		local leg = legOf(bones, def.bones, ground, def)
		if not leg then
			return nil
		end
		table.insert(legs, leg)
		hy += leg.hip[2] - ground
		cx += leg.hip[1]
		cz += leg.hip[3]
		span += leg.span
	end
	if #legs < 4 then
		return nil
	end
	local arms: { Leg } = {}
	local armChains: { OctoRigs.Chain } = rig.arms or {}
	for i, chain in armChains do
		local arm = legOf(bones, chain.bones, ground, { name = "A" .. i, group = 0, rank = 0, front = 1 })
		if arm then
			table.insert(arms, arm)
		end
	end
	local fangs: { Turn } = {}
	local fangChains: { OctoRigs.Chain } = rig.fangs or {}
	for _, chain in fangChains do
		local t = turnOf(bones, chain.bones, chain.side, "fang")
		if t then
			table.insert(fangs, t)
		end
	end
	local count = #legs
	return {
		rig = rig,
		legs = legs,
		fangs = fangs,
		abdomen = if rig.abdomen then turnOf(bones, rig.abdomen, 0, "pump") else nil,
		arms = arms,
		tail = if rig.tail then turnOf(bones, rig.tail, 0, "curl") else nil,
		ground = ground,
		hipH = math.max(1e-3, hy / count),
		cx = cx / count,
		cz = cz / count,
		span = span / count,
	}
end

---------------------------------------------------------------- one leg

-- The foot of `leg` (from its hip, in the leg's plane: along its rest direction and up) for joint turns `c`.
local function planar(leg: Leg, c: { number }): (number, number)
	local r, y, cum = 0, 0, 0
	local sr, sy = leg.sr, leg.sy
	for i = 1, leg.n do
		cum += c[i]
		local cs, sn = math.cos(cum), math.sin(cum)
		r += sr[i] * cs - sy[i] * sn
		y += sr[i] * sn + sy[i] * cs
	end
	return r, y
end

-- Writes the joint turns of the pair (a, b) into `c`.
function OctoPose.turns(leg: Leg, a: number, b: number, c: { number })
	local lift, bend = leg.lift, leg.bend
	for i = 1, leg.n do
		c[i] = lift[i] * a + bend[i] * b
	end
end

-- The yaw and the pair (a, b) that put the foot of `leg` on (tx, ty, tz) (look frame), from the guess (a, b): the yaw
-- exactly, the pair by damped least-squares steps in the leg's plane (out of reach, the foot gets as close as it can;
-- the knee never flips). `iters` steps at most. `ankle` turns the last joint on top of the pair (OctoPose.ankle);
-- `upto` < n puts the head of bone upto + 1 there instead of the foot (the joints below it left out).
function OctoPose.solve(
	leg: Leg,
	tx: number,
	ty: number,
	tz: number,
	a: number,
	b: number,
	iters: number,
	ankle: number?,
	upto: number?
): (number, number, number)
	local hip = leg.hip
	local dx, dy, dz = tx - hip[1], ty - hip[2], tz - hip[3]
	local flat2 = dx * dx + dz * dz
	local n = math.clamp(upto or leg.n, 1, leg.n)
	local extra = if n == leg.n then ankle or 0 else 0
	local sw = if n == leg.n then leg.sw else leg.sw - leg.sws[leg.n]
	-- the foot's flat distance in the plane (the part across it stays)
	local R = math.sqrt(math.max(flat2 - sw * sw, 1e-6))
	local psi = 0
	if flat2 > 1e-8 then
		local vx, vz = R * leg.rx + sw * leg.ax, R * leg.rz + sw * leg.az
		psi = heading(dx, dz) - heading(vx, vz)
		psi = (psi + math.pi) % TAU - math.pi
	end
	local sr, sy, lift, bend = leg.sr, leg.sy, leg.lift, leg.bend
	local damp = (0.04 * leg.reach) ^ 2
	for _ = 1, iters do
		local r, y = 0, 0
		local ar, ay, br, by = 0, 0, 0, 0
		local cum, da, db = 0, 0, 0
		for i = 1, n do
			cum += lift[i] * a + bend[i] * b
			if i == leg.n then
				cum += extra
			end
			da += lift[i]
			db += bend[i]
			local cs, sn = math.cos(cum), math.sin(cum)
			local pr, py = sr[i] * cs - sy[i] * sn, sr[i] * sn + sy[i] * cs
			r += pr
			y += py
			-- d(segment)/d(cum) is the segment turned a quarter: (-py, pr)
			ar -= py * da
			ay += pr * da
			br -= py * db
			by += pr * db
		end
		local er, ey = R - r, dy - y
		local a11, a12, a22 = ar * ar + ay * ay + damp, ar * br + ay * by, br * br + by * by + damp
		local g1, g2 = ar * er + ay * ey, br * er + by * ey
		local det = a11 * a22 - a12 * a12
		if det < 1e-12 then
			break
		end
		local stepA = math.clamp((g1 * a22 - a12 * g2) / det, -0.4, 0.4)
		local stepB = math.clamp((a11 * g2 - a12 * g1) / det, -0.4, 0.4)
		a = math.clamp(a + stepA, -1.4, 1.6)
		b = math.clamp(b + stepB, -1.0, 2.2)
		if math.abs(stepA) + math.abs(stepB) < 2e-4 then
			break
		end
	end
	return psi, a, b
end

-- The last segment (its head to the foot) in the leg's own frame (along its rest direction, across it along the bend
-- axis, up) after the joints above turned `C` in all, its own joint `cn` and its roll `ro` (about the leg's rest
-- direction: the last bone tilted out of the leg's plane, sideways).
local function lastSegment(leg: Leg, C: number, cn: number, ro: number): (number, number, number)
	local n = leg.n
	local sr, sy, sw = leg.sr[n], leg.sy[n], leg.sws[n]
	local ur, uy = sr * math.cos(cn) - sy * math.sin(cn), sr * math.sin(cn) + sy * math.cos(cn)
	local cr, rs = math.cos(ro), math.sin(ro)
	local vw, vy = sw * cr + uy * rs, -sw * rs + uy * cr
	return ur * math.cos(C) - vy * math.sin(C), vw, ur * math.sin(C) + vy * math.cos(C)
end

-- A foot standing on its point keeps the head of its last bone where it stood too (Studio review 2026-10-31: the
-- mesh's last bone stands over the claw; a bone pivoting on its point slid its head along the ground): the yaw and the
-- pair that put that head on (hx, hy, hz), then the last joint's turn on top of the pair and its roll that point the
-- last bone at the point (tx, ty, tz) (look frame): (psi, a, b, ankle, roll). Of the two ways to get there, the one
-- nearer last frame's (ankle0, roll0): the bone never swings round.
function OctoPose.pinned(
	leg: Leg,
	hx: number,
	hy: number,
	hz: number,
	tx: number,
	ty: number,
	tz: number,
	a: number,
	b: number,
	iters: number,
	ankle0: number,
	roll0: number
): (number, number, number, number, number)
	local n = leg.n
	local psi, a2, b2 = OctoPose.solve(leg, hx, hy, hz, a, b, iters, 0, n - 1)
	local sr, sy, lift, bend = leg.sr, leg.sy, leg.lift, leg.bend
	-- the head in the leg's own frame
	local r, y, w, C = 0, 0, 0, 0
	for i = 1, n - 1 do
		C += lift[i] * a2 + bend[i] * b2
		local cs, sn = math.cos(C), math.sin(C)
		r += sr[i] * cs - sy[i] * sn
		y += sr[i] * sn + sy[i] * cs
		w += leg.sws[i]
	end
	-- the point there (the yaw taken back)
	local hip = leg.hip
	local dx, dz = tx - hip[1], tz - hip[3]
	local cs, sn = math.cos(psi), math.sin(psi)
	local vx, vz = dx * cs - dz * sn, dx * sn + dz * cs
	local er = vx * leg.rx + vz * leg.rz - r
	local ew = vx * leg.ax + vz * leg.az - w
	local ey = ty - hip[2] - y
	-- (the way to it before the joints above turned it)
	local cc, sc = math.cos(C), math.sin(C)
	local qr, qy = er * cc + ey * sc, -er * sc + ey * cc
	local len = math.sqrt(qr * qr + ew * ew + qy * qy)
	local own = lift[n] * a2 + bend[n] * b2
	if len < 1e-6 then
		return psi, a2, b2, 0, 0
	end
	-- its own turn gives the way's part along the leg (the nearer of the two), the roll its tilt across
	local A = math.sqrt(sr[n] * sr[n] + sy[n] * sy[n])
	local S = math.sqrt(A * A + leg.sws[n] * leg.sws[n])
	local phi = math.atan2(sy[n], sr[n])
	local alpha = math.acos(math.clamp(S * qr / len / math.max(A, 1e-6), -1, 1))
	local bestTurn, bestRoll, bestCost = 0, roll0, math.huge
	for pass = 1, 2 do
		local k = if pass == 1 then alpha - phi else -alpha - phi
		local uy = A * math.sin(k + phi)
		local ro = (math.atan2(uy, leg.sws[n]) - math.atan2(qy, ew) + math.pi) % TAU - math.pi
		local turn = (k - own + math.pi) % TAU - math.pi
		local cost = math.abs((ro - roll0 + math.pi) % TAU - math.pi) + math.abs(turn - ankle0)
		if cost < bestCost then
			bestTurn, bestRoll, bestCost = turn, ro, cost
		end
	end
	return psi, a2, b2, bestTurn, bestRoll
end

-- Where joint `k` of `leg` is (look frame: 1 the hip, n the head of its last bone, n + 1 the foot) for yaw `psi` and
-- joint turns `c` (no tables: the hot path).
function OctoPose.joint(leg: Leg, psi: number, c: { number }, k: number): (number, number, number)
	local r, y, w, cum = 0, 0, 0, 0
	local n = leg.n
	for i = 1, math.min(k - 1, n) do
		local ro = if i == n then c[n + 1] or 0 else 0
		if ro ~= 0 then
			local dr, dw, dy = lastSegment(leg, cum, c[i], ro)
			r += dr
			y += dy
			w += dw
			cum += c[i]
		else
			cum += c[i]
			local ci, si = math.cos(cum), math.sin(cum)
			r += leg.sr[i] * ci - leg.sy[i] * si
			y += leg.sr[i] * si + leg.sy[i] * ci
			w += leg.sws[i]
		end
	end
	local vx, vz = r * leg.rx + w * leg.ax, r * leg.rz + w * leg.az
	local cs, sn = math.cos(psi), math.sin(psi)
	local hip = leg.hip
	return hip[1] + vx * cs + vz * sn, hip[2] + y, hip[3] - vx * sn + vz * cs
end

-- Where the foot of `leg` is (look frame) for yaw `psi` and joint turns `c`.
function OctoPose.foot(leg: Leg, psi: number, c: { number }): (number, number, number)
	return OctoPose.joint(leg, psi, c, leg.n + 1)
end

-- Every joint of `leg` and its foot (look frame), for yaw `psi` and turns `c`: n + 1 points into `out` (the specs, the
-- folded boxes).
function OctoPose.joints(leg: Leg, psi: number, c: { number }, out: { Vec }): { Vec }
	local cs, sn = math.cos(psi), math.sin(psi)
	local hip = leg.hip
	local r, y, w, cum = 0, 0, 0, 0
	out[1] = { hip[1], hip[2], hip[3] }
	local n = leg.n
	for i = 1, n do
		local ro = if i == n then c[n + 1] or 0 else 0
		if ro ~= 0 then
			local dr, dw, dy = lastSegment(leg, cum, c[i], ro)
			r += dr
			y += dy
			w += dw
			cum += c[i]
		else
			cum += c[i]
			local ci, si = math.cos(cum), math.sin(cum)
			r += leg.sr[i] * ci - leg.sy[i] * si
			y += leg.sr[i] * si + leg.sy[i] * ci
			w += leg.sws[i]
		end
		local vx, vz = r * leg.rx + w * leg.ax, r * leg.rz + w * leg.az
		out[i + 1] = { hip[1] + vx * cs + vz * sn, hip[2] + y, hip[3] - vx * sn + vz * cs }
	end
	return out
end

-- The planar foot of the curled pose at `depth` (0 rest .. 1 curled; below 0 the legs straighten out), into `c`.
function OctoPose.curl(leg: Leg, depth: number, c: { number })
	for i = 1, leg.n do
		c[i] = leg.curl[i] * depth
	end
end

OctoPose.planar = planar

return OctoPose
