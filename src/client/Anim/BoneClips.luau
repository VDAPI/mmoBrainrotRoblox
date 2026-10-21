--!strict
-- W26: plays the bone clips of an imported monster model (Data/MonsterClips, rig "bones" in Data/MonsterAssets) by
-- writing Bone.Transform, so the clips need no published animation assets. Tracks answer the calls AnimationController
-- makes on an AnimationTrack (Play, Stop, AdjustSpeed, Looped); a mixer blends the tracks that fade in and out and
-- writes the bones once per step. A non-looped clip holds its last frame (a death stays down).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BoneClip = require(ReplicatedStorage.Shared.Logic.BoneClip)
local MonsterClips = require(ReplicatedStorage.Shared.Data.MonsterClips)

local BoneClips = {}

local PREFIX = "mixamorig:"

export type Track = {
	Looped: boolean,
	Play: (self: Track, fade: number?) -> (),
	Stop: (self: Track, fade: number?) -> (),
	AdjustSpeed: (self: Track, speed: number) -> (),
	slot: MonsterClips.Slot,
	time: number,
	speed: number,
	weight: number,
	target: number,
	fadeRate: number,
	fit: number, -- W26: the playback factor that lands the blow (`slot.hit`) at the server's hit
	lead: number?, -- W26: seconds from Play to the server's hit (set by the caller before Play)
	mixer: Mixer,
}

export type Mixer = {
	clip: BoneClip.Decoded,
	bones: { Bone? },
	hips: number?, -- index of the Hips in `bones`
	scale: number, -- the model's scale (Hips offsets are in import units)
	playing: { Track },
	tracks: { [string]: Track },
	-- S159a: turns laid before the clip's pose of a bone (index in `bones`; client/Anim/BoneOverlay), nil = none
	pre: { [number]: CFrame }?,
}

local decoded: { [string]: BoneClip.Decoded } = {}

local function clipOf(id: string): BoneClip.Decoded?
	local cached = decoded[id]
	if cached then
		return cached
	end
	local clip = MonsterClips.get(id)
	if not clip then
		return nil
	end
	local d = BoneClip.decode(clip)
	decoded[id] = d
	return d
end

local function fadeRate(fade: number?): number
	local f = fade or 0.1
	return if f <= 0 then math.huge else 1 / f
end

local function play(self: Track, fade: number?)
	local mixer = self.mixer
	local index = table.find(mixer.playing, self)
	if index then
		table.remove(mixer.playing, index)
	else
		self.weight = 0
	end
	table.insert(mixer.playing, self)
	self.time = 0
	self.fit = 1
	-- W26: a clip with a blow starts late enough (or plays slower) for the blow to land at the server's hit
	local hit, lead = self.slot.hit, self.lead
	if hit and lead then
		local reach = math.max(0.05, lead) * self.slot.rate
		if hit > reach then
			self.time = hit - reach
		else
			self.fit = math.max(0.4, hit / reach)
		end
	end
	self.lead = nil
	self.target = 1
	self.fadeRate = fadeRate(fade)
end

local function stop(self: Track, fade: number?)
	self.target = 0
	self.fadeRate = fadeRate(fade)
end

local function adjustSpeed(self: Track, speed: number)
	self.speed = speed
end

-- A mixer for `model` (the cloned look) playing the clips of Data/MonsterClips `id`, or nil without them.
function BoneClips.new(model: Model, id: string): Mixer?
	local clip = clipOf(id)
	if not clip then
		return nil
	end
	local byName: { [string]: Bone } = {}
	for _, item in model:GetDescendants() do
		if item:IsA("Bone") then
			byName[item.Name] = item
		end
	end
	local bones: { Bone? } = {}
	local hips: number? = nil
	for i, name in clip.bones do
		bones[i] = byName[PREFIX .. name]
		if name == "Hips" then
			hips = i
		end
	end
	local mixer: Mixer = {
		clip = clip,
		bones = bones,
		hips = hips,
		scale = model:GetScale(),
		playing = {},
		tracks = {},
		pre = nil,
	}
	for name, slot in MonsterClips.slotsFor(id) do
		local track: Track = {
			Looped = false,
			Play = play,
			Stop = stop,
			AdjustSpeed = adjustSpeed,
			slot = slot,
			time = 0,
			speed = 1,
			weight = 0,
			target = 0,
			fadeRate = math.huge,
			fit = 1,
			lead = nil,
			mixer = mixer,
		}
		mixer.tracks[name] = track
	end
	return mixer
end

local function pose(mixer: Mixer, track: Track, bone: number): CFrame
	local slot = track.slot
	local d = mixer.clip
	local i0, i1, alpha = BoneClip.at(slot.from, slot.to, MonsterClips.FPS, track.time, track.Looped)
	local x0, y0, z0, w0 = BoneClip.rotation(d, i0, bone)
	local x1, y1, z1, w1 = BoneClip.rotation(d, i1, bone)
	local a = CFrame.new(0, 0, 0, x0, y0, z0, w0)
	local b = CFrame.new(0, 0, 0, x1, y1, z1, w1)
	if bone == mixer.hips then
		local k = mixer.scale
		local px0, py0, pz0 = BoneClip.hips(d, i0)
		local px1, py1, pz1 = BoneClip.hips(d, i1)
		a = CFrame.new(px0 * k, py0 * k, pz0 * k) * a
		b = CFrame.new(px1 * k, py1 * k, pz1 * k) * b
	end
	return a:Lerp(b, alpha)
end

-- Whether a track is still in its clip (a looped one always is).
function BoneClips.running(track: Track): boolean
	local slot = track.slot
	return track.Looped or track.time < BoneClip.length(slot.from, slot.to, MonsterClips.FPS)
end

-- Advances the tracks by `dt` seconds and writes the bones.
function BoneClips.step(mixer: Mixer, dt: number)
	local playing = mixer.playing
	for i = #playing, 1, -1 do
		local track = playing[i]
		track.time += dt * track.speed * track.slot.rate * track.fit
		local step = dt * track.fadeRate
		if track.weight < track.target then
			track.weight = math.min(track.target, track.weight + step)
		elseif track.weight > track.target then
			track.weight = math.max(track.target, track.weight - step)
		end
		if track.target == 0 and track.weight <= 0 then
			table.remove(playing, i)
		end
	end
	if #playing == 0 then
		return
	end
	local pre = mixer.pre
	for bone, instance in mixer.bones do
		if not instance then
			continue
		end
		local result: CFrame? = nil
		for _, track in playing do
			local p = pose(mixer, track, bone)
			result = if result then result:Lerp(p, track.weight) else p
		end
		local turn = pre and pre[bone]
		instance.Transform = if turn then turn * (result :: CFrame) else result :: CFrame
	end
end

return BoneClips
