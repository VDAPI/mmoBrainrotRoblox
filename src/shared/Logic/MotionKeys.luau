--!strict
-- Control frames of a motion (S110, docs/ANIMACJE.md §3): the moments AnimLab freezes and the Studio review screenshots,
-- computed from the data alone. Pure (Lune). Times in seconds from the start of the motion.
--   basic attack (timing = AttackPose.timing(motionFor(weaponType), interval, step), S113 per combo step):
--     start 0; peak = windup (end of the raise); hit = hitAt (AttackMotions.SERVER_HIT, the server's
--     AttackPose.hitDelay for melee; a ranged motion calls the same moment `release` and has no `hit`: it depends on
--     the flight); strikePeak = windup + strike (end of the blow); follow = end of the follow-through (windup +
--     strike + follow share * recover; 0.3 * recover without a follow pose); end = total
--   skill (SkillMotions.get(id), nil without a motion): start 0; hit = SkillMotions.hitDelay(id) when the motion has a
--     hit (the server's time, capped at MAX_HIT); release, land from the motion; peak = the last key before the first of
--     hit / release (h itself when no key is earlier; without both: the key with the most arm angle); follow = h + 0.35
--     * (end - h) with h = hit or release or peak; end = SkillPose.duration(motion, loopUntil)
--   generated monster (w = windup or Gait.DEFAULT_WINDUP): start 0; peak = w - Gait.STRIKE_SECONDS (the end of the
--     gather, cut at 0); hit = strikePeak = w (S117: the blow peaks at the server's damage after the telegraph, where
--     the telegraph flashes; before S117 it peaked STRIKE_SECONDS later); follow = w + 0.3 * RECOVER_SECONDS; end =
--     Gait.attackLength(w). `strikeNow` (a basic attack, damage with the event) moves everything by
--     -(w - Gait.STRIKE_NOW_LEAD) (AnimationController.MonsterAttack), cut at 0, and hit = 0: the blow peaks 0.03 s after
--     the event
--   boss attack / Elite II ability: a monster with w = attack.windup / ability.windup
--   clip: start 0, hit = the marker (when given), end = length; a clip played at `speed` (S113, Logic/ClipFit) divides
--     both by it
--   bone clip (studio review 2026-10-21; client/Anim/BoneClips, Data/MonsterClips slot { from, to, rate, hit }) played
--     with its blow fitted to land `lead` s after the start (it starts late in the clip, or plays slower): start 0;
--     hit = strikePeak = when the clip's blow comes; peak = hit - Gait.STRIKE_SECONDS (the end of the draw, cut at 0);
--     follow = hit + 0.3 * (end - hit); end = when the clip ends
--   a monster kind's regular blow (`basicBlow`, AnimLab `mob <kind> attack1`): the draw of Logic/BasicBlow as the game
--     plays it: a bone clip of the slot BasicBlow.slot on a model with clips, else a generated monster's attack

local AttackPose = require("./AttackPose")
local BasicBlow = require("./BasicBlow")
local BoneClip = require("./BoneClip")
local Bosses = require("../Data/Bosses")
local Gait = require("./Gait")
local MonsterAbilities = require("../Data/MonsterAbilities")
local MonsterClips = require("../Data/MonsterClips")
local MonsterLooks = require("../Data/MonsterLooks")
local Monsters = require("../Data/Monsters")
local SkillMotions = require("../Data/SkillMotions")
local SkillPose = require("./SkillPose")

local MotionKeys = {}

export type KeyName = "start" | "peak" | "release" | "hit" | "strikePeak" | "land" | "follow" | "end"
export type Key = { name: KeyName, t: number }
export type Keys = { Key } -- sorted by t, names unique

-- Order of names at the same time (a bow's peak and release coincide).
MotionKeys.ORDER = { "start", "peak", "release", "hit", "strikePeak", "land", "follow", "end" } :: { KeyName }

local FOLLOW_SKILL = 0.35 -- share of the time from the hit to the end
local FOLLOW_MONSTER = 0.3 -- share of Gait.RECOVER_SECONDS

local function rank(name: KeyName): number
	return table.find(MotionKeys.ORDER, name) or 99
end

local function build(entries: { [string]: number? }): Keys
	local out: Keys = {}
	for _, name in MotionKeys.ORDER do
		local t = entries[name]
		if t then
			local key: Key = { name = name :: KeyName, t = t }
			table.insert(out, key)
		end
	end
	table.sort(out, function(a, b)
		if a.t ~= b.t then
			return a.t < b.t
		end
		return rank(a.name) < rank(b.name)
	end)
	return out
end

-- The basic attack of a weapon type (nil / unknown = fists), combo step `step` (default 1); `interval` squeezes it
-- like AttackPose.timing.
function MotionKeys.attack(weaponType: string?, interval: number?, step: number?): Keys
	local timing = AttackPose.timing(AttackPose.motionFor(weaponType), interval, step)
	return build({
		start = 0,
		peak = timing.windup,
		hit = if timing.ranged then nil else timing.hitAt,
		release = if timing.ranged then timing.hitAt else nil,
		strikePeak = timing.windup + timing.strike,
		follow = timing.followAt,
		["end"] = timing.total,
	})
end

local function armWeight(pose: SkillMotions.Pose): number
	local sum = 0
	for _, joint in SkillMotions.ARM_JOINTS do
		local a = pose[joint]
		if a then
			for _, v in a do
				sum += math.abs(v)
			end
		end
	end
	return sum
end

-- A skill's motion (nil when the skill has none); `loopUntil` stretches a channel like SkillPose.duration. S115: `ctx`
-- (weapon family, waves, walking) picks the variant the character plays (SkillPose.pick); the events stay the base's.
function MotionKeys.skill(skillId: string, loopUntil: number?, ctx: SkillPose.PickContext?): Keys?
	local base = SkillMotions.get(skillId)
	if not base then
		return nil
	end
	local motion = SkillPose.pick(base, ctx)
	local hit = if motion.hit then SkillMotions.hitDelay(skillId) else nil
	local release = motion.release
	local first: number? = nil
	if hit and release then
		first = math.min(hit, release)
	else
		first = hit or release
	end
	local peak: number
	if first then
		local best: number? = nil
		for _, key in motion.keys do
			if key.t < first and (best == nil or key.t > best) then
				best = key.t
			end
		end
		peak = best or first
	else
		local best, weight = motion.keys[1].t, -1
		for _, key in motion.keys do
			local w = armWeight(key.pose)
			if w > weight then
				best, weight = key.t, w
			end
		end
		peak = best
	end
	local finish = SkillPose.duration(motion, loopUntil)
	local h = hit or release or peak
	return build({
		start = 0,
		peak = peak,
		hit = hit,
		release = release,
		land = motion.land,
		follow = h + FOLLOW_SKILL * (finish - h),
		["end"] = finish,
	})
end

-- A generated monster's attack (Logic/Gait) with `windup`; `strikeNow` = a basic attack (damage with the event).
function MotionKeys.monster(windup: number?, strikeNow: boolean?): Keys
	local w = math.max(windup or Gait.DEFAULT_WINDUP, 0.05)
	local entries: { [string]: number? } = {
		start = 0,
		peak = math.max(0, w - Gait.STRIKE_SECONDS),
		hit = w,
		strikePeak = w,
		follow = w + FOLLOW_MONSTER * Gait.RECOVER_SECONDS,
		["end"] = Gait.attackLength(w),
	}
	if strikeNow then
		local shift = math.max(0, w - Gait.STRIKE_NOW_LEAD)
		for name, t in entries do
			entries[name] = math.max(0, (t :: number) - shift)
		end
		entries.hit = 0
	end
	return build(entries)
end

-- A boss attack of Data/Bosses (nil for an unknown boss or attack).
function MotionKeys.boss(bossId: string, attackId: string): Keys?
	local boss = Bosses.get(bossId)
	if not boss then
		return nil
	end
	for _, attack in boss.attacks do
		if attack.id == attackId then
			return MotionKeys.monster(attack.windup)
		end
	end
	return nil
end

-- An Elite II ability of Data/MonsterAbilities (nil when unknown).
function MotionKeys.ability(abilityId: string): Keys?
	local ability = MonsterAbilities.get(abilityId)
	if not ability then
		return nil
	end
	return MotionKeys.monster(ability.windup)
end

-- An animation clip of `length` seconds with an optional "Hit" marker, played at `speed` (default 1: S113 fits the
-- speed with Logic/ClipFit.speed so the marker meets the server hit).
function MotionKeys.clip(length: number, hitMarker: number?, speed: number?): Keys
	local k = if speed and speed > 0 then speed else 1
	return build({ start = 0, hit = if hitMarker then hitMarker / k else nil, ["end"] = length / k })
end

-- Where a bone clip's slot starts and how fast it plays when its blow must land `lead` s after the start (the rule of
-- client/Anim/BoneClips play): the clip time at the start and the playback factor.
function MotionKeys.boneFit(slot: MonsterClips.Slot, lead: number?): (number, number)
	local hit = slot.hit
	if not hit or not lead then
		return 0, 1
	end
	local reach = math.max(0.05, lead) * slot.rate
	if hit > reach then
		return hit - reach, 1
	end
	return 0, math.max(0.4, hit / reach)
end

-- A bone clip slot played with its blow fitted to `lead` (client/Anim/BoneClips): seconds of the motion.
function MotionKeys.boneClip(slot: MonsterClips.Slot, lead: number?): Keys
	local t0, fit = MotionKeys.boneFit(slot, lead)
	local pace = slot.rate * fit
	local length = BoneClip.length(slot.from, slot.to, MonsterClips.FPS)
	local finish = math.max(0, (length - t0) / pace)
	local hit = if slot.hit then math.clamp((slot.hit - t0) / pace, 0, finish) else nil
	return build({
		start = 0,
		peak = if hit then math.max(0, hit - Gait.STRIKE_SECONDS) else nil,
		hit = hit,
		strikePeak = hit,
		follow = if hit then hit + FOLLOW_MONSTER * (finish - hit) else nil,
		["end"] = finish,
	})
end

-- A monster kind's regular blow as the game plays it (Logic/BasicBlow; nil for an unknown kind): its draw, and the
-- slot and clip of the real model when it has bone clips. Also returns the draw's seconds and the slot.
function MotionKeys.basicBlow(kindId: string, variant: string?): (Keys?, number, string)
	local kind = Monsters.get(kindId)
	if not kind then
		return nil, 0, "attack1"
	end
	local w = BasicBlow.wind(kind.attack, variant)
	local slotName = BasicBlow.slot(BasicBlow.shot(kind.attack, kind.damageKind))
	local look = MonsterLooks.get(kindId, kind.region)
	local asset = look and look.asset
	if asset and asset.rig == "bones" and MonsterClips.get(asset.model) then
		local slot = MonsterClips.slotsFor(asset.model)[slotName]
		if slot then
			return MotionKeys.boneClip(slot, w), w, slotName
		end
	end
	return MotionKeys.monster(w), w, slotName
end

-- A motion without frames of its own (idle, walk, an NPC without a clip): only the start.
function MotionKeys.still(): Keys
	return build({ start = 0 })
end

-- Time of the frame `name`, nil when the motion has none.
function MotionKeys.at(keys: Keys, name: KeyName): number?
	for _, key in keys do
		if key.name == name then
			return key.t
		end
	end
	return nil
end

return MotionKeys
