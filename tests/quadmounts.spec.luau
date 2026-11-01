--!strict
-- The mount styles (owner 2026-11-01, Data/QuadStyles `horse` and `lion`, docs/ASSETS.md "Wierzchowce"): Tripo mounts
-- ridden at 25-42 studs/s on Logic/QuadMotion, run on the placeholder skeletons of tests/QuadMountRigs (the real bone
-- maps come from the rig dumps) through the forward kinematics of tests/QuadRigFk: the gaits at the mount's speeds (one
-- gait, a real gallop's cadence, feet planted in stance, nothing through the ground), a calm back under the saddle,
-- the horse's nod, the lion's steady head and lagging tail, the idle and its fidgets, QuadMotion.saddle against the
-- drawn body, and the rider's own fit and saddle (Logic/RiderPose, Logic/Mounts.seatAt).

local MountData = require("../src/shared/Data/Mounts")
local Mounts = require("../src/shared/Logic/Mounts")
local QuadMotion = require("../src/shared/Logic/QuadMotion")
local QuadMountRigs = require("./QuadMountRigs")
local QuadPose = require("../src/shared/Logic/QuadPose")
local QuadRigFk = require("./QuadRigFk")
local QuadStyles = require("../src/shared/Data/QuadStyles")
local RiderPose = require("../src/shared/Logic/RiderPose")
local T = require("./Test")

type Vec = { number }
type Mat = { number }

local KINDS = { "horse", "lion" }
local LEGS = { "FL", "FR", "HL", "HR" }
local GAITS = { "walk", "trot", "gallop" }
local DT = 1 / 60
-- the mount's speeds (Config.Mount: x2.0-2.6 of the base walk, slows below)
local MOUNT_SPEEDS = { 25, 32, 42 }

-- Nose-up pitch and right-side-up roll of a turn (degrees).
local function pitchOf(m: Mat): number
	return math.deg(math.asin(math.clamp(-m[6], -1, 1)))
end
local function rollOf(m: Mat): number
	return math.deg(math.asin(math.clamp(m[4], -1, 1)))
end
local function yawOf(m: Mat): number
	-- the forward axis (-Z column) turned toward -X: + to the left
	return math.atan2(m[3], m[9])
end

local function step(inst: QuadMotion.Instance, now: number, speed: number, yawRate: number?): QuadPose.Posed
	return QuadMotion.step(inst, { now = now, dt = DT, speed = speed, yawRate = yawRate or 0, combat = false })
end

local function settle(inst: QuadMotion.Instance, seconds: number, speed: number, yawRate: number?): number
	local now = 0
	for _ = 1, math.floor(seconds / DT) do
		now += DT
		step(inst, now, speed, yawRate)
	end
	return now
end

local function heaviest(inst: QuadMotion.Instance): (string, number)
	local gait, weight = "walk", 0
	for name, w in inst.weights do
		if w > weight then
			gait, weight = name, w
		end
	end
	return gait, weight
end

-- Ranges over `frames` frames at `speed`: { lo, hi } per measure.
type Ranges = { [string]: { number } }
local function widen(r: Ranges, key: string, v: number)
	local range = r[key]
	if not range then
		r[key] = { v, v }
	else
		range[1], range[2] = math.min(range[1], v), math.max(range[2], v)
	end
end
local function span(r: Ranges, key: string): number
	return r[key][2] - r[key][1]
end

