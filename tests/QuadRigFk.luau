--!strict
-- Test helper (template animation, docs/ANIM-WZORCE.md F2): the skeleton of an imported quadruped from the Studio rig
-- dump (tools/anim/rigs/<model>.json: bone, parent, position in the model frame with the feet at y = 0 and the front
-- toward -Z, rest axes) and the forward kinematics of a Logic/QuadPose pose, so the specs can see where the feet, the
-- paws and the head really go without Studio.

local fs = require("@lune/fs")
local serde = require("@lune/serde")

local NpcPose = require("../src/shared/Logic/NpcPose")
local QuadPose = require("../src/shared/Logic/QuadPose")
local QuadRigs = require("../src/shared/Data/QuadRigs")

local QuadRigFk = {}

local mul, transpose = NpcPose.mul, NpcPose.transpose

type Vec = { number }
type Mat = { number }

export type Dump = {
	bones: { [string]: QuadPose.Bone },
	names: { string },
	height: number,
	width: number,
	depth: number,
}

local function sub(a: Vec, b: Vec): Vec
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end

local function unit(a: Vec): Vec
	local n = math.sqrt(a[1] * a[1] + a[2] * a[2] + a[3] * a[3])
	return if n > 1e-9 then { a[1] / n, a[2] / n, a[3] / n } else { 0, 1, 0 }
end

local function cross(a: Vec, b: Vec): Vec
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end

local function apply(m: Mat, v: Vec): Vec
	return {
		m[1] * v[1] + m[2] * v[2] + m[3] * v[3],
		m[4] * v[1] + m[5] * v[2] + m[6] * v[3],
		m[7] * v[1] + m[8] * v[2] + m[9] * v[3],
	}
end

-- The dump of `model` (positions scaled by `scale`).
function QuadRigFk.load(model: string, scale: number?): Dump
	local k = scale or 1
	local raw = serde.decode("json", fs.readFile(`tools/anim/rigs/{model}.json`))
	local bones: { [string]: QuadPose.Bone } = {}
	local names: { string } = {}
	for _, b in raw.bones do
		-- rest axes: up (+Y) and look (-Z) of the bone, made orthonormal (the dump rounds them)
		local up = unit(b.up)
		local back = unit({ -b.look[1], -b.look[2], -b.look[3] })
		local right = unit(cross(up, back))
		back = cross(right, up)
		bones[b.name] = {
			rest = { right[1], up[1], back[1], right[2], up[2], back[2], right[3], up[3], back[3] },
			pos = { b.pos[1] * k, b.pos[2] * k, b.pos[3] * k },
			parent = b.parent,
		}
		table.insert(names, b.name)
	end
	return { bones = bones, names = names, height = raw.height * k, width = raw.width * k, depth = raw.depth * k }
end

-- The skeleton of `model`'s role map on its dump.
function QuadRigFk.skeleton(model: string, scale: number?): (QuadPose.Skeleton?, Dump)
	local dump = QuadRigFk.load(model, scale)
	local rig = QuadRigs.get(model)
	return if rig then QuadPose.skeleton(dump.bones, rig) else nil, dump
end

-- Every bone's joint (model frame) and turn (model axes) from the driven bones' world turns and the body's shift.
local function place(
	skel: QuadPose.Skeleton,
	world: { [string]: Mat },
	shift: Vec
): ({ [string]: Vec }, { [string]: Mat })
	local bones = skel.bones
	-- the turn of every bone: its own when driven, else its nearest driven ancestor's (the Transform is identity)
	local turnOf: { [string]: Mat } = {}
	local function turn(name: string): Mat
		local t = turnOf[name]
		if t then
			return t
		end
		local w = world[name]
		if not w then
			local p = bones[name].parent
			w = if p and bones[p] then turn(p) else QuadPose.rx(0)
		end
		turnOf[name] = w
		return w
	end
	local out: { [string]: Vec } = {}
	local function at(name: string): Vec
		local done = out[name]
		if done then
			return done
		end
		local bone = bones[name]
		local p = bone.parent
		local v: Vec
		if p and bones[p] then
			local base = at(p)
			local d = apply(turn(p), sub(bone.pos, bones[p].pos))
			v = { base[1] + d[1], base[2] + d[2], base[3] + d[3] }
		else
			v = { bone.pos[1], bone.pos[2], bone.pos[3] }
		end
		if name == skel.rig.body then
			v = { v[1] + shift[1], v[2] + shift[2], v[3] + shift[3] }
		end
		out[name] = v
		return v
	end
	for name in bones do
		at(name)
		turn(name)
	end
	return out, turnOf
end

-- Where every bone's joint is (model frame) in the pose of `controls`, and every bone's turn (model axes).
function QuadRigFk.pose(skel: QuadPose.Skeleton, controls: QuadPose.Controls): ({ [string]: Vec }, { [string]: Mat })
	local world, shift = QuadPose.world(skel, controls)
	return place(skel, world, shift)
end

-- The same from the Transforms a frame writes (Logic/QuadMotion.step's output): what the model really shows.
function QuadRigFk.posed(skel: QuadPose.Skeleton, posed: QuadPose.Posed): ({ [string]: Vec }, { [string]: Mat })
	local world: { [string]: Mat } = {}
	local shift: Vec = { 0, 0, 0 }
	for _, name in skel.order do
		local entry = posed[name]
		local rest = skel.bones[name].rest
		local p = skel.parent[name]
		local base = if p then world[p] or QuadPose.rx(0) else QuadPose.rx(0)
		-- Transform = rest^-1 * turn * rest, so turn = rest * Transform * rest^-1
		local turn = if entry then mul(mul(rest, entry.rot), transpose(rest)) else QuadPose.rx(0)
		world[name] = mul(base, turn)
		if entry and entry.offset and name == skel.rig.body then
			shift = apply(rest, entry.offset)
		end
	end
	return place(skel, world, shift)
end

-- Where every bone's joint is (model frame) in the pose of `controls`.
function QuadRigFk.positions(skel: QuadPose.Skeleton, controls: QuadPose.Controls): { [string]: Vec }
	return (QuadRigFk.pose(skel, controls))
end

-- Where each foot is (model frame): the last joint of the leg, or the tip the map gives its last bone.
function QuadRigFk.feetOf(skel: QuadPose.Skeleton, at: { [string]: Vec }, turns: { [string]: Mat }): { [string]: Vec }
	local out: { [string]: Vec } = {}
	for side, leg in skel.rig.legs do
		local last = leg[#leg].bone
		local segs = skel.chains[side].segs
		local d = apply(turns[last], segs[#segs])
		local j = at[last]
		out[side] = { j[1] + d[1], j[2] + d[2], j[3] + d[3] }
	end
	return out
end

function QuadRigFk.feetAt(skel: QuadPose.Skeleton, controls: QuadPose.Controls): { [string]: Vec }
	return QuadRigFk.feetOf(skel, QuadRigFk.pose(skel, controls))
end

-- The last bone of each leg (the foot or paw joint).
function QuadRigFk.feet(skel: QuadPose.Skeleton): { [string]: string }
	local out: { [string]: string } = {}
	for side, leg in skel.rig.legs do
		out[side] = leg[#leg].bone
	end
	return out
end

return QuadRigFk
