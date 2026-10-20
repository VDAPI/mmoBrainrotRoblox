--!strict
-- W26: reads the bone clips of Data/MonsterClips (format in its header). Pure: the client turns the numbers into
-- Bone.Transform (client/Anim/BoneClips).

local BoneClip = {}

export type Decoded = {
	bones: { string },
	frames: number,
	stride: number, -- bytes per frame
	buf: buffer,
}

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local VALUE: { [number]: number } = {}
for i = 1, #ALPHABET do
	VALUE[string.byte(ALPHABET, i)] = i - 1
end
local PAD = string.byte("=")

-- Base64 text to bytes.
function BoneClip.base64(text: string): buffer
	local n = #text
	local pads = 0
	if n > 0 and string.byte(text, n) == PAD then
		pads += 1
	end
	if n > 1 and string.byte(text, n - 1) == PAD then
		pads += 1
	end
	local size = n // 4 * 3 - pads
	local out = buffer.create(size)
	local o = 0
	for i = 1, n, 4 do
		local a, b, c, d = string.byte(text, i, i + 3)
		local v = (VALUE[a] or 0) * 262144
			+ (VALUE[b] or 0) * 4096
			+ (VALUE[c or PAD] or 0) * 64
			+ (VALUE[d or PAD] or 0)
		if o < size then
			buffer.writeu8(out, o, v // 65536)
		end
		if o + 1 < size then
			buffer.writeu8(out, o + 1, v // 256 % 256)
		end
		if o + 2 < size then
			buffer.writeu8(out, o + 2, v % 256)
		end
		o += 3
	end
	return out
end

function BoneClip.decode(clip: { bones: { string }, frames: number, data: string }): Decoded
	return {
		bones = clip.bones,
		frames = clip.frames,
		stride = #clip.bones * 6 + 6,
		buf = BoneClip.base64(clip.data),
	}
end

-- Rotation of bone `bone` (1-based) at frame `frame` (0-based): x, y, z, w of a unit quaternion.
function BoneClip.rotation(d: Decoded, frame: number, bone: number): (number, number, number, number)
	local at = frame * d.stride + (bone - 1) * 6
	local x = buffer.readi16(d.buf, at) / 32767
	local y = buffer.readi16(d.buf, at + 2) / 32767
	local z = buffer.readi16(d.buf, at + 4) / 32767
	local w = math.sqrt(math.max(0, 1 - x * x - y * y - z * z))
	return x, y, z, w
end

-- The Hips offset at `frame` in import units (times the model's scale gives studs).
function BoneClip.hips(d: Decoded, frame: number): (number, number, number)
	local at = frame * d.stride + #d.bones * 6
	return buffer.readi16(d.buf, at) / 100, buffer.readi16(d.buf, at + 2) / 100, buffer.readi16(d.buf, at + 4) / 100
end

-- Frame position of a slot `time` seconds in: whole frames i0, i1 and the blend between them.
function BoneClip.at(from: number, to: number, fps: number, time: number, looped: boolean): (number, number, number)
	local span = to - from
	local f = time * fps
	if looped and span > 0 then
		f %= span
	else
		f = math.clamp(f, 0, span)
	end
	local i0 = math.floor(f)
	local i1 = if i0 >= span then (if looped then 0 else span) else i0 + 1
	return from + i0, from + i1, f - i0
end

-- Seconds a slot lasts at rate 1.
function BoneClip.length(from: number, to: number, fps: number): number
	return (to - from) / fps
end

return BoneClip
