--!strict
-- Real clips on R15 characters (S113, DESIGN-16 §5, docs/ANIMACJE.md "Własne klipy ataków i umiejętności"): one
-- Animation per id, one track per (Animator, id), the "Hit" marker, the speed fitted to the server's hit
-- (Logic/ClipFit), a failed clip remembered so the procedural pose takes over (AnimationController).
-- LoadAnimation does not fail for an id without permission or under moderation: the track just keeps Length 0. The
-- first use of an id starts loading and returns nil (the pose plays); when the track has no length after
-- ClipFit.LOAD_SECONDS the id is marked failed with one warning, otherwise it plays from the next attack on.
-- A clip played by a player's own client on their character also replicates to the others, who play it locally from
-- the same event: on other characters a replicated track of a clip id we play is stopped (no double animation).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ClipFit = require(ReplicatedStorage.Shared.Logic.ClipFit)
local Clock = require(script.Parent.Parent.Vfx.Clock)

local CharacterClips = {}

export type Play = { track: AnimationTrack, speed: number, stop: (fade: number?) -> () }
export type Status = "ok" | "loading" | "failed"

local animations: { [string]: Animation } = {}
local tracksOf: { [Animator]: { [string]: AnimationTrack } } = setmetatable({} :: any, { __mode = "k" })
local watched: { [Animator]: boolean } = setmetatable({} :: any, { __mode = "k" })
local failed: { [string]: boolean } = {}
local loaded: { [string]: boolean } = {}
local loading: { [string]: boolean } = {}
local markers: { [string]: number | false } = {}
local measuring: { [string]: boolean } = {}
local warnedFit: { [string]: boolean } = {}
local localTracks: { [AnimationTrack]: boolean } = setmetatable({} :: any, { __mode = "k" })

local function animationOf(id: string): Animation
	local animation = animations[id]
	if not animation then
		local created = Instance.new("Animation")
		created.AnimationId = id
		animations[id] = created
		animation = created
	end
	return animation
end

-- Replicated duplicates: a track of one of our clip ids that we did not start, on another player's character.
local function watchDuplicates(animator: Animator, model: Model)
	if watched[animator] or model == Players.LocalPlayer.Character then
		return
	end
	watched[animator] = true
	animator.AnimationPlayed:Connect(function(track: AnimationTrack)
		local animation = track.Animation
		local id = animation and animation.AnimationId
		if id and animations[id] and not localTracks[track] then
			track:Stop(0)
		end
	end)
end

local function trackOf(animator: Animator, id: string): AnimationTrack?
	local list = tracksOf[animator]
	if not list then
		list = {}
		tracksOf[animator] = list
	end
	local existing = list[id]
	if existing then
		return existing
	end
	local ok, track = pcall(function()
		return animator:LoadAnimation(animationOf(id))
	end)
	if not ok or not track then
		if not failed[id] then
			failed[id] = true
			warn(`[CharacterClips] clip {id} did not load ({tostring(track)}); the procedural pose stays`)
		end
		return nil
	end
	localTracks[track] = true
	list[id] = track
	return track
end

-- Waits in the background for the first track of `id` to get a length; marks the id failed (one warning) when it
-- does not within ClipFit.LOAD_SECONDS.
local function watchLoad(id: string, track: AnimationTrack)
	if loading[id] or loaded[id] or failed[id] then
		return
	end
	loading[id] = true
	task.spawn(function()
		local deadline = os.clock() + ClipFit.LOAD_SECONDS
		while os.clock() < deadline and track.Length <= 0 do
			task.wait(0.1)
		end
		loading[id] = nil
		if track.Length > 0 then
			loaded[id] = true
		else
			failed[id] = true
			warn(
				`[CharacterClips] clip {id} did not load (no permission, moderation or a wrong id); the procedural pose stays`
			)
		end
	end)
end

-- The marker's time of the clip at speed 1, measured from the published KeyframeSequence (Studio and the game where
-- KeyframeSequenceProvider allows it). Yields; nil without a marker or when the sequence cannot be read.
local function measure(id: string, marker: string): number?
	local ok, sequence = pcall(function()
		return game:GetService("KeyframeSequenceProvider"):GetKeyframeSequenceAsync(id)
	end)
	if not ok or not sequence then
		return nil
	end
	local found: number? = nil
	for _, frame in (sequence :: KeyframeSequence):GetKeyframes() do
		if frame:IsA("Keyframe") then
			for _, m in frame:GetMarkers() do
				if m.Name == marker and (found == nil or frame.Time < found) then
					found = frame.Time
				end
			end
		end
	end
	sequence:Destroy()
	return found
