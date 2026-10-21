--!strict
-- W30: the procedural pose of the owner's NPC models (Logic/NpcPose): bone names, the turn from bone directions, the
-- relaxed stance from any rest pose and bone orientation, facing and the motion frames.

local NpcPose = require("../src/shared/Logic/NpcPose")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local function near(a: { number }, b: { number }, eps: number?)
	for i = 1, #b do
		expect(a[i]).toBeNear(b[i], eps or 1e-6)
	end
end

local function len(v: { number }): number
	return math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
end

describe("NpcPose.boneKey", function()
	it("reads Mixamo names with and without the prefix", function()
		expect(NpcPose.boneKey("mixamorig:LeftArm")).toBe("LeftArm")
		expect(NpcPose.boneKey("mixamorig1:RightForeArm")).toBe("RightForeArm")
		expect(NpcPose.boneKey("mixamorig_Spine2")).toBe("Spine2")
		expect(NpcPose.boneKey("Head")).toBe("Head")
		expect(NpcPose.boneKey("rightarm")).toBe("RightArm")
	end)
	it("ignores bones the layer does not drive", function()
		expect(NpcPose.boneKey("mixamorig:LeftHandIndex1")).toBe(nil)
		expect(NpcPose.boneKey("Root")).toBe(nil)
	end)
end)

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

describe("NpcPose stance targets", function()
	it("hangs the arms down, a little out and forward", function()
		local right = NpcPose.armTarget(1)
		local left = NpcPose.armTarget(-1)
		expect(len(right)).toBeNear(1)
		expect(right[2] < -0.95).toBe(true)
		expect(right[1] > 0).toBe(true)
		expect(left[1] < 0).toBe(true)
		expect(right[3] < 0).toBe(true) -- front is -Z
	end)
	it("bends the forearm forward by the elbow angle", function()
		local arm, fore = NpcPose.armTarget(1), NpcPose.foreTarget(1)
		local d = arm[1] * fore[1] + arm[2] * fore[2] + arm[3] * fore[3]
		-- about the side axis: a little less than the angle, the arm hangs slightly out
		expect(math.acos(d)).toBeNear(NpcPose.ELBOW, 0.02)
		expect(fore[3] < arm[3]).toBe(true)
	end)
	it("reads the ArmSpread attribute within bounds", function()
		expect(NpcPose.spread(20)).toBeNear(math.rad(20))
		expect(NpcPose.spread(90)).toBe(nil)
		expect(NpcPose.spread("wide")).toBe(nil)
	end)
end)

