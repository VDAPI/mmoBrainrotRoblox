--!strict
-- S110: control frames (Logic/MotionKeys), the monster state at time t (Gait.stateMotion), clip time (LookAnim.clipTime)
-- and the /animlab parser and stage layout (Logic/AnimLab).

local AnimLab = require("../src/shared/Logic/AnimLab")
local AttackMotions = require("../src/shared/Data/AttackMotions")
local AttackPose = require("../src/shared/Logic/AttackPose")
local Bosses = require("../src/shared/Data/Bosses")
local Gait = require("../src/shared/Logic/Gait")
local LookAnim = require("../src/shared/Logic/LookAnim")
local MonsterAbilities = require("../src/shared/Data/MonsterAbilities")
local MotionKeys = require("../src/shared/Logic/MotionKeys")
local SkillMotions = require("../src/shared/Data/SkillMotions")
local SkillPose = require("../src/shared/Logic/SkillPose")
local Skills = require("../src/shared/Data/Skills")
local T = require("./Test")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local EPS = 1e-9
local TAU = 2 * math.pi

local function weaponTypes(): { string }
	local list: { string } = {}
	for weaponType in AttackMotions.byWeapon do
		table.insert(list, weaponType)
	end
	table.sort(list)
	table.insert(list, "unarmed")
	return list
end

local function activeSkills(): { string }
	local list: { string } = {}
	for id, def in Skills.byId do
		if def.type ~= "passive" then
			table.insert(list, id)
		end
	end
	table.sort(list)
	return list
end

-- Sorted by time, unique names, the first key is start = 0.
local function checkShape(label: string, keys: MotionKeys.Keys)
	local seen: { [string]: boolean } = {}
	T.expect({ label, keys[1].name, keys[1].t }).toEqual({ label, "start", 0 })
	for i, key in keys do
		T.expect({ label, key.name, seen[key.name] }).toEqual({ label, key.name, nil })
		seen[key.name] = true
		T.expect({ label, key.name, key.t >= 0 }).toEqual({ label, key.name, true })
		if i > 1 then
			T.expect({ label, key.name, key.t >= keys[i - 1].t }).toEqual({ label, key.name, true })
		end
	end
end

local function samePose(a: { [string]: { number } }, b: { [string]: { number } }): boolean
	for joint, values in a do
		local other = b[joint]
		if not other or #other ~= #values then
			return false
		end
		for i, v in values do
			if other[i] ~= v then
				return false
			end
		end
	end
	for joint in b do
		if not a[joint] then
			return false
		end
	end
	return true
end

