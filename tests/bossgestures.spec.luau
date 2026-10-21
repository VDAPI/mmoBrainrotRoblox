--!strict
-- S159a: every dodgeable pattern a boss casts has a gesture (Data/BossMotions.patterns) whose blow lands at the
-- pattern's release (Logic/HazardGesture) after an anticipation of at least the fair warning, held over a channel;
-- the roars by phase, the draws of ranged monsters and Elites, and the follow-through / hold / turn curves of Gait.

local BossMotions = require("../src/shared/Data/BossMotions")
local BossTuning = require("../src/shared/Data/BossTuning")
local Bosses = require("../src/shared/Data/Bosses")
local Combat = require("../src/shared/Data/Combat")
local Gait = require("../src/shared/Logic/Gait")
local HazardGesture = require("../src/shared/Logic/HazardGesture")
local HazardPatterns = require("../src/shared/Data/HazardPatterns")
local Hazards = require("../src/shared/Logic/Hazards")
local MonsterLooks = require("../src/shared/Data/MonsterLooks")
local MonsterMotions = require("../src/shared/Data/MonsterMotions")
local Monsters = require("../src/shared/Data/Monsters")
local Sfx = require("../src/shared/Data/Sfx")
local T = require("./Test")

local EPS = 1e-6

type Cast = { pattern: string, warn: number, how: string, attack: string? }

-- The warning of an ambient cast (Entities/Boss patternWarn).
local function ambientWarn(patternId: string): number
	local pattern = HazardPatterns.get(patternId) :: any
	local first = pattern and pattern.emitters[1]
	return math.max(Hazards.MIN_WARN, if first and first.delay then first.delay else Hazards.MIN_WARN)
end

