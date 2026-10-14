--!strict
-- Real animation clips over the procedural poses (S113, DESIGN-16 §5): the id format, the defaults and the playback
-- speed that puts the clip's "Hit" marker on the server's hit time. Pure: client/Anim/CharacterClips plays the tracks.
-- Data: AttackMotions.motions.<motion>.clips (combo step i = clips[i]), AttackMotions.clipsByWeapon.<weaponType>
-- (over the motion's clips), SkillMotions.motions.<skillId>.clip. A plain "rbxassetid://…" means { id, hit = "Hit" }.

local AttackMotions = require("../Data/AttackMotions")

local ClipFit = {}

export type Clip = AttackMotions.Clip
export type ClipRef = AttackMotions.ClipRef
-- The parts of Data/AttackMotions attackClip reads (tests pass their own table).
export type Source = {
	motions: { [string]: { clips: { ClipRef }? } },
	clipsByWeapon: { [string]: { ClipRef } },
	byWeapon: { [string]: string },
}

ClipFit.MARKER = "Hit"
ClipFit.MIN_SPEED = 0.5
ClipFit.MAX_SPEED = 2.5
ClipFit.TOLERANCE = 0.03 -- seconds the marker may miss the server hit (DESIGN-16 §2.2)
ClipFit.MAX_CLIPS = 3 -- clips of one motion / weapon type (combo steps)
ClipFit.LOAD_SECONDS = 3 -- a track still without a length after this long failed (no permission, moderation, wrong id)
ClipFit.FALLBACK_LATE = 0.1 -- the hit effects fire this long after the server hit when the marker never comes
ClipFit.SWING_LEAD = 0.06 -- with a clip: the swing sound this long before the server hit
ClipFit.TRAIL_AFTER = 0.08 -- with a clip: the weapon trail from the start until this long after the server hit

function ClipFit.validId(id: string): boolean
	return string.match(id, "^rbxassetid://%d+$") ~= nil
end

-- A string becomes { id = ref, hit = MARKER }; a table gets the marker name when it has none (other fields stay).
function ClipFit.normalize(ref: ClipRef): Clip
	if type(ref) == "string" then
		return { id = ref, hit = ClipFit.MARKER }
	end
	local clip = ref :: Clip
	return { id = clip.id, hit = clip.hit or ClipFit.MARKER, speed = clip.speed, hitTime = clip.hitTime }
end

-- Speed of the track: markerTime (measured, else the data's hitTime) / serverHit, clamped to MIN_SPEED..MAX_SPEED;
-- without a marker time (or without a server hit) the data's speed or 1. Second value: false when clamping moved the
-- marker by more than TOLERANCE away from the server hit.
function ClipFit.speed(clip: Clip, serverHit: number, markerTime: number?): (number, boolean)
	local marker = markerTime or clip.hitTime
	if not marker or marker <= 0 or serverHit <= 0 then
		return clip.speed or 1, true
	end
	local speed = math.clamp(marker / serverHit, ClipFit.MIN_SPEED, ClipFit.MAX_SPEED)
	local landsAt = marker / speed
	return speed, math.abs(landsAt - serverHit) <= ClipFit.TOLERANCE + 1e-9
end

-- The clip list of a weapon type: clipsByWeapon[weaponType] over its motion's clips; nil when there are none.
function ClipFit.attackClips(weaponType: string?, source: Source?): { ClipRef }?
	local data: Source = source or (AttackMotions :: any)
	local own = if weaponType then data.clipsByWeapon[weaponType] else nil
	if own and #own > 0 then
		return own
	end
	local name = if weaponType then data.byWeapon[weaponType] or "unarmed" else "unarmed"
	local motion = data.motions[name]
	local list = motion and motion.clips
	if list and #list > 0 then
		return list
	end
	return nil
end

-- The clip of a basic attack's combo step (clips[step]); nil when there is none.
function ClipFit.attackClip(weaponType: string?, step: number, source: Source?): Clip?
	local list = ClipFit.attackClips(weaponType, source)
	local ref = list and list[step]
	return if ref then ClipFit.normalize(ref) else nil
end

-- Every clip id named in the data (attack motions, weapon types, skills): the client preloads them.
function ClipFit.allIds(skillClips: { [string]: Clip }?): { string }
	local seen: { [string]: boolean } = {}
	local out: { string } = {}
	local function add(ref: ClipRef)
		local id = ClipFit.normalize(ref).id
		if not seen[id] then
			seen[id] = true
			table.insert(out, id)
		end
	end
	for _, motion in AttackMotions.motions do
		local list = motion.clips
		if list then
			for _, ref in list do
				add(ref)
			end
		end
	end
	for _, list in AttackMotions.clipsByWeapon do
		for _, ref in list do
			add(ref)
		end
	end
	if skillClips then
		for _, clip in skillClips do
			add(clip)
		end
	end
	table.sort(out)
	return out
end

return ClipFit