end

-- hitTime from the data, else the measured marker time (measured once per id in the background), cached per id.
function CharacterClips.markerTime(clip: ClipFit.Clip): number?
	if clip.hitTime then
		return clip.hitTime
	end
	local known = markers[clip.id]
	if known ~= nil then
		return if known == false then nil else known :: number
	end
	if not measuring[clip.id] then
		measuring[clip.id] = true
		task.spawn(function()
			local t = measure(clip.id, clip.hit or ClipFit.MARKER)
			markers[clip.id] = if t then t else false
		end)
	end
	return nil
end

-- The marker time read now (yields; AnimLab `clip`).
function CharacterClips.measureNow(clip: ClipFit.Clip): number?
	if clip.hitTime then
		return clip.hitTime
	end
	local t = measure(clip.id, clip.hit or ClipFit.MARKER)
	markers[clip.id] = if t then t else false
	return t
end

local function animatorOf(model: Model): Animator?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return nil
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	return if animator then animator else nil
end

-- Plays `clip` on the character's Animator; calls onHit once at the marker (or at serverHit + FALLBACK_LATE when the
-- marker never fires). Returns nil (the caller animates procedurally) when: not R15, no Animator, a copy outside the
-- Workspace (the skills-window preview), the id failed before, or the track is not loaded yet (Length == 0; loading
-- continues).
function CharacterClips.play(
	model: Model,
	clip: ClipFit.Clip,
	serverHit: number,
	priority: Enum.AnimationPriority,
	onHit: (() -> ())?
): Play?
	if failed[clip.id] or not model:IsDescendantOf(Workspace) then
		return nil
	end
	local animator = animatorOf(model)
	if not animator then
		return nil
	end
	watchDuplicates(animator, model)
	local track = trackOf(animator, clip.id)
	if not track then
		return nil
	end
	if track.Length <= 0 then
		watchLoad(clip.id, track)
		return nil
	end
	loaded[clip.id] = true
	local speed, fits = ClipFit.speed(clip, serverHit, CharacterClips.markerTime(clip))
	if not fits and not warnedFit[clip.id] then
		warnedFit[clip.id] = true
		local marker = CharacterClips.markerTime(clip) or 0
		warn(
			`[CharacterClips] {clip.id}: Hit at {math.floor(marker * 1000 + 0.5) / 1000} s cannot meet the server hit {serverHit} s`
		)
	end
	track.Priority = priority
	track.Looped = false
	if track.IsPlaying then
		track:Stop(0)
	end
	track:Play(0.05, 1, speed)
	local done = false
	local connection: RBXScriptConnection? = nil
	local function fire()
		if done then
			return
		end
		done = true
		if connection then
			connection:Disconnect()
			connection = nil
		end
		if onHit then
			onHit()
		end
	end
	connection = track:GetMarkerReachedSignal(clip.hit or ClipFit.MARKER):Connect(fire)
	-- never zero times: the marker may be missing or the track stopped early
	Clock.after(serverHit + ClipFit.FALLBACK_LATE, fire)
	return {
		track = track,
		speed = speed,
		stop = function(fade: number?)
			if track.IsPlaying then
				track:Stop(fade or 0.1)
			end
		end,
	}
end

-- At Start: Animation objects for every clip id in the data (AttackMotions, SkillMotions).
function CharacterClips.preload(ids: { string })
	for _, id in ids do
		animationOf(id)
	end
end

function CharacterClips.failed(id: string): boolean
	return failed[id] == true
end

-- Every id seen so far: "ok" (a track had a length), "failed", or "loading".
function CharacterClips.status(): { [string]: Status }
	local out: { [string]: Status } = {}
	for id in animations do
		out[id] = if failed[id] then "failed" elseif loaded[id] then "ok" else "loading"
	end
	return out
end

-- AnimLab `clip`: forgets a failure so a fixed id can be tried again.
function CharacterClips.retry(id: string)
	failed[id] = nil
	warnedFit[id] = nil
	markers[id] = nil
	measuring[id] = nil
end

return CharacterClips
