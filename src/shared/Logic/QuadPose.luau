--!strict
-- Template animation (docs/ANIM-WZORCE.md F2): the pose of an imported quadruped (Tripo bones, Data/QuadRigs role map)
-- from named controls. Pure: client/Anim/QuadRig reads the bones' rest rotations, positions and parents in the model's
-- root space (front -Z, up +Y, right +X) and writes the Transforms returned here.
-- Every driven bone takes a turn in root axes composed on its parent's: world = parentWorld * local; its Transform is
-- rest^-1 * (parentWorld^-1 * world) * rest (the convention of Logic/BipedPose).
-- Controls (radians; distances in leg lengths L, the hind hip's height):
--   body  bx by bz bpitch (+ nose up) broll (+ right side up) byaw
--   spine sflex (+ arched: the ends drop) syaw (+ the front bends left)
--   neck  npitch (+ down) nyaw;  head hpitch (+ down) hyaw hroll;  jaw (+ open);  earL earR (+ back)
--   tail  tpitch (+ up) tyaw, per bone tY1..tY4 / tP1..tP4 added on
--   legs  <leg>u (+ swing forward) <leg>f (+ fold) <leg>p (+ paw curled back) <leg>o (+ out), leg = FL FR HL HR;
--         <leg>l 0..1 keeps the rig's `level` joint (a plantigrade foot) at its rest pitch against the joints above it
--   pivot bpx bpy bpz: the point (leg lengths from the body bone) the body's turn turns about, e.g. the hind feet of a
--         rear-up or the ground line under a flank (0: the body bone itself)
--   trunk kpitch (+ swings forward) kside (+ swings the tip to the left) kcurl (+ curls the tip up and forward), per
--         bone kP1..kP8 / kS1..kS8 added on
--   feet  <leg>k 0..1 puts the foot on a target instead (planted feet): <leg>y <leg>z the target from the foot's rest
--         point in leg lengths (model frame, + up, + back); the leg's swing and fold are solved for it in the plane of
--         the leg (a two-parameter IK over the map's joint shares), so a body that bobs, pitches or rears does not move
--         a planted foot

local NpcPose = require("./NpcPose")
local QuadRigs = require("../Data/QuadRigs")

local QuadPose = {}

-- Per-bone control names of the trunk (no string building per frame).
local TRUNK_P = { "kP1", "kP2", "kP3", "kP4", "kP5", "kP6", "kP7", "kP8" }
local TRUNK_S = { "kS1", "kS2", "kS3", "kS4", "kS5", "kS6", "kS7", "kS8" }
local LEVEL = { FL = "FLl", FR = "FRl", HL = "HLl", HR = "HRl" }
local PLANT = { FL = "FLk", FR = "FRk", HL = "HLk", HR = "HRk" }
local TARGET_Y = { FL = "FLy", FR = "FRy", HL = "HLy", HR = "HRy" }
local TARGET_Z = { FL = "FLz", FR = "FRz", HL = "HLz", HR = "HRz" }

type Vec = { number }
type Mat = { number }
export type Controls = { [string]: number }
export type Bone = { rest: Mat, pos: Vec, parent: string? }
-- A leg for the foot solver: its joints' rest segments (to the next joint; the last one to the foot's tip) and the
-- foot's rest point (model frame).
export type Chain = { top: string, segs: { Vec }, foot: Vec, reach: number }
export type Skeleton = {
	rig: QuadRigs.Rig,
	bones: { [string]: Bone },
	order: { string }, -- driven bones, parents first
	parent: { [string]: string? }, -- nearest driven ancestor
	L: number, -- hind hip height over the ground
	chains: { [string]: Chain }, -- by leg (FL FR HL HR)
	tops: { [string]: string }, -- the top joint of each leg -> the leg
}
export type Posed = { [string]: { rot: Mat, offset: Vec? } }

local IDENTITY = NpcPose.IDENTITY
local mul, transpose, apply, axisAngle = NpcPose.mul, NpcPose.transpose, NpcPose.apply, NpcPose.axisAngle

local function rx(a: number): Mat
	return if a == 0 then IDENTITY else axisAngle({ 1, 0, 0 }, a)
end
local function ry(a: number): Mat
	return if a == 0 then IDENTITY else axisAngle({ 0, 1, 0 }, a)
end
local function rz(a: number): Mat
	return if a == 0 then IDENTITY else axisAngle({ 0, 0, 1 }, a)
end
QuadPose.rx, QuadPose.ry, QuadPose.rz = rx, ry, rz

QuadPose.LEGS = { "FL", "FR", "HL", "HR" }

-- The skeleton from the bones in root space (every bone of the model by name: rest, pos, parent name) and the role
-- map; nil when a mapped bone is missing.
function QuadPose.skeleton(bones: { [string]: Bone }, rig: QuadRigs.Rig): Skeleton?
	local driven: { [string]: boolean } = { [rig.body] = true, [rig.head] = true }
	for _, row in rig.spine do
		driven[row.bone] = true
	end
	for _, row in rig.neck do
		driven[row.bone] = true
	end
	for _, name in rig.tail do
		driven[name] = true
	end
	if rig.trunk then
		for _, name in rig.trunk do
			driven[name] = true
		end
	end
	if rig.jaw then
		driven[rig.jaw.bone] = true
	end
	if rig.ears then
		if rig.ears.L then
			driven[rig.ears.L] = true
		end
		if rig.ears.R then
			driven[rig.ears.R] = true
		end
	end
	for _, leg in rig.legs do
		for _, joint in leg do
			driven[joint.bone] = true
		end
	end
	for name in driven do
		if not bones[name] then
			return nil
		end
	end
	-- nearest driven ancestor of each driven bone, and the order (parents first)
	local parent: { [string]: string? } = {}
	local depth: { [string]: number } = {}
	for name in driven do
		local p = bones[name].parent
		while p and not driven[p] do
			local b = bones[p]
			p = if b then b.parent else nil
		end
		parent[name] = p
		-- the bone's depth in the model's hierarchy (parents always sort first)
		local d = 0
		local q = bones[name].parent
		while q and bones[q] do
			d += 1
			q = bones[q].parent
		end
		depth[name] = d
	end
	local order: { string } = {}
	for name in driven do
		table.insert(order, name)
	end
	table.sort(order, function(a, b)
		if depth[a] ~= depth[b] then
			return depth[a] < depth[b]
		end
		return a < b
	end)
	local L = 0
	for _, side in { "HL", "HR" } do
		local leg = rig.legs[side]
		if leg and leg[1] then
			L = math.max(L, bones[leg[1].bone].pos[2])
		end
	end
	if L <= 0 then
		L = 1
	end
	local chains: { [string]: Chain } = {}
	local tops: { [string]: string } = {}
	for side, leg in rig.legs do
		local segs: { Vec } = {}
		for i, joint in leg do
			local a = bones[joint.bone].pos
			local nextJoint = leg[i + 1]
			if nextJoint then
				local b = bones[nextJoint.bone].pos
				segs[i] = { b[1] - a[1], b[2] - a[2], b[3] - a[3] }
			else
				-- the last bone: to its tip when the map gives one (a forearm that carries the paw), else it ends here
				local tip = joint.tip
				segs[i] = if tip then { tip[1] * L, tip[2] * L, tip[3] * L } else { 0, 0, 0 }
			end
		end
		local top = bones[leg[1].bone].pos
		local foot = { top[1], top[2], top[3] }
		local reach = 0
		for _, seg in segs do
			foot[1] += seg[1]
			foot[2] += seg[2]
			foot[3] += seg[3]
			reach += math.sqrt(seg[1] * seg[1] + seg[2] * seg[2] + seg[3] * seg[3])
		end
		chains[side] = { top = leg[1].bone, segs = segs, foot = foot, reach = math.max(reach, 1e-3) }
		tops[leg[1].bone] = side
	end
	return { rig = rig, bones = bones, order = order, parent = parent, L = L, chains = chains, tops = tops }
end

-- The leg's pitches (model axes, about +X, each on the one above it) for swing `u`, fold `f`, paw curl `p` and level
-- `level`: the rule of QuadPose.world, shared with the foot solver.
local function jointPitch(joint: QuadRigs.Joint, u: number, f: number, p: number, level: number, above: number): number
	local pitch = (joint.swing or 0) * u + (joint.fold or 0) * f + (joint.paw or 0) * p
	if joint.level and level ~= 0 then
		pitch -= level * above
	end
	return pitch
end

-- The swing and fold that put the foot of `leg` at (ty, tz) (the plane of the leg, from its top joint), from the
-- guess (u, f): damped least-squares steps on the planar chain with its analytic Jacobian (a target out of reach, or
-- a leg near straight, leaves the foot as close as it gets instead of throwing the leg about).
local function solveLeg(
	leg: { QuadRigs.Joint },
	chain: Chain,
	u: number,
	f: number,
	p: number,
	level: number,
	ty: number,
	tz: number
): (number, number)
	local damp = (0.05 * chain.reach) ^ 2
	for _ = 1, 8 do
		local y, z = 0, 0
		local uy, uz, fy, fz = 0, 0, 0, 0
		local cum, du, df = 0, 0, 0
		for i, joint in leg do
			local pitch = jointPitch(joint, u, f, p, level, cum)
			local dpu = joint.swing or 0
			local dpf = joint.fold or 0
			if joint.level and level ~= 0 then
				dpu -= level * du
				dpf -= level * df
			end
			cum += pitch
			du += dpu
			df += dpf
			local seg = chain.segs[i]
			local cs, sn = math.cos(cum), math.sin(cum)
			local sy, sz = seg[2], seg[3]
			y += cs * sy - sn * sz
			z += sn * sy + cs * sz
			-- d(segment)/d(cum)
			local gy, gz = -sn * sy - cs * sz, cs * sy - sn * sz
			uy += gy * du
			uz += gz * du
			fy += gy * df
			fz += gz * df
		end
		local ry_, rz_ = ty - y, tz - z
		-- (J^T J + damp) step = J^T r, J = [[uy, fy], [uz, fz]]
		local a11, a12, a22 = uy * uy + uz * uz + damp, uy * fy + uz * fz, fy * fy + fz * fz + damp
		local b1, b2 = uy * ry_ + uz * rz_, fy * ry_ + fz * rz_
		local det = a11 * a22 - a12 * a12
		if det < 1e-12 then
			break
		end
		local stepU = math.clamp((b1 * a22 - a12 * b2) / det, -0.5, 0.5)
		local stepF = math.clamp((a11 * b2 - a12 * b1) / det, -0.5, 0.5)
		u = math.clamp(u + stepU, -1.5, 1.5)
		f = math.clamp(f + stepF, -0.4, 2)
		if math.abs(stepU) + math.abs(stepF) < 1e-4 then
			break
		end
	end
	return u, f
end

local function c(controls: Controls, key: string): number
	return controls[key] or 0
end

-- The world turns (root axes) and the body's offset (studs) for `controls`.
function QuadPose.world(skel: Skeleton, controls: Controls): ({ [string]: Mat }, Vec, Vec?)
	local rig = skel.rig
	local localTurn: { [string]: Mat } = {}
	local L = skel.L
	-- body: the whole model turns about its root bone, then moves
	localTurn[rig.body] = mul(mul(ry(c(controls, "byaw")), rx(c(controls, "bpitch"))), rz(c(controls, "broll")))
	local shift: Vec = { c(controls, "bx") * L, c(controls, "by") * L, c(controls, "bz") * L }
	for _, row in rig.spine do
		localTurn[row.bone] = mul(ry(c(controls, "syaw") * row.share), rx(-c(controls, "sflex") * row.share))
	end
	for _, row in rig.neck do
		localTurn[row.bone] = mul(ry(c(controls, "nyaw") * row.share), rx(-c(controls, "npitch") * row.share))
	end
	if #rig.neck > 0 then
		localTurn[rig.head] = mul(mul(ry(c(controls, "hyaw")), rx(-c(controls, "hpitch"))), rz(c(controls, "hroll")))
	else
		-- no neck bones (a bear, a boar): the head takes the neck's turn too
		localTurn[rig.head] = mul(
			mul(ry(c(controls, "nyaw") + c(controls, "hyaw")), rx(-c(controls, "npitch") - c(controls, "hpitch"))),
			rz(c(controls, "hroll"))
		)
	end
	if rig.jaw then
		localTurn[rig.jaw.bone] = rx(c(controls, "jaw") * rig.jaw.sign)
	end
	if rig.ears then
		-- "yaw" ears (a mammoth's) flap out about the vertical; the others fold back about the side axis
		local flap = rig.ears.axis == "yaw"
		if rig.ears.L then
			localTurn[rig.ears.L] = if flap then ry(-c(controls, "earL")) else rx(c(controls, "earL"))
		end
		if rig.ears.R then
			localTurn[rig.ears.R] = if flap then ry(c(controls, "earR")) else rx(c(controls, "earR"))
		end
	end
	local trunk = rig.trunk
	if trunk then
		-- the root of the trunk takes the most of its swing, the curl grows toward the tip
		local m = #trunk
		local curlSum = m * (m + 1) / 2
		local kpitch, kside, kcurl = c(controls, "kpitch"), c(controls, "kside"), c(controls, "kcurl")
		for i, name in trunk do
			local share = if i == 1 then 0.4 elseif m > 1 then 0.6 / (m - 1) else 0
			local pitch = kpitch * share + kcurl * i / curlSum + c(controls, TRUNK_P[i] or "")
			local side = kside * share + c(controls, TRUNK_S[i] or "")
			localTurn[name] = mul(rz(-side), rx(pitch))
		end
	end
	local n = #rig.tail
	for i, name in rig.tail do
		local share = 1 / n
		local yaw = c(controls, "tyaw") * share + c(controls, "tY" .. i)
		local pitch = c(controls, "tpitch") * share + c(controls, "tP" .. i)
		localTurn[name] = mul(ry(yaw), rx(-pitch))
	end
	local function legTurns(side: string, leg: { QuadRigs.Joint }, u: number, f: number)
		local p, o = c(controls, side .. "p"), c(controls, side .. "o")
		local level = math.min(c(controls, LEVEL[side] or ""), 1)
		local out = if string.sub(side, 2, 2) == "R" then 1 else -1
		local above = 0
		for _, joint in leg do
			local pitch = jointPitch(joint, u, f, p, level, above)
			above += pitch
			local turn = rx(pitch)
			if joint.spread and o ~= 0 then
				turn = mul(rz(out * o * joint.spread), turn)
			end
			localTurn[joint.bone] = turn
		end
	end
	for side, leg in rig.legs do
		legTurns(side, leg, c(controls, side .. "u"), c(controls, side .. "f"))
	end
	-- the body turns about the pivot point: the body bone moves by v - R v
	local px, py, pz = c(controls, "bpx"), c(controls, "bpy"), c(controls, "bpz")
	if px ~= 0 or py ~= 0 or pz ~= 0 then
		local v: Vec = { px * L, py * L, pz * L }
		local rv = apply(localTurn[rig.body], v)
		shift = { shift[1] + v[1] - rv[1], shift[2] + v[2] - rv[2], shift[3] + v[3] - rv[3] }
	end
	local bones = skel.bones
	local world: { [string]: Mat } = {}
	-- the turn a bone moves with (its own when driven, else its nearest driven ancestor's), from the world so far
	local function carried(name: string?): Mat
		while name do
			local w = world[name]
			if w then
				return w
			end
			local b = bones[name]
			name = if b then b.parent else nil
		end
		return IDENTITY
	end
	-- where a bone's joint is in the pose (model frame), through its ancestors posed so far
	local function jointAt(name: string): Vec
		local bone = bones[name]
		local q = bone.parent
		if name == rig.body or not q or not bones[q] then
			if name == rig.body then
				return { bone.pos[1] + shift[1], bone.pos[2] + shift[2], bone.pos[3] + shift[3] }
			end
			return bone.pos
		end
		local base = jointAt(q)
		local qpos = bones[q].pos
		local d = apply(carried(q), { bone.pos[1] - qpos[1], bone.pos[2] - qpos[2], bone.pos[3] - qpos[3] })
		return { base[1] + d[1], base[2] + d[2], base[3] + d[3] }
	end
	for _, name in skel.order do
		local p = skel.parent[name]
		local base = if p then world[p] or IDENTITY else IDENTITY
		-- a planted foot: the leg's swing and fold solved so the foot reaches its target
		local side = skel.tops[name]
		local plant = if side then c(controls, PLANT[side]) else 0
		if side and plant > 0.001 then
			local chain = skel.chains[side]
			local hip = jointAt(name)
			local foot = chain.foot
			local target = {
				foot[1] - hip[1],
				foot[2] + c(controls, TARGET_Y[side]) * L - hip[2],
				foot[3] + c(controls, TARGET_Z[side]) * L - hip[3],
			}
			local inLeg = apply(transpose(base), target)
			local u0, f0 = c(controls, side .. "u"), c(controls, side .. "f")
			local leg = rig.legs[side]
			local level = math.min(c(controls, LEVEL[side]), 1)
			local u, f = solveLeg(leg, chain, u0, f0, c(controls, side .. "p"), level, inLeg[2], inLeg[3])
			local k = math.min(plant, 1)
			legTurns(side, leg, u0 + (u - u0) * k, f0 + (f - f0) * k)
		end
		world[name] = mul(base, localTurn[name] or IDENTITY)
	end
	return world, shift, nil
end

-- The Transforms for world turns and the body's offset.
function QuadPose.transforms(skel: Skeleton, world: { [string]: Mat }, shift: Vec): Posed
	local out: Posed = {}
	local bodyName = skel.rig.body
	for _, name in skel.order do
		local bone = skel.bones[name]
		local p = skel.parent[name]
		local pw = if p then world[p] or IDENTITY else IDENTITY
		local turn = mul(transpose(pw), world[name])
		local rest = bone.rest
		local entry = { rot = mul(mul(transpose(rest), turn), rest), offset = nil :: Vec? }
		if name == bodyName then
			entry.offset = apply(transpose(rest), shift)
		end
		out[name] = entry
	end
	return out
end

function QuadPose.solve(skel: Skeleton, controls: Controls): Posed
	local world, shift = QuadPose.world(skel, controls)
	return QuadPose.transforms(skel, world, shift)
end

return QuadPose
