--!strict
-- Template animation (docs/ANIM-WZORCE.md F3): the pose of an imported flyer (Tripo bones, Data/FlyerRigs role map) from
-- named controls. Pure: client/Anim/FlyerRig reads the bones' rest rotations, positions and parents in the look's root
-- space (front -Z, up +Y, right +X, the ground at y = 0) and writes the Transforms returned here.
-- * The export is first turned to face -Z, laid level and centred over its root (FlyerRigs `facing`, `level`, `centre`,
--   at the `hover` height when the map gives one): every pose is solved in that corrected space and the body bone's
--   Transform carries the correction.
-- * Each driven bone takes a turn in root axes composed on its logical parent's (the spine on the body, the neck on the
--   chest, a wing on the chest even where Tripo hung it from the head); its Transform is
--   rest^-1 * (parentWorld^-1 * world) * rest against its real parent (the convention of Logic/QuadPose), and a bone
--   pinned to another than its real parent (FlyerRigs wing `pin`, `fanBase`) is moved back to where that bone carries
--   it. The bones run in the order of what they hang on (their parent, pin, base, the wing segment before them and the
--   bone a follower copies), so every turn they compose on is solved before them.
-- * Wings live in a canonical frame: spread straight out to the side, flat, the top up (0 on every control). Each wing's
--   plane is fitted once from its rest joints (shoulder, wrist, tip), so a heraldic, a folded or a spread export all
--   flap the same way (FlyerRigs `surface`: the feathers' plane measured from the mesh, where the arm bends out of
--   it). A wing's `fingers` turn with its hand and fan about the wing's normal; a `follow` bone takes the
--   turn of the bone it copies (part of the way from its parent's).
-- Controls (radians; distances in dump units, FlyerRigs `measure` / `restHeight`):
--   body  bx by bz, bpitch (+ nose up) byaw (+ turns left) broll (+ right side up): about the body's centre
--   spine spitch syaw sroll;  neck npitch nyaw;  head hpitch hyaw hroll (pitch + up);  jaw (+ open)
--   tail  tpitch (+ its tip up) tyaw (+ its tip to the left) fan (+ feathers spread)
--   legs  l<S>s (+ the foot forward) l<S>f (+ tucked) l<S>c (+ toes curled) l<S>o (+ out); S = L / R
--   wings w<S>e elevation (+ up), w<S>s sweep (+ forward), w<S>t twist (+ leading edge up), w<S>f elbow fold (the wrist
--         toward the leading edge), w<S>h wrist fold (the primaries back), w<S>b w<S>w w<S>p the forearm, the hand and
--         the primaries bent up (the whip), w<S>q the hand's twist, w<S>n the fingers fanned (+ back, by their spread)
-- Hot path without allocations: the matrices and the result table live in the skeleton and are rewritten every frame.

local FlyerRigs = require("../Data/FlyerRigs")

local FlyerPose = {}

export type Mat = { number }
export type Vec = { number }
export type Controls = { [string]: number }
export type Bone = { rest: Mat, pos: Vec, parent: string? }
export type Entry = { rot: Mat, offset: Vec? }
export type Posed = { [string]: Entry }
export type Options = { scale: number? } -- scale: the clone's size over its template's (FlyerRigs `hover`)

type Node = {
	name: string,
	role: string, -- body spine neck head jaw tail fan leg clav wing finger follow leaf
	rest: Mat, -- the export's rest rotation (root space)
	pos: Vec, -- the corrected rest pivot
	origin: Vec, -- the export's rest pivot
	sp: Node?, -- nearest driven ancestor in the export's hierarchy
	pin: Node?, -- the bone its position hangs from, when not `sp`
	base: Node?, -- the bone its turn composes on (a finger: its wing segment; a follower: the bone it copies)
	link: Node?, -- wing: the segment before it
	share: number,
	swing: number,
	fold: number,
	curl: number,
	side: number, -- -1 left, 1 right
	seg: number, -- wing segment: 1 humerus, 2 forearm, 3 hand, 4 primaries
	spread: number, -- finger: its share of the fan
	fit: Mat?, -- wing: rest -> canonical (spread straight out, flat)
	chain: Mat, -- wing: its canonical chain this frame (the shoulder's turns and the bends up to it)
	keys: { [string]: string }?, -- leg / wing: its control names by letter (no strings built per frame)
	world: Mat,
	at: Vec,
	entry: Entry,
	offset: Vec,
}

export type Skeleton = {
	rig: FlyerRigs.Rig,
	nodes: { Node },
	byName: { [string]: Node },
	fix: Mat, -- the export's correction: Rx(-level) * Ry(-facing)
	pivot: Vec, -- the body's centre (corrected rest, root space)
	unit: number, -- studs per dump unit (the clone's scale)
	lowest: number, -- height of the lowest bone over the ground at rest (studs)
	neck: number, -- studs from the neck's base to the head
	wings: boolean,
	posed: Posed,
	muzzleAt: { Node },
	muzzleOffset: Vec, -- studs, the corrected rest frame (carried by the first muzzle bone's turn)
}

---------------------------------------------------------------- matrices (row-major 3x3, in place)

local function newMat(): Mat
	return { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
end

local function setIdentity(o: Mat)
	o[1], o[2], o[3], o[4], o[5], o[6], o[7], o[8], o[9] = 1, 0, 0, 0, 1, 0, 0, 0, 1
end

local function copyMat(o: Mat, a: Mat)
	for i = 1, 9 do
		o[i] = a[i]
	end
end

-- o = a * b (o is neither a nor b)
local function mulInto(o: Mat, a: Mat, b: Mat)
	local a1, a2, a3, a4, a5, a6, a7, a8, a9 = a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9]
	local b1, b2, b3, b4, b5, b6, b7, b8, b9 = b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9]
	o[1] = a1 * b1 + a2 * b4 + a3 * b7
	o[2] = a1 * b2 + a2 * b5 + a3 * b8
	o[3] = a1 * b3 + a2 * b6 + a3 * b9
	o[4] = a4 * b1 + a5 * b4 + a6 * b7
	o[5] = a4 * b2 + a5 * b5 + a6 * b8
	o[6] = a4 * b3 + a5 * b6 + a6 * b9
	o[7] = a7 * b1 + a8 * b4 + a9 * b7
	o[8] = a7 * b2 + a8 * b5 + a9 * b8
	o[9] = a7 * b3 + a8 * b6 + a9 * b9
end

-- o = a^T * b
local function tmulInto(o: Mat, a: Mat, b: Mat)
	local a1, a2, a3, a4, a5, a6, a7, a8, a9 = a[1], a[2], a[3], a[4], a[5], a[6], a[7], a[8], a[9]
	local b1, b2, b3, b4, b5, b6, b7, b8, b9 = b[1], b[2], b[3], b[4], b[5], b[6], b[7], b[8], b[9]
	o[1] = a1 * b1 + a4 * b4 + a7 * b7
	o[2] = a1 * b2 + a4 * b5 + a7 * b8
	o[3] = a1 * b3 + a4 * b6 + a7 * b9
	o[4] = a2 * b1 + a5 * b4 + a8 * b7
	o[5] = a2 * b2 + a5 * b5 + a8 * b8
	o[6] = a2 * b3 + a5 * b6 + a8 * b9
	o[7] = a3 * b1 + a6 * b4 + a9 * b7
	o[8] = a3 * b2 + a6 * b5 + a9 * b8
	o[9] = a3 * b3 + a6 * b6 + a9 * b9
end

-- Ry(yaw) * Rx(pitch) * Rz(roll)
local function eulerInto(o: Mat, yaw: number, pitch: number, roll: number)
	local cy, sy = math.cos(yaw), math.sin(yaw)
	local cp, sp = math.cos(pitch), math.sin(pitch)
	local cr, sr = math.cos(roll), math.sin(roll)
	o[1] = cy * cr + sy * sp * sr
	o[2] = -cy * sr + sy * sp * cr
	o[3] = sy * cp
	o[4] = cp * sr
	o[5] = cp * cr
	o[6] = -sp
	o[7] = -sy * cr + cy * sp * sr
	o[8] = sy * sr + cy * sp * cr
	o[9] = cy * cp
end

-- Rz(a) * Ry(b) * Rx(c): a wing's elevation, sweep and twist at its shoulder
local function zyxInto(o: Mat, a: number, b: number, c: number)
	local ca, sa = math.cos(a), math.sin(a)
	local cb, sb = math.cos(b), math.sin(b)
	local cc, sc = math.cos(c), math.sin(c)
	o[1] = ca * cb
	o[2] = ca * sb * sc - sa * cc
	o[3] = ca * sb * cc + sa * sc
	o[4] = sa * cb
	o[5] = sa * sb * sc + ca * cc
	o[6] = sa * sb * cc - ca * sc
	o[7] = -sb
	o[8] = cb * sc
	o[9] = cb * cc
end

-- Ry(b) * Rz(a) * Rx(c): a wing joint's fold (in the wing's plane), bend (up) and twist
local function yzxInto(o: Mat, b: number, a: number, c: number)
	local ca, sa = math.cos(a), math.sin(a)
	local cb, sb = math.cos(b), math.sin(b)
	local cc, sc = math.cos(c), math.sin(c)
	-- Ry(b) * Rz(a)
	local m1, m2, m3 = cb * ca, -cb * sa, sb
	local m4, m5, m6 = sa, ca, 0
	local m7, m8, m9 = -sb * ca, sb * sa, cb
	-- * Rx(c)
	o[1] = m1
	o[2] = m2 * cc + m3 * sc
	o[3] = -m2 * sc + m3 * cc
	o[4] = m4
	o[5] = m5 * cc + m6 * sc
	o[6] = -m5 * sc + m6 * cc
	o[7] = m7
	o[8] = m8 * cc + m9 * sc
	o[9] = -m8 * sc + m9 * cc
end

local function apply(m: Mat, x: number, y: number, z: number): (number, number, number)
	return m[1] * x + m[2] * y + m[3] * z, m[4] * x + m[5] * y + m[6] * z, m[7] * x + m[8] * y + m[9] * z
end

local function tapply(m: Mat, x: number, y: number, z: number): (number, number, number)
	return m[1] * x + m[4] * y + m[7] * z, m[2] * x + m[5] * y + m[8] * z, m[3] * x + m[6] * y + m[9] * z
end

local function axisAngleInto(o: Mat, x: number, y: number, z: number, angle: number)
	local c, s = math.cos(angle), math.sin(angle)
	local t = 1 - c
	o[1], o[2], o[3] = t * x * x + c, t * x * y - s * z, t * x * z + s * y
	o[4], o[5], o[6] = t * x * y + s * z, t * y * y + c, t * y * z - s * x
	o[7], o[8], o[9] = t * x * z - s * y, t * y * z + s * x, t * z * z + c
end

local function axisAngle(x: number, y: number, z: number, angle: number): Mat
	local o = newMat()
	axisAngleInto(o, x, y, z, angle)
	return o
end

-- o = the turn `r` taken `k` of the way (same axis, k times the angle; o is not r)
local function partialInto(o: Mat, r: Mat, k: number)
	local x, y, z = r[8] - r[6], r[3] - r[7], r[4] - r[2]
	local s = math.sqrt(x * x + y * y + z * z) -- 2 sin(angle)
	if s < 1e-7 then
		setIdentity(o)
		return
	end
	axisAngleInto(o, x / s, y / s, z / s, math.atan2(s, r[1] + r[5] + r[9] - 1) * k)
end

local function vsub(a: Vec, b: Vec): Vec
	return { a[1] - b[1], a[2] - b[2], a[3] - b[3] }
end

local function vlen(a: Vec): number
	return math.sqrt(a[1] * a[1] + a[2] * a[2] + a[3] * a[3])
end

local function vunit(a: Vec): Vec?
	local l = vlen(a)
	if l < 1e-6 then
		return nil
	end
	return { a[1] / l, a[2] / l, a[3] / l }
end

local function vdot(a: Vec, b: Vec): number
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

local function vcross(a: Vec, b: Vec): Vec
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end

-- The rotation whose columns are x, y, z.
local function columns(x: Vec, y: Vec, z: Vec): Mat
	return { x[1], y[1], z[1], x[2], y[2], z[2], x[3], y[3], z[3] }
end

-- The turn taking direction `d` onto the canonical span `(side, 0, 0)` inside the wing's plane (about +Y), then the
-- small rest out of the plane by the shortest turn.
local function alignSpan(d: Vec, side: number): Mat
	local inPlane = math.atan2(-d[3], d[1]) -- angle of d about +Y measured from +X
	local target = if side > 0 then 0 else math.pi
	local m = axisAngle(0, 1, 0, target - inPlane)
	local x, y, z = apply(m, d[1], d[2], d[3])
	local u = vunit({ x, y, z }) :: Vec
	local goal = { side, 0, 0 }
	local dot = math.clamp(vdot(u, goal), -1, 1)
	local axis = vunit(vcross(u, goal))
	if not axis or dot > 1 - 1e-9 then
		return m
	end
	local tilt = axisAngle(axis[1], axis[2], axis[3], math.acos(dot))
	local out = newMat()
	mulInto(out, tilt, m)
	return out
end

---------------------------------------------------------------- the skeleton

-- The bones the skeleton turns (the rest of the export rides on them).
local function driven(rig: FlyerRigs.Rig): { [string]: boolean }
	local set: { [string]: boolean } = { [rig.body] = true, [rig.head] = true }
	local function add(name: string?)
		if name then
			set[name] = true
		end
	end
	for _, row in rig.spine do
		add(row.bone)
	end
	for _, row in rig.neck do
		add(row.bone)
	end
	add(rig.jaw)
	for _, name in rig.tail do
		add(name)
	end
	local fan: { string } = rig.fan or {}
	for _, name in fan do
		add(name)
	end
	add(rig.fanBase)
	for _, leg in rig.legs do
		for _, joint in leg do
			add(joint.bone)
		end
	end
	if rig.wings then
		for _, wing in rig.wings do
			add(wing.clav)
			add(wing.humerus)
			add(wing.forearm)
			add(wing.hand)
			add(wing.primaries)
			add(wing.pin)
			local fingers: { FlyerRigs.Finger } = wing.fingers or {}
			for _, finger in fingers do
				add(finger.bone)
			end
		end
	end
	local follow: { FlyerRigs.Follow } = rig.follow or {}
	for _, row in follow do
		add(row.bone)
		add(row.like)
	end
	for _, name in rig.muzzle.at do
		add(name)
	end
	return set
end

local function controlNames(prefix: string, letters: string): { [string]: string }
	local out: { [string]: string } = {}
	for letter in string.gmatch(letters, ".") do
		out[letter] = prefix .. letter
	end
	return out
end

-- The export's turn about +Y (rad) that faces it to -Z: the map's `facing`, else read from the wings (the right wing's
-- shoulder, elbow and wrist lie to +X of the left's).
local function facingOf(bones: { [string]: Bone }, rig: FlyerRigs.Rig): number
	if rig.facing then
		return math.rad(rig.facing)
	end
	local wings = rig.wings
	local r, l = if wings then wings.R else nil, if wings then wings.L else nil
	if not r or not l then
		return 0
	end
	local x, z = 0, 0
	for _, pair in { { r.humerus, l.humerus }, { r.forearm, l.forearm }, { r.hand, l.hand } } do
		local a, b = bones[pair[1]].pos, bones[pair[2]].pos
		x += a[1] - b[1]
		z += a[3] - b[3]
	end
	return math.atan2(-z, x)
end

-- The skeleton from every bone of the look (root space: rest, pos, parent name; the ground at y = 0) and the role map;
-- nil when a bone of the map is missing. `opts.scale`: the clone's size over its template's (the `hover` height grows
-- with it; without it the map's own measure scales it).
function FlyerPose.skeleton(bones: { [string]: Bone }, rig: FlyerRigs.Rig, opts: Options?): Skeleton?
	for name in FlyerRigs.bones(rig) do
		if not bones[name] then
			return nil
		end
	end
	local drive = driven(rig)
	local bodyBone = bones[rig.body]
	-- studs per dump unit: the measured distance of two bones, else the body bone's height
	local unit = 1
	local measure = rig.measure
	if measure then
		unit = vlen(vsub(bones[measure.from].pos, bones[measure.to].pos)) / measure.length
	elseif rig.restHeight then
		unit = bodyBone.pos[2] / rig.restHeight
	end
	if not (unit > 1e-4) then
		unit = 1
	end
	-- the correction about the body bone's pivot (faced to -Z, then laid level), then the centre over the root
	local fix = newMat()
	mulInto(fix, axisAngle(1, 0, 0, -math.rad(rig.level or 0)), axisAngle(0, 1, 0, -facingOf(bones, rig)))
	local o = bodyBone.pos
	local function corrected(p: Vec): Vec
		local x, y, z = apply(fix, p[1] - o[1], p[2] - o[2], p[3] - o[3])
		return { x + o[1], y + o[2], z + o[3] }
	end
	local cx, cy, cz = 0, 0, 0
	for _, name in rig.centre do
		local p = corrected(bones[name].pos)
		cx += p[1]
		cy += p[2]
		cz += p[3]
	end
	local n = #rig.centre
	cx, cy, cz = cx / n, cy / n, cz / n
	-- the centre at the hover's height (old-template studs times the clone's scale)
	local lift = 0
	if rig.hover then
		local scale = if opts and opts.scale and opts.scale > 0 then opts.scale else unit
		lift = rig.hover * scale - cy
	end
	local function placed(p: Vec): Vec
		local q = corrected(p)
		return { q[1] - cx, q[2] + lift, q[3] - cz }
	end
	local lowest = math.huge
	for _, bone in bones do
		lowest = math.min(lowest, placed(bone.pos)[2])
	end
	local byName: { [string]: Node } = {}
	local nodes: { Node } = {}
	local posed: Posed = {}
	for name in drive do
		local bone = bones[name]
		local entry: Entry = { rot = newMat(), offset = nil }
		local node: Node = {
			name = name,
			role = "",
			rest = bone.rest,
			pos = placed(bone.pos),
			origin = bone.pos,
			sp = nil,
			pin = nil,
			base = nil,
			link = nil,
			share = 1,
			swing = 0,
			fold = 0,
			curl = 0,
			side = 1,
			seg = 0,
			spread = 0,
			fit = nil,
			chain = newMat(),
			keys = nil,
			world = newMat(),
			at = { 0, 0, 0 },
			entry = entry,
			offset = { 0, 0, 0 },
		}
		byName[name] = node
		table.insert(nodes, node)
		posed[name] = entry
	end
	for _, node in nodes do
		local p = bones[node.name].parent
		while p and not drive[p] do
			local b = bones[p]
			p = if b then b.parent else nil
		end
		node.sp = if p then byName[p] else nil
	end
	-- roles and the bones their turns compose on
	local body = byName[rig.body]
	body.role = "body"
	local last = body
	for _, row in rig.spine do
		local node = byName[row.bone]
		node.role, node.share, node.base = "spine", row.share, last
		last = node
	end
	local chest = last
	for _, row in rig.neck do
		local node = byName[row.bone]
		node.role, node.share, node.base = "neck", row.share, last
		last = node
	end
	local head = byName[rig.head]
	head.role, head.base = "head", last
	if rig.jaw then
		local jaw = byName[rig.jaw]
		jaw.role, jaw.base = "jaw", head
	end
	local neckLength = vlen(vsub(head.pos, byName[(rig.neck[1] or { bone = rig.head }).bone].pos))
	last = body
	for i, name in rig.tail do
		local node = byName[name]
		node.role, node.share, node.base = "tail", 1 / #rig.tail, last
		node.seg = i
		last = node
	end
	-- the fan turns with the tail's last bone and hangs from `fanBase` (Tripo hung the crow's from the body)
	local fanBase = if rig.fanBase then byName[rig.fanBase] else nil
	local fan: { string } = rig.fan or {}
	for i, name in fan do
		local node = byName[name]
		node.role, node.base = "fan", last
		-- the centre feather stays, the others spread to either side
		node.side = if i == 1 then 0 elseif i % 2 == 0 then 1 else -1
		if fanBase and node.sp ~= fanBase and node ~= fanBase then
			node.pin = fanBase
		end
	end
	for sideName, leg in rig.legs do
		local side = if sideName == "R" then 1 else -1
		local prev = body
		for i, joint in leg do
			local node = byName[joint.bone]
			node.role, node.base, node.side = "leg", prev, side
			node.swing, node.fold, node.curl = joint.swing or 0, joint.fold or 0, joint.curl or 0
			node.seg = i
			node.keys = controlNames("l" .. sideName, "sfco")
			prev = node
		end
	end
	local childOf: { [string]: string } = {}
	for name, bone in bones do
		local parent = bone.parent
		if parent and (not childOf[parent] or name < childOf[parent]) then
			childOf[parent] = name
		end
	end
	local hasWings = false
	if rig.wings then
		for sideName, wing in rig.wings do
			hasWings = true
			local side = if sideName == "R" then 1 else -1
			local keys = controlNames("w" .. sideName, "estfhbwpqn")
			local anchor = if wing.pin then byName[wing.pin] else chest
			anchor = anchor or chest
			local first = wing.clav or wing.humerus
			local firstNode = byName[first]
			if wing.pin and firstNode.sp ~= anchor then
				firstNode.pin = anchor
			end
			if wing.clav then
				local clav = byName[wing.clav]
				clav.role, clav.base, clav.side = "clav", anchor, side
				clav.keys = keys
			end
			-- the wing's plane from the shoulder, the wrist and the tip
			local S = byName[wing.humerus].pos
			local E = byName[wing.forearm].pos
			local W = byName[wing.hand].pos
			local P = if wing.primaries then byName[wing.primaries].pos else nil
			local tipBone = if wing.tip then bones[wing.tip] else nil
			local T: Vec
			if tipBone then
				T = placed(tipBone.pos)
			else
				local from = P or W
				local back = if P then W else E
				T = { from[1] + (from[1] - back[1]), from[2] + (from[2] - back[2]), from[3] + (from[3] - back[3]) }
			end
			local dorsal = vunit(wing.dorsal) or { 0, 1, 0 }
			-- the feathers' own plane where the arm has a gull bend out of it, else the plane of the three joints
			local normal = (if wing.surface then vunit(wing.surface) else nil)
				or vunit(vcross(vsub(W, S), vsub(T, S)))
				or dorsal
			if vdot(normal, dorsal) < 0 then
				normal = { -normal[1], -normal[2], -normal[3] }
			end
			local reach = vsub(T, S)
			local k = vdot(reach, normal)
			local span = vunit({ reach[1] - normal[1] * k, reach[2] - normal[2] * k, reach[3] - normal[3] * k })
				or { side, 0, 0 }
			local chord = vcross(span, normal)
			local restFrame = columns(span, normal, chord)
			local canon = columns({ side, 0, 0 }, { 0, 1, 0 }, { 0, 0, side })
			local F = newMat()
			mulInto(F, canon, { -- canon * restFrame^T
				restFrame[1],
				restFrame[4],
				restFrame[7],
				restFrame[2],
				restFrame[5],
				restFrame[8],
				restFrame[3],
				restFrame[6],
				restFrame[9],
			})
			local segments: { { name: string, from: Vec, to: Vec } } = {
				{ name = wing.humerus, from = S, to = E },
				{ name = wing.forearm, from = E, to = W },
				{ name = wing.hand, from = W, to = P or T },
			}
			if wing.primaries and P then
				table.insert(segments, { name = wing.primaries, from = P, to = T })
			end
			local prev: Node? = nil
			for i, row in segments do
				local node = byName[row.name]
				node.role, node.base, node.side, node.seg, node.link = "wing", anchor, side, i, prev
				node.keys = keys
				local d = vsub(row.to, row.from)
				local x, y, z = apply(F, d[1], d[2], d[3])
				local fit = newMat()
				mulInto(fit, alignSpan({ x, y, z }, side), F)
				node.fit = fit
				prev = node
			end
			-- the fingers fan about the normal of the segment they hang from (else the hand), laid into its plane (a
			-- membrane finger that hangs at rest spreads flat)
			local fingers: { FlyerRigs.Finger } = wing.fingers or {}
			for _, finger in fingers do
				local node = byName[finger.bone] :: Node
				local sp = node.sp
				local seg: Node = if sp and sp.role == "wing" and sp.side == side then sp else byName[wing.hand] :: Node
				node.role, node.base, node.side, node.spread = "finger", seg, side, finger.spread
				node.keys = keys
				local segFit = seg.fit :: Mat
				local fit = newMat()
				copyMat(fit, segFit)
				local child = childOf[finger.bone]
				if child then
					local d = vsub(placed(bones[child].pos), node.pos)
					local x, y, z = apply(segFit, d[1], d[2], d[3])
					local u = vunit({ x, y, z })
					local flat = vunit({ x, 0, z })
					local axis = if u and flat then vunit(vcross(u, flat)) else nil
					if u and flat and axis then
						local tilt = axisAngle(axis[1], axis[2], axis[3], math.acos(math.clamp(vdot(u, flat), -1, 1)))
						mulInto(fit, tilt, segFit)
					end
				end
				node.fit = fit
			end
		end
	end
	-- bones that belong to a wing but hang from the body or a shoulder blade copy a wing bone's turn
	local follow: { FlyerRigs.Follow } = rig.follow or {}
	for _, row in follow do
		local node = byName[row.bone]
		node.role, node.base, node.share = "follow", byName[row.like], row.share or 1
	end
	-- bones mapped for the muzzle (or as a pin) only follow their parents
	for _, node in nodes do
		if node.role == "" then
			node.role = "leaf"
		end
	end
	-- the order: after every bone a turn or a pivot hangs on (its parent, pin, base, the segment before it)
	local level: { [Node]: number } = {}
	local function levelOf(node: Node, guard: number): number
		local known = level[node]
		if known then
			return known
		end
		local l = 0
		local function after(other: Node?)
			if other and other ~= node and guard < 64 then
				l = math.max(l, levelOf(other, guard + 1) + 1)
			end
		end
		after(node.sp)
		after(node.pin)
		after(node.base)
		after(node.link)
		level[node] = l
		return l
	end
	for _, node in nodes do
		levelOf(node, 0)
	end
	table.sort(nodes, function(a, b)
		if level[a] ~= level[b] then
			return level[a] < level[b]
		end
		return a.name < b.name
	end)
	local muzzleAt: { Node } = {}
	for _, name in rig.muzzle.at do
		table.insert(muzzleAt, byName[name])
	end
	return {
		rig = rig,
		nodes = nodes,
		byName = byName,
		fix = fix,
		pivot = { 0, cy + lift, 0 },
		unit = unit,
		lowest = lowest,
		neck = math.max(0.05, neckLength),
		wings = hasWings,
		posed = posed,
		muzzleAt = muzzleAt,
		muzzleOffset = { 0, (rig.muzzle.up or 0) * unit, -(rig.muzzle.ahead or 0) * unit },
	}
end

---------------------------------------------------------------- the pose

local L = newMat()
local M1 = newMat()
local M2 = newMat()

local function c(controls: Controls, key: string): number
	return controls[key] or 0
end

-- A wing segment's canonical chain into its `chain`: the shoulder's elevation, sweep and twist, then each joint's bends
-- on the chain of the segment before it.
local function wingChain(node: Node, controls: Controls)
	local k = node.keys :: { [string]: string }
	local m = node.side
	local seg = node.seg
	local link = node.link
	if seg == 1 or not link then
		zyxInto(node.chain, m * c(controls, k.e), m * c(controls, k.s), c(controls, k.t))
		return
	end
	if seg == 2 then
		yzxInto(L, m * c(controls, k.f), m * c(controls, k.b), 0)
	elseif seg == 3 then
		yzxInto(L, -m * c(controls, k.h), m * c(controls, k.w), c(controls, k.q))
	else
		yzxInto(L, -m * c(controls, k.h) * 0.35, m * c(controls, k.p), 0)
	end
	mulInto(node.chain, link.chain, L)
end

-- Fills every node's world turn and pivot for `controls` (corrected space).
function FlyerPose.world(skel: Skeleton, controls: Controls)
	local rig = skel.rig
	local unit = skel.unit
	local pv = skel.pivot
	for _, node in skel.nodes do
		local role = node.role
		local world = node.world
		if role == "body" then
			eulerInto(world, c(controls, "byaw"), c(controls, "bpitch") + rig.carriage, c(controls, "broll"))
		elseif role == "spine" then
			local k = node.share
			eulerInto(L, c(controls, "syaw") * k, c(controls, "spitch") * k, c(controls, "sroll") * k)
			mulInto(world, (node.base :: Node).world, L)
		elseif role == "neck" then
			local k = node.share
			eulerInto(L, c(controls, "nyaw") * k, c(controls, "npitch") * k, 0)
			mulInto(world, (node.base :: Node).world, L)
		elseif role == "head" then
			eulerInto(L, c(controls, "hyaw"), c(controls, "hpitch"), c(controls, "hroll"))
			mulInto(world, (node.base :: Node).world, L)
		elseif role == "tail" then
			-- the tail points back: + pitch lifts its tip, + yaw swings it to the left
			local k = node.share
			eulerInto(L, -c(controls, "tyaw") * k, -c(controls, "tpitch") * k, 0)
			mulInto(world, (node.base :: Node).world, L)
		elseif role == "fan" then
			eulerInto(L, c(controls, "fan") * node.side, 0, 0)
			mulInto(world, (node.base :: Node).world, L)
		elseif role == "leg" then
			local k = node.keys :: { [string]: string }
			local pitch = node.swing * c(controls, k.s) + node.fold * c(controls, k.f) + node.curl * c(controls, k.c)
			local roll = if node.seg == 1 then node.side * c(controls, k.o) else 0
			eulerInto(L, 0, pitch, roll)
			mulInto(world, (node.base :: Node).world, L)
		elseif role == "clav" then
			local k = node.keys :: { [string]: string }
			local m = node.side
			zyxInto(L, m * c(controls, k.e) * 0.25, m * c(controls, k.s) * 0.3, 0)
			mulInto(world, (node.base :: Node).world, L)
		elseif role == "wing" then
			wingChain(node, controls)
			mulInto(M1, (node.base :: Node).world, node.chain)
			mulInto(world, M1, node.fit :: Mat)
		elseif role == "finger" then
			-- fanned about the normal of its segment (the wing's plane there), back toward the trailing edge
			local seg = node.base :: Node
			local k = node.keys :: { [string]: string }
			axisAngleInto(L, 0, 1, 0, -node.side * c(controls, k.n) * node.spread)
			mulInto(M1, seg.chain, L)
			mulInto(M2, (seg.base :: Node).world, M1)
			mulInto(world, M2, node.fit :: Mat)
		elseif role == "jaw" then
			eulerInto(L, 0, -c(controls, "jaw"), 0)
			mulInto(world, (node.base :: Node).world, L)
		elseif role == "follow" then
			-- the turn of the bone it copies, part of the way from its parent's; a feather row on a wing segment
			-- (the secondaries on the forearm) keeps its spread lie to the segment it copies, so it trails behind the
			-- folded wing instead of fanning out sideways with the forearm
			local like = node.base :: Node
			local sp = node.sp
			local goal = like.world
			if sp and sp.role == "wing" and like.role == "wing" then
				mulInto(M2, (like.base :: Node).world, like.chain)
				mulInto(M1, M2, sp.fit :: Mat)
				goal = M1
			end
			if node.share >= 0.999 or not sp then
				copyMat(world, goal)
			else
				tmulInto(M2, sp.world, goal)
				partialInto(L, M2, node.share)
				mulInto(world, sp.world, L)
			end
		elseif role == "leaf" and node.sp then
			copyMat(world, (node.sp :: Node).world)
		else
			setIdentity(world)
		end
	end
	-- pivots: the body about the centre, the rest carried by their parents (or by their pin)
	for _, node in skel.nodes do
		local at = node.at
		if node.role == "body" then
			local w = node.world
			local x, y, z = apply(w, node.pos[1] - pv[1], node.pos[2] - pv[2], node.pos[3] - pv[3])
			at[1] = pv[1] + x + c(controls, "bx") * unit
			at[2] = pv[2] + y + c(controls, "by") * unit
			at[3] = pv[3] + z + c(controls, "bz") * unit
		else
			local from = node.pin or node.sp
			if from then
				local x, y, z =
					apply(from.world, node.pos[1] - from.pos[1], node.pos[2] - from.pos[2], node.pos[3] - from.pos[3])
				at[1], at[2], at[3] = from.at[1] + x, from.at[2] + y, from.at[3] + z
			else
				at[1], at[2], at[3] = node.pos[1], node.pos[2], node.pos[3]
			end
		end
	end
end

-- The Transforms of the turns and pivots FlyerPose.world left in the skeleton (the skeleton's own `posed` table).
function FlyerPose.transforms(skel: Skeleton): Posed
	local fix = skel.fix
	for _, node in skel.nodes do
		local entry = node.entry
		local sp = node.sp
		-- the true turn of a bone is world * fix (the correction first); against its real parent:
		-- rel = (spWorld * fix)^T * (world * fix) = fix^T * spWorld^T * world * fix
		if sp then
			tmulInto(M1, sp.world, node.world)
			mulInto(M2, M1, fix)
			tmulInto(M1, fix, M2)
		else
			mulInto(M1, node.world, fix)
		end
		-- rest^T * rel * rest
		mulInto(M2, M1, node.rest)
		tmulInto(entry.rot, node.rest, M2)
		if node.role == "body" then
			local o = node.offset
			o[1], o[2], o[3] =
				tapply(node.rest, node.at[1] - node.origin[1], node.at[2] - node.origin[2], node.at[3] - node.origin[3])
			entry.offset = o
		elseif node.pin and sp then
			-- carried by its pin, not its real parent: move it back by the difference (in the parent's frame)
			local x, y, z = apply(sp.world, node.pos[1] - sp.pos[1], node.pos[2] - sp.pos[2], node.pos[3] - sp.pos[3])
			local dx, dy, dz = node.at[1] - (sp.at[1] + x), node.at[2] - (sp.at[2] + y), node.at[3] - (sp.at[3] + z)
			mulInto(M1, sp.world, fix)
			local ax, ay, az = tapply(M1, dx, dy, dz)
			local o = node.offset
			o[1], o[2], o[3] = tapply(node.rest, ax, ay, az)
			entry.offset = o
		else
			entry.offset = nil
		end
	end
	return skel.posed
end

function FlyerPose.solve(skel: Skeleton, controls: Controls): Posed
	FlyerPose.world(skel, controls)
	return FlyerPose.transforms(skel)
end

-- Where shots leave the body in the last solved pose (root space) into `out`: the mean of the muzzle bones plus the
-- rig's offset carried by the first one's turn.
function FlyerPose.muzzle(skel: Skeleton, out: Vec)
	local list = skel.muzzleAt
	local n = #list
	if n == 0 then
		return
	end
	local x, y, z = 0, 0, 0
	for _, node in list do
		x += node.at[1]
		y += node.at[2]
		z += node.at[3]
	end
	local o = skel.muzzleOffset
	local ox, oy, oz = apply(list[1].world, o[1], o[2], o[3])
	out[1], out[2], out[3] = x / n + ox, y / n + oy, z / n + oz
end

-- Where a bone's pivot is in the last solved pose (root space), nil for a bone the skeleton does not drive.
function FlyerPose.at(skel: Skeleton, name: string): Vec?
	local node = skel.byName[name]
	return if node then node.at else nil
end

return FlyerPose
