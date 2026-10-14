--!strict
-- Control frames of a motion (S110, docs/ANIMACJE.md §3): the moments AnimLab freezes and the Studio review screenshots,
-- computed from the data alone. Pure (Lune). Times in seconds from the start of the motion.
--   basic attack (timing = AttackPose.timing(motionFor(weaponType), interval)):
--     start 0; peak = windup (end of the raise); hit = hitAt (the server's AttackPose.hitDelay for melee; a ranged
--     motion calls the same moment `release` and has no `hit`: it depends on the flight); follow = windup + strike +
--     0.3 * recover; end = total
--   skill (SkillMotions.get(id), nil without a motion): start 0; hit = SkillMotions.hitDelay(id) when the motion has a
--     hit (the server's time, capped at MAX_HIT); release, land from the motion; peak = the last key before the first of
--     hit / release (h itself when no key is earlier; without both: the key with the most arm angle); follow = h + 0.35
--     * (end - h) with h = hit or release or peak; end = SkillPose.duration(motion, loopUntil)
--   generated monster (w = windup or Gait.DEFAULT_WINDUP): start 0; peak = w (raise 1); hit = w (the server's damage
--     after the telegraph); strikePeak = w + Gait.STRIKE_SECONDS (strike 1: where the motion really lands); follow =
--     strikePeak + 0.3 * RECOVER_SECONDS; end = Gait.attackLength(w). `strikeNow` (a basic attack, damage with the
--     event) moves everything by -(w - 0.06) (AnimationController.MonsterAttack), cut at 0, and hit = 0
--   boss attack / Elite II ability: a monster with w = attack.windup / ability.windup
--   clip: start 0, hit = the marker (when given), end = length

local AttackPose = require("./AttackPose")
local Bosses = require("../Data/Bosses")
local Gait = require("./Gait")
local MonsterAbilities = require("../Data/MonsterAbilities")
local SkillMotions = require("../Data/SkillMotions")
local SkillPose = require("./SkillPose")

local MotionKeys = {}

export type KeyName = "start" | "peak" | "release" | "hit" | "strikePeak" | "land" | "follow" | "end"
export type Key = { name: KeyName, t: number }
export type Keys = { Key } -- sorted by t, names unique

-- Order of names at the same time (a bow's peak and release coincide).
MotionKeys.ORDER = { "start", "peak", "release", "hit", "strikePeak", "land", "follow", "end" } :: { KeyName }

local FOLLOW_ATTACK = 0.3 -- share of the recovery
local FOLLOW_SKILL = 0.35 -- share of the time from the hit to the end
local FOLLOW_MONSTER = 0.3 -- share of Gait.RECOVER_SECONDS
local STRIKE_NOW_LEAD = 0.06 -- AnimationController.MonsterAttack: a strikeNow attack starts this much before the end of the windup

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

-- The basic attack of a weapon type (nil / unknown = fists); `interval` squeezes it like AttackPose.timing.
function MotionKeys.attack(weaponType: string?, interval: number?): Keys
	local timing = AttackPose.timing(AttackPose.motionFor(weaponType), interval)
	return build({
		start = 0,
		peak = timing.windup,
		hit = if timing.ranged then nil else timing.hitAt,
		release = if timing.ranged then timing.hitAt else nil,
		follow = timing.windup + timing.strike + FOLLOW_ATTACK * timing.recover,
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

-- A skill's motion (nil when the skill has none); `loopUntil` stretches a channel like SkillPose.duration.
function MotionKeys.skill(skillId: string, loopUntil: number?): Keys?
	local motion = SkillMotions.get(skillId)
	if not motion then
		return nil
	end
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
	local strikePeak = w + Gait.STRIKE_SECONDS
	local entries: { [string]: number? } = {
		start = 0,
		peak = w,
		hit = w,
		strikePeak = strikePeak,
		follow = strikePeak + FOLLOW_MONSTER * Gait.RECOVER_SECONDS,
		["end"] = Gait.attackLength(w),
	}
	if strikeNow then
		local shift = math.max(0, w - STRIKE_NOW_LEAD)
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

-- An animation clip of `length` seconds with an optional "Hit" marker.
function MotionKeys.clip(length: number, hitMarker: number?): Keys
	return build({ start = 0, hit = hitMarker, ["end"] = length })
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