T.describe("MotionKeys: basic attacks", function()
	T.it("every weapon type: shape, end = total, melee hit = the server's hitDelay, ranged release", function()
		for _, weaponType in weaponTypes() do
			local keys = MotionKeys.attack(weaponType)
			checkShape(weaponType, keys)
			local timing = AttackPose.timing(AttackPose.motionFor(weaponType))
			T.expect(MotionKeys.at(keys, "end")).toBeNear(timing.total, EPS)
			if timing.ranged then
				T.expect(MotionKeys.at(keys, "release")).toBeNear(timing.hitAt, EPS)
				T.expect(MotionKeys.at(keys, "hit")).toBeNil()
			else
				local hit = MotionKeys.at(keys, "hit") :: number
				T.expect(hit).toBeNear(AttackPose.hitDelay(weaponType, 0, false), EPS)
				T.expect({ weaponType, (MotionKeys.at(keys, "peak") :: number) < hit }).toEqual({ weaponType, true })
			end
		end
	end)

	T.it("a short interval scales every key by the factor of AttackPose.timing", function()
		for _, weaponType in weaponTypes() do
			local motion = AttackPose.motionFor(weaponType)
			local k = AttackPose.timing(motion, 0.3).total / AttackPose.timing(motion).total
			local full = MotionKeys.attack(weaponType)
			local short = MotionKeys.attack(weaponType, 0.3)
			T.expect(#short).toBe(#full)
			for i, key in full do
				T.expect(short[i].name).toBe(key.name)
				T.expect(short[i].t).toBeNear(key.t * k, 1e-9)
			end
		end
	end)

	T.it("the pose at a key is the same twice; a melee hit lands in the strike at full weight", function()
		for _, weaponType in weaponTypes() do
			local motion = AttackPose.motionFor(weaponType)
			for _, key in MotionKeys.attack(weaponType) do
				local a, phaseA, wA = AttackPose.sample(motion, key.t)
				local b, phaseB, wB = AttackPose.sample(motion, key.t)
				T.expect(samePose(a, b)).toBe(true)
				T.expect(phaseA).toBe(phaseB)
				T.expect(wA).toBe(wB)
				if key.name == "hit" then
					T.expect({ weaponType, phaseA, wA }).toEqual({ weaponType, "strike", 1 })
				end
			end
		end
	end)
end)

T.describe("MotionKeys: skills", function()
	T.it("every active skill has keys: hit = hitDelay, end = duration, peak before the hit", function()
		for _, id in activeSkills() do
			local keys = MotionKeys.skill(id)
			T.expect({ id, keys ~= nil }).toEqual({ id, true })
			local list = keys :: MotionKeys.Keys
			checkShape(id, list)
			local motion = SkillMotions.get(id) :: SkillMotions.Motion
			local hit = MotionKeys.at(list, "hit")
			if motion.hit then
				T.expect(hit).toBeNear(SkillMotions.hitDelay(id), EPS)
			else
				T.expect(hit).toBeNil()
			end
			local finish = MotionKeys.at(list, "end") :: number
			T.expect(finish).toBeNear(SkillPose.duration(motion), EPS)
			local limit = hit or MotionKeys.at(list, "release") or finish
			T.expect({ id, (MotionKeys.at(list, "peak") :: number) <= limit }).toEqual({ id, true })
			for _, key in list do
				local a, wA, dA = SkillPose.sample(motion, key.t)
				local b, wB, dB = SkillPose.sample(motion, key.t)
				T.expect(samePose(a, b)).toBe(true)
				T.expect(wA).toBe(wB)
				T.expect(dA).toBe(dB)
			end
		end
	end)

	T.it("a picked variant gives its own keys with the base's events (S115)", function()
		local base = MotionKeys.skill("doubleShot") :: MotionKeys.Keys
		local three = MotionKeys.skill("doubleShot", nil, { hits = 3 }) :: MotionKeys.Keys
		local motion = SkillMotions.get("doubleShot") :: SkillMotions.Motion
		local picked = SkillPose.pick(motion, { hits = 3 })
		T.expect(picked ~= motion).toBe(true)
		T.expect(MotionKeys.at(three, "end")).toBeNear(SkillPose.duration(picked), EPS)
		T.expect((MotionKeys.at(three, "end") :: number) > (MotionKeys.at(base, "end") :: number)).toBe(true)
		T.expect(MotionKeys.at(three, "release")).toBe(MotionKeys.at(base, "release"))
		-- no variant fits: the base keys
		local none = MotionKeys.skill("doubleShot", nil, { hits = 2 }) :: MotionKeys.Keys
		T.expect(MotionKeys.at(none, "end")).toBeNear(MotionKeys.at(base, "end") :: number, EPS)
	end)

	T.it("passive and unknown skills have none", function()
		for id, def in Skills.byId do
			if def.type == "passive" then
				T.expect(MotionKeys.skill(id)).toBeNil()
			end
		end
		T.expect(MotionKeys.skill("noSuchSkill")).toBeNil()
	end)
end)

T.describe("MotionKeys: monsters, bosses, clips", function()
	T.it("every boss attack: hit = strikePeak = windup (S117), end = attackLength", function()
		for _, boss in Bosses.all do
			for _, attack in boss.attacks do
				local keys = MotionKeys.boss(boss.id, attack.id) :: MotionKeys.Keys
				checkShape(`{boss.id}.{attack.id}`, keys)
				T.expect(MotionKeys.at(keys, "hit")).toBeNear(attack.windup, EPS)
				T.expect(MotionKeys.at(keys, "strikePeak")).toBeNear(attack.windup, EPS)
				T.expect(MotionKeys.at(keys, "peak")).toBeNear(attack.windup - Gait.STRIKE_SECONDS, EPS)
				T.expect(MotionKeys.at(keys, "end")).toBeNear(Gait.attackLength(attack.windup), EPS)
			end
		end
		T.expect(MotionKeys.boss("noSuchBoss", "sweep")).toBeNil()
		T.expect(MotionKeys.boss("grimrok", "nope")).toBeNil()
	end)

	T.it("every Elite II ability like a boss attack", function()
		for id, ability in MonsterAbilities.byId do
			local keys = MotionKeys.ability(id) :: MotionKeys.Keys
			checkShape(id, keys)
			T.expect(MotionKeys.at(keys, "hit")).toBeNear(ability.windup, EPS)
			T.expect(MotionKeys.at(keys, "strikePeak")).toBeNear(ability.windup, EPS)
			T.expect(MotionKeys.at(keys, "end")).toBeNear(Gait.attackLength(ability.windup), EPS)
		end
		T.expect(MotionKeys.ability("noSuchAbility")).toBeNil()
	end)

	T.it("a basic monster attack (strikeNow) hits at 0 and peaks STRIKE_NOW_LEAD later (S117)", function()
		local keys = MotionKeys.monster(nil, true)
		checkShape("strikeNow", keys)
		T.expect(MotionKeys.at(keys, "hit")).toBe(0)
		T.expect(MotionKeys.at(keys, "strikePeak")).toBeNear(Gait.STRIKE_NOW_LEAD, EPS)
	end)

	T.it("a clip has start, the marker and the end", function()
		T.expect(MotionKeys.clip(1.2, 0.4)).toEqual({
			{ name = "start", t = 0 },
			{ name = "hit", t = 0.4 },
			{ name = "end", t = 1.2 },
		})
		T.expect(MotionKeys.clip(1.2)).toEqual({ { name = "start", t = 0 }, { name = "end", t = 1.2 } })
	end)
end)

T.describe("Gait.stateMotion and LookAnim.clipTime", function()
	T.it("is deterministic and follows the attack curve", function()
		T.expect(Gait.stateMotion("attack1", 0.3, { windup = 0.4 }))
			.toEqual(Gait.stateMotion("attack1", 0.3, { windup = 0.4 }))
		local w = 0.5
		-- S117: the gather ends where the strike starts, the strike peaks at the windup (the server's hit)
		local atGather = Gait.stateMotion("attack1", w - Gait.STRIKE_SECONDS, { windup = w })
		T.expect(atGather.raise).toBeNear(1, 1e-9)
		T.expect(atGather.strike).toBeNear(0, 1e-9)
		local atStrike = Gait.stateMotion("attack2", w, { windup = w })
		T.expect(atStrike.strike).toBeNear(1, 1e-9)
	end)

	T.it("death, spawn and hit use the shared lengths", function()
		T.expect(Gait.HIT_SECONDS).toBe(0.25)
		T.expect(Gait.DEATH_SECONDS).toBe(0.8) -- S117 (Config.MonsterLook.deathSeconds)
		T.expect(Gait.stateMotion("death", Gait.DEATH_SECONDS).dead).toBe(1)
		T.expect(Gait.stateMotion("spawn", 0).dead).toBe(1)
		T.expect(Gait.stateMotion("hit", 0).hit).toBe(1)
		T.expect(Gait.stateMotion("hit", Gait.HIT_SECONDS).hit).toBe(0)
	end)

	T.it("idle at t = 0 leaves the legs at rest", function()
		local m = Gait.stateMotion("idle", 0, { seed = 0 })
		for _, role in { "leg", "spiderLeg" } do
			local joint: Gait.Joint = { role = role :: any, side = 1, phase = 0, amp = 1 }
			T.expect(Gait.isRest(Gait.pose(joint, m))).toBe(true)
		end
	end)

	T.it("one walk step of t equals ten steps of t / 10", function()
		local t = 0.83
		local m = Gait.stateMotion("walk", t, { speed = 8, scale = 1.3 })
		local cycle = 0
		for _ = 1, 10 do
			cycle = Gait.advance(cycle, t / 10, 8, 1.3)
		end
		local diff = (m.cycle - cycle) % TAU
		T.expect(math.min(diff, TAU - diff)).toBeNear(0, 1e-9)
		T.expect(m.move).toBe(1)
	end)

	T.it("clip time wraps loops and stops one-shots before the end", function()
		T.expect(LookAnim.clipTime(2.5, 1, true)).toBeNear(0.5, 1e-9)
		T.expect(LookAnim.clipTime(5, 1, false) < 1).toBe(true)
		T.expect(LookAnim.clipTime(0.2, 1, false, 2)).toBeNear(0.4, 1e-9)
		T.expect(LookAnim.clipTime(3, 0, true)).toBe(0)
	end)
end)

T.describe("AnimLab", function()
	T.it("parses every action", function()
		local good: { { string } } = {
			{},
			{ "on" },
			{ "off" },
			{ "attack", "sword1h" },
			{ "attack", "unarmed" },
			{ "skill", "mightyStrike" },
			{ "mob", "wolf" },
			{ "mob", "wolf", "death" },
			{ "mob", "grimrok", "cast" },
			{ "boss", "grimrok", "sweep" },
			{ "npc", "blacksmith" },
			{ "npc", "healer", "wave" },
			{ "sfx", "swing.light" },
			{ "loop" },
			{ "freeze", "0.21" },
			{ "freeze", "0" },
			{ "step", "-0.05" },
			{ "play" },
			{ "keys" },
			{ "cam", "threequarter" },
			{ "cam", "off" },
			{ "stress", "20" },
			{ "state" },
			-- S113
			{ "attack", "sword1h", "3" },
			{ "attack", "hammer2h", "combo" },
			{ "hit", "armor" },
			{ "hit", "slime", "crit" },
			{ "flinch", "left" },
			{ "flinch", "front", "crit" },
			{ "clip", "1234567" },
			{ "clip", "1234567", "attack", "sword1h", "2" },
			{ "clip", "1234567", "skill", "mightyStrike" },
		}
		for _, args in good do
			local command, err = AnimLab.parse(args)
			T.expect({ args, err }).toEqual({ args, nil })
			T.expect(command ~= nil).toBe(true)
		end
		local mob = AnimLab.parse({ "mob", "wolf" }) :: AnimLab.Command
		T.expect(mob.slot).toBe("attack1")
		T.expect((AnimLab.parse({ "freeze", "0.21" }) :: AnimLab.Command).t).toBe(0.21)
		T.expect((AnimLab.parse({}) :: AnimLab.Command).action).toBe("on")
		local step = AnimLab.parse({ "attack", "sword1h", "2" }) :: AnimLab.Command
		T.expect({ step.id, step.n, step.slot }).toEqual({ "sword1h", 2, nil })
		T.expect((AnimLab.parse({ "attack", "bow", "combo" }) :: AnimLab.Command).slot).toBe("combo")
		-- S115: a skill with the actor's weapon type
		local shot = AnimLab.parse({ "skill", "aimedShot", "crossbow" }) :: AnimLab.Command
		T.expect({ shot.action, shot.id, shot.slot }).toEqual({ "skill", "aimedShot", "crossbow" })
		local clip = AnimLab.parse({ "clip", "99", "attack", "axe1h", "3" }) :: AnimLab.Command
		T.expect({ clip.id, clip.slot, clip.ref, clip.n }).toEqual({ "99", "attack", "axe1h", 3 })
		T.expect(AnimLab.stepsOf("sword1h")).toBe(3)
		T.expect(AnimLab.stepsOf(nil)).toBe(3)
	end)

	T.it("refuses bad calls with their own key", function()
		local bad: { { any } } = {
			{ { "dance" }, "animlab.error.action" },
			{ { "keys", "x" }, "animlab.error.args" },
			{ { "attack", "katana" }, "animlab.error.weapon" },
			{ { "attack" }, "animlab.error.weapon" },
			{ { "skill", "steelSkin" }, "animlab.error.skill" },
			{ { "skill", "nope" }, "animlab.error.skill" },
			{ { "skill", "aimedShot", "katana" }, "animlab.error.skill" },
			{ { "skill", "aimedShot", "crossbow", "x" }, "animlab.error.args" },
			{ { "mob", "nope" }, "animlab.error.mob" },
			{ { "mob", "wolf", "dance" }, "animlab.error.slot" },
			{ { "boss", "grimrok", "nope" }, "animlab.error.boss" },
			{ { "boss", "grimrok" }, "animlab.error.boss" },
			{ { "npc", "nope" }, "animlab.error.npc" },
			{ { "sfx" }, "animlab.error.sfx" },
			{ { "freeze", "-1" }, "animlab.error.time" },
			{ { "freeze", "0,2" }, "animlab.error.time" },
			{ { "freeze", "11" }, "animlab.error.time" },
			{ { "freeze" }, "animlab.error.time" },
			{ { "step", "0" }, "animlab.error.step" },
			{ { "step", "2" }, "animlab.error.step" },
			{ { "cam", "fisheye" }, "animlab.error.cam" },
			{ { "stress", "31" }, "animlab.error.stress" },
			{ { "stress", "0" }, "animlab.error.stress" },
			{ { "stress", "2.5" }, "animlab.error.stress" },
			-- S113
			{ { "attack", "sword1h", "4" }, "animlab.error.weapon" },
			{ { "attack", "bow", "2" }, "animlab.error.weapon" },
			{ { "attack", "sword1h", "x" }, "animlab.error.weapon" },
			{ { "attack", "sword1h", "1", "2" }, "animlab.error.args" },
			{ { "hit" }, "animlab.error.hit" },
			{ { "hit", "glass" }, "animlab.error.hit" },
			{ { "hit", "armor", "big" }, "animlab.error.hit" },
			{ { "flinch", "up" }, "animlab.error.flinch" },
			{ { "flinch" }, "animlab.error.flinch" },
			{ { "clip" }, "animlab.error.clip" },
			{ { "clip", "abc" }, "animlab.error.clip" },
			{ { "clip", "12", "attack", "katana" }, "animlab.error.clip" },
			{ { "clip", "12", "attack", "sword1h", "4" }, "animlab.error.clip" },
			{ { "clip", "12", "skill", "steelSkin" }, "animlab.error.clip" },
			{ { "clip", "12", "dance" }, "animlab.error.clip" },
		}
		for _, case in bad do
			local command, err = AnimLab.parse(case[1])
			T.expect({ case[1], command, err }).toEqual({ case[1], nil, case[2] })
		end
	end)

	T.it("every error key exists in PL and EN", function()
		for _, key in AnimLab.ERRORS do
			T.expect({ key, en[key] ~= nil, pl[key] ~= nil }).toEqual({ key, true, true })
		end
	end)

	T.it("the layout has five cameras looking at another point, actor and target on the floor", function()
		local layout = AnimLab.LAYOUT
		T.expect(#AnimLab.CAMERAS).toBe(5)
		for _, name in AnimLab.CAMERAS do
			local cam = (layout.cameras :: any)[name]
			T.expect({ name, cam ~= nil }).toEqual({ name, true })
			local d = 0
			for i = 1, 3 do
				d += (cam.pos[i] - cam.look[i]) ^ 2
			end
			T.expect({ name, d > 1 }).toEqual({ name, true })
		end
		local half = { layout.floor.size[1] / 2, layout.floor.size[3] / 2 }
		for _, at in { layout.actor, layout.target } do
			T.expect(math.abs(at[1]) < half[1] and math.abs(at[3]) < half[2]).toBe(true)
		end
	end)

	T.it("every active skill has a weapon to be shown with", function()
		for _, id in activeSkills() do
			local weaponType = AnimLab.weaponForSkill(id)
			T.expect({ id, weaponType ~= nil and AttackMotions.byWeapon[weaponType :: string] ~= nil }).toEqual({
				id,
				true,
			})
		end
		T.expect(#AnimLab.activeSkills()).toBe(#activeSkills())
	end)
end)

return nil
