--!strict
-- S22: procedural attack poses (Data/AttackMotions, Logic/AttackPose).

local AttackMotions = require("../src/shared/Data/AttackMotions")
local AttackPose = require("../src/shared/Logic/AttackPose")
local WeaponLooks = require("../src/shared/Data/WeaponLooks")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

local function names(): { AttackPose.MotionName }
	local out = {}
	for name in AttackMotions.motions do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

local function maxDiff(a: AttackPose.Pose, b: AttackPose.Pose): number
	local worst = 0
	for _, joint in AttackMotions.JOINTS do
		for i = 1, 3 do
			worst = math.max(worst, math.abs(a[joint][i] - b[joint][i]))
		end
	end
	return worst
end

local function isRest(pose: AttackPose.Pose): boolean
	for _, joint in AttackMotions.JOINTS do
		for i = 1, 3 do
			if math.abs(pose[joint][i]) > 1e-6 then
				return false
			end
		end
	end
	return true
end

describe("AttackPose", function()
	it("gives every weapon a motion", function()
		for itemType in WeaponLooks.list do
			if not AttackMotions.offhand[itemType] then
				expect(AttackMotions.byWeapon[itemType] ~= nil).toBe(true)
			end
		end
		expect(AttackPose.motionFor(nil)).toBe("unarmed")
		expect(AttackPose.motionFor("no_such_weapon")).toBe("unarmed")
		expect(AttackPose.motionFor("longbow")).toBe("bow")
		expect(AttackPose.motionFor("heavycrossbow")).toBe("crossbow")
	end)

	it("starts and ends at rest", function()
		for _, name in names() do
			local timing = AttackPose.timing(name)
			local first, _, w0 = AttackPose.sample(name, 0, nil)
			expect(isRest(first)).toBe(true)
			expect(w0).toBe(0)
			local last, phase, w1 = AttackPose.sample(name, timing.total, nil)
			expect(isRest(last)).toBe(true)
			expect(phase).toBe("rest")
			expect(w1).toBe(0)
			local almost = AttackPose.sample(name, timing.total - 1e-4, nil)
			expect(maxDiff(almost, last) < 0.5).toBe(true)
		end
	end)

	it("moves continuously (no jumps between frames)", function()
		for _, name in names() do
			local timing = AttackPose.timing(name)
			local dt = 1 / 240
			local previous = AttackPose.sample(name, 0, nil)
			local t = dt
			while t <= timing.total + dt do
				local pose = AttackPose.sample(name, t, nil)
				-- at most ~16 degrees per 1/240 s (a very fast cut is ~200 degrees in 0.1 s)
				expect(maxDiff(previous, pose) < 16).toBe(true)
				previous = pose
				t += dt
			end
		end
	end)

	it("keeps every key pose within the joint limits", function()
		for _, name in names() do
			local m = AttackMotions.motions[name]
			for _, pose in { m.poses.windup, m.poses.strike } do
				for joint, a in pose do
					local limit = AttackMotions.LIMITS[joint]
					expect(math.abs(a[1]) <= limit and math.abs(a[2]) <= 180 and math.abs(a[3]) <= 90).toBe(true)
				end
			end
		end
	end)

	it("holds the bow in the left hand and draws with the right", function()
		local bow = AttackMotions.motions.bow
		expect(bow.ranged).toBe(true)
		expect(bow.poses.windup.lShoulder[1] >= 80).toBe(true) -- left arm up towards the target
		expect(bow.poses.windup.lElbow[1] <= 10).toBe(true) -- straight
		expect(bow.poses.windup.rElbow[1] >= 100).toBe(true) -- right hand draws to the cheek
		expect(WeaponLooks.list.bow.hand).toBe("left")
		-- the shot leaves at the end of the draw
		local timing = AttackPose.timing("bow")
		expect(timing.hitAt).toBeNear(timing.windup, 1e-9)
	end)

	it("raises the crossbow without drawing", function()
		local crossbow = AttackMotions.motions.crossbow
		expect(crossbow.poses.windup.lShoulder[1] >= 80).toBe(true)
		expect(math.abs(crossbow.poses.strike.rElbow[1] - crossbow.poses.windup.rElbow[1]) <= 15).toBe(true)
		expect(WeaponLooks.list.crossbow.hand).toBe("left")
	end)

	it("lands the blow during the strike and squeezes into short intervals", function()
		for _, name in names() do
			local timing = AttackPose.timing(name)
			expect(timing.hitAt >= timing.windup - 1e-9).toBe(true)
			expect(timing.hitAt <= timing.windup + timing.strike + 1e-9).toBe(true)
			expect(timing.hitAt <= 0.25).toBe(true) -- the visible hit stays close to the server's damage
			local fast = AttackPose.timing(name, timing.total / 2)
			expect(fast.total).toBeNear(timing.total / 2, 1e-9)
			local tiny = AttackPose.timing(name, 0.01)
			expect(tiny.total).toBeNear(timing.total * 0.4, 1e-9)
		end
	end)

	it("blends from an interrupted attack without a jump", function()
		local timing = AttackPose.timing("slash1h")
		local mid = AttackPose.sample("slash1h", timing.windup + timing.strike * 0.5, nil)
		local start, _, weight = AttackPose.sample("thrust", 0, nil, mid)
		expect(maxDiff(start, mid) < 1e-6).toBe(true)
		expect(weight).toBe(1)
	end)

	it("hit delay: melee at the blow, ranged at the release plus the flight (FIX 2026-10-09)", function()
		local sword = AttackPose.timing(AttackPose.motionFor("sword1h"))
		expect(AttackPose.hitDelay("sword1h", 5, false)).toBeNear(sword.hitAt)
		local bow = AttackPose.timing(AttackPose.motionFor("bow"))
		expect(AttackPose.hitDelay("bow", 33, true)).toBeNear(bow.hitAt + AttackPose.flightTime("arrow", 33))
		expect(AttackPose.hitDelay("bow", 200, true)).toBeNear(bow.hitAt + 0.4)
		expect(AttackPose.projectile("slash1h")).toBeNil()
		expect(AttackPose.projectile("crossbow")).toBe("bolt")
	end)

	it("real weapon models belong to existing weapons and fit the hand", function()
		local Items = require("../src/shared/Data/Items")
		for defId, asset in WeaponLooks.assets do
			local def = Items.get(defId) :: any
			expect(def ~= nil and WeaponLooks.get(def.type) ~= nil).toBe(true)
			expect(asset.length > 0 and asset.grip >= 0 and asset.grip < 1).toBe(true)
		end
	end)
end)
