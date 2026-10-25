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
--   legs  <leg>u (+ swing forward) <leg>f (+ fold) <leg>p (+ paw curled back) <leg>o (+ out), leg = FL FR HL HR

local NpcPose = require("./NpcPose")
local QuadRigs = require("../Data/QuadRigs")

local QuadPose = {}

type Vec = { number }
type Mat = { number }
export type Controls = { [string]: number }
export type Bone = { rest: Mat, pos: Vec, parent: string? }
export type Skeleton = {
	rig: QuadRigs.Rig,
	bones: { [string]: Bone },
	order: { string }, -- driven bones, parents first
	parent: { [string]: string? }, -- nearest driven ancestor
	L: number, -- hind hip height over the ground
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
	return { rig = rig, bones = bones, order = order, parent = parent, L = L }
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
	localTurn[rig.head] = mul(mul(ry(c(controls, "hyaw")), rx(-c(controls, "hpitch"))), rz(c(controls, "hroll")))
	if rig.jaw then
		localTurn[rig.jaw.bone] = rx(c(controls, "jaw") * rig.jaw.sign)
	end
	if rig.ears then
		if rig.ears.L then
			localTurn[rig.ears.L] = rx(c(controls, "earL"))
		end
		if rig.ears.R then
			localTurn[rig.ears.R] = rx(c(controls, "earR"))
		end
	end
	local n = #rig.tail
	for i, name in rig.tail do
		local share = 1 / n
		local yaw = c(controls, "tyaw") * share + c(controls, "tY" .. i)
		local pitch = c(controls, "tpitch") * share + c(controls, "tP" .. i)
		localTurn[name] = mul(ry(yaw), rx(-pitch))
	end
	for side, leg in rig.legs do
		local u, f, p, o =
			c(controls, side .. "u"), c(controls, side .. "f"), c(controls, side .. "p"), c(controls, side .. "o")
		local out = if string.sub(side, 2, 2) == "R" then 1 else -1
		for _, joint in leg do
			local pitch = (joint.swing or 0) * u + (joint.fold or 0) * f + (joint.paw or 0) * p
			local turn = rx(pitch)
			if joint.spread and o ~= 0 then
				turn = mul(rz(out * o * joint.spread), turn)
			end
			localTurn[joint.bone] = turn
		end
	end
	local world: { [string]: Mat } = {}
	for _, name in skel.order do
		local p = skel.parent[name]
		local base = if p then world[p] or IDENTITY else IDENTITY
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
