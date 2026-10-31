--!strict
-- Template animation: reads the mocap clips of Data/BipedClips (baked by tools/anim/bake_biped.py from Mixamo FBX) and
-- samples one as world turns of the model's bones (Logic/BipedPose.World), retargeted by rest direction: the model's
-- bone first turns onto the clip's rest direction (an A-pose model on a T-pose clip), then by the clip's turn D(t) from
-- its own rest. 2026-10-31 (the monsters' actions on mocap):
-- * a clip is decoded once and shared by every instance (`decode` caches by source);
-- * a clip plays mirrored (`mirror`: left and right swapped, a right-hand swipe as the left's) at no extra cost;
-- * the arms also keep their roll where both rests know the knuckle line (the hand's index -> little finger root: the
--   clip's `knuckles`, the skeleton's from its finger bones), and a weapon's blade (the model's `grip`) can be laid
--   along the clip's (the line its fist closes round: `blade`), the wrist turning it as the keyed actions' aim does.
-- Pure.

local BoneClip = require("./BoneClip")
local NpcPose = require("./NpcPose")

local BipedClip = {}

type Vec = { number }
type Mat = { number }

export type Source = {
	bones: { string },
	dirs: { [string]: Vec },
	knuckles: { [string]: Vec }?, -- "R" / "L": the rest knuckle line (index -> little finger root), root space
	frames: number,
	fps: number,
	loop: boolean,
	speed: number?,
	contact: number?,
	hit: number?, -- seconds from the first frame to the contact or the release
	strike: number?, -- seconds of the fast part before it
	data: string,
}

export type Clip = {
	source: Source,
	bones: { string },
	frames: number,
	fps: number,
	length: number, -- seconds
	stride: number,
	buf: buffer,
	partner: { number }, -- by bone index: the index of the other side's bone (itself on the middle line)
}

-- Fit options: `mirror` the clip played with left and right swapped; `knuckles` the model's rest knuckle lines (root
-- space, "R" / "L"); `grip` the blade's rest direction in the model's right hand, laid along the clip's.
export type FitOptions = { mirror: boolean?, knuckles: { [string]: Vec }?, grip: Vec? }

local IDENTITY = NpcPose.IDENTITY
local mul, transpose, apply, unit = NpcPose.mul, NpcPose.transpose, NpcPose.apply, NpcPose.unit

local function otherSide(name: string): string
	if string.sub(name, 1, 4) == "Left" then
		return "Right" .. string.sub(name, 5)
	elseif string.sub(name, 1, 5) == "Right" then
		return "Left" .. string.sub(name, 6)
	end
	return name
end
BipedClip.otherSide = otherSide

-- (decoded clips by source: the data is read-only, every instance shares it)
local decoded: { [Source]: Clip } = setmetatable({} :: any, { __mode = "k" })