T.describe("Mount styles: shape", function()
	for _, kind in KINDS do
		local style = QuadStyles.get(kind)
		T.it(`{kind}: a walk, a trot and a gallop on planted feet, idle fidgets and no blows`, function()
			T.expect(style ~= nil).toBe(true)
			local s = assert(style, kind)
			for _, name in GAITS do
				local g = s.gaits[name]
				T.expect(g ~= nil).toBe(true)
				T.expect(g.plant).toBe(true)
				T.expect(g.duty > 0 and g.duty < 1).toBe(true)
				T.expect(g.k > 0).toBe(true)
				for _, leg in LEGS do
					T.expect(g.foot[leg] >= 0 and g.foot[leg] < 1).toBe(true)
				end
			end
			T.expect(s.thresholds.trot < s.thresholds.gallop).toBe(true)
			T.expect(#s.basic).toBe(0)
			T.expect(next(s.abilities)).toBeNil()
			T.expect(#s.death).toBe(0)
			T.expect(#s.fidgets >= 2).toBe(true)
			for _, name in s.fidgets do
				T.expect(s.actions[name] ~= nil).toBe(true)
			end
			for _, leg in LEGS do
				T.expect(s.stance[leg .. "k"]).toBe(1)
				T.expect((s.ground :: any)[leg .. "k"]).toBe(1)
			end
		end)
	end

	T.it("the horse's hooves never curl, the lion's paws curl in the swing", function()
		local horse, lion = assert(QuadStyles.get("horse")), assert(QuadStyles.get("lion"))
		for _, name in GAITS do
			T.expect(horse.gaits[name].pawFront).toBe(0)
			T.expect(horse.gaits[name].pawHind).toBe(0)
			T.expect(lion.gaits[name].pawFront > 0).toBe(true)
		end
	end)

	T.it(
		"the horse walks in four even beats, trots on diagonals, gallops transverse; the lion gallops rotary",
		function()
			local horse, lion = assert(QuadStyles.get("horse")), assert(QuadStyles.get("lion"))
			local walk = horse.gaits.walk.foot
			T.expect(walk).toEqual({ HL = 0, FL = 0.25, HR = 0.5, FR = 0.75 })
			local trot = horse.gaits.trot.foot
			T.expect(trot.HL).toBe(trot.FR)
			T.expect(trot.HR).toBe(trot.FL)
			T.expect(math.abs(trot.HR - trot.HL)).toBe(0.5)
			-- transverse: the fore pair lands in the hind pair's order; rotary: in the other one
			local hg, lg = horse.gaits.gallop.foot, lion.gaits.gallop.foot
			T.expect(hg.HL < hg.HR and hg.HR < hg.FL and hg.FL < hg.FR).toBe(true)
			T.expect(lg.HL < lg.HR and lg.HR < lg.FR and lg.FR < lg.FL).toBe(true)
		end
	)

	T.it("the monster styles keep their motion: no mount gait fields", function()
		for _, id in { "canine", "bear", "boar", "mammoth", "dragon" } do
			local style = assert(QuadStyles.get(id), id)
			for _, g in style.gaits do
				T.expect(g.nod).toBeNil()
				T.expect(g.headLevel).toBeNil()
				T.expect(g.tailLag).toBeNil()
				T.expect(g.tailWave).toBeNil()
			end
		end
	end)
end)

T.describe("Mount styles: at the mount's speeds", function()
	for _, kind in KINDS do
		local skel = QuadMountRigs.skeleton(kind)
		local style = assert(QuadStyles.get(kind))
		local L = skel.L
		local rest = QuadRigFk.feetAt(skel, {})
		local restSaddle = QuadMountRigs.saddle(skel)

		T.it(`{kind}: the placeholder's feet rest on the ground and a positive fold lifts them`, function()
			for _, leg in LEGS do
				T.expect(rest[leg][2] / L).toBeBetween(-0.01, 0.12)
				local folded = QuadRigFk.feetAt(skel, { [leg .. "f"] = 0.6 })
				T.expect((folded[leg][2] - rest[leg][2]) / L > 0.05).toBe(true)
			end
		end)

		local paces: { { any } } = {
			{ "walk", 0.8 * L, "walk" },
			{ "trot", 3 * L, "trot" },
		}
		for _, v in MOUNT_SPEEDS do
			table.insert(paces, { `{v} studs/s`, v, "gallop" })
		end
		for _, pace in paces do
			local label, speed, want = pace[1] :: string, pace[2] :: number, pace[3] :: string
			T.it(
				`{kind} at {label}: the {want}, feet planted in stance, nothing through the ground, a calm saddle`,
				function()
					local inst = assert(QuadMotion.new(skel, kind, 9))
					local now = settle(inst, 2, speed)
					local gait, weight = heaviest(inst)
					T.expect(gait).toBe(want)
					T.expect(weight > 0.97).toBe(true)
					local g = style.gaits[gait]
					local slide, hover, low, nan = 0, 0, math.huge, false
					local runs: { [string]: { number } } = {}
					local r: Ranges = {}
					for _ = 1, 240 do
						now += DT
						local at, turns = QuadRigFk.posed(skel, step(inst, now, speed))
						for name, p in at do
							if p[1] ~= p[1] or p[2] ~= p[2] or p[3] ~= p[3] then
								nan = true
							elseif name ~= skel.rig.body then
								low = math.min(low, p[2] / L)
							end
						end
						widen(r, "rise", (at.saddle[2] - restSaddle[2]) / L)
						widen(r, "pitch", pitchOf(turns.saddle))
						widen(r, "roll", rollOf(turns.saddle))
						local feet = QuadRigFk.feetOf(skel, at, turns)
						for _, leg in LEGS do
							local duty = if string.sub(leg, 1, 1) == "F" then (g.dutyFront or g.duty) else g.duty
							local p = (inst.phase - g.foot[leg]) % 1
							-- the foot's place on the ground (the model goes toward -Z at `speed`)
							local ground = (feet[leg][3] - speed * now) / L
							if p > 0.08 * duty and p < 0.75 * duty then
								local run = runs[leg]
								if not run then
									run = { ground, ground }
									runs[leg] = run
								end
								run[1], run[2] = math.min(run[1], ground), math.max(run[2], ground)
								slide = math.max(slide, run[2] - run[1])
								hover = math.max(hover, math.abs(feet[leg][2] - rest[leg][2]) / L)
							else
								runs[leg] = nil
							end
						end
					end
					T.expect(nan).toBe(false)
					T.expect(low > -0.02).toBe(true)
					T.expect(slide < 0.02).toBe(true)
					T.expect(hover < 0.03).toBe(true)
					-- the rider's seat: rises and falls at most 0.06 leg lengths (with the drop), tilts at most 4.5 degrees
					-- and on a straight line hardly rolls
					T.expect(span(r, "rise") <= 0.06).toBe(true)
					T.expect(r.rise[1] >= -0.08 and r.rise[2] <= 0.02).toBe(true)
					T.expect(math.max(-r.pitch[1], r.pitch[2]) <= 4.5).toBe(true)
					T.expect(math.max(-r.roll[1], r.roll[2]) <= 1.5).toBe(true)
				end
			)
		end

		T.it(
			`{kind}: the gallop at 25-42 studs/s strides about 1.5-2.8 times a second (the legs never spin)`,
			function()
				for _, v in MOUNT_SPEEDS do
					local inst = assert(QuadMotion.new(skel, kind, 3))
					local now = settle(inst, 1.5, v)
					local cycles, phase = 0, inst.phase
					for _ = 1, 180 do
						now += DT
						step(inst, now, v)
						cycles += (inst.phase - phase) % 1
						phase = inst.phase
					end
					local hz = cycles / (180 * DT)
					T.expect(hz).toBeBetween(1.4, 2.8)
					-- one stride per k leg lengths travelled (the cadence keeps the planted feet on the ground)
					T.expect(hz).toBeNear(v / (style.gaits.gallop.k * L), 0.05)
				end
			end
		)

		T.it(`{kind}: a turn at a gallop leans the body into it, at most 10 degrees`, function()
			local inst = assert(QuadMotion.new(skel, kind, 4))
			local now = settle(inst, 1.5, 32, 2)
			local lo = math.huge
			for _ = 1, 60 do
				now += DT
				local _, turns = QuadRigFk.posed(skel, step(inst, now, 32, 2))
				lo = math.min(lo, rollOf(turns.saddle))
			end
			-- a left turn: the left side down
			T.expect(lo < -3).toBe(true)
			T.expect(lo >= -10.5).toBe(true)
		end)

		T.it(
			`{kind}: standing, the idle and its fidgets keep the saddle still and nothing goes through the ground`,
			function()
				local inst = assert(QuadMotion.new(skel, kind, 6))
				local now = 0
				local r: Ranges = {}
				local played: { [string]: boolean } = {}
				local low, nan = math.huge, false
				for _ = 1, math.floor(45 / DT) do
					now += DT
					local at, turns = QuadRigFk.posed(skel, step(inst, now, 0))
					if inst.fidget then
						played[inst.fidget.name] = true
					end
					widen(r, "rise", (at.saddle[2] - restSaddle[2]) / L)
					widen(r, "pitch", pitchOf(turns.saddle))
					widen(r, "roll", rollOf(turns.saddle))
					for name, p in at do
						if p[2] ~= p[2] then
							nan = true
						elseif name ~= skel.rig.body then
							low = math.min(low, p[2] / L)
						end
					end
				end
				local count = 0
				for name in played do
					T.expect(table.find(style.fidgets, name) ~= nil).toBe(true)
					count += 1
				end
				T.expect(count >= 2).toBe(true)
				T.expect(nan).toBe(false)
				T.expect(low > -0.02).toBe(true)
				T.expect(span(r, "rise") <= 0.025).toBe(true)
				T.expect(math.max(-r.pitch[1], r.pitch[2]) <= 2).toBe(true)
				T.expect(math.max(-r.roll[1], r.roll[2]) <= 2).toBe(true)
			end
		)

		T.it(`{kind}: QuadMotion.saddle carries a point on the back as the drawn body does`, function()
			local inst = assert(QuadMotion.new(skel, kind, 8))
			local rise0, pitch0, roll0 = QuadMotion.saddle(inst, restSaddle)
			T.expect(rise0).toBe(0)
			T.expect(pitch0).toBe(0)
			T.expect(roll0).toBe(0)
			-- the first spine bone's joint moves with the body alone: exactly; the saddle (on the flexing spine) nearly
			local spine = skel.rig.spine[1].bone
			local spineRest = skel.bones[spine].pos
			local now = 0
			for i = 1, 200 do
				now += DT
				local speed = if i < 100 then 32 else 0
				local at = QuadRigFk.posed(skel, step(inst, now, speed, if i > 150 then 1.5 else 0))
				local rise = QuadMotion.saddle(inst, spineRest)
				T.expect(rise).toBeNear(at[spine][2] - spineRest[2], 1e-6)
				local seat = QuadMotion.saddle(inst, restSaddle)
				T.expect(math.abs(seat - (at.saddle[2] - restSaddle[2])) / L < 0.012).toBe(true)
			end
		end)
	end

	T.it("horse: the head nods in the walk and the gallop and holds still in the trot", function()
		local skel = QuadMountRigs.skeleton("horse")
		local L = skel.L
		local head = skel.rig.head
		local function nodSpan(speed: number): number
			local inst = assert(QuadMotion.new(skel, "horse", 5))
			local now = settle(inst, 2, speed)
			local r: Ranges = {}
			for _ = 1, 180 do
				now += DT
				local _, turns = QuadRigFk.posed(skel, step(inst, now, speed))
				widen(r, "head", pitchOf(turns[head]))
			end
			return span(r, "head")
		end
		T.expect(nodSpan(0.8 * L) > 6).toBe(true)
		T.expect(nodSpan(3 * L) < 3).toBe(true)
		T.expect(nodSpan(32) > 7).toBe(true)
	end)

	T.it("lion: the head stays steady over the bounding gallop while the spine flexes", function()
		local skel = QuadMountRigs.skeleton("lion")
		local inst = assert(QuadMotion.new(skel, "lion", 5))
		local now = settle(inst, 2, 32)
		local r: Ranges = {}
		local chest = skel.rig.spine[#skel.rig.spine].bone
		for _ = 1, 180 do
			now += DT
			local _, turns = QuadRigFk.posed(skel, step(inst, now, 32))
			widen(r, "head", pitchOf(turns[skel.rig.head]))
			widen(r, "flex", pitchOf(turns[chest]) - pitchOf(turns[skel.rig.body]))
		end
		T.expect(span(r, "head") < 3).toBe(true)
		T.expect(span(r, "flex") > 4).toBe(true)
	end)

	T.it("lion: the tail's sway runs down its six bones, the tip's later than the base's", function()
		local skel = QuadMountRigs.skeleton("lion")
		local tail = skel.rig.tail
		T.expect(#tail).toBe(6)
		local inst = assert(QuadMotion.new(skel, "lion", 2))
		local speed = 0.8 * skel.L
		local now = settle(inst, 2, speed)
		-- the cycle phase at which each end swings furthest to the left
		local best: { [string]: { number } } = {}
		local cadence = speed / (assert(QuadStyles.get("lion")).gaits.walk.k * skel.L)
		for _ = 1, math.ceil(2 / cadence / DT) do
			now += DT
			local _, turns = QuadRigFk.posed(skel, step(inst, now, speed))
			for _, name in { tail[1], tail[#tail] } do
				local yaw = yawOf(turns[name])
				local b = best[name]
				if not b or yaw > b[1] then
					best[name] = { yaw, inst.phase }
				end
			end
		end
		local lag = (best[tail[#tail]][2] - best[tail[1]][2]) % 1
		T.expect(lag > 0.05 and lag < 0.6).toBe(true)
	end)
end)

T.describe("Mount styles: the rider", function()
	T.it("a mount's fit lays its fields over RIDER and keeps the rest", function()
		T.expect(RiderPose.rider(nil)).toBe(MountData.RIDER)
		local base = MountData.RIDER
		-- a broad lion: the thighs spread 8 degrees wider and the seat a little higher
		local lion = RiderPose.rider({ rHip = { 70, 0, 30 }, lHip = { 70, 0, -30 }, seatLift = 0.85 })
		T.expect(lion.rHip[3] > base.rHip[3]).toBe(true)
		T.expect(lion.lHip[3] < base.lHip[3]).toBe(true)
		T.expect(lion.rKnee).toBe(base.rKnee)
		T.expect(lion.bob).toBe(base.bob)
		T.expect(lion.stride).toBe(base.stride)
		T.expect(lion.seatLift).toBe(0.85)
		T.expect(table.isfrozen(lion)).toBe(true)
		local pose = RiderPose.sample(0.7, 1, lion)
		T.expect(pose.rHip).toEqual({ 70, 0, 30 })
		T.expect(pose.lHip).toEqual({ 70, 0, -30 })
	end)

	T.it("on a template mount the rider rides the saddle's rise and leans with its pitch and roll", function()
		local calm = RiderPose.rider({ bob = 0 })
		local pose = RiderPose.sample(1.3, 1, calm, { -0.12, math.rad(2), math.rad(-1) })
		T.expect(pose.root[1]).toBeNear(2, 1e-9)
		T.expect(pose.root[2]).toBe(0)
		T.expect(pose.root[3]).toBeNear(-1, 1e-9)
		T.expect(pose.root[4]).toBeNear(-0.12, 1e-9)
		-- without a saddle, the old pose: no tilt, the bob only
		local plain = RiderPose.sample(1.3, 1)
		T.expect(plain.root[1]).toBe(0)
		T.expect(plain.root[4]).toBeNear(MountData.RIDER.bob * math.sin(2.6), 1e-9)
	end)

	T.it("a mount's own seat lift raises the rider by the difference", function()
		local base = Mounts.seatAt(0, { 0, 4.4, 0.4 }, 1)
		local higher = Mounts.seatAt(0, { 0, 4.4, 0.4 }, 1, MountData.RIDER.seatLift + 0.2)
		T.expect(higher.hipHeight - base.hipHeight).toBeNear(0.2, 1e-9)
		T.expect(higher.offset[2] - base.offset[2]).toBeNear(-0.2, 1e-9)
		T.expect(Mounts.seatAt(0, { 0, 4.4, 0.4 }, 1, nil)).toEqual(base)
	end)
end)
