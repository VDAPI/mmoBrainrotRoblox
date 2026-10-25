--!strict
-- Template animation: reads the mocap clips of Data/BipedClips (baked by tools/anim/bake_biped.py from Mixamo FBX) and
-- samples one as world turns of the model's bones (Logic/BipedPose.World), retargeted by rest direction: the model's
-- bone first turns onto the clip's rest direction (an A-pose model on a T-pose clip), then by the clip's turn D(t) from
-- its own rest. Pure.

local BoneClip = require("./BoneClip")
local NpcPose = require("./NpcPose")

local BipedClip = {}

type Vec = { number }
type Mat = { number }

export type Source = {
	bones: { string },
	dirs: { [string]: Vec },
	frames: number,
	fps: number,
	loop: boolean,
	speed: number?,
	contact: number?,
	hit: number?,
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
}

function BipedClip.decode(source: Source): Clip
	return {
		source = source,
		bones = source.bones,
		frames = source.frames,
		fps = source.fps,
		length = math.max(1, source.frames - 1) / source.fps,
		stride = #source.bones * 6 + 6,
		buf = BoneClip.base64(source.data),
	}
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

-- The retargeting turns of a model (rest directions in root space by bone key, `modelDirs`) onto a clip: per bone the
-- shortest turn from the model's rest direction to the clip's (identity where either is unknown).
function BipedClip.fit(source: Source, modelDirs: { [string]: Vec }): { [string]: Mat }
	local out: { [string]: Mat } = {}
	for _, key in source.bones do
		local a, b = modelDirs[key], source.dirs[key]
		out[key] = if a and b then NpcPose.fromTo(a, b) else NpcPose.IDENTITY
	end
	return out
end

-- The clip's pose at `time`: world turns by bone key (D(t) * fit) and the Hips offset in hip heights.
function BipedClip.sample(clip: Clip, time: number, looped: boolean, fit: { [string]: Mat }): ({ [string]: Mat }, Vec)
	local i0, i1, k = BipedClip.at(clip, time, looped)
	local world: { [string]: Mat } = {}
	for i, key in clip.bones do
		local ax, ay, az, aw = quat(clip, i0, i)
		local bx, by, bz, bw = quat(clip, i1, i)
		local x, y, z, w = nlerp(ax, ay, az, aw, bx, by, bz, bw, k)
		world[key] = NpcPose.mul(toMat(x, y, z, w), fit[key] or NpcPose.IDENTITY)
	end
	local hx0, hy0, hz0 = hips(clip, i0)
	local hx1, hy1, hz1 = hips(clip, i1)
	return world, { hx0 + (hx1 - hx0) * k, hy0 + (hy1 - hy0) * k, hz0 + (hz1 - hz0) * k }
end

return BipedClip