function BipedClip.decode(source: Source): Clip
	local cached = decoded[source]
	if cached then
		return cached
	end
	local index: { [string]: number } = {}
	for i, name in source.bones do
		index[name] = i
	end
	local partner = table.create(#source.bones, 0)
	for i, name in source.bones do
		partner[i] = index[otherSide(name)] or i
	end
	local clip: Clip = {
		source = source,
		bones = source.bones,
		frames = source.frames,
		fps = source.fps,
		length = math.max(1, source.frames - 1) / source.fps,
		stride = #source.bones * 6 + 6,
		buf = BoneClip.base64(source.data),
		partner = partner,
	}
	decoded[source] = clip
	return clip
end

local function quat(clip: Clip, frame: number, bone: number): (number, number, number, number)
	local at = frame * clip.stride + (bone - 1) * 6
	local x = buffer.readi16(clip.buf, at) / 32767
	local y = buffer.readi16(clip.buf, at + 2) / 32767
	local z = buffer.readi16(clip.buf, at + 4) / 32767
	return x, y, z, math.sqrt(math.max(0, 1 - x * x - y * y - z * z))
end

local function hips(clip: Clip, frame: number): (number, number, number)
	local at = frame * clip.stride + #clip.bones * 6
	return buffer.readi16(clip.buf, at) / 1000,
		buffer.readi16(clip.buf, at + 2) / 1000,
		buffer.readi16(clip.buf, at + 4) / 1000
end

-- Quaternion (x, y, z, w) to a rotation matrix (row-major).
local function toMat(x: number, y: number, z: number, w: number): Mat
	return {
		1 - 2 * (y * y + z * z),
		2 * (x * y - z * w),
		2 * (x * z + y * w),
		2 * (x * y + z * w),
		1 - 2 * (x * x + z * z),
		2 * (y * z - x * w),
		2 * (x * z - y * w),
		2 * (y * z + x * w),
		1 - 2 * (x * x + y * y),
	}
end
BipedClip.toMat = toMat

-- Normalized lerp of two quaternions along the short way.
local function nlerp(
	ax: number,
	ay: number,
	az: number,
	aw: number,
	bx: number,
	by: number,
	bz: number,
	bw: number,
	k: number
): (number, number, number, number)
	if ax * bx + ay * by + az * bz + aw * bw < 0 then
		bx, by, bz, bw = -bx, -by, -bz, -bw
	end
	local x, y, z, w = ax + (bx - ax) * k, ay + (by - ay) * k, az + (bz - az) * k, aw + (bw - aw) * k
	local n = math.sqrt(x * x + y * y + z * z + w * w)
	if n < 1e-9 then
		return 0, 0, 0, 1
	end
	return x / n, y / n, z / n, w / n
end
BipedClip.nlerp = nlerp

-- The frame pair and blend at `time` seconds (wrapped for a loop, held at the ends otherwise).
function BipedClip.at(clip: Clip, time: number, looped: boolean): (number, number, number)
	local span = clip.frames - 1
	local f = time * clip.fps
	if looped and span > 0 then
		f %= span
	else
		f = math.clamp(f, 0, span)
	end
	local i0 = math.floor(f)
	local i1 = if i0 >= span then (if looped then 0 else span) else i0 + 1
	return i0, i1, f - i0
end

-- A direction of the clip's rest seen in the mirror (x flips).
local function flip(v: Vec): Vec
	return { -v[1], v[2], v[3] }
end

-- The rest direction of `key` in the clip (mirrored: the other side's, flipped).
local function dirOf(source: Source, key: string, mirror: boolean?): Vec?
	if mirror then
		local d = source.dirs[otherSide(key)]
		return if d then flip(d) else nil
	end
	return source.dirs[key]
end

local function knuckleOf(source: Source, side: string, mirror: boolean?): Vec?
	local list = source.knuckles
	if not list then
		return nil
	end
	if mirror then
		local k = list[if side == "R" then "L" else "R"]
		return if k then flip(k) else nil
	end
	return list[side]
end

-- The turn taking direction `a` onto `b` and the reference `r` (square to `a`) onto `s` (square to `b`): the roll about
-- the bone kept as well. Nil when a reference lies too close along its direction.
local function twoVector(a: Vec, r: Vec, b: Vec, s: Vec): Mat?
	local function frame(d: Vec, ref: Vec): Mat?
		local k = ref[1] * d[1] + ref[2] * d[2] + ref[3] * d[3]
		local side = { ref[1] - d[1] * k, ref[2] - d[2] * k, ref[3] - d[3] * k }
		if math.sqrt(side[1] * side[1] + side[2] * side[2] + side[3] * side[3]) < 0.3 then
			return nil
		end
		local u = unit(side) :: Vec
		local w = { d[2] * u[3] - d[3] * u[2], d[3] * u[1] - d[1] * u[3], d[1] * u[2] - d[2] * u[1] }
		-- columns d, u, w (row-major)
		return { d[1], u[1], w[1], d[2], u[2], w[2], d[3], u[3], w[3] }
	end
	local da, db = unit(a), unit(b)
	local ra, sb = unit(r), unit(s)
	if not da or not db or not ra or not sb then
		return nil
	end
	local fa, fb = frame(da, ra), frame(db, sb)
	if not fa or not fb then
		return nil
	end
	return mul(fb, transpose(fa))
end
BipedClip.twoVector = twoVector

local ARM_SIDE: { [string]: string } = {
	RightArm = "R",
	RightForeArm = "R",
	RightHand = "R",
	LeftArm = "L",
	LeftForeArm = "L",
	LeftHand = "L",
}

-- The retargeting turns of a model (rest directions in root space by bone key, `modelDirs`) onto a clip: per bone the
-- shortest turn from the model's rest direction to the clip's (identity where either is unknown); the arms by their
-- knuckle lines too where both know them; the right hand laying the model's blade (`grip`) along the clip's.
function BipedClip.fit(source: Source, modelDirs: { [string]: Vec }, options: FitOptions?): { [string]: Mat }
	local mirror = options and options.mirror
	local knuckles = options and options.knuckles
	local out: { [string]: Mat } = {}
	for _, key in source.bones do
		local a, b = modelDirs[key], dirOf(source, key, mirror)
		local turn = if a and b then NpcPose.fromTo(a, b) else IDENTITY
		local side = ARM_SIDE[key]
		if side and a and b and knuckles then
			local km, kc = knuckles[side], knuckleOf(source, side, mirror)
			local roll = if km and kc then twoVector(a, km, b, kc) else nil
			if roll then
				turn = roll
			end
		end
		out[key] = turn
	end
	local grip = options and options.grip
	local blade = knuckleOf(source, "R", mirror)
	local hand = out.RightHand
	if grip and blade and hand then
		-- the blade runs through the fist along the knuckle line (little finger -> index): the hand turned so the
		-- model's blade lies along it (the wrist takes the difference, as the keyed aim's does)
		local g = apply(hand, grip)
		out.RightHand = mul(NpcPose.fromTo(g, blade), hand)
	end
	return out
end

-- The clip's pose at `time`: world turns by bone key (D(t) * fit) and the Hips offset in hip heights; `mirror` plays it
-- with left and right swapped (the fit made for the mirror).
function BipedClip.sample(
	clip: Clip,
	time: number,
	looped: boolean,
	fit: { [string]: Mat },
	mirror: boolean?
): ({ [string]: Mat }, Vec)
	local i0, i1, k = BipedClip.at(clip, time, looped)
	local world: { [string]: Mat } = {}
	local partner = clip.partner
	for i, key in clip.bones do
		local j = if mirror then partner[i] else i
		local ax, ay, az, aw = quat(clip, i0, j)
		local bx, by, bz, bw = quat(clip, i1, j)
		local x, y, z, w = nlerp(ax, ay, az, aw, bx, by, bz, bw, k)
		if mirror then
			-- a turn seen in the mirror (x flips): its axis' y and z flip
			y, z = -y, -z
		end
		world[key] = NpcPose.mul(toMat(x, y, z, w), fit[key] or IDENTITY)
	end
	local hx, hy, hz = BipedClip.hipsAt(clip, time, looped)
	return world, { if mirror then -hx else hx, hy, hz }
end

-- The Hips offset (hip heights, the clip's own side) at `time`.
function BipedClip.hipsAt(clip: Clip, time: number, looped: boolean): (number, number, number)
	local i0, i1, k = BipedClip.at(clip, time, looped)
	local hx0, hy0, hz0 = hips(clip, i0)
	local hx1, hy1, hz1 = hips(clip, i1)
	return hx0 + (hx1 - hx0) * k, hy0 + (hy1 - hy0) * k, hz0 + (hz1 - hz0) * k
end

return BipedClip
