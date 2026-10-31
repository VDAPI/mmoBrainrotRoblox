--!strict
-- Template animation (owner 2026-10-31, docs/ANIM-WZORCE.md §6.6): the rigged caveSpider's legs (Data/OctoRigs,
-- Logic/OctoPose, Logic/OctoMotion over its Data/RigidStyles recipe). The map is picked only by the new model's bones,
-- the bones turn the way client/Anim/RigidRig writes them, the feet stay planted in the world while it walks, trots,
-- runs and turns, the tetrads alternate, every action stays finite and strikes the ground on the server's hit, the
-- pounce tucks and splays, the deaths curl the legs in without sinking, nothing pops, and AnimLab shows every state.
local AnimLab = require("../src/shared/Logic/AnimLab")
local MonsterLooks = require("../src/shared/Data/MonsterLooks")
local NpcPose = require("../src/shared/Logic/NpcPose")
local OctoMotion = require("../src/shared/Logic/OctoMotion")
local OctoPose = require("../src/shared/Logic/OctoPose")
local OctoRigs = require("../src/shared/Data/OctoRigs")
local OctoSim = require("./OctoSim")
local RigidMotion = require("../src/shared/Logic/RigidMotion")
local RigidRigs = require("../src/shared/Data/RigidRigs")
local RigidStyles = require("../src/shared/Data/RigidStyles")
local T = require("./Test")

type Mat = { number }

local DT = 1 / 60
-- caveSpider's walk, trot (going home) and chase speeds (Data/Monsters moveSpeed 13: 0.4x, 0.7x, 1x).
local WALK, TROT, RUN = 5.2, 9.1, 13
-- The windup of its blows in AnimLab (the hit, W).
local W = 0.81

local function finite(x: number): boolean
	return x == x and x > -1e9 and x < 1e9
end

local function hasAll(dump: OctoSim.Dump): (string) -> boolean
	return function(name: string): boolean
		return dump.bones[name] ~= nil
	end
end

