--!strict
-- Template animation (owner 2026-11-10: "modele poruszają się nie poruszając głową tak 2d"): Logic/HeadGaze turns
-- the head of a model without bones toward its target within its limits at its rate, glances about when calm (the
-- same at every replay), at the local player now and then, sniffs standing still, nods with the steps, flinches away
-- from a blow, keeps level against the body's own pitch, hangs stunned, eases back to rest in its death and holds
-- while the clock stands; the data's heads stay within their limits through a busy minute; the lowest graphics level
-- turns none.
local GraphicsLevel = require("../src/shared/Logic/GraphicsLevel")
local HeadGaze = require("../src/shared/Logic/HeadGaze")
local RigidRigs = require("../src/shared/Data/RigidRigs")
local T = require("./Test")

local LYNX = RigidRigs.gaze("lynx") :: HeadGaze.Options
local RABBIT = RigidRigs.gaze("rabbit") :: HeadGaze.Options
local CROW = RigidRigs.gaze("carrionCrow") :: HeadGaze.Options
local FRAME = 1 / 60
-- The dazed sway's reach (degrees: Logic/HeadGaze's DAZED_SWAY of the lynx's glance, and a little).
local DAZED_YAW = 0.3 * LYNX.glance + 0.5

-- A direction `yaw` degrees to the left and `pitch` up (the look's axes).
local function dir(yaw: number, pitch: number): { number }
	local y, p = math.rad(yaw), math.rad(pitch)
	return { -math.sin(y) * math.cos(p), math.sin(p), -math.cos(y) * math.cos(p) }
end

-- Steps `st` at 60 Hz from `from` for `seconds` with `input(t)`; the angles of the last frame (degrees) and every
-- frame's (radians) through `each`.
local function run(
	st: HeadGaze.State,
	from: number,
	seconds: number,
	input: (t: number) -> { [string]: any },
	each: ((t: number, yaw: number, pitch: number, roll: number) -> ())?
): (number, number, number)
	local yaw, pitch, roll = 0, 0, 0
	local frames = math.floor(seconds / FRAME + 0.5)
	for k = 0, frames do
		local t = from + k * FRAME
		local i = input(t) :: any
		i.now = t
		i.dt = if i.dt == nil then FRAME else i.dt
		yaw, pitch, roll = HeadGaze.step(st, i :: HeadGaze.Input)
		if each then
			each(t, yaw, pitch, roll)
		end
	end
	return math.deg(yaw), math.deg(pitch), math.deg(roll)
end

T.describe("HeadGaze: a target", function()
	T.it("aims within the head's limits", function()
		local y, p = HeadGaze.aim(LYNX, table.unpack(dir(20, 10)))
		T.expect(math.deg(y)).toBeNear(20, 1e-6)
		T.expect(math.deg(p)).toBeNear(10, 1e-6)
		y = HeadGaze.aim(LYNX, table.unpack(dir(-20, 0)))
		T.expect(math.deg(y)).toBeNear(-20, 1e-6)
		-- behind on the left, high above, deep below: at the limits
		y = HeadGaze.aim(LYNX, table.unpack(dir(150, 0)))
		T.expect(math.deg(y)).toBeNear(LYNX.yaw, 1e-6)
		local _, high = HeadGaze.aim(LYNX, table.unpack(dir(0, 70)))
		local _, low = HeadGaze.aim(LYNX, table.unpack(dir(0, -70)))
		T.expect(math.deg(high)).toBeNear(LYNX.up, 1e-6)
		T.expect(math.deg(low)).toBeNear(-LYNX.down, 1e-6)
	end)

	T.it("turns toward it at its rate, then holds on it", function()
		local st = HeadGaze.new(LYNX, 3)
		HeadGaze.step(st, { now = 0, dt = 0, snap = true, combat = true })
		local look = dir(25, 8)
		local y1 = run(st, FRAME, 0.1, function()
			return { look = look, combat = true }
		end)
		-- after a tenth of a second about half the way (rate 7/s), after a second there
		T.expect(y1).toBeBetween(8, 18)
		local y2, p2 = run(st, 0.1 + FRAME, 0.9, function()
			return { look = look, combat = true }
		end)
		T.expect(y2).toBeNear(25, 0.05)
		T.expect(p2).toBeNear(8, 0.05)
	end)

	T.it("is where it looks at once after a jump of the clock", function()
		local st = HeadGaze.new(LYNX, 3)
		local yaw, pitch = HeadGaze.step(st, { now = 5, dt = FRAME, snap = true, look = dir(-15, -5) })
		T.expect(math.deg(yaw)).toBeNear(-15, 1e-6)
		T.expect(math.deg(pitch)).toBeNear(-5, 1e-6)
		-- (the clock jumping back is a jump too)
		yaw = HeadGaze.step(st, { now = 1, dt = FRAME, look = dir(10, 0) })
		T.expect(math.deg(yaw)).toBeNear(10, 1e-6)
	end)

	T.it("eases back to rest in its death, without the flinch", function()
		local st = HeadGaze.new(LYNX, 3)
		run(st, 0, 1, function()
			return { look = dir(25, 10), combat = true }
		end)
		local yaw, pitch, roll = run(st, 1 + FRAME, 1, function(t)
			return { dying = true, hitAt = 1.05, hitSide = "left", move = 1, phase = t % 1 }
		end)
		T.expect(math.abs(yaw) < 0.05).toBe(true)
		T.expect(math.abs(pitch) < 0.05).toBe(true)
		T.expect(math.abs(roll) < 0.05).toBe(true)
	end)

	T.it("holds while the clock stands (frozen)", function()
		local st = HeadGaze.new(RABBIT, 3)
		local y0, p0 = run(st, 0, 0.5, function()
			return { look = dir(20, 0), move = 1, phase = 0.3 }
		end)
		local y1, p1 = run(st, 0.5 + FRAME, 1, function()
			return { look = dir(-20, 0), move = 1, phase = 0.6, dt = 0 }
		end)
		T.expect(y1).toBe(y0)
		T.expect(p1).toBe(p0)
	end)
end)

T.describe("HeadGaze: calm", function()
	T.it("glances aside now and then and ahead in between, the same at every replay", function()
		local a, b = HeadGaze.new(LYNX, 7), HeadGaze.new(LYNX, 7)
		local left, right, ahead, frames = 0, 0, 0, 0
		local same = true
		run(a, 0, 60, function()
			return {}
		end, function(t, yaw)
			local other = HeadGaze.step(b, { now = t, dt = FRAME })
			if other ~= yaw then
				same = false
			end
			frames += 1
			T.expect(math.abs(math.deg(yaw)) <= LYNX.glance + 1e-6).toBe(true)
			if math.deg(yaw) > 0.4 * LYNX.glance then
				left += 1
			elseif math.deg(yaw) < -0.4 * LYNX.glance then
				right += 1
			elseif math.abs(math.deg(yaw)) < 1 then
				ahead += 1
			end
		end)
		T.expect(same).toBe(true)
		T.expect(left > frames * 0.05).toBe(true)
		T.expect(right > frames * 0.05).toBe(true)
		T.expect(ahead > frames * 0.05).toBe(true)
	end)

	T.it("glances less while it walks", function()
		local most = 0
		for k = 0, 600 do
			local yaw = HeadGaze.glance(LYNX, 7, k * 0.1, nil, 1)
			most = math.max(most, math.abs(math.deg(yaw)))
		end
		T.expect(most <= 0.4 * LYNX.glance + 1e-6).toBe(true)
		T.expect(most > 0).toBe(true)
	end)

	T.it("looks at the local player now and then when near", function()
		local at, slots = 0, 0
		for k = 0, 400 do
			local yaw = HeadGaze.glance(LYNX, 7, k * 0.5, dir(15, 0), 0)
			slots += 1
			if math.abs(math.deg(yaw) - 15) < 1e-6 then
				at += 1
			end
		end
		T.expect(at > slots * 0.1).toBe(true)
	end)

	T.it("a bird cocks its head as it glances", function()
		local tilted = 0
		for k = 0, 400 do
			local yaw, _, roll = HeadGaze.glance(CROW, 7, k * 0.3, nil, 0)
			if yaw ~= 0 then
				T.expect(roll * yaw > 0).toBe(true)
				T.expect(math.abs(math.deg(roll)) <= CROW.tilt + 1e-6).toBe(true)
				tilted += 1
			end
		end
		T.expect(tilted > 0).toBe(true)
		local _, _, still = HeadGaze.glance(LYNX, 7, 3, nil, 0)
		T.expect(still).toBe(0)
	end)

	T.it("sniffs standing still (quick nods with the nose down), not walking", function()
		local st = HeadGaze.new(RABBIT, 11)
		local most = 0
		run(st, 0, 40, function()
			return {}
		end, function(_t, _yaw, pitch)
			most = math.max(most, math.abs(pitch - st.pitch))
		end)
		T.expect(math.deg(most)).toBeBetween(0.5 * RABBIT.sniff, RABBIT.sniff + 1e-6)
		local walking = 0
		run(st, 40, 40, function()
			return { move = 1 }
		end, function(_t, _yaw, pitch)
			walking = math.max(walking, math.abs(pitch - st.pitch))
		end)
		T.expect(walking).toBe(0)
	end)

	T.it("looks ahead in a fight without a target and going home", function()
		for _, flag in { "combat", "returning" } do
			local st = HeadGaze.new(LYNX, 7)
			local yaw, pitch = run(st, 0, 3, function()
				return { [flag] = true }
			end)
			T.expect(math.abs(yaw) < 1e-3).toBe(true)
			T.expect(math.abs(pitch) < 1e-3).toBe(true)
		end
	end)

	T.it("hangs low and sways stunned, a target or not", function()
		local st = HeadGaze.new(LYNX, 7)
		local _, pitch = run(st, 0, 2, function()
			return { stun = true }
		end)
		T.expect(pitch < -0.3 * LYNX.down).toBe(true)
		-- (the target high on the right: the dazed head does not follow it)
		local yaw, high = run(st, 2, 2, function()
			return { stun = true, combat = true, look = dir(-25, 12) }
		end)
		T.expect(high < -0.3 * LYNX.down).toBe(true)
		T.expect(math.abs(yaw) <= DAZED_YAW + 1e-6).toBe(true)
	end)
end)

T.describe("HeadGaze: over the look", function()
	T.it("nods with the steps (at the gait's bumps) only while it walks", function()
		local st = HeadGaze.new(LYNX, 7)
		local most = 0
		run(st, 0, 2, function(t)
			return { combat = true, move = 1, phase = (t * 1.25) % 1, bumps = 2 }
		end, function(_t, _yaw, pitch)
			most = math.max(most, math.abs(pitch - st.pitch))
		end)
		T.expect(math.deg(most)).toBeNear(LYNX.nod, 0.05)
		local still = 0
		run(st, 2, 2, function(t)
			return { combat = true, move = 0, phase = (t * 1.25) % 1, bumps = 2 }
		end, function(_t, _yaw, pitch)
			still = math.max(still, math.abs(pitch - st.pitch))
		end)
		T.expect(still).toBe(0)
	end)

	T.it("flinches away from a blow and comes back", function()
		local function flinch(side: string): (number, number, number)
			local st = HeadGaze.new(LYNX, 7)
			local peakYaw, peakPitch = 0, 0
			local yaw = run(st, 0, 1.6, function()
				return { combat = true, hitAt = 1, hitSide = side }
			end, function(t, y, p)
				if t >= 1 and t <= 1.2 then
					if math.abs(y) > math.abs(peakYaw) then
						peakYaw = y
					end
					if math.abs(p) > math.abs(peakPitch) then
						peakPitch = p
					end
				end
			end)
			return math.deg(peakYaw), math.deg(peakPitch), yaw
		end
		local yl, pl, afterL = flinch("left")
		T.expect(yl < -0.6 * LYNX.flinch).toBe(true)
		T.expect(pl > 0).toBe(true)
		T.expect(math.abs(afterL) < 0.01).toBe(true)
		local yr = flinch("right")
		T.expect(yr > 0.6 * LYNX.flinch).toBe(true)
		local _, pf = flinch("front")
		T.expect(pf > 0.9 * LYNX.flinch).toBe(true)
		local _, pb = flinch("back")
		T.expect(pb < 0).toBe(true)
	end)

	T.it("keeps more level against the body's own pitch, not in a blow", function()
		local st = HeadGaze.new(LYNX, 7)
		local _, pitch = run(st, 0, 1, function()
			return { combat = true, bodyPitch = 0.2 }
		end)
		T.expect(pitch).toBeNear(-math.deg(LYNX.steady * 0.2), 1e-6)
		local _, acting = run(st, 1 + FRAME, 1, function()
			return { combat = true, bodyPitch = 0.2, acting = true }
		end)
		T.expect(math.abs(acting) < 1e-3).toBe(true)
	end)

	T.it("builds its turn as yaw, then pitch, then roll", function()
		local function apply(m: { number }, v: { number }): { number }
			return {
				m[1] * v[1] + m[2] * v[2] + m[3] * v[3],
				m[4] * v[1] + m[5] * v[2] + m[6] * v[3],
				m[7] * v[1] + m[8] * v[2] + m[9] * v[3],
			}
		end
		local nose = { 0, 0, -1 }
		local left = apply(HeadGaze.matrix(math.rad(30), 0, 0), nose)
		T.expect(left[1]).toBeNear(-0.5, 1e-9)
		local up = apply(HeadGaze.matrix(0, math.rad(30), 0), nose)
		T.expect(up[2]).toBeNear(0.5, 1e-9)
		local right = apply(HeadGaze.matrix(0, 0, math.rad(30)), { 1, 0, 0 })
		T.expect(right[2]).toBeNear(0.5, 1e-9)
		-- (a turn: its columns unit and square to each other)
		local m = HeadGaze.matrix(0.4, -0.3, 0.2)
		for a = 1, 3 do
			for b = 1, 3 do
				local dot = m[a] * m[b] + m[a + 3] * m[b + 3] + m[a + 6] * m[b + 6]
				T.expect(dot).toBeNear(if a == b then 1 else 0, 1e-9)
			end
		end
		-- the same as the angles one by one
		local both = apply(HeadGaze.matrix(math.rad(30), math.rad(20), 0), nose)
		T.expect(both[1]).toBeNear(-math.sin(math.rad(30)) * math.cos(math.rad(20)), 1e-9)
		T.expect(both[2]).toBeNear(math.sin(math.rad(20)), 1e-9)
	end)

	T.it("keeps every head of the data within its limits through a busy minute", function()
		for _, model in RigidRigs.gazes() do
			local o = RigidRigs.gaze(model) :: HeadGaze.Options
			local st = HeadGaze.new(o, 5)
			local extra = o.flinch + o.sniff + o.nod + o.steady * 30
			run(st, 0, 60, function(t)
				local phase = t % 20
				return {
					look = if phase >= 5 and phase < 12
						then dir(200 * math.sin(t * 0.7), 60 * math.sin(t * 1.3))
						else nil,
					notice = dir(40, 5),
					move = if phase < 8 then 1 else 0,
					phase = (t * 1.4) % 1,
					bumps = 2,
					hitAt = math.floor(t / 3) * 3,
					hitSide = ({ "front", "back", "left", "right" })[math.floor(t / 3) % 4 + 1],
					bodyPitch = 0.4 * math.sin(t * 2),
					acting = phase >= 10 and phase < 11,
					stun = phase >= 12 and phase < 14,
					dying = phase >= 18,
				}
			end, function(_t, yaw, pitch, roll)
				T.expect(yaw == yaw and pitch == pitch and roll == roll).toBe(true)
				T.expect(math.abs(math.deg(yaw)) <= o.yaw + o.flinch + 1e-6).toBe(true)
				T.expect(math.deg(pitch)).toBeBetween(-o.down - extra - 1e-6, o.up + extra + 1e-6)
				T.expect(math.abs(math.deg(roll)) <= o.tilt + 1e-6).toBe(true)
			end)
		end
	end)
end)

T.describe("HeadGaze: the budget (Config.Graphics.levels)", function()
	T.it("the lowest level turns no heads, the higher ones the nearest few within a radius", function()
		local low, medium, high = GraphicsLevel.get("low"), GraphicsLevel.get("medium"), GraphicsLevel.get("high")
		T.expect(low.heads).toBe(0)
		T.expect(medium.heads > 0 and medium.heads <= high.heads and high.heads <= 12).toBe(true)
		T.expect(medium.headRadius > 0 and medium.headRadius <= high.headRadius).toBe(true)
		T.expect(high.headRadius <= high.npcRadius).toBe(true)
	end)
end)
