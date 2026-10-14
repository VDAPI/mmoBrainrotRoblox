--!strict
-- S22: procedural attack poses (Data/AttackMotions, Logic/AttackPose). S113: the server's hit time pinned
-- (SERVER_HIT), combo steps, contact and follow-through poses (DESIGN-16 §2 as assertions), hit reactions, sounds,
-- hit sparks and trails.

local AttackMotions = require("../src/shared/Data/AttackMotions")
local AttackPose = require("../src/shared/Logic/AttackPose")
local HitFx = require("../src/shared/Data/HitFx")
local Sfx = require("../src/shared/Data/Sfx")
local VfxTextures = require("../src/shared/Data/VfxTextures")
local WeaponLooks = require("../src/shared/Data/WeaponLooks")
local Test = require("./Test")

local describe, it, expect = Test.describe, Test.it, Test.expect

type Pose = AttackPose.Pose

local function names(): { AttackPose.MotionName }
	local out = {}
	for name in AttackMotions.motions do
		table.insert(out, name)
	end
	table.sort(out)
	return out
end

-- Every (motion, step) pair in a fixed order.
local function steps(): { { name: string, step: number } }
	local out = {}
	for _, name in names() do
		for i in AttackMotions.motions[name].steps do
			table.insert(out, { name = name, step = i })
		end
	end
	return out
end

local function maxDiff(a: Pose, b: Pose): number
	local worst = 0
	for _, joint in AttackMotions.JOINTS do
		for i = 1, 3 do
			worst = math.max(worst, math.abs(a[joint][i] - b[joint][i]))
		end
	end
	return worst
end

local function isRest(pose: Pose): boolean
	for _, joint in AttackMotions.JOINTS do
		for i = 1, 3 do
			if math.abs(pose[joint][i]) > 1e-6 then
				return false
			end
		end
	end
	return true
end

local ZERO = { 0, 0, 0 }

local function of(pose: Pose?, joint: string): { number }
	return (pose and pose[joint]) or ZERO
end

local function dist(a: { number }, b: { number }): number
	return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2 + (a[3] - b[3]) ^ 2)
end

-- The main joint of a step: the shoulder that moves most between the windup and the strike.
local function mainJoint(step: AttackMotions.Step): string
	local r = dist(of(step.poses.windup, "rShoulder"), of(step.poses.strike, "rShoulder"))
	local l = dist(of(step.poses.windup, "lShoulder"), of(step.poses.strike, "lShoulder"))
	return if l > r then "lShoulder" else "rShoulder"
end

-- The axis (1..3) of the main joint that changes most in the strike.
local function mainAxis(step: AttackMotions.Step, joint: string): number
	local a, b = of(step.poses.windup, joint), of(step.poses.strike, joint)
	local best, size = 1, -1
	for i = 1, 3 do
		if math.abs(b[i] - a[i]) > size then
			best, size = i, math.abs(b[i] - a[i])
		end
	end
	return best
end

-- 3x3 rotation matrices (rows), CFrame.fromEulerAnglesYXZ(x, y, z) = Ry * Rx * Rz.
type Mat = { { number } }
local function mul(a: Mat, b: Mat): Mat
	local out: Mat = { {}, {}, {} }
	for r = 1, 3 do
		for c = 1, 3 do
			out[r][c] = a[r][1] * b[1][c] + a[r][2] * b[2][c] + a[r][3] * b[3][c]
		end
	end
	return out
end
local function apply(m: Mat, v: { number }): { number }
	return {
		m[1][1] * v[1] + m[1][2] * v[2] + m[1][3] * v[3],
		m[2][1] * v[1] + m[2][2] * v[2] + m[2][3] * v[3],
		m[3][1] * v[1] + m[3][2] * v[2] + m[3][3] * v[3],
	}
