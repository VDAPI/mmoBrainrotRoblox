--!strict
-- S28: skill animations (Data/SkillMotions + Logic/SkillPose), skill visuals (Data/SkillVfx), breakpoints
-- (Logic/Skills.breakpointsAt / effective) and knockback (Logic/Knockback).

local Knockback = require("../src/shared/Logic/Knockback")
local SkillData = require("../src/shared/Data/Skills")
local SkillMotions = require("../src/shared/Data/SkillMotions")
local SkillPose = require("../src/shared/Logic/SkillPose")
local SkillVfx = require("../src/shared/Data/SkillVfx")
local Skills = require("../src/shared/Logic/Skills")
local Test = require("./Test")
local en = require("../src/shared/Data/Localization/en")
local pl = require("../src/shared/Data/Localization/pl")

local describe, it, expect = Test.describe, Test.it, Test.expect

local function actives(): { SkillData.SkillDef }
	local out = {}
	for _, skill in SkillData.byId do
		if skill.type ~= "passive" then
			table.insert(out, skill)
		end
	end
	table.sort(out, function(a, b)
		return a.id < b.id
	end)
	return out
end

local function finite(v: number): boolean
	return v == v and v ~= math.huge and v ~= -math.huge
end

local KNOWN_JOINTS: { [string]: boolean } = {}
for _, joint in SkillMotions.JOINTS do
	KNOWN_JOINTS[joint] = true
end

local VFX_PIECES: { [string]: boolean } = {}
for _, name in
	{
		"slash",
		"whirl",
		"shockwave",
		"cracks",
		"burst",
		"pillar",
		"sparkle",
		"aura",
		"shield",
		"beam",
		"dash",
		"dust",
		"rune",
		"arrowRain",
		"fan",
		"lineBeam",
		"skyBolt",
		"meteor",
		"smoke",
		"cloud",
	}
do
	VFX_PIECES[name] = true
end

local BEHAVIOURS: { [string]: boolean } = {}
for _, key in
	{
		"add",
		"mul",
		"values",
		"pull",
		"knockback",
		"castMove",
		"stunNear",
		"bleedStacks",
		"lingering",
		"echo",
		"pierce",
		"execute",
		"trap",
		"split",
		"stunLast",
		"splash",
		"secondTarget",
		"overhealShield",
		"cleanse",
		"lifesteal",
		"selfHeal",
		"effect",
		"selfEffect",
		"allyEffect",
	}
do
	BEHAVIOURS[key] = true
end

