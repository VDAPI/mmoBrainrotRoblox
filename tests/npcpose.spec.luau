--!strict
-- The rotation math every procedural rig shares (Logic/NpcPose; 2026-10-26 the NPC motion itself moved onto the
-- biped template, tests/npcmotion.spec.luau): turns between directions, about an axis and into a joint's own frame;
-- the R15 joints an NPC figure without a model is posed through; the seeded hash.

local NpcPose = require("../src/shared/Logic/NpcPose")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local function near(a: { number }, b: { number }, eps: number?)
	for i = 1, #b do
		expect(a[i]).toBeNear(b[i], eps or 1e-6)
	end
end

describe("NpcPose.fromTo", function()
	it("takes one direction onto another", function()
		local m = NpcPose.fromTo({ 1, 0, 0 }, { 0, -1, 0 })
		near(NpcPose.apply(m, { 1, 0, 0 }), { 0, -1, 0 })
		-- the turn is about the front axis: the front stays
		near(NpcPose.apply(m, { 0, 0, -1 }), { 0, 0, -1 })
	end)
	it("works for unnormalized and opposite directions", function()
		near(NpcPose.apply(NpcPose.fromTo({ 3, 4, 0 }, { 0, 0, 2 }), { 0.6, 0.8, 0 }), { 0, 0, 1 })
		near(NpcPose.apply(NpcPose.fromTo({ 0, 1, 0 }, { 0, -1, 0 }), { 0, 1, 0 }), { 0, -1, 0 })
	end)
	it("is the identity for equal or zero directions", function()
		near(NpcPose.fromTo({ 0, 1, 0 }, { 0, 1, 0 }), NpcPose.IDENTITY)
		near(NpcPose.fromTo({ 0, 0, 0 }, { 0, 1, 0 }), NpcPose.IDENTITY)
	end)
	it("gives a proper rotation", function()
		local m = NpcPose.fromTo({ 0.3, -0.2, 0.9 }, { -0.5, 0.1, 0.4 })
		near(NpcPose.mul(m, NpcPose.transpose(m)), NpcPose.IDENTITY, 1e-9)
	end)
end)

describe("NpcPose.axisAngle and toLocal", function()
	it("turns right-handed about its axis", function()
		-- a quarter turn about up takes the front (-Z) to the left (-X)
		near(NpcPose.apply(NpcPose.axisAngle({ 0, 1, 0 }, math.pi / 2), { 0, 0, -1 }), { -1, 0, 0 })
		near(NpcPose.apply(NpcPose.axisAngle({ 1, 0, 0 }, math.pi / 2), { 0, 1, 0 }), { 0, 0, 1 })
		near(NpcPose.axisAngle({ 0, 0, 1 }, 0), NpcPose.IDENTITY)
	end)
	it("puts a turn in root axes into the joint's own frame", function()
		local rest = NpcPose.axisAngle({ 0, 0, 1 }, math.pi / 2) -- the bone's own X lies along root up
		local c = NpcPose.axisAngle({ 0, 1, 0 }, 0.4) -- a turn about root up
		local l = NpcPose.toLocal(rest, c)
		-- about the bone's own X by the same angle
		near(l, NpcPose.axisAngle({ 1, 0, 0 }, 0.4), 1e-9)
		-- rest * local = c * rest
		near(NpcPose.mul(rest, l), NpcPose.mul(c, rest), 1e-9)
	end)
	it("normalizes or refuses a zero vector", function()
		near(NpcPose.unit({ 0, 3, 4 }) :: { number }, { 0, 0.6, 0.8 })
		expect(NpcPose.unit({ 0, 0, 0 })).toBeNil()
	end)
end)

describe("NpcPose.hash01", function()
	it("is deterministic, in 0..1 and differs by seed", function()
		local differ = 0
		for n = 1, 200 do
			local a = NpcPose.hash01(n, 0.37)
			expect(a >= 0 and a < 1).toBe(true)
			expect(NpcPose.hash01(n, 0.37)).toBe(a)
			if NpcPose.hash01(n, 0.81) ~= a then
				differ += 1
			end
		end
		expect(differ > 190).toBe(true)
	end)
end)

describe("NpcPose on an R15 figure", function()
	it("names a skeleton key and a parent key for each of the 15 joints", function()
		local count = 0
		for joint, key in NpcPose.R15_JOINTS do
			count += 1
			expect(type(key)).toBe("string")
			if joint ~= "Root" then
				expect({ joint, NpcPose.R15_PARENT[joint] ~= nil }).toEqual({ joint, true })
			end
		end
		expect(count).toBe(15)
		-- a joint's parent key is the key of the joint that carries its Part0
		local keys: { [string]: boolean } = {}
		for _, key in NpcPose.R15_JOINTS do
			keys[key] = true
		end
		for joint, parent in NpcPose.R15_PARENT do
			expect({ joint, keys[parent] == true }).toEqual({ joint, true })
		end
	end)
end)