-- Every pattern cast of a boss as Entities/Boss sends it: the pattern, its least warning (the event's `d`) and how.
local function castsOf(bossId: string): { Cast }
	local boss = Bosses.get(bossId) :: any
	local windups: { [string]: number } = {}
	for _, attack in boss.attacks do
		windups[attack.id] = attack.windup
	end
	local out: { Cast } = {}
	local tuning = (BossTuning.patterns :: any)[bossId]
	if tuning then
		for attackId, patternId in tuning.replace or {} do
			table.insert(out, { pattern = patternId, warn = windups[attackId], how = "replace", attack = attackId })
		end
		for attackId, add in tuning.add or {} do
			table.insert(out, { pattern = add.pattern, warn = windups[attackId], how = "add", attack = attackId })
		end
		for _, ambient in tuning.ambient or {} do
			table.insert(out, { pattern = ambient.pattern, warn = ambientWarn(ambient.pattern), how = "ambient" })
		end
	end
	local extra = (BossTuning.extra :: any)[bossId]
	for kind, spec in (extra or {}) :: { [string]: any } do
		if spec.pattern then
			table.insert(out, { pattern = spec.pattern, warn = spec.windup, how = kind })
		end
	end
	return out
end

T.describe("Boss pattern gestures (S159a)", function()
	T.it("every pattern a boss casts has its gesture (own style or the attack it rides), no dead entries", function()
		for _, boss in Bosses.all do
			local def = BossMotions.get(boss.id) :: any
			local used: { [string]: boolean } = {}
			for _, cast in castsOf(boss.id) do
				used[cast.pattern] = true
				local gesture = BossMotions.gesture(boss.id, cast.pattern)
				local tag = `{boss.id}.{cast.pattern}`
				T.expect({ tag, gesture ~= nil }).toEqual({ tag, true })
				if not gesture then
					continue
				end
				if cast.how == "add" then
					-- a pattern following an attack rides on that attack's own motion
					T.expect({ tag, gesture.rides, gesture.style }).toEqual({ tag, cast.attack, nil })
					T.expect({ tag, BossMotions.attack(boss.id, cast.attack :: string) ~= nil }).toEqual({ tag, true })
				else
					local style = gesture.style
					T.expect({ tag, gesture.rides, style ~= nil and MonsterMotions.STYLES[style] ~= nil })
						.toEqual({ tag, nil, true })
				end
			end
			for patternId in def.patterns do
				T.expect({ boss.id, patternId, used[patternId] == true }).toEqual({ boss.id, patternId, true })
			end
		end
	end)

	T.it("gesture sounds are playable Data/Sfx keys, shakes within 0..1", function()
		for _, boss in Bosses.all do
			local def = BossMotions.get(boss.id) :: any
			for patternId, gesture in def.patterns do
				local tag = `{boss.id}.{patternId}`
				for _, key in { gesture.windSound, gesture.sound } :: { string? } do
					if key then
						T.expect({ tag, key, Sfx.playable(key) }).toEqual({ tag, key, true })
					end
				end
				if gesture.style then
					T.expect({ tag, gesture.sound ~= nil }).toEqual({ tag, true })
				end
				local shake = gesture.shake or 0
				T.expect({ tag, shake >= 0 and shake <= 1 }).toEqual({ tag, true })
			end
		end
	end)

	T.it("the blow lands at the release, after an anticipation of at least the fair warning", function()
		for _, boss in Bosses.all do
			for _, cast in castsOf(boss.id) do
				local pattern = HazardPatterns.get(cast.pattern) :: any
				local timing = HazardGesture.timing(pattern, cast.warn)
				local tag = `{boss.id}.{cast.pattern}.{cast.how}`
				-- the strike of the pose peaks at the first release (Gait.charge peaks at the windup)
				T.expect({ tag, math.abs(timing.windup - timing.release) < EPS }).toEqual({ tag, true })
				T.expect({ tag, timing.windup >= Hazards.MIN_WARN - EPS }).toEqual({ tag, true })
				-- the anticipation runs inside the warning: nothing is released or lands before the blow
				T.expect({ tag, timing.release <= math.max(cast.warn, timing.last) + EPS }).toEqual({ tag, true })
				-- a channel holds the blow to the last release (within MAX_HOLD)
				local expected = math.clamp(timing.last - timing.windup, 0, HazardGesture.MAX_HOLD)
				T.expect({ tag, math.abs(timing.hold - expected) < EPS }).toEqual({ tag, true })
				if cast.how == "add" then
					-- the attack's own blow (its windup) is the release of the pattern riding on it
					T.expect({ tag, math.abs(timing.release - cast.warn) < EPS }).toEqual({ tag, true })
				end
			end
		end
	end)

	T.it("a thrown lob is released LOB_FLIGHT before it lands, a rock from the sky at its landing", function()
		local bombs = HazardGesture.timing(HazardPatterns.get("gr_bombs") :: any, 1.4)
		T.expect(math.abs(bombs.release - (1.4 - HazardGesture.LOB_FLIGHT)) < EPS).toBe(true)
		-- two bombs per fighter, 0.25 s apart: the throwing pose holds for the second
		T.expect(math.abs(bombs.hold - 0.25) < EPS).toBe(true)
		local meteor = HazardGesture.timing(HazardPatterns.get("az_meteor") :: any, 1.6)
		T.expect(math.abs(meteor.release - 1.6) < EPS).toBe(true)
		T.expect(meteor.hold).toBe(0)
		T.expect(HazardGesture.thrown("boulder")).toBe(true)
		T.expect(HazardGesture.thrown("meteor")).toBe(false)
		T.expect(HazardGesture.flight(0.3)).toBe(0.3)
	end)

	T.it("channels hold: the spiral, the breath and the shard rains", function()
		local spiral = HazardGesture.timing(HazardPatterns.get("mv_spiral") :: any, 1.2)
		T.expect(math.abs(spiral.hold - 9 * 0.22) < EPS).toBe(true)
		local breath = HazardGesture.timing(HazardPatterns.get("hv_frostBreath") :: any, 1.5)
		T.expect(math.abs(breath.release - 1.5) < EPS and math.abs(breath.hold - 2.4) < EPS).toBe(true)
		local rain = HazardGesture.timing(HazardPatterns.get("hv_shardRain") :: any, 1.1)
		T.expect(rain.hold > 1 and rain.hold <= HazardGesture.MAX_HOLD).toBe(true)
		local wave = HazardGesture.timing(HazardPatterns.get("hv_glacierWalls") :: any, 2.2)
		T.expect(math.abs(wave.release - 2.2) < EPS and wave.hold == 0).toBe(true)
	end)

	T.it("the body turns with a breath's cone and a spiral's shots", function()
		local breath = HazardPatterns.get("hv_frostBreath") :: any
		local cast: Hazards.Cast = {
			seed = 7,
			origin = { x = 0, y = 0, z = 0 },
			yaw = 0,
			targets = { { x = 20, y = 0, z = 0 } },
			delay = 1.5,
		}
		local insts = Hazards.expand(breath, cast)
		local inst = insts[1]
		-- facing the target (Hazards angle 0): the turn mirrors the cone's start and end
		local from, to = HazardGesture.turnOf(breath, insts, 0)
		T.expect(math.abs((from :: number) + inst.from) < EPS and math.abs((to :: number) + inst.to) < EPS).toBe(true)
		local spiral = HazardPatterns.get("mv_spiral") :: any
		local sFrom, sTo = HazardGesture.turnOf(spiral, {}, 0)
		T.expect(sFrom).toBe(0)
		T.expect(math.abs((sTo :: number) + math.rad(14 * 9)) < EPS).toBe(true)
		local none = HazardGesture.turnOf(HazardPatterns.get("gr_axeThrow") :: any, {}, 0)
		T.expect(none).toBeNil()
		-- a Roblox look vector (0, 0, -1) is the Hazards angle -pi/2
		T.expect(math.abs(HazardGesture.facing(0, -1) + math.pi / 2) < EPS).toBe(true)
	end)
end)

T.describe("Boss roars (S159a)", function()
	T.it("every boss roars in its own style, a rage roar into the last phase, with a playable sound", function()
		for _, boss in Bosses.all do
			local def = BossMotions.get(boss.id) :: any
			local roar = def.roar
			T.expect({ boss.id, roar.style ~= "roar", MonsterMotions.STYLES[roar.style] ~= nil })
				.toEqual({ boss.id, true, true })
			for phase, style in roar.byPhase or {} do
				T.expect({ boss.id, phase >= 2 and phase <= 3, MonsterMotions.STYLES[style] ~= nil })
					.toEqual({ boss.id, true, true })
			end
			T.expect({ boss.id, BossMotions.roarStyle(boss.id, 3) ~= roar.style }).toEqual({ boss.id, true })
			T.expect({ boss.id, BossMotions.roarStyle(boss.id, 2) }).toEqual({ boss.id, roar.style })
			T.expect({ boss.id, roar.sound ~= nil and Sfx.playable(roar.sound) }).toEqual({ boss.id, true })
		end
		T.expect(BossMotions.roarStyle("noSuchBoss", 2)).toBeNil()
	end)
end)

T.describe("Ranged draws (S159a)", function()
	T.it("every ranged monster draws in a style of its own before its shot, every plan can throw", function()
		for _, monster in Monsters.list do
			if monster.attack ~= "ranged" then
				continue
			end
			local look = MonsterLooks.get(monster.id) :: any
			local shot = if monster.damageKind == "magic" then "bolt" else "arrow"
			local style = MonsterMotions.rangedFor(look.plan, look.weapon, shot)
			local melee = MonsterMotions.styleFor(look.plan, look.weapon, nil)
			T.expect({ monster.id, style ~= nil and MonsterMotions.STYLES[style :: string] ~= nil, style ~= melee })
				.toEqual({ monster.id, true, true })
		end
		for plan, entry in MonsterMotions.RANGED do
			T.expect({ plan, MonsterMotions.PLANS[plan] ~= nil }).toEqual({ plan, true })
			for shot, style in entry do
				T.expect({ plan, shot, MonsterMotions.STYLES[style] ~= nil }).toEqual({ plan, shot, true })
			end
		end
		for plan in MonsterMotions.PLANS do
			local style = MonsterMotions.rangedFor(plan, nil, "throw")
			T.expect({ plan, style ~= nil and MonsterMotions.STYLES[style :: string] ~= nil }).toEqual({ plan, true })
		end
		-- the Elite II's throw is drawn back as long as a fair, short tell
		T.expect(Combat.basicWind.throw >= Combat.basicWind.ranged and Combat.basicWind.throw <= 0.8).toBe(true)
	end)
end)

T.describe("Gait follow-through, held blow and turn (S159a)", function()
	T.it("a held blow keeps the strike at its peak, then recovers", function()
		local m: Gait.Motion = { cycle = 0, move = 0, time = 3, raise = 0, strike = 0, hit = 0, dead = 0 }
		Gait.attackMotion(m, 1.0, 1.0, true, { hold = 1.5 })
		T.expect(math.abs(m.strike - 1) < EPS).toBe(true)
		Gait.attackMotion(m, 2.2, 1.0, true, { hold = 1.5 })
		T.expect(math.abs(m.strike - 1) < EPS).toBe(true)
		T.expect(m.follow).toBe(0)
		Gait.attackMotion(m, 2.5 + Gait.RECOVER_SECONDS + 0.01, 1.0, true, { hold = 1.5 })
		T.expect(m.strike).toBe(0)
		T.expect(m.follow).toBe(1)
		Gait.attackMotion(m, 2.5 + Gait.attackLength(0, 0, true) + 0.01, 1.0, true, { hold = 1.5 })
		T.expect(m.follow).toBe(0)
		T.expect(Gait.acting(m)).toBe(false)
		-- without a hold the curves are the ones before S159a
		local a: Gait.Motion = { cycle = 0, move = 0, time = 3, raise = 0, strike = 0, hit = 0, dead = 0 }
		Gait.attackMotion(a, 0.9, 1.2, true)
		local raise, strike = Gait.charge(0.9, 1.2)
		T.expect({ a.raise, a.strike }).toEqual({ raise, strike })
		T.expect(Gait.heldElapsed(3, 1, nil)).toBe(3)
		T.expect(Gait.heldElapsed(2, 1, 2)).toBe(1)
		T.expect(Gait.heldElapsed(4, 1, 2)).toBe(2)
	end)

	T.it("the follow pose fades in as the strike fades out and settles", function()
		T.expect(Gait.followOf(1.0, 1.0, 0)).toBe(0)
		local mid = Gait.followOf(1.0 + Gait.RECOVER_SECONDS / 2, 1.0, 0)
		T.expect(mid > 0.3 and mid < 0.7).toBe(true)
		T.expect(Gait.followOf(1.0 + Gait.RECOVER_SECONDS + Gait.FOLLOW_HOLD / 2, 1.0, 0)).toBe(1)
		T.expect(Gait.followOf(1.0 + Gait.attackLength(0, 0, true), 1.0, 0)).toBe(0)
		T.expect(Gait.attackLength(1, 2, true)).toBe(1 + 2 + Gait.RECOVER_SECONDS + Gait.FOLLOW_HOLD + Gait.FOLLOW_OUT)
	end)

	T.it("a style's follow pose and the body turn reach the joints; overlay is the action alone", function()
		local arm: Gait.Joint = { role = "arm", side = 1, phase = 0, amp = 1, front = 0 }
		local body: Gait.Joint = { role = "body", side = 0, phase = 0, amp = 1, front = 0 }
		local m: Gait.Motion = { cycle = 0, move = 0, time = 3, raise = 0, strike = 0, hit = 0, dead = 0 }
		m.style = "gr_axeThrow"
		m.follow = 1
		local follow = (MonsterMotions.STYLES.gr_axeThrow :: any).follow.arm
		local p = Gait.overlay(arm, m)
		T.expect(math.abs(p.rx - follow[1]) < EPS and math.abs(p.rz - follow[3]) < EPS).toBe(true)
		m.style = nil
		m.follow = 0
		m.turn = 0.5
		T.expect(math.abs(Gait.overlay(body, m).ry - 0.5) < EPS).toBe(true)
		m.turn = 0
		local rest = Gait.overlay(arm, m)
		T.expect(Gait.isRest(rest)).toBe(true)
		-- the turn goes towards `from` over the windup, to `to` over the hold, back over the follow-through
		T.expect(math.abs(Gait.turnOf(1, 1, 2, 0.3, -0.6) - 0.3) < EPS).toBe(true)
		T.expect(math.abs(Gait.turnOf(3, 1, 2, 0.3, -0.6) + 0.6) < EPS).toBe(true)
		T.expect(Gait.turnOf(3 + Gait.attackLength(0, 0, true), 1, 2, 0.3, -0.6)).toBe(0)
	end)
end)