end
local function euler(a: { number }): Mat
	local x, y, z = math.rad(a[1]), math.rad(a[2]), math.rad(a[3])
	local rx = { { 1, 0, 0 }, { 0, math.cos(x), -math.sin(x) }, { 0, math.sin(x), math.cos(x) } }
	local ry = { { math.cos(y), 0, math.sin(y) }, { 0, 1, 0 }, { -math.sin(y), 0, math.cos(y) } }
	local rz = { { math.cos(z), -math.sin(z), 0 }, { math.sin(z), math.cos(z), 0 }, { 0, 0, 1 } }
	return mul(mul(ry, rx), rz)
end

-- The hand in the torso frame (shoulder at the origin, upper arm and forearm 1.0 each, hanging along -Y at rest).
local function hand(pose: Pose, shoulder: string): { number }
	local elbow = if shoulder == "rShoulder" then "rElbow" else "lElbow"
	local s = euler(of(pose, shoulder))
	local e = mul(s, euler(of(pose, elbow)))
	local down = { 0, -1, 0 }
	local a, b = apply(s, down), apply(e, down)
	return { a[1] + b[1], a[2] + b[2], a[3] + b[3] }
end

-- Distance of p from the segment a-b.
local function fromSegment(p: { number }, a: { number }, b: { number }): number
	local ab = { b[1] - a[1], b[2] - a[2], b[3] - a[3] }
	local ap = { p[1] - a[1], p[2] - a[2], p[3] - a[3] }
	local len2 = ab[1] ^ 2 + ab[2] ^ 2 + ab[3] ^ 2
	local u = if len2 > 0 then math.clamp((ap[1] * ab[1] + ap[2] * ab[2] + ap[3] * ab[3]) / len2, 0, 1) else 0
	return dist(p, { a[1] + ab[1] * u, a[2] + ab[2] * u, a[3] + ab[3] * u })
end