-- Runs `frames` frames of `input` (the game's way: the root moves), calling `each` after every frame.
local function drive(sim: OctoSim.Sim, frames: number, input: { [string]: any }, each: ((k: number) -> ())?)
	for k = 1, frames do
		local i = table.clone(input)
		if k == 1 and sim.now == 0 then
			i.snap = true
		end
		OctoSim.step(sim, DT, i, true)
		if each then
			each(k)
		end
	end
end

-- Plays the spider's action `name` from 0.3 s (hit `hit` after its start, the target ahead), AnimLab's way, calling
-- `each` with the time since its start.
local function play(name: string, hit: number, each: (sim: OctoSim.Sim, t: number) -> (), seed: number?): OctoSim.Sim
	local sim = OctoSim.new(seed)
	local style = RigidStyles.get("spider") :: RigidStyles.Style
	local action = style.actions[name]
	local run = { name = name, start = 0.3, hit = hit, reach = { 0, 0, -2 } }
	local frames = math.ceil((0.3 + RigidMotion.length(action, hit) + 0.6) / DT)
	for k = 1, frames do
		local started = sim.now + DT >= 0.3 - 1e-9
		OctoSim.step(
			sim,
			DT,
			{ combat = true, look = { 0, 0, -1 }, action = if started then run else nil, snap = k == 1 }
		)
		each(sim, sim.now - 0.3)
	end
	return sim
end

-- Rotation (row-major) about unit axis `a` by `angle` (right hand, as CFrame.fromAxisAngle).
local function axisAngle(a: { number }, angle: number): Mat
	local x, y, z = a[1], a[2], a[3]
	local c, s = math.cos(angle), math.sin(angle)
	local t = 1 - c
	return {
		t * x * x + c,
		t * x * y - s * z,
		t * x * z + s * y,
		t * x * y + s * z,
		t * y * y + c,
		t * y * z - s * x,
		t * x * z - s * y,
		t * y * z + s * x,
		t * z * z + c,
	}
end

local function apply(m: Mat, v: { number }): { number }
	return {
		m[1] * v[1] + m[2] * v[2] + m[3] * v[3],
		m[4] * v[1] + m[5] * v[2] + m[6] * v[3],
		m[7] * v[1] + m[8] * v[2] + m[9] * v[3],
	}
end

local function unit(v: { number }): { number }
	local n = math.sqrt(v[1] * v[1] + v[2] * v[2] + v[3] * v[3])
	return { v[1] / n, v[2] / n, v[3] / n }
end

T.describe("OctoMotion rig map", function()
	T.it("picks the octopod map only on the rigged spider (the old rigid model and other rigs never match)", function()
		local v2 = OctoSim.load("caveSpider_v2")
		T.expect(OctoRigs.find("caveSpider", hasAll(v2)) ~= nil).toBe(true)
		T.expect(OctoRigs.find("caveSpider", hasAll(OctoSim.load("caveSpider"))) == nil).toBe(true)
		-- the old bear has Tripo bones of the same kind: no collision
		T.expect(OctoRigs.find("caveSpider", hasAll(OctoSim.load("brownBear"))) == nil).toBe(true)
		T.expect(OctoRigs.find("desertScorpion", hasAll(v2)) == nil).toBe(true)
		-- the rigid model keeps its recipe and its mesh fold
		local look = MonsterLooks.get("caveSpider")
		T.expect(look and look.asset and look.asset.motion).toBe("spider")
		T.expect(RigidRigs.fold("caveSpider") ~= nil).toBe(true)
		for _, id in OctoRigs.models() do
			T.expect(#OctoRigs.all(id) >= 1).toBe(true)
		end
	end)

	T.it("builds seven legs and two palps from the dump, each on its side, the front pair in front", function()
		local sim = OctoSim.new()
		local skel = sim.skel
		T.expect(#skel.legs).toBe(9)
		local byName = {}
		for _, leg in skel.legs do
			byName[leg.name] = leg
			local want = if string.sub(leg.name, 1, 1) == "L" or leg.name == "PL" then -1 else 1
			T.expect(leg.side).toBe(want)
			T.expect(math.abs(leg.foot[2] - skel.ground) < 1e-6).toBe(true)
			T.expect(leg.knee >= 2 and leg.knee <= leg.n).toBe(true)
		end
		T.expect(byName.L1.hip[3] < byName.L4.hip[3]).toBe(true)
		T.expect(byName.R1.hip[3] < byName.R4.hip[3]).toBe(true)
		T.expect(byName.L1.foot[3] < byName.L1.hip[3]).toBe(true)
		T.expect(byName.L4.foot[3] > byName.L4.hip[3]).toBe(true)
		T.expect(#skel.fangs).toBe(3)
		T.expect(skel.abdomen ~= nil).toBe(true)
		T.expect(skel.hipH > 0.3 * sim.rigid.body.h).toBe(true)
	end)
end)

T.describe("OctoPose legs", function()
	T.it("puts the foot on any target within reach (inverse kinematics)", function()
		local sim = OctoSim.new()
		for _, leg in sim.skel.legs do
			local c = table.create(leg.n, 0)
			local x, y, z = OctoPose.foot(leg, 0, c)
			T.expect(math.abs(x - leg.foot[1]) + math.abs(y - leg.foot[2]) + math.abs(z - leg.foot[3]) < 1e-6)
				.toBe(true)
			for k = 1, 12 do
				local s = 0.2 * leg.span
				local tx = leg.foot[1] + s * math.sin(k * 1.7)
				local ty = leg.foot[2] + 0.4 * s * math.max(0, math.sin(k * 2.3))
				local tz = leg.foot[3] + s * math.cos(k * 1.3)
				local psi, a, b = OctoPose.solve(leg, tx, ty, tz, 0, 0, 40)
				OctoPose.turns(leg, a, b, c)
				local fx, fy, fz = OctoPose.foot(leg, psi, c)
				local miss = math.sqrt((fx - tx) ^ 2 + (fy - ty) ^ 2 + (fz - tz) ^ 2)
				if miss > 1e-3 then
					error(`{leg.name}: missed ({tx}, {ty}, {tz}) by {miss}`)
				end
			end
		end
	end)

	T.it("turns each bone by rest^-1 * R(axis, angle) * rest (the bones' world as Roblox chains them)", function()
		local sim = OctoSim.new()
		local state = 31
		local function rnd(lo: number, hi: number): number
			state = (state * 1103515245 + 12345) % 2147483648
			return lo + (hi - lo) * state / 2147483648
		end
		local function randomRot(): Mat
			return axisAngle(unit({ rnd(-1, 1), rnd(-1, 1), rnd(-1, 1) }), rnd(0, 6))
		end
		for _, leg in sim.skel.legs do
			-- rest frames (non-identity, as the Studio import has them) and joint positions
			local rest: { Mat } = {}
			for j = 1, leg.n do
				rest[j] = randomRot()
			end
			local restPts = OctoPose.joints(leg, 0, table.create(leg.n, 0), {})
			local c = table.create(leg.n, 0)
			local psi = rnd(-0.6, 0.6)
			for j = 1, leg.n do
				c[j] = rnd(-0.8, 0.8)
			end
			-- the rig's Transforms: the yaw and the bend axis turned into each bone's own axes
			local n = { leg.ax, 0, leg.az }
			local tr: { Mat } = {}
			for j = 1, leg.n do
				local wt = NpcPose.transpose(rest[j])
				local bend = axisAngle(apply(wt, n), c[j])
				tr[j] = if j == 1 then NpcPose.mul(axisAngle(apply(wt, { 0, 1, 0 }), psi), bend) else bend
			end
			-- Roblox: world_j = world_parent * (rest_parent^-1 * rest_j) * Transform_j; the body stays at rest
			local rot: Mat = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
			local parentRest: Mat = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
			local pos = { restPts[1][1], restPts[1][2], restPts[1][3] }
			local want = OctoPose.joints(leg, psi, c, {})
			for j = 1, leg.n do
				if j > 1 then
					local off = apply(NpcPose.transpose(parentRest), {
						restPts[j][1] - restPts[j - 1][1],
						restPts[j][2] - restPts[j - 1][2],
						restPts[j][3] - restPts[j - 1][3],
					})
					local d = apply(rot, off)
					pos = { pos[1] + d[1], pos[2] + d[2], pos[3] + d[3] }
				end
				local p = want[j]
				local err = math.abs(pos[1] - p[1]) + math.abs(pos[2] - p[2]) + math.abs(pos[3] - p[3])
				if err > 1e-6 then
					error(`{leg.name} joint {j}: {err}`)
				end
				rot = NpcPose.mul(NpcPose.mul(rot, NpcPose.mul(NpcPose.transpose(parentRest), rest[j])), tr[j])
				parentRest = rest[j]
			end
			-- the foot, in the last bone's frame
			local last = restPts[leg.n]
			local tip = restPts[leg.n + 1]
			local d = apply(
				rot,
				apply(NpcPose.transpose(parentRest), {
					tip[1] - last[1],
					tip[2] - last[2],
					tip[3] - last[3],
				})
			)
			local p = want[leg.n + 1]
			local err = math.abs(pos[1] + d[1] - p[1]) + math.abs(pos[2] + d[2] - p[2]) + math.abs(pos[3] + d[3] - p[3])
			T.expect(err < 1e-6).toBe(true)
		end
		-- a fang opening swings its tip forward (-Z), the abdomen's pump lifts a chain pointing back
		for _, fang in sim.skel.fangs do
			local tip = apply(axisAngle(fang.axis[1], 0.3), { 0, -1, 0 })
			T.expect(tip[3] < -0.2).toBe(true)
		end
		local abdomen = sim.skel.abdomen :: OctoPose.Turn
		T.expect(apply(axisAngle(abdomen.axis[1], 0.3), { 0, 0, 1 })[2] > 0.2).toBe(true)
	end)
end)

T.describe("OctoMotion gait", function()
	T.it("keeps every foot on the ground where it landed while it walks, trots, runs and turns", function()
		for _, case in
			{
				{ speed = WALK, gait = "walk", yaw = 0 },
				{ speed = TROT, gait = "trot", yaw = 0 },
				{ speed = RUN, gait = "run", yaw = 0 },
				{ speed = WALK, gait = "walk", yaw = 1.2 },
				{ speed = RUN, gait = "run", yaw = -1.5 },
			}
		do
			local sim = OctoSim.new()
			local last: { [number]: { number } } = {}
			local minDown, worstSlide, worstMiss, lifts = math.huge, 0, 0, 0
			drive(sim, 300, { speed = case.speed, gait = case.gait, yawRate = case.yaw }, function(k)
				local down = 0
				for i, f in sim.octo.feet do
					local wx, wz = OctoSim.world(sim, f.px, f.pz)
					local was = last[i]
					if f.down then
						down += 1
						if was and was[3] == 1 then
							worstSlide = math.max(worstSlide, math.abs(wx - was[1]) + math.abs(wz - was[2]))
						end
						if k > 30 then
							local x, y, z = OctoSim.foot(sim, i)
							worstMiss = math.max(worstMiss, math.sqrt((x - f.px) ^ 2 + (y - f.py) ^ 2 + (z - f.pz) ^ 2))
						end
					elseif was and was[3] == 1 then
						lifts += 1
					end
					last[i] = { wx, wz, if f.down then 1 else 0 }
				end
				if k > 30 then
					minDown = math.min(minDown, down)
				end
			end)
			local label = `{case.gait} {case.yaw}`
			if worstSlide > 1e-6 then
				error(`{label}: a planted foot slid {worstSlide}`)
			end
			if worstMiss > 0.03 then
				error(`{label}: a planted foot drawn {worstMiss} off its point`)
			end
			-- seven walking legs: a tetrad of three always stands
			T.expect(minDown >= 3).toBe(true)
			T.expect(lifts >= 20).toBe(true)
		end
	end)

	T.it("alternates the tetrads at a walk and carries the palps up while it moves", function()
		local sim = OctoSim.new()
		local both = 0
		local palpsUp = true
		drive(sim, 300, { speed = WALK, gait = "walk" }, function(k)
			local g0, g1 = false, false
			for i, f in sim.octo.feet do
				local leg = sim.skel.legs[i]
				if leg.palp then
					if k > 60 then
						palpsUp = palpsUp and not f.down
					end
				elseif not f.down then
					if leg.group == 0 then
						g0 = true
					else
						g1 = true
					end
				end
			end
			if k > 30 and g0 and g1 then
				both += 1
			end
		end)
		T.expect(both).toBe(0)
		T.expect(palpsUp).toBe(true)
	end)

	T.it("turns in place by stepping, and settles its legs back under the body when it stops", function()
		local sim = OctoSim.new()
		local lifts, minDown = 0, math.huge
		local was: { boolean } = {}
		drive(sim, 180, { yawRate = 2.4 }, function(k)
			local down = 0
			for i, f in sim.octo.feet do
				if f.down then
					down += 1
				elseif was[i] and not sim.skel.legs[i].palp then
					lifts += 1
				end
				was[i] = f.down
			end
			if k > 30 then
				minDown = math.min(minDown, down)
			end
		end)
		T.expect(lifts >= 10).toBe(true)
		T.expect(minDown >= 3).toBe(true)
		-- it stops: within two seconds every foot stands near its rest point again
		drive(sim, 120, {})
		local skel = sim.skel
		local m = (sim.posed :: RigidMotion.Posed).m
		for i, leg in skel.legs do
			local f = sim.octo.feet[i]
			local x, _, z =
				m[1] * leg.foot[1] + m[3] * leg.foot[3] + m[10], 0, m[7] * leg.foot[1] + m[9] * leg.foot[3] + m[12]
			local d = math.sqrt((f.px - x) ^ 2 + (f.pz - z) ^ 2)
			if d > 0.3 * skel.span then
				error(`{leg.name} stands {d} from its rest point`)
			end
		end
	end)

	T.it("shifts a leg now and then in the idle and trembles stunned, holds still frozen", function()
		local sim = OctoSim.new()
		local shifts = 0
		local was: { boolean } = {}
		drive(sim, 600, {}, function()
			for i, f in sim.octo.feet do
				if was[i] and not f.down then
					shifts += 1
				end
				was[i] = f.down
			end
		end)
		T.expect(shifts >= 2).toBe(true)
		-- stunned: the knees shake
		local moved = 0
		local prev = table.clone(sim.octo.feet[2].c)
		drive(sim, 60, { stun = true }, function()
			local c = sim.octo.feet[2].c
			for j = 1, #c do
				moved = math.max(moved, math.abs(c[j] - prev[j]))
			end
			prev = table.clone(c)
		end)
		T.expect(moved > 1e-3).toBe(true)
		-- frozen: nothing moves
		drive(sim, 2, { frozen = true })
		local held = table.clone(sim.octo.feet[2].c)
		local psi = sim.octo.feet[2].psi
		drive(sim, 30, { frozen = true })
		for j = 1, #held do
			T.expect(sim.octo.feet[2].c[j]).toBe(held[j])
		end
		T.expect(sim.octo.feet[2].psi).toBe(psi)
	end)

	T.it("stands its feet on a sloped ground and tilts the body with them", function()
		local slope = 0.15
		local function stand(probe: ((x: number, z: number) -> number?)?): OctoSim.Sim
			local sim = OctoSim.new()
			local octoIn: OctoMotion.Input = { ground = probe }
			for k = 1, 240 do
				sim.now += DT
				local input: any = { now = sim.now, dt = DT, speed = 0, yawRate = 0, combat = false, snap = k == 1 }
				local posed = RigidMotion.step(sim.rigid, input)
				OctoMotion.step(sim.octo, sim.rigid, input, posed, octoIn)
				sim.posed = posed
			end
			return sim
		end
		local sloped = stand(function(_x: number, z: number): number?
			return -slope * z
		end)
		local flat = stand(nil)
		for _, f in sloped.octo.feet do
			T.expect(math.abs(f.py + slope * f.pz) < 0.02).toBe(true)
		end
		-- the ground rises toward the front (-Z): the nose comes up
		T.expect(sloped.octo.tiltP > 0.02).toBe(true)
		T.expect(flat.octo.tiltP).toBe(0)
		local a, b = (sloped.posed :: RigidMotion.Posed).m, (flat.posed :: RigidMotion.Posed).m
		T.expect(a[8] - b[8] > 0.02).toBe(true)
	end)
end)

T.describe("OctoMotion actions", function()
	T.it(
		"plays every action of the spider finite, and the stabs strike the ground ahead on the server's hit",
		function()
			local style = RigidStyles.get("spider") :: RigidStyles.Style
			for name, action in style.actions do
				local hit = if action.hold then action.strike else W
				local atHit = false
				play(name, hit, function(sim, t)
					for i, f in sim.octo.feet do
						for j = 1, #f.c do
							if not finite(f.c[j]) then
								error(`{name}: leg {i} joint {j} not finite at {t}`)
							end
						end
						T.expect(finite(f.psi)).toBe(true)
					end
					for _, v in (sim.posed :: RigidMotion.Posed).m do
						T.expect(finite(v)).toBe(true)
					end
					T.expect(finite(sim.octo.fang) and finite(sim.octo.pump)).toBe(true)
					if math.abs(t - hit) < DT / 2 + 1e-9 and (name == "bite" or name == "heavy" or name == "crush") then
						atHit = true
						local c = sim.rigid.c
						T.expect((c.stab or 0) >= 0.95).toBe(true)
						T.expect((c.fang or 0) < -0.2).toBe(true)
						-- the front pair on the ground ahead of their rest points
						for _, i in { 2, 7 } do
							local _, y, z = OctoSim.foot(sim, i)
							if math.abs(y - sim.skel.ground) > 0.1 then
								error(`{name}: {sim.skel.legs[i].name} {y} off the ground on the hit`)
							end
							T.expect(z < sim.skel.legs[i].hip[3]).toBe(true)
						end
					end
				end)
				if name == "bite" or name == "heavy" or name == "crush" then
					T.expect(atHit).toBe(true)
				end
			end
		end
	)

	T.it("rears up with the front legs raised and waving before the bite and the alert", function()
		for _, name in { "alert", "bite", "heavy", "crush" } do
			local high, waved = 0, {}
			local hipH = 0
			play(name, W, function(sim, t)
				hipH = sim.skel.hipH
				if t > 0.25 and t < W - 0.2 then
					local _, y = OctoSim.foot(sim, 2)
					high = math.max(high, y)
					table.insert(waved, sim.octo.feet[2].psi)
				end
			end)
			if high < 1.5 * hipH then
				error(`{name}: the front leg only rose to {high}`)
			end
			if name ~= "bite" then
				local lo, hi = math.huge, -math.huge
				for _, v in waved do
					lo, hi = math.min(lo, v), math.max(hi, v)
				end
				T.expect(hi - lo > 0.05).toBe(true)
			end
		end
	end)

	T.it("pounces with the legs drawn in on the flight and splayed on the landing", function()
		local tucked, landed = false, false
		local restMean = 0
		play("pounce", W, function(sim, t)
			local skel = sim.skel
			if restMean == 0 then
				for _, leg in skel.legs do
					restMean += math.sqrt((leg.foot[1] - skel.cx) ^ 2 + (leg.foot[3] - skel.cz) ^ 2) / #skel.legs
				end
			end
			local strike = 0.4
			if math.abs(t - (W - strike * 0.45)) < DT / 2 + 1e-9 then
				-- mid-flight: off the ground, curled in
				tucked = true
				T.expect(sim.octo.tuck > 0.8).toBe(true)
				for i, f in sim.octo.feet do
					T.expect(f.down).toBe(false)
					T.expect(f.airborne).toBe(true)
					local _, y = OctoSim.foot(sim, i)
					T.expect(y > skel.ground).toBe(true)
				end
			elseif math.abs(t - (W + 0.1)) < DT / 2 + 1e-9 then
				landed = true
				T.expect((sim.rigid.c.splay or 0) > 0.6).toBe(true)
				local m = (sim.posed :: RigidMotion.Posed).m
				local bx, bz = m[1] * skel.cx + m[3] * skel.cz + m[10], m[7] * skel.cx + m[9] * skel.cz + m[12]
				local mean, down = 0, 0
				for i, f in sim.octo.feet do
					if not skel.legs[i].palp then
						mean += math.sqrt((f.px - bx) ^ 2 + (f.pz - bz) ^ 2) / 7
						down += if f.down then 1 else 0
					end
				end
				T.expect(down >= 6).toBe(true)
				T.expect(mean > restMean).toBe(true)
			end
		end)
		T.expect(tucked and landed).toBe(true)
	end)

	T.it("curls the legs in over the body in both deaths and never sinks a joint under the ground", function()
		for _, name in { "deathFlip", "deathCurl" } do
			local style = RigidStyles.get("spider") :: RigidStyles.Style
			local action = style.actions[name]
			local low = math.huge
			local sim = play(name, action.strike, function(sim, t)
				if t > 0 then
					for i in sim.octo.feet do
						for _, p in OctoSim.joints(sim, i) do
							low = math.min(low, p[2])
						end
					end
				end
			end)
			if low < sim.skel.ground - 0.05 then
				error(`{name}: a joint {low} under the ground`)
			end
			-- held: every leg in its curl (the fold at 1)
			for i, leg in sim.skel.legs do
				local f = sim.octo.feet[i]
				for j = 1, leg.n do
					if math.abs(f.c[j] - leg.curl[j]) > 0.25 then
						error(`{name}: {leg.name} joint {j} at {f.c[j]}, curl {leg.curl[j]}`)
					end
				end
				-- the foot drawn in toward the body (closer to the hip than at rest)
				local x, _, z = OctoPose.foot(leg, f.psi, f.c)
				local d = math.sqrt((x - leg.hip[1]) ^ 2 + (z - leg.hip[3]) ^ 2)
				T.expect(d < 0.8 * leg.span).toBe(true)
			end
		end
	end)

	T.it("gives RigidMotion the box of the curled legs: lower and narrower as they fold", function()
		local sim = OctoSim.new()
		local folds = sim.rigid.body.folds :: { RigidMotion.Fold }
		T.expect(#folds).toBe(9)
		T.expect(math.abs(folds[1].h - sim.rigid.body.h) < 1e-6).toBe(true)
		T.expect(math.abs(folds[1].W - sim.rigid.body.W) < 1e-6).toBe(true)
		T.expect(folds[9].W < folds[1].W).toBe(true)
		T.expect(folds[9].lift > folds[1].lift).toBe(true)
	end)

	T.it("moves every joint smoothly (no pops) through the gaits and the actions", function()
		local function watch(sim: OctoSim.Sim, label: string): (number) -> ()
			local last: { { number } } = {}
			return function(k: number)
				for i, f in sim.octo.feet do
					local prev = last[i]
					if prev and k > 3 then
						for j = 1, #f.c do
							local d = math.abs(f.c[j] - prev[j])
							if d > 0.6 then
								error(`{label}: {sim.skel.legs[i].name} joint {j} jumped {d} at frame {k}`)
							end
						end
						if math.abs(f.psi - prev[#f.c + 1]) > 0.6 then
							error(`{label}: {sim.skel.legs[i].name} yaw jumped at frame {k}`)
						end
					end
					local copy = table.clone(f.c)
					table.insert(copy, f.psi)
					last[i] = copy
				end
			end
		end
		for _, case in { { WALK, "walk", 0 }, { RUN, "run", 0 }, { 0, nil, 2.4 }, { TROT, "trot", 1.5 } } do
			local sim = OctoSim.new()
			drive(sim, 240, { speed = case[1], gait = case[2], yawRate = case[3] }, watch(sim, `{case[2]} {case[3]}`))
		end
		local style = RigidStyles.get("spider") :: RigidStyles.Style
		for name, action in style.actions do
			if name ~= "spawn" and name ~= "summon" then
				local k = 0
				local check: ((number) -> ())? = nil
				play(name, if action.hold then action.strike else W, function(sim)
					k += 1
					if not check then
						check = watch(sim, name)
					end
					(check :: (number) -> ())(k)
				end)
			end
		end
	end)
end)

T.describe("OctoMotion in AnimLab", function()
	T.it("shows every state of the rigged spider (the ground running under the standing look)", function()
		local style = RigidStyles.get("spider") :: RigidStyles.Style
		for _, state in RigidStyles.labStates("spider") do
			local command, err = AnimLab.parse({ "mob", "caveSpider", state })
			if not command then
				error(`/animlab mob caveSpider {state}: {err}`)
			end
			local slots: { [string]: string? } = {
				attack1 = style.basic[1],
				attack2 = style.basic[2] or style.basic[1],
				cast = style.abilities.poisonPool,
				alert = style.aggro,
				heavy = style.abilities.heavyBlow,
				crush = style.abilities.crush,
				pounce = style.abilities.pounce,
				throw = style.throw,
				spawn = style.spawn,
				summon = style.summon,
				death = style.death[1].name,
			}
			local name = slots[state] or state
			local action = style.actions[name]
			local sim = OctoSim.new()
			for k = 1, 200 do
				local t = k * DT
				local i: { [string]: any } = { combat = true, snap = k == 1 }
				if action then
					i.action = { name = name, start = 0, hit = if action.hold then action.strike else W }
				elseif state == "walk" then
					i.speed, i.gait, i.combat = WALK, "walk", false
				elseif state == "trot" or state == "home" then
					i.speed, i.gait, i.combat = TROT, "trot", false
				elseif state == "run" then
					i.speed, i.gait = RUN, "run"
				elseif state == "turn" then
					i.yawRate = 2.4
				elseif state == "stun" then
					i.stun = t >= 0.3
				elseif state == "freeze" then
					i.frozen = t > 0.8
				elseif string.sub(state, 1, 3) == "hit" then
					i.hitAt, i.hitSide =
						0.2, ({ hit = "front", hitBack = "back", hitLeft = "left", hitRight = "right" })[state]
				elseif state == "idle" then
					i.combat = false
				end
				-- AnimLab: the look stands, no root move
				OctoSim.step(sim, DT, i, false)
				for _, f in sim.octo.feet do
					for j = 1, #f.c do
						if not finite(f.c[j]) then
							error(`{state}: not finite`)
						end
					end
				end
			end
		end
	end)
end)