-- A rest frame of a bone with an arbitrary orientation (the export's own axes).
local function oddRest(): { number }
	return NpcPose.mul(NpcPose.axisAngle({ 0, 0, 1 }, 1.1), NpcPose.axisAngle({ 0.6, 0, 0.8 }, -2.3))
end

describe("NpcPose.armPose", function()
	it("brings a T-pose arm and forearm onto their targets", function()
		for _, side in { 1, -1 } do
			local pose = NpcPose.armPose(side, { side * 1, 0, 0 }, { side * 1, 0, 0 })
			near(NpcPose.apply(pose.arm, { side, 0, 0 }), NpcPose.armTarget(side))
			-- the forearm: carried by the arm, then its own turn
			local fore = NpcPose.apply(pose.fore, NpcPose.apply(pose.arm, { side, 0, 0 }))
			near(fore, NpcPose.foreTarget(side))
		end
	end)
	it("works from an A-pose with a bent elbow too", function()
		local armDir, foreDir = { 0.7, -0.7, 0.1 }, { 0.5, -0.6, -0.4 }
		local pose = NpcPose.armPose(1, armDir, foreDir)
		near(NpcPose.apply(pose.arm, NpcPose.unit(armDir) :: { number }), NpcPose.armTarget(1))
		local fore = NpcPose.apply(pose.fore, NpcPose.apply(pose.arm, NpcPose.unit(foreDir) :: { number }))
		near(fore, NpcPose.foreTarget(1))
	end)
	it("poses the same whatever the bone's own axes (Transform = rest^-1 C rest)", function()
		-- chain: upper arm then forearm, both with odd rest rotations; the world direction of the forearm's length
		-- after the Transforms must reach the target
		local pose = NpcPose.armPose(1, { 1, 0, 0 }, { 1, 0, 0 })
		local restArm, restFore = oddRest(), NpcPose.mul(oddRest(), NpcPose.axisAngle({ 0, 1, 0 }, 0.7))
		local tArm = NpcPose.toLocal(restArm, NpcPose.armTurn(pose))
		local tFore = NpcPose.toLocal(restFore, NpcPose.foreTurn(pose))
		-- posed world rotations: arm = restArm * tArm; forearm = (arm delta) * restFore * tFore
		local armWorld = NpcPose.mul(restArm, tArm)
		local armDelta = NpcPose.mul(armWorld, NpcPose.transpose(restArm))
		local foreWorld = NpcPose.mul(NpcPose.mul(armDelta, restFore), tFore)
		-- the bone's length axis in its own frame, whichever it is: the rest direction taken into the bone
		local armAxis = NpcPose.apply(NpcPose.transpose(restArm), { 1, 0, 0 })
		local foreAxis = NpcPose.apply(NpcPose.transpose(restFore), { 1, 0, 0 })
		near(NpcPose.apply(armWorld, armAxis), NpcPose.armTarget(1))
		near(NpcPose.apply(foreWorld, foreAxis), NpcPose.foreTarget(1))
	end)
	it("bends the elbow more about the posed arm's hinge", function()
		local pose = NpcPose.armPose(1, { 1, 0, 0 }, nil)
		local turn = NpcPose.foreTurn(pose, 0.5)
		local fore = NpcPose.apply(pose.arm, NpcPose.apply(turn, { 1, 0, 0 }))
		local arm = NpcPose.armTarget(1)
		local d = arm[1] * fore[1] + arm[2] * fore[2] + arm[3] * fore[3]
		expect(math.acos(d)).toBeNear(NpcPose.ELBOW + 0.5, 0.02)
	end)
	it("raises the arm forward with a positive pitch gesture", function()
		local pose = NpcPose.armPose(1, { 1, 0, 0 }, nil)
		local dir = NpcPose.apply(NpcPose.armTurn(pose, { rx = 0.6, ry = 0, rz = 0 }), { 1, 0, 0 })
		expect(dir[3] < NpcPose.armTarget(1)[3] - 0.3).toBe(true)
	end)
end)

describe("NpcPose facing", function()
	it("turns the front toward the player", function()
		expect(NpcPose.faceYaw(0, -5)).toBeNear(0)
		local yaw = NpcPose.faceYaw(4, 0) -- player on the right
		near(NpcPose.apply(NpcPose.euler({ rx = 0, ry = yaw, rz = 0 }), { 0, 0, -1 }), { 1, 0, 0 })
		expect(math.abs(NpcPose.faceYaw(0, 5))).toBeNear(math.pi)
	end)
	it("turns at a limited rate the short way round", function()
		expect(NpcPose.turnToward(0, 1, 2, 0.1)).toBeNear(0.2)
		expect(NpcPose.turnToward(0.95, 1, 2, 0.1)).toBeNear(1)
		expect(NpcPose.turnToward(3, -3, 2, 0.1)).toBeNear(3.2)
	end)
end)

describe("NpcPose.frame", function()
	it("breathes and shifts weight in the idle, small angles only", function()
		local a = NpcPose.frame(1, 0.3, "idle", 0, 0)
		local b = NpcPose.frame(2.5, 0.3, "idle", 0, 0)
		expect(a.Spine2 ~= nil and a.Hips ~= nil).toBe(true)
		expect(a.Spine2.rx ~= b.Spine2.rx).toBe(true)
		for t = 0, 30, 0.37 do
			local f = NpcPose.frame(t, 0.3, "idle", 0, 0)
			expect(math.abs(f.Spine2.rx) < 0.05).toBe(true)
			expect(math.abs(f.Hips.rz) < 0.05).toBe(true)
			expect(math.abs(f.Head.ry) <= NpcPose.LOOK_YAW * 0.6 + 1e-9).toBe(true)
		end
	end)
	it("looks around smoothly and differently per NPC", function()
		local prev = NpcPose.look(0, 0.2)
		local moved = false
		for t = 0.05, 40, 0.05 do
			local yaw = NpcPose.look(t, 0.2)
			expect(math.abs(yaw - prev) < 0.2).toBe(true)
			moved = moved or math.abs(yaw) > 0.05
			prev = yaw
		end
		expect(moved).toBe(true)
		local same = true
		for t = 0, 40, 1 do
			same = same and NpcPose.look(t, 0.2) == NpcPose.look(t, 0.7)
		end
		expect(same).toBe(false)
	end)
	it("gestures and nods while talking, faded by the blend", function()
		local any, nod = false, false
		for t = 0, 12, 0.1 do
			local f = NpcPose.frame(t, 0.5, "talk", 1, 0)
			any = any or (f._bendR ~= nil and f._bendR.rx > 0.3) or (f._bendL ~= nil and f._bendL.rx > 0.3)
			nod = nod or (f.Head ~= nil and f.Head.rx < -0.1)
		end
		expect(any).toBe(true)
		expect(nod).toBe(true)
		local off = NpcPose.frame(0.85, 0.5, "talk", 0, 0)
		expect(off._bendR).toBe(nil)
		expect(off._bendL).toBe(nil)
	end)
	it("turns the whole body by the facing on the hips", function()
		local f = NpcPose.frame(3, 0.1, "talk", 1, 1.2)
		expect(f.Hips.ry).toBeNear(1.2)
	end)
	it("raises and drops the hammer arm once a beat", function()
		local high, low = -math.huge, math.huge
		for t = 0, NpcPose.HAMMER_BEAT, 0.02 do
			local rx = NpcPose.frame(t, 0, "hammer", 0, 0).RightArm.rx
			high, low = math.max(high, rx), math.min(low, rx)
		end
		expect(high - low > 1).toBe(true)
	end)
end)

-- W31 (owner 2026-10-21: the NPCs without a model stood frozen): the R15 figures move through their Motor6Ds.
describe("NpcPose on an R15 figure", function()
	it("drives every skeleton key through some R15 joint", function()
		local carried: { [string]: boolean } = {}
		for _, key in NpcPose.R15_JOINTS do
			carried[key] = true
			expect({ key, table.find(NpcPose.KEYS, key) ~= nil }).toEqual({ key, true })
		end
		for _, key in NpcPose.KEYS do
			local into = NpcPose.FOLD[key] or key
			expect({ key, carried[into] == true }).toEqual({ key, true })
		end
	end)
	it("folds the chest, the head and the clavicles onto the joints that carry them", function()
		local frame = NpcPose.frame(2.3, 0.4, "talk", 1, 0.5)
		local folded = NpcPose.fold(frame)
		local function sum(keys: { string }, axis: string): number
			local total = 0
			for _, key in keys do
				local e = frame[key]
				total += if e then (e :: any)[axis] else 0
			end
			return total
		end
		for _, axis in { "rx", "ry", "rz" } do
			expect((folded.Spine :: any)[axis]).toBeNear(sum({ "Spine", "Spine1", "Spine2" }, axis))
			expect((folded.Neck :: any)[axis]).toBeNear(sum({ "Neck", "Head" }, axis))
			expect((folded.RightArm :: any)[axis]).toBeNear(sum({ "RightShoulder", "RightArm" }, axis))
		end
		expect(folded.Spine1).toBe(nil)
		expect(folded.Head).toBe(nil)
		expect(folded.RightShoulder).toBe(nil)
		expect(folded.Hips.ry).toBeNear(frame.Hips.ry)
		-- the elbow bends stay, the frame given is not changed
		if frame._bendR then
			expect(folded._bendR.rx).toBeNear(frame._bendR.rx)
		end
		expect(frame.Spine1 ~= nil).toBe(true)
	end)
	it("hangs R15 arms close to the body with a light elbow bend", function()
		-- the base body's arm straight down from the shoulder, the forearm on from it
		local pose = NpcPose.armPose(1, { 0, -1.2, 0 }, { 0, -1.1, 0 }, NpcPose.R15_SPREAD, NpcPose.R15_ELBOW)
		local arm = NpcPose.apply(pose.arm, { 0, -1, 0 })
		near(arm, NpcPose.armTarget(1, NpcPose.R15_SPREAD))
		expect(arm[1] > 0 and arm[1] < math.sin(math.rad(6))).toBe(true)
		-- the stance turn of the shoulder is small: no T-pose to undo
		local tilt = math.deg(math.acos(math.clamp(-arm[2], -1, 1)))
		expect(tilt < 8).toBe(true)
	end)
end)
