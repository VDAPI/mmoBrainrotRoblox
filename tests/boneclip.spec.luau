--!strict
-- W26: the bone clips of imported monster models decode to unit rotations and every clip fits the shared slots.
local T = require("./Test")
local BoneClip = require("../src/shared/Logic/BoneClip")
local MonsterAssets = require("../src/shared/Data/MonsterAssets")
local MonsterClips = require("../src/shared/Data/MonsterClips")

T.describe("BoneClip", function()
	T.it("decodes base64", function()
		local b = BoneClip.base64("AQID/w==")
		T.expect(buffer.len(b)).toBe(4)
		T.expect(buffer.readu8(b, 3)).toBe(255)
	end)

	T.it("every clip is whole, its rotations unit and its slots inside", function()
		local last = 0
		for _, slot in MonsterClips.SLOTS do
			last = math.max(last, slot.to)
		end
		for _, id in MonsterClips.ids() do
			local clip = MonsterClips.get(id) :: MonsterClips.Clip
			local d = BoneClip.decode(clip)
			T.expect({ id, buffer.len(d.buf) }).toEqual({ id, d.stride * clip.frames })
			T.expect({ id, clip.frames > last }).toEqual({ id, true })
			T.expect({ id, clip.bones[1] }).toEqual({ id, "Hips" })
			-- W26: the clip's own slots (weapon attacks, spells, the hit) lie inside its frames, blows inside the slot
			for name, slot in MonsterClips.slotsFor(id) do
				T.expect({ id, name, slot.from >= 0 and slot.to < clip.frames and slot.from < slot.to })
					.toEqual({ id, name, true })
				if slot.hit then
					T.expect({ id, name, slot.hit >= 0 and slot.hit <= (slot.to - slot.from) / MonsterClips.FPS + 0.1 })
						.toEqual({ id, name, true })
				end
			end
			for frame = 0, clip.frames - 1, 7 do
				for bone = 1, #clip.bones do
					local x, y, z, w = BoneClip.rotation(d, frame, bone)
					local n = x * x + y * y + z * z + w * w
					T.expect({ id, frame, bone, math.abs(n - 1) < 0.01 }).toEqual({ id, frame, bone, true })
				end
			end
		end
	end)

	T.it("every model with rig bones has clips", function()
		for id, entry in MonsterAssets do
			T.expect({ id, entry.rig ~= "bones" or MonsterClips.get(id) ~= nil }).toEqual({ id, true })
		end
	end)

	T.it("frame positions wrap or hold", function()
		local a, b, t = BoneClip.at(10, 20, 15, 1, true)
		T.expect({ a, b }).toEqual({ 15, 16 })
		T.expect(t < 1e-9).toBe(true)
		a, b = BoneClip.at(10, 20, 15, 5, false)
		T.expect({ a, b }).toEqual({ 20, 20 })
	end)
end)