-- AttackPose.hitDelay before S113 (A2 snapshot of 4d533e2..eef2459): weapon type -> per distance
-- { 0, 3, 7, 12, 20, 35, 60 } studs { melee, ranged }.
local DISTANCES = { 0, 3, 7, 12, 20, 35, 60 }
local HIT_DELAY_BEFORE: { [string]: { { number } } } = {
	axe1h = {
		{ 0.18, 0.18 },
		{ 0.18, 0.18 },
		{ 0.18, 0.18 },
		{ 0.18, 0.18 },
		{ 0.18, 0.18 },
		{ 0.18, 0.18 },
		{ 0.18, 0.18 },
	},
	axe2h = {
		{ 0.2115, 0.2115 },
		{ 0.2115, 0.2115 },
		{ 0.2115, 0.2115 },
		{ 0.2115, 0.2115 },
		{ 0.2115, 0.2115 },
		{ 0.2115, 0.2115 },
		{ 0.2115, 0.2115 },
	},
	bow = {
		{ 0.2, 0.26 },
		{ 0.2, 0.26 },
		{ 0.2, 0.263636363636 },
		{ 0.2, 0.309090909091 },
		{ 0.2, 0.381818181818 },
		{ 0.2, 0.518181818182 },
		{ 0.2, 0.6 },
	},
	crossbow = {
		{ 0.12, 0.18 },
		{ 0.12, 0.18 },
		{ 0.12, 0.18 },
		{ 0.12, 0.2 },
		{ 0.12, 0.253333333333 },
		{ 0.12, 0.353333333333 },
		{ 0.12, 0.52 },
	},
	flail1h = {
		{ 0.235, 0.235 },
		{ 0.235, 0.235 },
		{ 0.235, 0.235 },
		{ 0.235, 0.235 },
		{ 0.235, 0.235 },
		{ 0.235, 0.235 },
		{ 0.235, 0.235 },
	},
	hammer2h = {
		{ 0.235, 0.235 },
		{ 0.235, 0.235 },
		{ 0.235, 0.235 },
		{ 0.235, 0.235 },
		{ 0.235, 0.235 },
		{ 0.235, 0.235 },
		{ 0.235, 0.235 },
	},
	heavycrossbow = {
		{ 0.12, 0.18 },
		{ 0.12, 0.18 },
		{ 0.12, 0.18 },
		{ 0.12, 0.2 },
		{ 0.12, 0.253333333333 },
		{ 0.12, 0.353333333333 },
		{ 0.12, 0.52 },
	},
	holystaff = {
		{ 0.235, 0.235 },
		{ 0.235, 0.235 },
		{ 0.235, 0.235 },
		{ 0.235, 0.235 },
		{ 0.235, 0.235 },
		{ 0.235, 0.235 },
		{ 0.235, 0.235 },
	},
	longbow = {
		{ 0.2, 0.26 },
		{ 0.2, 0.26 },
		{ 0.2, 0.263636363636 },
		{ 0.2, 0.309090909091 },
		{ 0.2, 0.381818181818 },
		{ 0.2, 0.518181818182 },
		{ 0.2, 0.6 },
	},
	mace1h = {
		{ 0.235, 0.235 },
		{ 0.235, 0.235 },
		{ 0.235, 0.235 },
		{ 0.235, 0.235 },
		{ 0.235, 0.235 },
		{ 0.235, 0.235 },
		{ 0.235, 0.235 },
	},
	runestaff = {
		{ 0.167, 0.227 },
		{ 0.167, 0.227 },
		{ 0.167, 0.249352941176 },
		{ 0.167, 0.308176470588 },
		{ 0.167, 0.402294117647 },
		{ 0.167, 0.567 },
		{ 0.167, 0.567 },
	},
	saber1h = {
		{ 0.18, 0.18 },
		{ 0.18, 0.18 },
		{ 0.18, 0.18 },
		{ 0.18, 0.18 },
		{ 0.18, 0.18 },
		{ 0.18, 0.18 },
		{ 0.18, 0.18 },
	},
	scepter = {
		{ 0.18, 0.18 },
		{ 0.18, 0.18 },
		{ 0.18, 0.18 },
		{ 0.18, 0.18 },
		{ 0.18, 0.18 },
		{ 0.18, 0.18 },
		{ 0.18, 0.18 },
	},
	shortbow = {
		{ 0.2, 0.26 },
		{ 0.2, 0.26 },
		{ 0.2, 0.263636363636 },
		{ 0.2, 0.309090909091 },
		{ 0.2, 0.381818181818 },
		{ 0.2, 0.518181818182 },
		{ 0.2, 0.6 },
	},
	spear2h = {
		{ 0.183, 0.183 },
		{ 0.183, 0.183 },
		{ 0.183, 0.183 },
		{ 0.183, 0.183 },
		{ 0.183, 0.183 },
		{ 0.183, 0.183 },
		{ 0.183, 0.183 },
	},
	staff = {
		{ 0.167, 0.227 },
		{ 0.167, 0.227 },
		{ 0.167, 0.249352941176 },
		{ 0.167, 0.308176470588 },
		{ 0.167, 0.402294117647 },
		{ 0.167, 0.567 },
		{ 0.167, 0.567 },
	},
	sword1h = {
		{ 0.18, 0.18 },
		{ 0.18, 0.18 },
		{ 0.18, 0.18 },
		{ 0.18, 0.18 },
		{ 0.18, 0.18 },
		{ 0.18, 0.18 },
		{ 0.18, 0.18 },
	},
	sword2h = {
		{ 0.2115, 0.2115 },
		{ 0.2115, 0.2115 },
		{ 0.2115, 0.2115 },
		{ 0.2115, 0.2115 },
		{ 0.2115, 0.2115 },
		{ 0.2115, 0.2115 },
		{ 0.2115, 0.2115 },
	},
	wand = {
		{ 0.136, 0.196 },
		{ 0.136, 0.196 },
		{ 0.136, 0.218352941176 },
		{ 0.136, 0.277176470588 },
		{ 0.136, 0.371294117647 },
		{ 0.136, 0.536 },
		{ 0.136, 0.536 },
	},
	unarmed = {
		{ 0.156, 0.156 },
		{ 0.156, 0.156 },
		{ 0.156, 0.156 },
		{ 0.156, 0.156 },
		{ 0.156, 0.156 },
		{ 0.156, 0.156 },
		{ 0.156, 0.156 },
	},
}
-- The snapshot has 12 significant digits: the tolerance is 1e-9 above that rounding.
local SNAPSHOT_EPS = 1e-9

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

	it("every step starts and ends at rest", function()
		for _, s in steps() do
			local timing = AttackPose.timing(s.name, nil, s.step)
			local first, _, w0 = AttackPose.sample(s.name, 0, nil, nil, s.step)
			expect(isRest(first)).toBe(true)
			expect(w0).toBe(0)
			local last, phase, w1 = AttackPose.sample(s.name, timing.total, nil, nil, s.step)
			expect(isRest(last)).toBe(true)
			expect(phase).toBe("rest")
			expect(w1).toBe(0)
			local almost = AttackPose.sample(s.name, timing.total - 1e-4, nil, nil, s.step)
			expect({ s.name, s.step, maxDiff(almost, last) < 0.5 }).toEqual({ s.name, s.step, true })
		end
	end)

	it("every step moves continuously (no jumps between frames)", function()
		for _, s in steps() do
			local timing = AttackPose.timing(s.name, nil, s.step)
			local dt = 1 / 240
			local previous = AttackPose.sample(s.name, 0, nil, nil, s.step)
			local t = dt
			while t <= timing.total + dt do
				local pose = AttackPose.sample(s.name, t, nil, nil, s.step)
				-- at most ~16 degrees per 1/240 s (a very fast cut is ~200 degrees in 0.1 s)
				local d = maxDiff(previous, pose)
				expect({ s.name, s.step, t, d < 16 }).toEqual({ s.name, s.step, t, true })
				previous = pose
				t += dt
			end
		end
	end)

	it("keeps every key pose of every step within the joint limits", function()
		for _, s in steps() do
			local step = AttackMotions.motions[s.name].steps[s.step]
			for _, pose in { step.poses.windup, step.poses.pass, step.poses.strike, step.poses.follow } do
				for joint, a in pose do
					local limit = AttackMotions.LIMITS[joint]
					local ok = limit ~= nil
						and math.abs(a[1]) <= limit
						and math.abs(a[2]) <= 180
						and math.abs(a[3]) <= 90
					expect({ s.name, s.step, joint, ok }).toEqual({ s.name, s.step, joint, true })
				end
			end
		end
	end)

	it("holds the bow in the left hand and draws with the right", function()
		local bow = AttackMotions.motions.bow
		expect(bow.ranged).toBe(true)
		for _, step in bow.steps do
			expect(step.poses.windup.lShoulder[1] >= 80).toBe(true) -- left arm up towards the target
			expect(step.poses.windup.lElbow[1] <= 10).toBe(true) -- straight
			expect(step.poses.windup.rElbow[1] >= 100).toBe(true) -- right hand draws to the cheek
		end
		expect(WeaponLooks.list.bow.hand).toBe("left")
		-- the shot leaves at the end of the draw
		local timing = AttackPose.timing("bow")
		expect(timing.hitAt).toBeNear(timing.windup, 1e-9)
	end)

	it("raises the crossbow without drawing", function()
		for _, step in AttackMotions.motions.crossbow.steps do
			-- S113: levelled at the target (the stock lies across the palm: its pitch is shoulder + elbow + wrist)
			local w = step.poses.windup
			expect(math.abs(w.lShoulder[1] + w.lElbow[1] + w.lWrist[1]) <= 20).toBe(true)
			expect(w.lShoulder[1] >= 45).toBe(true) -- raised to the chest
			expect(math.abs(step.poses.strike.rElbow[1] - step.poses.windup.rElbow[1]) <= 15).toBe(true)
		end
		expect(WeaponLooks.list.crossbow.hand).toBe("left")
	end)

	it("points the weapon at the target at the hit (S113)", function()
		-- A weapon across the palm (WeaponLooks FORWARD mount: tip along the hand's -Z) is level when shoulder + elbow +
		-- wrist pitch is 0; an upright one (staffs, bows: along +Y) leans its head forward when the pitch is negative.
		for _, s in steps() do
			if s.name ~= "unarmed" then
				local timing = AttackPose.timing(s.name, nil, s.step)
				local pose = AttackPose.sample(s.name, timing.hitAt, nil, nil, s.step)
				local left = s.name == "bow" or s.name == "crossbow"
				local pitch = pose[if left then "lShoulder" else "rShoulder"][1]
					+ pose[if left then "lElbow" else "rElbow"][1]
					+ pose[if left then "lWrist" else "rWrist"][1]
				local low, high = -10, 45
				if s.name == "staff" then
					low, high = -60, 0 -- the head leans towards the target
				elseif s.name == "bow" then
					low, high = 0, 35 -- the bow stands (canted back at most 35 degrees)
				end
				expect({ s.name, s.step, pitch, pitch >= low and pitch <= high }).toEqual({
					s.name,
					s.step,
					pitch,
					true,
				})
			end
		end
	end)

	it("lands the blow during the strike and squeezes into short intervals", function()
		for _, s in steps() do
			local timing = AttackPose.timing(s.name, nil, s.step)
			expect(timing.hitAt >= timing.windup - 1e-9).toBe(true)
			expect(timing.hitAt <= timing.windup + timing.strike + 1e-9).toBe(true)
			expect(timing.hitAt <= 0.25).toBe(true) -- the visible hit stays close to the server's damage
			local fast = AttackPose.timing(s.name, timing.total / 2, s.step)
			expect(fast.total).toBeNear(timing.total / 2, 1e-9)
			expect(fast.hitAt).toBeNear(timing.hitAt / 2, 1e-9)
			local tiny = AttackPose.timing(s.name, 0.01, s.step)
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

	it("steps start and end at rest, move continuously and blend from any step into any step", function()
		local all = steps()
		for _, a in all do
			local ta = AttackPose.timing(a.name, nil, a.step)
			local mid = AttackPose.sample(a.name, ta.windup + ta.strike * 0.5, nil, nil, a.step)
			for _, b in all do
				local start, _, weight = AttackPose.sample(b.name, 0, nil, mid, b.step)
				expect({ a.name, a.step, b.name, b.step, maxDiff(start, mid) < 1e-6, weight }).toEqual({
					a.name,
					a.step,
					b.name,
					b.step,
					true,
					1,
				})
				-- the first frame after the blend start stays close to it
				local next = AttackPose.sample(b.name, 1 / 240, nil, mid, b.step)
				expect({ a.name, a.step, b.name, b.step, maxDiff(start, next) < 16 }).toEqual({
					a.name,
					a.step,
					b.name,
					b.step,
					true,
				})
			end
		end
	end)

	it("hit delay: melee at the blow, ranged at the release plus the flight (FIX 2026-10-09)", function()
		expect(AttackPose.hitDelay("sword1h", 5, false)).toBeNear(AttackMotions.SERVER_HIT.slash1h)
		expect(AttackPose.hitDelay("bow", 33, true)).toBeNear(
			AttackMotions.SERVER_HIT.bow + AttackPose.flightTime("arrow", 33)
		)
		expect(AttackPose.hitDelay("bow", 200, true)).toBeNear(AttackMotions.SERVER_HIT.bow + 0.4)
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

describe("AttackPose S113", function()
	it("server hit timing unchanged (S113)", function()
		local count = 0
		for weaponType, rows in HIT_DELAY_BEFORE do
			local wt = if weaponType == "unarmed" then nil else weaponType
			for i, d in DISTANCES do
				for j, ranged in { false, true } do
					local now = AttackPose.hitDelay(wt, d, ranged)
					expect({ weaponType, d, ranged, math.abs(now - rows[i][j]) <= SNAPSHOT_EPS }).toEqual({
						weaponType,
						d,
						ranged,
						true,
					})
					count += 1
				end
			end
		end
		-- every attacking weapon type of the game is in the snapshot
		for itemType in WeaponLooks.list do
			if not AttackMotions.offhand[itemType] then
				expect({ itemType, HIT_DELAY_BEFORE[itemType] ~= nil }).toEqual({ itemType, true })
			end
		end
		expect(count).toBe(20 * 7 * 2)
		-- every step of every motion lands at SERVER_HIT; the derived hit fraction is inside the blow
		for _, s in steps() do
			local timing = AttackPose.timing(s.name, nil, s.step)
			expect({ s.name, s.step, math.abs(timing.hitAt - AttackMotions.SERVER_HIT[s.name]) <= 1e-9 }).toEqual({
				s.name,
				s.step,
				true,
			})
			local low, high = if timing.ranged then 0 else 0.3, if timing.ranged then 1 else 0.9
			expect({ s.name, s.step, timing.hit >= low - 1e-9 and timing.hit <= high + 1e-9, timing.hit }).toEqual({
				s.name,
				s.step,
				true,
				timing.hit,
			})
		end
	end)

	it("§2 checks (S113)", function()
		for _, s in steps() do
			local step = AttackMotions.motions[s.name].steps[s.step]
			local timing = AttackPose.timing(s.name, nil, s.step)
			local label = `{s.name} step {s.step}`
			-- 1. anticipation: at least 0.1 s; heavy weapons slower before the blow and fast in it
			expect({ label, "windup", step.windup, step.windup >= 0.1 }).toEqual({ label, "windup", step.windup, true })
			if s.name == "slash2h" or s.name == "smash" then
				expect({ label, "heavy", step.windup, step.strike, step.windup >= 0.14 and step.strike <= 0.12 }).toEqual({
					label,
					"heavy",
					step.windup,
					step.strike,
					true,
				})
			end
			local joint = mainJoint(step)
			local strikeEnd = timing.windup + timing.strike
			-- 2. the contact: the main shoulder is fastest at the server's hit (±0.03 s)
			if not timing.ranged and step.poses.pass then
				local dt = 1 / 240
				local best, bestAt = -1, 0
				local previous = AttackPose.sample(s.name, 0, nil, nil, s.step)[joint]
				local t = dt
				while t <= timing.total do
					local now = AttackPose.sample(s.name, t, nil, nil, s.step)[joint]
					local speed = dist(previous, now) / dt
					if speed > best then
						best, bestAt = speed, t - dt / 2
					end
					previous = now
					t += dt
				end
				local off = math.abs(bestAt - timing.hitAt)
				expect({ label, "peak at", bestAt, "hit", timing.hitAt, off <= 0.03 }).toEqual({
					label,
					"peak at",
					bestAt,
					"hit",
					timing.hitAt,
					true,
				})
			end
			-- 3. follow-through: the main axis goes on the way it struck, the overshoot is 3-20 degrees
			if step.poses.follow then
				local axis = mainAxis(step, joint)
				local struck = of(step.poses.strike, joint)[axis] - of(step.poses.windup, joint)[axis]
				local a = AttackPose.sample(s.name, strikeEnd, nil, nil, s.step)[joint][axis]
				local b = AttackPose.sample(s.name, strikeEnd + 0.04, nil, nil, s.step)[joint][axis]
				expect({ label, "follow way", math.sign(b - a) == math.sign(struck) }).toEqual({
					label,
					"follow way",
					true,
				})
				local over = dist(of(step.poses.follow, joint), of(step.poses.strike, joint))
				expect({ label, "overshoot", over, over >= 3 and over <= 20 }).toEqual({
					label,
					"overshoot",
					over,
					true,
				})
			end
			-- 4. no "robot": no two consecutive 1/60 s stretches of the blow and the recovery move the same
			local dt = 1 / 60
			local t = timing.windup
			local lastMove: { number }? = nil
			while t + dt <= timing.total do
				local a = AttackPose.sample(s.name, t, nil, nil, s.step)[joint]
				local b = AttackPose.sample(s.name, t + dt, nil, nil, s.step)[joint]
				local move = { b[1] - a[1], b[2] - a[2], b[3] - a[3] }
				local size = math.abs(move[1]) + math.abs(move[2]) + math.abs(move[3])
				if lastMove and size > 1e-6 then
					local change = math.abs(move[1] - lastMove[1])
						+ math.abs(move[2] - lastMove[2])
						+ math.abs(move[3] - lastMove[3])
					expect({ label, "robot", t, change > 1e-6 }).toEqual({ label, "robot", t, true })
				end
				lastMove = move
				t += dt
			end
			-- 5. arcs: a melee hand travels on an arc (>= 0.15 of the arm's length 2.0 off the straight line)
			if not timing.ranged then
				local samples: { { number } } = {}
				for i = 0, 7 do
					local pose =
						AttackPose.sample(s.name, timing.windup + timing.strike * i / 7 - 1e-9 * i, nil, nil, s.step)
					table.insert(samples, hand(pose, joint))
				end
				local off = 0
				for _, p in samples do
					off = math.max(off, fromSegment(p, samples[1], samples[8]))
				end
				expect({ label, "arc", off, off >= 0.3 }).toEqual({ label, "arc", off, true })
			end
		end
	end)

	it("every weapon type has a motion with 1–3 steps; melee motions used by players have 2–3", function()
		for name, motion in AttackMotions.motions do
			local n = #motion.steps
			expect({ name, n >= 1 and n <= 3 }).toEqual({ name, true })
			expect({ name, AttackPose.stepCount(name) }).toEqual({ name, n })
		end
		local want =
			{ slash1h = 3, slash2h = 3, thrust = 3, smash = 2, unarmed = 3, bow = 1, crossbow = 1, wand = 2, staff = 2 }
		for name, n in want do
			expect({ name, #AttackMotions.motions[name].steps }).toEqual({ name, n })
		end
		expect(AttackPose.step("bow", 3)).toBe(AttackMotions.motions.bow.steps[1]) -- wraps around
		expect(AttackPose.timing("slash1h", nil, 4).step).toBe(1)
	end)

	it("combo steps cycle within the window", function()
		expect(AttackPose.nextStep(nil, "slash1h", 10, 3)).toBe(1)
		local prev: AttackPose.ComboState = { motion = "slash1h", step = 1, at = 0 }
		local seen = {}
		local now = 0
		for _ = 1, 4 do
			now += 0.8
			local step = AttackPose.nextStep(prev, "slash1h", now, 3)
			table.insert(seen, step)
			prev = { motion = "slash1h", step = step, at = now }
		end
		expect(seen).toEqual({ 2, 3, 1, 2 })
		-- a pause longer than the window starts over
		expect(AttackPose.nextStep({ motion = "slash1h", step = 2, at = 0 }, "slash1h", 1.6, 3)).toBe(1)
		expect(AttackPose.nextStep({ motion = "slash1h", step = 2, at = 0 }, "slash1h", AttackMotions.COMBO_WINDOW, 3)).toBe(
			3
		)
		-- another motion starts over; one step is always 1
		expect(AttackPose.nextStep({ motion = "thrust", step = 2, at = 0 }, "slash1h", 0.5, 3)).toBe(1)
		expect(AttackPose.nextStep({ motion = "bow", step = 1, at = 0 }, "bow", 0.5, 1)).toBe(1)
	end)

	it("flinch leans away from the blow", function()
		local half = AttackMotions.FLINCH.seconds / 2
		local front = AttackPose.flinch({ x = 0, z = 1 }, 1, half)
		expect(front.waist[1] > 0).toBe(true) -- struck from the front: leans back
		expect(front.rShoulder[1] < 0 and front.lShoulder[1] < 0).toBe(true) -- the arms swing back
		local right = AttackPose.flinch({ x = 1, z = 0 }, 1, half)
		local left = AttackPose.flinch({ x = -1, z = 0 }, 1, half)
		expect(right.waist[3] ~= 0 and math.sign(right.waist[3]) == -math.sign(left.waist[3])).toBe(true)
		-- pushed to the right (struck from the left): the upper body tilts right (-z on the waist)
		expect(right.waist[3] < 0).toBe(true)
		for _, t in { 0, AttackMotions.FLINCH.seconds, -1, 5 } do
			local pose = AttackPose.flinch({ x = 0.6, z = 0.8 }, 1, t)
			expect({ t, pose.waist[1], pose.waist[3], pose.rShoulder[1] }).toEqual({ t, 0, 0, 0 })
		end
		local crit = AttackPose.flinch({ x = 0, z = 1 }, AttackPose.flinchStrength(true), half)
		expect(crit.waist[1] > front.waist[1]).toBe(true)
		expect(AttackPose.flinchStrength(false)).toBe(1)
	end)

	it("sound keys exist; hit sparks are sound textures, colours and ranges", function()
		for name, keys in AttackMotions.SFX do
			expect({ name, AttackMotions.motions[name] ~= nil }).toEqual({ name, true })
			for _, key in { keys.start, keys.swing, keys.release } do
				expect({ name, key, Sfx.has(key) }).toEqual({ name, key, true })
			end
		end
		for _, s in steps() do
			local sfx = AttackMotions.motions[s.name].steps[s.step].sfx
			if sfx then
				for _, key in { sfx.start, sfx.swing, sfx.release } do
					expect({ s.name, s.step, key, Sfx.has(key) }).toEqual({ s.name, s.step, key, true })
				end
			end
		end
		local materials: { string } = {}
		for material, spark in HitFx.byMaterial do
			table.insert(materials, material)
			local texture = VfxTextures.get(spark.key)
			expect({ material, spark.key, texture ~= nil and texture.kind == "particle" }).toEqual({
				material,
				spark.key,
				true,
			})
			expect({ material, string.match(spark.color, "^#%x%x%x%x%x%x$") ~= nil }).toEqual({ material, true })
			expect({ material, spark.count > 0, spark.gravity >= 0 }).toEqual({ material, true, true })
			expect({ material, spark.speed[1] > 0 and spark.speed[1] <= spark.speed[2] }).toEqual({ material, true })
			expect({ material, spark.life[1] > 0 and spark.life[1] <= spark.life[2] }).toEqual({ material, true })
		end
		table.sort(materials)
		local expected = table.clone(Sfx.MATERIALS)
		table.sort(expected)
		expect(materials).toEqual(expected)
		expect(HitFx.byMaterial[HitFx.default] ~= nil).toBe(true)
		expect(HitFx.byMaterial[HitFx.player] ~= nil).toBe(true)
		expect(HitFx.crit.countMul >= 1 and HitFx.crit.flashScale >= 1).toBe(true)
		expect(string.match(HitFx.smashTint, "^#%x%x%x%x%x%x$") ~= nil).toBe(true)
		expect(
			VfxTextures.get(AttackMotions.TRAIL.key) ~= nil and (VfxTextures.get(AttackMotions.TRAIL.key) :: any).kind
		).toBe("trail")
	end)

	it("trail windows inside the step, short hitstops", function()
		for _, s in steps() do
			local step = AttackMotions.motions[s.name].steps[s.step]
			local timing = AttackPose.timing(s.name, nil, s.step)
			local trail = step.trail
			if trail then
				expect({ s.name, s.step, trail.from >= 0 and trail.from < trail.to and trail.to <= timing.total }).toEqual({
					s.name,
					s.step,
					true,
				})
			end
			if step.hitstop then
				expect({ s.name, s.step, step.hitstop > 0 and step.hitstop <= 0.05 }).toEqual({ s.name, s.step, true })
			end
			if step.follow then
				expect({ s.name, s.step, step.follow > 0 and step.follow < 1 }).toEqual({ s.name, s.step, true })
			end
		end
		local trail = AttackMotions.TRAIL
		expect(trail.base >= 0 and trail.base < 1 and trail.lifetime > 0).toBe(true)
		for _, base in trail.baseByMotion do
			expect(base >= 0 and base < 1).toBe(true)
		end
	end)
end)