describe("Skill data (S28)", function()
	it("every active skill has a motion, a visual and exactly two breakpoints (5 and 10) with texts", function()
		local count = 0
		for _, skill in actives() do
			count += 1
			if not SkillMotions.get(skill.id) then
				error(`{skill.id}: no motion`)
			end
			if not SkillVfx[skill.id] then
				error(`{skill.id}: no visual`)
			end
			local bps = skill.breakpoints
			if not bps or not bps[5] or not bps[10] then
				error(`{skill.id}: needs breakpoints at 5 and 10`)
			end
			local n = 0
			for at, bp in bps do
				n += 1
				expect(at == 5 or at == 10).toBe(true)
				for key in bp :: any do
					if not BEHAVIOURS[key] then
						error(`{skill.id}: unknown breakpoint key {key}`)
					end
				end
				local key = `skill.{skill.id}.bp{at}`
				if (pl :: any)[key] == nil or (en :: any)[key] == nil then
					error(`missing {key}`)
				end
			end
			expect(n).toBe(2)
		end
		expect(count).toBe(45)
	end)

	it("passives have no motion, visual or breakpoints", function()
		for _, skill in SkillData.byId do
			if skill.type == "passive" then
				expect(SkillMotions.get(skill.id)).toBeNil()
				expect(SkillVfx[skill.id]).toBeNil()
				expect(skill.breakpoints).toBeNil()
			end
		end
	end)

	it("motions use known joints with the right number of values, keys in time order, hits within 0.6 s", function()
		for id, motion in SkillMotions.motions do
			expect(SkillData.get(id) ~= nil).toBe(true)
			local last = 0
			for _, key in motion.keys do
				expect(key.t > last).toBe(true)
				last = key.t
				for joint, v in key.pose do
					if not KNOWN_JOINTS[joint] then
						error(`{id}: unknown joint {joint}`)
					end
					expect(#v).toBe(SkillMotions.SIZE[joint] or 3)
				end
			end
			expect(motion.recover > 0).toBe(true)
			for _, event in { "hit", "release", "land" } do
				local t = (motion :: any)[event]
				if t then
					expect(t >= 0 and t <= last + motion.recover).toBe(true)
				end
			end
			expect(SkillMotions.hitDelay(id) <= SkillMotions.MAX_HIT).toBe(true)
			if motion.loop then
				expect(motion.loop.from < motion.loop.to and motion.loop.to <= last).toBe(true)
			end
		end
	end)

	it("visuals use known pieces and colours", function()
		for id, entry in SkillVfx do
			for _, name in entry.impact do
				if not VFX_PIECES[name] then
					error(`{id}: unknown piece {name}`)
				end
			end
			local c = entry.color
			expect(
				c == "class" or c == "element" or c == "holy" or c == "heal" or (string.sub(c, 1, 1) == "#" and #c == 7)
			).toBe(true)
			expect(type(entry.sound)).toBe("string")
			expect((entry.shake or 0) >= 0 and (entry.shake or 0) <= 1).toBe(true)
			expect((entry.hitstop or 0) <= 0.08).toBe(true)
		end
	end)
end)

describe("SkillPose", function()
	it("every motion starts and ends at rest with finite poses", function()
		for id, motion in SkillMotions.motions do
			local loopUntil = if motion.loop then motion.loop.to + 1 else nil
			local total = SkillPose.duration(motion, loopUntil)
			local startPose, startWeight = SkillPose.sample(motion, 0, { loopUntil = loopUntil })
			expect(startWeight).toBe(0)
			for _, v in startPose do
				for _, x in v do
					expect(x).toBe(0)
				end
			end
			for i = 0, 40 do
				local pose, weight, done = SkillPose.sample(motion, total * i / 40, { loopUntil = loopUntil })
				expect(finite(weight) and weight >= 0 and weight <= 1).toBe(true)
				if not done then
					for joint, v in pose do
						for _, x in v do
							if not finite(x) then
								error(`{id}: {joint} not finite`)
							end
						end
					end
				end
			end
			local _, endWeight, done = SkillPose.sample(motion, total + 0.01, { loopUntil = loopUntil })
			expect(done).toBe(true)
			expect(endWeight).toBe(0)
		end
	end)

	it("reaches every key's pose at its time", function()
		local motion = assert(SkillMotions.get("earthquake"))
		for _, key in motion.keys do
			local pose = SkillPose.sample(motion, key.t)
			for joint, v in key.pose do
				for i, x in v do
					expect(math.abs(pose[joint][i] - x) < 1e-6).toBe(true)
				end
			end
		end
	end)

	it("scales time with the speed and blends in from any pose", function()
		local motion = assert(SkillMotions.get("bladeWhirl"))
		local a = SkillPose.sample(motion, 0.4)
		local b = SkillPose.sample(motion, 0.2, { speed = 2 })
		expect(math.abs(a.root[2] - b.root[2]) < 1e-6).toBe(true)
		-- from an odd pose: the first instant is that pose, owning the joints at once
		local from = { rShoulder = { 150, 10, -20 }, waist = { -30, 40, 0 } }
		local pose, weight = SkillPose.sample(motion, 0, { from = from })
		expect(weight).toBe(1)
		expect(pose.rShoulder[1]).toBe(150)
		expect(pose.waist[2]).toBe(40)
		local later = SkillPose.sample(motion, 0.05, { from = from })
		expect(later.rShoulder[1] < 150 and later.rShoulder[1] > 10).toBe(true)
	end)

	it("Blade Whirl turns twice, Disengage flips backwards, Earthquake jumps", function()
		local whirl = assert(SkillMotions.get("bladeWhirl"))
		local turned = 0
		for _, key in whirl.keys do
			turned = math.max(turned, key.pose.root and key.pose.root[2] or 0)
		end
		expect(turned >= 680).toBe(true)
		local flip = assert(SkillMotions.get("disengage"))
		local pitch = 0
		for _, key in flip.keys do
			pitch = math.max(pitch, key.pose.root and key.pose.root[1] or 0)
		end
		expect(pitch).toBe(360)
		local quake = assert(SkillMotions.get("earthquake"))
		local lift = 0
		for _, key in quake.keys do
			lift = math.max(lift, key.pose.root and key.pose.root[4] or 0)
		end
		expect(lift >= 2).toBe(true)
	end)

	it("returns from a spin or a flip the short way", function()
		for _, id in { "bladeWhirl", "disengage", "circleOfLight" } do
			local motion = assert(SkillMotions.get(id))
			local last = motion.keys[#motion.keys].t
			local previous: number? = nil
			-- (at the last key itself the angle may still read 700°: the same direction as -20°)
			for i = 1, 10 do
				local pose = SkillPose.sample(motion, last + motion.recover * i / 10)
				local root = pose.root
				for axis = 1, 3 do
					expect(math.abs(root[axis]) <= 180).toBe(true)
				end
				if previous then
					expect(math.abs(root[2] - previous) < 60).toBe(true)
				end
				previous = root[2]
			end
		end
	end)

	it("a channel loops until it ends", function()
		local motion = assert(SkillMotions.get("evocation"))
		local short = SkillPose.duration(motion, nil)
		local long = SkillPose.duration(motion, 6)
		expect(long > short).toBe(true)
		local _, weight, done = SkillPose.sample(motion, 5, { loopUntil = 6 })
		expect(done).toBe(false)
		expect(weight).toBe(1)
	end)
end)

describe("Breakpoints", function()
	local cleave = assert(SkillData.get("cleave"))
	local charge = assert(SkillData.get("charge"))

	it("breakpointsAt: none before 5, one from 5, two from 10, none when switched off", function()
		expect(#Skills.breakpointsAt(cleave, 1, true)).toBe(0)
		expect(#Skills.breakpointsAt(cleave, 4, true)).toBe(0)
		expect(#Skills.breakpointsAt(cleave, 5, true)).toBe(1)
		expect(#Skills.breakpointsAt(cleave, 9, true)).toBe(1)
		expect(#Skills.breakpointsAt(cleave, 10, true)).toBe(2)
		expect(#Skills.breakpointsAt(cleave, 10, false)).toBe(0)
		local def, bp = Skills.effective(cleave, 10, false)
		expect(def).toBe(cleave)
		expect(next(bp)).toBeNil()
	end)

	it("effective applies numbers and behaviours", function()
		expect(Skills.effective(cleave, 4, true).angle).toBe(90)
		expect(Skills.effective(cleave, 5, true).angle).toBe(120)
		local _, bp = Skills.effective(cleave, 10, true)
		expect(bp.bleedStacks).toBe(3)
		expect(Skills.effective(charge, 5, true).range).toBe(32)
		-- the data itself is untouched
		expect(cleave.angle).toBe(90)
		expect(charge.range).toBe(25)
	end)

	it("every skill's numbers stay finite and positive after its breakpoints", function()
		for _, skill in actives() do
			for _, level in { 1, 4, 5, 9, 10 } do
				local def = Skills.effective(skill, level, true)
				for field in def.values do
					local v = Skills.valueAt(def, field, level)
					expect(finite(v)).toBe(true)
				end
				for _, field in { "radius", "angle", "range", "length", "width", "hits", "delay" } do
					local v = (def :: any)[field]
					if v ~= nil then
						expect(finite(v) and v >= 0).toBe(true)
					end
				end
				local cd = Skills.scaled(def, def.cooldown, level)
				expect(finite(cd) and cd > 0).toBe(true)
				local args = Skills.descriptionArgs(skill, level)
				for _, v in args do
					expect(finite(v)).toBe(true)
				end
				-- stats of extra effects read values that exist
				for _, effect in def.effects or {} do
					for _, field in effect.stats or {} do
						expect(def.values[field] ~= nil).toBe(true)
					end
				end
			end
		end
	end)
end)

describe("Knockback", function()
	it("pushes away from the source, stops before walls", function()
		local dx, dz = Knockback.direction(10, 0, 0, 0)
		expect(dx).toBe(1)
		expect(dz).toBe(0)
		local x = Knockback.destination(10, 0, dx, dz, 6, 1)
		expect(x).toBe(16)
		local blocked = Knockback.destination(10, 0, dx, dz, 6, 0.5)
		expect(math.abs(blocked - (10 + 3 - Knockback.WALL_GAP)) < 1e-6).toBe(true)
		local wall = Knockback.destination(10, 0, dx, dz, 6, 0.1)
		expect(wall).toBe(10) -- never behind the start
	end)

	it("same spot: falls back to the given direction", function()
		local dx, dz = Knockback.direction(0, 0, 0, 0, 0, 2)
		expect(dx).toBe(0)
		expect(dz).toBe(1)
	end)

	it("pulls stop short; bosses do not move, players half", function()
		expect(Knockback.pullDistance(12, 0, 0, 0)).toBe(12 - Knockback.PULL_GAP)
		expect(Knockback.pullDistance(2, 0, 0, 0)).toBe(0)
		expect(Knockback.scaled(8, "boss")).toBe(0)
		expect(Knockback.scaled(8, "player")).toBe(4)
		expect(Knockback.scaled(8, "monster")).toBe(8)
	end)

	it("moves fast first, ends at the goal", function()
		expect(Knockback.progress(0)).toBe(0)
		expect(Knockback.progress(1)).toBe(1)
		expect(Knockback.progress(0.5) > 0.5).toBe(true)
	end)
end)

return nil
