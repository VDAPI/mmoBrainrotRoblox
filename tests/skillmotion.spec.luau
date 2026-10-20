--!strict
-- S28: skill animations (Data/SkillMotions + Logic/SkillPose), skill visuals (Data/SkillVfx), breakpoints
-- (Logic/Skills.breakpointsAt / effective) and knockback (Logic/Knockback). S114: the server's times pinned
-- (tests/fixtures/skill_timing), motion variants (SkillPose.pick), the three layers and the signature of every class's
-- skills (tests/SkillLooks; S114 Warrior and Cleric, S115 Hunter and Mage), the meaning of an impact's `n`
-- (Logic/SkillFxWave). S115: shots and their crossbow variants, waves of arrows and bolts, snares, phase sounds.

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
		"tether", -- S74
		"falcon", -- S77
		-- S112
		"impactFlash",
		"sparks",
		"groundDecal",
		"smokePuff",
		"magicCircle",
		"ringWave",
		-- S114
		"shieldArc",
		"wings",
		-- S115
		"snare",
		"stormCloud",
		-- W03
		"fireBlast",
		"frostBlast", -- W04
	}
do
	VFX_PIECES[name] = true
end

local BEHAVIOURS: { [string]: boolean } = require("./BreakpointKeys")

describe("Skill data (S28)", function()
	it(
		"every active skill has a motion, a visual and breakpoints at ranks 5 and 10 (A, B optional) with texts",
		function()
			for _, skill in actives() do
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
				for at, pair in bps do
					n += 1
					expect(at == 5 or at == 10).toBe(true)
					expect(pair.a ~= nil).toBe(true)
					for option, bp in pair :: any do
						if option ~= "a" and option ~= "b" then
							error(`{skill.id}: unknown breakpoint option {option}`)
						end
						for key in bp do
							if not BEHAVIOURS[key] then
								error(`{skill.id}: unknown breakpoint key {key}`)
							end
						end
						local key = Skills.breakpointKey(skill.id, at, option)
						if (pl :: any)[key] == nil or (en :: any)[key] == nil then
							error(`missing {key}`)
						end
					end
				end
				expect(n).toBe(2)
			end
		end
	)

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

	it("clips (S113): valid ids and markers, never on a channel, the keys stay as the fallback", function()
		local ClipFit = require("../src/shared/Logic/ClipFit")
		for id, motion in SkillMotions.motions do
			local clip = motion.clip
			if clip then
				expect({ id, ClipFit.validId(clip.id), clip.hit == nil or clip.hit ~= "" }).toEqual({ id, true, true })
				if clip.speed then
					expect({ id, clip.speed >= ClipFit.MIN_SPEED and clip.speed <= ClipFit.MAX_SPEED }).toEqual({
						id,
						true,
					})
				end
				if clip.hitTime then
					expect({ id, clip.hitTime > 0 }).toEqual({ id, true })
				end
				expect({ id, motion.loop == nil }).toEqual({ id, true })
				expect({ id, #motion.keys > 0 }).toEqual({ id, true })
			end
			-- the server's hit time of every skill stays the motion's hit (or release), capped (S28 rule, unchanged)
			expect(SkillMotions.hitDelay(id)).toBeNear(
				math.clamp(motion.hit or motion.release or 0, 0, SkillMotions.MAX_HIT),
				1e-12
			)
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
			expect(type(entry.sound)).toBe("string") -- S111: the key is checked in sfx.spec
			expect((entry.shake or 0) >= 0 and (entry.shake or 0) <= 1).toBe(true)
			expect((entry.hitstop or 0) <= 0.08).toBe(true)
			-- S74: pieces on allies, their colour and the server object
			for _, name in entry.allies or {} do
				if not VFX_PIECES[name] then
					error(`{id}: unknown ally piece {name}`)
				end
			end
			local ally = entry.allyColor
			expect(ally == nil or (string.sub(ally, 1, 1) == "#" and #ally == 7)).toBe(true)
			expect(entry.object == nil or (entry.object == "banner" and id == "warBanner")).toBe(true)
			-- S115: storm strike pieces
			for _, name in entry.strike or {} do
				if not VFX_PIECES[name] then
					error(`{id}: unknown strike piece {name}`)
				end
			end
			-- S77: trap trigger pieces, only on traps
			local trigger = entry.trigger
			if trigger then
				local skill = SkillData.get(id)
				expect({ id, skill ~= nil and skill.type == "trap" }).toEqual({ id, true })
				for _, name in trigger do
					if not VFX_PIECES[name] then
						error(`{id}: unknown trigger piece {name}`)
					end
				end
			end
		end
		expect(SkillVfx.warBanner.object).toBe("banner")
	end)
end)

describe("Warrior S74 motions and looks", function()
	local WeaponLooks = require("../src/shared/Data/WeaponLooks")
	local LOCKED = { shieldWall = true, carnage = true, warBanner = true, advanceOrder = true, intercept = false }

	it("six path skills: motion, visual, lock, texts", function()
		for _, id in { "intercept", "shieldWall", "rend", "carnage", "warBanner", "advanceOrder" } do
			local motion = SkillMotions.get(id)
			expect({ id, motion ~= nil, SkillVfx[id] ~= nil }).toEqual({ id, true, true })
			local m: any = motion
			expect({ id, m.hit <= SkillMotions.MAX_HIT }).toEqual({ id, true })
			if LOCKED[id] ~= nil then
				expect({ id, m.lock == true }).toEqual({ id, LOCKED[id] })
			end
			for _, suffix in { "bp5", "bp5b", "bp10", "bp10b" } do
				local key = `skill.{id}.{suffix}`
				expect({ key, (pl :: any)[key] ~= nil, (en :: any)[key] ~= nil }).toEqual({ key, true, true })
			end
		end
	end)

	it("the banner object: materials, colours, a 9-stud pole", function()
		local pole = nil
		for _, piece in WeaponLooks.BANNER do
			expect({ piece.name, table.find(WeaponLooks.MATERIALS, piece.material) ~= nil }).toEqual({
				piece.name,
				true,
			})
			expect(string.sub(piece.color, 1, 1) == "#" and #piece.color == 7).toBe(true)
			if piece.name == "Pole" then
				pole = piece
			end
		end
		expect(pole ~= nil and (pole :: any).size[2] == 9).toBe(true)
	end)
end)

describe("Hunter S77 motions and looks", function()
	it("six path skills: motion, visual, lock, loop, texts", function()
		for _, id in { "drawBead", "heartseeker", "venomSnare", "snarefield", "falcon", "drive" } do
			local motion = SkillMotions.get(id)
			expect({ id, motion ~= nil, SkillVfx[id] ~= nil }).toEqual({ id, true, true })
			for _, suffix in { "bp5", "bp5b", "bp10", "bp10b" } do
				local key = `skill.{id}.{suffix}`
				expect({ key, (pl :: any)[key] ~= nil, (en :: any)[key] ~= nil }).toEqual({ key, true, true })
			end
		end
		-- Heartseeker: the draw loops for the aim; the shot comes from the server, moving cancels it
		local heart: any = SkillMotions.get("heartseeker")
		expect({ heart.loop ~= nil, heart.lock, heart.hit, heart.release }).toEqual({ true, nil, nil, nil })
		for _, id in { "venomSnare", "snarefield" } do
			local m: any = SkillMotions.get(id)
			expect({ id, m.lock }).toEqual({ id, true })
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
		expect(#Skills.breakpointsAt(cleave, 1, nil, true)).toBe(0)
		expect(#Skills.breakpointsAt(cleave, 4, nil, true)).toBe(0)
		expect(#Skills.breakpointsAt(cleave, 5, nil, true)).toBe(1)
		expect(#Skills.breakpointsAt(cleave, 9, nil, true)).toBe(1)
		expect(#Skills.breakpointsAt(cleave, 10, nil, true)).toBe(2)
		expect(#Skills.breakpointsAt(cleave, 10, nil, false)).toBe(0)
		local def, bp = Skills.effective(cleave, 10, nil, nil, false)
		expect(def).toBe(cleave)
		expect(next(bp)).toBeNil()
	end)

	it("effective applies numbers and behaviours", function()
		expect(Skills.effective(cleave, 4, nil, nil, true).angle).toBe(90)
		expect(Skills.effective(cleave, 5, nil, nil, true).angle).toBe(120)
		local _, bp = Skills.effective(cleave, 10, nil, nil, true)
		expect(bp.bleedStacks).toBe(3)
		expect(Skills.effective(charge, 5, nil, nil, true).range).toBe(32)
		-- the data itself is untouched
		expect(cleave.angle).toBe(90)
		expect(charge.range).toBe(25)
	end)

	it("every skill's numbers stay finite and positive after its breakpoints", function()
		for _, skill in actives() do
			for _, level in { 1, 4, 5, 9, 10 } do
				local def = Skills.effective(skill, level, nil, nil, true)
				for field in def.values do
					local v = Skills.valueAt(def, field, level)
					expect(finite(v)).toBe(true)
				end
				for _, field in
					{ "radius", "hitRadius", "allyRadius", "angle", "range", "length", "width", "hits", "delay" }
				do
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
				for _, list in { def.effects or {}, def.selfEffects or {}, def.allyEffects or {} } do
					for _, effect in list do
						for _, field in effect.stats or {} do
							expect(def.values[field] ~= nil).toBe(true)
						end
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

describe("Mage S80 motions and looks", function()
	it("four path skills: motion, visual, lock, loop, release, texts", function()
		for _, id in { "elementalVortex", "cataclysm", "arcaneDischarge", "arcaneTorrent" } do
			local motion = SkillMotions.get(id)
			expect({ id, motion ~= nil, SkillVfx[id] ~= nil }).toEqual({ id, true, true })
			for _, suffix in { "bp5", "bp5b", "bp10", "bp10b" } do
				local key = `skill.{id}.{suffix}`
				expect({ key, (pl :: any)[key] ~= nil, (en :: any)[key] ~= nil }).toEqual({ key, true, true })
			end
		end
		local torrent: any = SkillMotions.get("arcaneTorrent")
		expect(torrent.loop ~= nil and torrent.lock == true).toBe(true)
		local cataclysm: any = SkillMotions.get("cataclysm")
		expect(cataclysm.lock == true and cataclysm.hit <= SkillMotions.MAX_HIT).toBe(true)
		local vortex: any = SkillMotions.get("elementalVortex")
		expect(vortex.lock).toBeNil()
		local discharge: any = SkillMotions.get("arcaneDischarge")
		expect(discharge.release ~= nil).toBe(true)
	end)

	it("everyWave within impact, waves only on circleTarget, chargeSize only with a projectile", function()
		for id, entry in SkillVfx do
			for _, name in entry.everyWave or {} do
				expect({ id, name, table.find(entry.impact, name) ~= nil }).toEqual({ id, name, true })
			end
			if entry.waves then
				local skill = SkillData.get(id)
				expect({ id, skill ~= nil and skill.type == "circleTarget" }).toEqual({ id, true })
			end
			if entry.chargeSize then
				expect({ id, entry.projectile ~= nil }).toEqual({ id, true })
			end
		end
	end)
end)

describe("Skill looks of every class (S114 Warrior and Cleric, S115 Hunter and Mage)", function()
	local Config = require("../src/shared/Config")
	local Sfx = require("../src/shared/Data/Sfx")
	local SkillFxWave = require("../src/shared/Logic/SkillFxWave")
	local SkillLooks = require("./SkillLooks")
	local Timing = require("./fixtures/skill_timing")
	local VfxTextures = require("../src/shared/Data/VfxTextures")

	local CLASSES = { Warrior = true, Cleric = true, Hunter = true, Mage = true }
	local function classSkills(): { SkillData.SkillDef }
		local out = {}
		for _, skill in actives() do
			if CLASSES[skill.class] then
				table.insert(out, skill)
			end
		end
		return out
	end
	local EVENTS = { "hit", "release", "land", "loop", "lock" }

	it("keeps the server's time of every active skill (tests/fixtures/skill_timing)", function()
		local seen: { [string]: boolean } = {}
		for _, skill in actives() do
			local id = skill.id
			seen[id] = true
			local pin = Timing.skills[id]
			if not pin then
				error(`{id}: not in the pin (a new skill: add its row by hand, never regenerate the file)`)
			end
			local m = assert(SkillMotions.get(id))
			local now: { [string]: any } = {
				hitDelay = SkillMotions.hitDelay(id),
				hit = m.hit or false,
				release = m.release or false,
				land = m.land or false,
				loopFrom = if m.loop then m.loop.from else false,
				loopTo = if m.loop then m.loop.to else false,
				lock = m.lock == true,
			}
			for field, was in pin :: any do
				if now[field] ~= was then
					error(`{id}.{field}: was {tostring(was)}, is {tostring(now[field])}`)
				end
			end
		end
		for id in Timing.skills do
			expect({ id, seen[id] == true }).toEqual({ id, true })
		end
	end)

	it("keeps the projectile and waves of every circleTarget (Offense.circleTarget reads them)", function()
		for _, skill in actives() do
			if skill.type == "circleTarget" then
				local pin = Timing.circleTarget[skill.id]
				local entry = SkillVfx[skill.id]
				expect({ skill.id, pin ~= nil }).toEqual({ skill.id, true })
				expect({ skill.id, entry.projectile or false, entry.waves == true }).toEqual({
					skill.id,
					pin.projectile,
					pin.waves,
				})
			end
		end
	end)

	it("variants: ordered keys of known joints, from rest to rest, no events, not shorter than the motion", function()
		local count = 0
		for id, motion in SkillMotions.motions do
			for i, variant in motion.variants or {} do
				count += 1
				local label = `{id}[{i}]`
				for _, event in EVENTS do
					expect({ label, event, (variant :: any)[event] }).toEqual({ label, event, nil })
				end
				expect({ label, variant.weapon ~= nil or variant.hits ~= nil or variant.move ~= nil }).toEqual({
					label,
					true,
				})
				local last = 0
				for _, key in variant.keys do
					expect({ label, key.t > last }).toEqual({ label, true })
					last = key.t
					for joint, v in key.pose do
						if not KNOWN_JOINTS[joint] then
							error(`{label}: unknown joint {joint}`)
						end
						expect({ label, joint, #v }).toEqual({ label, joint, SkillMotions.SIZE[joint] or 3 })
					end
				end
				for _, event in { "hit", "release", "land" } do
					local t = (motion :: any)[event]
					if t then
						expect({ label, event, last >= t }).toEqual({ label, event, true })
					end
				end
				local picked = SkillPose.pick(motion, {
					weapon = variant.weapon,
					hits = variant.hits,
					move = variant.move,
				})
				expect({ label, picked.keys == variant.keys }).toEqual({ label, true })
				for _, event in EVENTS do
					expect({ label, event, (picked :: any)[event] == (motion :: any)[event] }).toEqual({
						label,
						event,
						true,
					})
				end
				local total = SkillPose.duration(picked)
				local startPose, startWeight = SkillPose.sample(picked, 0)
				expect(startWeight).toBe(0)
				for _, v in startPose do
					for _, x in v do
						expect(x).toBe(0)
					end
				end
				for step = 0, 30 do
					local pose = SkillPose.sample(picked, total * step / 30)
					for joint, v in pose do
						for _, x in v do
							if not finite(x) then
								error(`{label}: {joint} not finite`)
							end
						end
					end
				end
				local _, endWeight, done = SkillPose.sample(picked, total + 0.01)
				expect({ label, done, endWeight }).toEqual({ label, true, 0 })
			end
		end
		expect(count >= 5).toBe(true)
	end)

	it("pick: the variant whose conditions hold, else the motion", function()
		local whirl = assert(SkillMotions.get("bladeWhirl"))
		local titans = assert(SkillMotions.get("titansWrath"))
		local mighty = assert(SkillMotions.get("mightyStrike"))
		expect(SkillPose.pick(whirl, nil)).toBe(whirl)
		expect(SkillPose.pick(whirl, {})).toBe(whirl)
		expect(SkillPose.pick(whirl, { hits = 3 })).toBe(whirl)
		local moving = SkillPose.pick(whirl, { move = true, hits = 3 })
		expect(moving ~= whirl and moving.keys[2].pose.rHip == nil).toBe(true)
		local four = SkillPose.pick(whirl, { hits = 4 })
		expect(four ~= whirl and four.keys[2].pose.rHip ~= nil and #four.keys == #whirl.keys + 1).toBe(true)
		local fourMoving = SkillPose.pick(whirl, { hits = 4, move = true })
		expect(fourMoving ~= four and fourMoving.keys[2].pose.rHip == nil).toBe(true)
		expect(SkillPose.pick(whirl, { hits = 4 })).toBe(four) -- made once
		expect(SkillPose.pick(whirl, { weapon = "slash2h" }) ~= whirl).toBe(true)
		expect(SkillPose.pick(whirl, { weapon = "nope" })).toBe(whirl)
		expect(SkillPose.pick(mighty, { weapon = "slash2h" }) ~= mighty).toBe(true)
		expect(SkillPose.pick(mighty, { weapon = "slash1h" })).toBe(mighty)
		expect(SkillPose.pick(titans, { hits = 3 })).toBe(titans)
		local titans4 = SkillPose.pick(titans, { hits = 4 })
		expect(titans4 ~= titans).toBe(true)
		-- the 4th blow lands at hit + 3 x interval (Titan's Wrath 0.45, Blade Whirl 0.2)
		local function keyNear(motion: SkillMotions.Motion, t: number): boolean
			for _, key in motion.keys do
				if math.abs(key.t - t) <= 0.03 then
					return true
				end
			end
			return false
		end
		local titansDef = assert(SkillData.get("titansWrath")) :: any
		local whirlDef = assert(SkillData.get("bladeWhirl")) :: any
		expect(keyNear(titans4, (titans.hit :: number) + 3 * titansDef.interval)).toBe(true)
		expect(keyNear(titans4, 1.65)).toBe(true)
		expect(keyNear(four, (whirl.hit :: number) + 3 * whirlDef.interval)).toBe(true)
		expect(keyNear(four, 0.78)).toBe(true)
		-- the blade passes the front (turn 90 mod 360) at every wave of the motion and of the 4-wave variant
		for _, m in { whirl, four } do
			local waves = if m == four then 4 else 3
			for wave = 1, waves do
				local t = (whirl.hit :: number) + (wave - 1) * whirlDef.interval
				local yaw = SkillPose.sample(m, t).root[2]
				expect({ wave, math.abs(((yaw - 90) + 180) % 360 - 180) < 1 }).toEqual({ wave, true })
			end
		end
	end)

	it("Charge bashes at the server's damage (event + 0.15 s), its event stays 0.15", function()
		local charge = assert(SkillMotions.get("charge"))
		expect(charge.hit).toBe(0.15)
		local found = false
		for _, key in charge.keys do
			if math.abs(key.t - 0.3) < 1e-9 then
				found = true
			end
		end
		expect(found).toBe(true)
		expect(SkillVfx.charge.coreDelay).toBe(0.15)
	end)

	it("every skill of both classes: motion, look, its own sound key", function()
		local empty = {}
		for _, skill in classSkills() do
			local id = skill.id
			local entry = SkillVfx[id]
			expect({ id, SkillMotions.get(id) ~= nil, entry ~= nil }).toEqual({ id, true, true })
			expect({ id, entry.sound == "" or entry.sound == "skill." .. id }).toEqual({ id, true })
			expect({ id, Sfx.has("skill." .. id) }).toEqual({ id, true })
			if not Sfx.playable("skill." .. id) then
				table.insert(empty, id)
			end
		end
		for _, key in Sfx.keys("skill.") do
			local id, suffix = string.match(key, "^skill%.([%w]+)%.(%a+)$")
			if id and suffix and id ~= "default" then
				local skill = SkillData.get(id)
				expect({ key, skill ~= nil and skill.type ~= "passive" }).toEqual({ key, true })
				-- S114 cast, S115 trigger (traps), wave (later waves, storm strikes), strike (the falcon)
				local known = suffix == "cast"
					or (suffix == "trigger" and skill ~= nil and skill.type == "trap")
					or suffix == "wave"
					or key == "skill.falcon.strike"
					or key == "skill.guardianAngel.save"
				expect({ key, known }).toEqual({ key, true })
			end
		end
		table.sort(empty)
		print(`  S114: skill keys without a sound ({#empty}): {table.concat(empty, ", ")}`)
	end)

	it("three layers (core, body, trail) for every skill of both classes; every piece has a layer", function()
		for name in VFX_PIECES do
			expect({ name, SkillLooks.PIECE_LAYER[name] ~= nil, SkillLooks.PIECE_COST[name] ~= nil }).toEqual({
				name,
				true,
				true,
			})
		end
		for name in SkillLooks.PIECE_LAYER do
			expect({ name, VFX_PIECES[name] == true }).toEqual({ name, true })
		end
		for _, skill in classSkills() do
			if not SkillLooks.LAYER_EXCEPT[skill.id] then
				local layers = SkillLooks.layersOf(SkillVfx[skill.id])
				expect({ skill.id, layers.core, layers.body, layers.trail }).toEqual({ skill.id, true, true, true })
			end
		end
		for id, why in SkillLooks.LAYER_EXCEPT do
			expect({ id, SkillVfx[id] ~= nil, #why > 0 }).toEqual({ id, true, true })
		end
	end)

	it("one cast stays within Config.Vfx.perCast", function()
		local budget = Config.Vfx.perCast
		for _, skill in classSkills() do
			local cost = SkillLooks.costOf(SkillVfx[skill.id])
			expect({
				skill.id,
				cost.emitters <= budget.emitters,
				cost.beams <= budget.beams,
				cost.lights <= budget.lights,
				cost.decals <= budget.decals,
			}).toEqual({ skill.id, true, true, true, true })
		end
	end)

	it("textures: every key exists, every textured piece is in the entry", function()
		for id, entry in SkillVfx do
			for _, key in { entry.sparks or "spark", entry.decal or "cracks", entry.circle or "magicCircle" } do
				expect({ id, key, VfxTextures.get(key :: string) ~= nil }).toEqual({ id, key, true })
			end
			local listed: { [string]: boolean } = {}
			for _, name in SkillLooks.pieces(entry) do
				listed[name] = true
			end
			-- S115: `projectile` is the trail of the entry's projectile
			listed.projectile = entry.projectile ~= nil
			for name, key in entry.tex or {} do
				expect({ id, name, listed[name] == true, VfxTextures.get(key) ~= nil }).toEqual({ id, name, true, true })
			end
		end
	end)

	it("no two skills of one class look alike (silhouette, whole-body flags, pieces)", function()
		local byClass: { [string]: { { id: string, sig: any } } } = {}
		for _, skill in classSkills() do
			byClass[skill.class] = byClass[skill.class] or {}
			table.insert(byClass[skill.class], { id = skill.id, sig = SkillLooks.signature(skill.id) })
		end
		for class, list in byClass do
			for i = 1, #list do
				for j = i + 1, #list do
					local a, b = list[i], list[j]
					local sameBody = a.sig.silhouette == b.sig.silhouette and a.sig.flags == b.sig.flags
					if sameBody and a.sig.effects == b.sig.effects then
						error(`{class}: {a.id} and {b.id} look the same`)
					elseif sameBody then
						print(`  S114 same silhouette ({class}): {a.id} / {b.id}`)
					end
				end
			end
		end
	end)

	it("area skills outline their area (telegraph of the right shape)", function()
		-- reasons a skill shows no outline
		local EXCEPT: { [string]: string } = {
			bladeWhirl = "the whirl itself spins on the radius every wave; a ring would hide it",
			elementalVortex = "the vortex follows the mage every wave; an outline at the start would mislead",
		}
		for _, skill in classSkills() do
			local def: any = skill
			local damage = def.values ~= nil and def.values.dmg ~= nil
			local want: string? = nil
			if skill.type == "cone" then
				want = "cone"
			elseif skill.type == "line" and damage then
				want = "line"
			elseif skill.type == "circleSelf" or skill.type == "circleTarget" or skill.type == "healZone" then
				want = if damage or skill.type == "healZone" then "circle" else nil
			elseif skill.type == "shout" and damage then
				want = "circle"
			end
			if want and not EXCEPT[skill.id] then
				expect({ skill.id, SkillVfx[skill.id].telegraph }).toEqual({ skill.id, want })
			end
		end
	end)

	it("SkillFxWave: a wave only for circleSelf and per-wave circleTarget", function()
		local heal = SkillFxWave.of("heal", nil, 2)
		expect({ heal.wave, heal.target, heal.count }).toEqual({ 1, 2, nil })
		local self2 = SkillFxWave.of("circleSelf", nil, 2)
		expect({ self2.wave, self2.target }).toEqual({ 2, 1 })
		local rain = SkillFxWave.of("circleTarget", false, 4)
		expect({ rain.wave, rain.count, rain.target }).toEqual({ 1, 4, 1 })
		local cataclysm = SkillFxWave.of("circleTarget", true, 3)
		expect({ cataclysm.wave, cataclysm.count }).toEqual({ 3, nil })
		local chain = SkillFxWave.of("heal", nil, 4)
		expect({ chain.wave, chain.target }).toEqual({ 1, 4 })
		for _, kind in { "hot", "shield", "trap", "target" } do
			local w = SkillFxWave.of(kind, nil, 2)
			expect({ kind, w.wave, w.target }).toEqual({ kind, 1, 2 })
		end
		local none = SkillFxWave.of("circleSelf", nil, nil)
		expect({ none.wave, none.target }).toEqual({ 1, 1 })
		local bad = SkillFxWave.of("heal", nil, 0 / 0)
		expect(bad.target).toBe(1)
	end)
end)

-- S144 (DESIGN-18 §6.3): the Hunter pools' new skills: a motion from the shooting rigs with its crossbow variant, a look
-- in three layers, the breakpoint texts and an own sound key; the shots release at the server's time with both rigs.
describe("Hunter pools (S144)", function()
	local Sfx = require("../src/shared/Data/Sfx")
	local NEW = { "heavyBolt", "pinningShot", "windstep", "netShot", "deadlyBolt" }
	local RELEASES: { [string]: number } = { heavyBolt = 0.42, pinningShot = 0.28, netShot = 0.3, deadlyBolt = 0.5 }

	it("motion, look, texts and sound of the five new actives", function()
		for _, id in NEW do
			local motion = SkillMotions.get(id)
			expect({ id, motion ~= nil, SkillVfx[id] ~= nil, Sfx.has(`skill.{id}`) }).toEqual({ id, true, true, true })
			for _, suffix in { "name", "short", "desc", "bp5", "bp5b", "bp10", "bp10b" } do
				local key = `skill.{id}.{suffix}`
				expect({ key, (pl :: any)[key] ~= nil, (en :: any)[key] ~= nil }).toEqual({ key, true, true })
			end
		end
		for _, id in { "toxicTips", "quickReload" } do
			expect({ id, SkillMotions.get(id), SkillVfx[id] }).toEqual({ id, nil, nil })
		end
	end)

	it("the shots: a crossbow variant and a key at the server's release with both rigs", function()
		for id, t in RELEASES do
			local motion = assert(SkillMotions.get(id))
			expect({ id, motion.release }).toEqual({ id, t })
			local crossbow = SkillPose.pick(motion, { weapon = "crossbow" })
			expect({ id, crossbow ~= motion }).toEqual({ id, true })
			for _, m in { motion, crossbow } do
				local near = false
				for _, key in m.keys do
					if math.abs(key.t - t) <= 0.03 then
						near = true
					end
				end
				expect({ id, near }).toEqual({ id, true })
			end
		end
		-- Wind Step: a skip with a landing, no shot
		local step: any = assert(SkillMotions.get("windstep"))
		expect({ step.release, step.land ~= nil, step.hit ~= nil }).toEqual({ nil, true, true })
	end)
end)

describe("Hunter and Mage looks (S115)", function()
	local Sfx = require("../src/shared/Data/Sfx")
	local Timing = require("./fixtures/skill_timing")

	local function keyNear(motion: SkillMotions.Motion, t: number, tolerance: number?): boolean
		for _, key in motion.keys do
			if math.abs(key.t - t) <= (tolerance or 0.03) then
				return true
			end
		end
		return false
	end

	local SHOTS = {
		"aimedShot",
		"doubleShot",
		"venomArrow",
		"volley",
		"piercingArrow",
		"stormArrow",
		"heartseeker",
		"drawBead",
		"arrowRain",
		"drive",
	}

	it("the pin covers every active skill of both classes", function()
		for _, skill in actives() do
			if skill.class == "Hunter" or skill.class == "Mage" then
				expect({ skill.id, Timing.skills[skill.id] ~= nil }).toEqual({ skill.id, true })
			end
		end
	end)

	it("every shot of the Hunter has a crossbow variant; pick chooses it only for the crossbow", function()
		for _, id in SHOTS do
			local motion = assert(SkillMotions.get(id))
			local crossbow = SkillPose.pick(motion, { weapon = "crossbow" })
			expect({ id, crossbow ~= motion }).toEqual({ id, true })
			expect({ id, SkillPose.pick(motion, { weapon = "bow" }) == motion }).toEqual({ id, true })
		end
		local aimed = assert(SkillMotions.get("aimedShot"))
		expect(SkillPose.pick(aimed, { weapon = "crossbow" }) ~= aimed).toBe(true)
		expect(SkillPose.pick(aimed, { weapon = "bow" })).toBe(aimed)
		expect(SkillPose.pick(aimed, nil)).toBe(aimed)
	end)

	it("the arrow leaves at the release: a key at every server shot (bow and crossbow)", function()
		local RELEASES: { [string]: { number } } = {
			aimedShot = { 0.58 },
			doubleShot = { 0.16, 0.31 },
			venomArrow = { 0.36 },
			stormArrow = { 0.58 },
			piercingArrow = { 0.4 },
			volley = { 0.22 },
		}
		for id, times in RELEASES do
			local motion = assert(SkillMotions.get(id))
			for _, m in { motion, SkillPose.pick(motion, { weapon = "crossbow" }) } do
				for _, t in times do
					expect({ id, t, keyNear(m, t) }).toEqual({ id, t, true })
				end
			end
			-- the first release is the server's (the pin)
			expect({ id, motion.release }).toEqual({ id, times[1] })
		end
		-- Heartseeker: the release just after the aim's loop ends (the server shoots then)
		local heart = assert(SkillMotions.get("heartseeker"))
		local loop = assert(heart.loop, "heartseeker loops its draw")
		local released = false
		for _, key in heart.keys do
			if key.t > loop.to and key.t <= loop.to + 0.03 then
				released = true
			end
		end
		expect(released).toBe(true)
		expect({ heart.hit, heart.release, heart.lock }).toEqual({ nil, nil, nil })
	end)

	it("waves of shots: Double Shot 3, Volley 8, Arcane Bolt 2; Evocation walking keeps its feet", function()
		local double = assert(SkillMotions.get("doubleShot"))
		local three = SkillPose.pick(double, { hits = 3 })
		expect(three ~= double).toBe(true)
		expect(keyNear(three, 0.46)).toBe(true)
		expect(keyNear(double, 0.46)).toBe(false)
		local volley = assert(SkillMotions.get("volley"))
		local volleyDef: any = assert(SkillData.get("volley"))
		local function turnEnd(m: SkillMotions.Motion): number
			return m.keys[#m.keys - 1].t
		end
		expect(turnEnd(volley) >= 0.22 + 0.06 * volleyDef.hits - 1e-9).toBe(true)
		local eight = SkillPose.pick(volley, { hits = 8 })
		expect(eight ~= volley and turnEnd(eight) >= 0.7 - 1e-9).toBe(true)
		local bolt = assert(SkillMotions.get("firebolt"))
		local two = SkillPose.pick(bolt, { hits = 2 })
		expect(two ~= bolt and keyNear(two, 0.31)).toBe(true)
		expect(SkillPose.pick(bolt, { hits = 2, weapon = "staff" }) ~= two).toBe(true)
		local evocation = assert(SkillMotions.get("evocation"))
		local walking = SkillPose.pick(evocation, { move = true })
		expect(walking ~= evocation).toBe(true)
		for _, key in walking.keys do
			for _, joint in { "rHip", "lHip", "rKnee", "lKnee", "root" } do
				expect({ key.t, joint, key.pose[joint] }).toEqual({ key.t, joint, nil })
			end
		end
	end)

	it("a staff has its own Arcane Bolt, Fireball and Arcane Discharge", function()
		for _, id in { "firebolt", "fireball", "arcaneDischarge" } do
			local motion = assert(SkillMotions.get(id))
			expect({ id, SkillPose.pick(motion, { weapon = "staff" }) ~= motion }).toEqual({ id, true })
			expect({ id, SkillPose.pick(motion, { weapon = "wand" }) == motion }).toEqual({ id, true })
		end
	end)

	it("looks of the two classes: launch, toss, strike, rim, falling rocks", function()
		for id, entry in SkillVfx do
			local skill = assert(SkillData.get(id))
			local launch = entry.launch
			if launch then
				local valid = launch == "l" or launch == "r" or launch == "both" or launch == "weapon"
				expect({ id, valid, entry.projectile ~= nil }).toEqual({ id, true, true })
			end
			local toss = entry.toss
			if toss then
				local motion = assert(SkillMotions.get(id))
				local hit = motion.hit or 0
				expect({ id, skill.type == "trap", toss.from <= toss.to, toss.to < hit }).toEqual({
					id,
					true,
					true,
					true,
				})
				expect({ id, table.find(entry.impact, "snare") ~= nil }).toEqual({ id, true })
			end
			if entry.strike then
				expect({ id, skill.type == "circleTarget" }).toEqual({ id, true })
			end
			if entry.rim then
				expect({ id, table.find(entry.impact, "arrowRain") ~= nil }).toEqual({ id, true })
			end
			-- the rock falls the event's `d`: its landing waits for it
			if table.find(entry.impact, "meteor") then
				expect({ id, entry.landsAfter == true }).toEqual({ id, true })
			end
		end
		-- every trap of the Trapper lies as a snare and springs with its own pieces and core
		for _, id in { "frostTrap", "venomSnare", "snarefield" } do
			local entry = SkillVfx[id]
			expect({ id, table.find(entry.impact, "snare") ~= nil }).toEqual({ id, true })
			expect({ id, table.find(entry.trigger or {}, "impactFlash") ~= nil }).toEqual({ id, true })
		end
	end)

	it("sounds: an own key for every skill, the phase keys the client plays", function()
		for _, skill in actives() do
			if skill.class == "Hunter" or skill.class == "Mage" then
				expect({ skill.id, Sfx.has("skill." .. skill.id) }).toEqual({ skill.id, true })
			end
		end
		for _, key in
			{
				"skill.aimedShot.cast",
				"skill.stormArrow.cast",
				"skill.heartseeker.cast",
				"skill.meteor.cast",
				"skill.meteorStorm.cast",
				"skill.cataclysm.cast",
				"skill.frostTrap.trigger",
				"skill.venomSnare.trigger",
				"skill.snarefield.trigger",
				"skill.falcon.strike",
				"skill.firewall.wave",
				"skill.meteorStorm.wave",
				"skill.cataclysm.wave",
			}
		do
			expect({ key, Sfx.has(key) }).toEqual({ key, true })
		end
	end)
end)

-- S145 (DESIGN-18 §6.4): the Cleric pools' new skills: a motion from the Cleric's S114 motions (a variant), a look in
-- three layers, the breakpoint texts and an own sound key; the passives have neither motion nor look.
describe("Cleric pools (S145)", function()
	local Sfx = require("../src/shared/Data/Sfx")
	local NEW = { "lightRay", "blindingLight", "miracle", "consecrate", "holyChains", "holyNova", "rebuke" }

	it("motion, look, texts and sound of the seven new actives", function()
		for _, id in NEW do
			local motion = SkillMotions.get(id)
			expect({ id, motion ~= nil, SkillVfx[id] ~= nil, Sfx.has(`skill.{id}`) }).toEqual({ id, true, true, true })
			for _, suffix in { "name", "short", "desc", "bp5", "bp5b", "bp10", "bp10b" } do
				local key = `skill.{id}.{suffix}`
				expect({ key, (pl :: any)[key] ~= nil, (en :: any)[key] ~= nil }).toEqual({ key, true, true })
			end
		end
		for _, id in { "grace", "guidingLight", "zeal" } do
			expect({ id, SkillMotions.get(id), SkillVfx[id] }).toEqual({ id, nil, nil })
		end
	end)

	it("Light Ray leaves the hand at its release; Miracle holds the prayer over its cast time", function()
		local ray: any = assert(SkillMotions.get("lightRay"))
		expect(ray.release ~= nil).toBe(true)
		local miracle: any = assert(SkillMotions.get("miracle"))
		expect(miracle.loop ~= nil).toBe(true)
	end)
end)

return nil
